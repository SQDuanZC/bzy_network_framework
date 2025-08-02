import 'dart:async';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'interceptor_manager.dart';

/// 拦截器执行超时配置
class ExecutionTimeoutConfig {
  /// 是否启用执行超时控制
  final bool enabled;
  
  /// 默认执行超时时间
  final Duration defaultTimeout;
  
  /// 最大执行超时时间
  final Duration maxTimeout;
  
  /// 最小执行超时时间
  final Duration minTimeout;
  
  /// 超时后是否继续执行后续拦截器
  final bool continueOnTimeout;
  
  /// 是否记录超时统计
  final bool enableStatistics;
  
  /// 超时警告阈值（超过此时间会记录警告）
  final Duration warningThreshold;
  
  const ExecutionTimeoutConfig({
    this.enabled = true,
    this.defaultTimeout = const Duration(seconds: 10),
    this.maxTimeout = const Duration(seconds: 30),
    this.minTimeout = const Duration(milliseconds: 100),
    this.continueOnTimeout = true,
    this.enableStatistics = true,
    this.warningThreshold = const Duration(seconds: 5),
  });
}

/// 拦截器执行超时处理策略
enum ExecutionTimeoutStrategy {
  /// 立即中断
  interrupt,
  /// 继续执行但记录警告
  continueWithWarning,
  /// 跳过当前拦截器继续执行
  skipAndContinue,
}

/// 拦截器执行超时管理器
class ExecutionTimeoutManager {
  static ExecutionTimeoutManager? _instance;
  static ExecutionTimeoutManager get instance {
    _instance ??= ExecutionTimeoutManager._();
    return _instance!;
  }
  
  ExecutionTimeoutManager._();
  
  final Logger _logger = Logger('ExecutionTimeoutManager');
  final ExecutionTimeoutConfig _config = const ExecutionTimeoutConfig();
  
  /// 超时统计
  final Map<String, ExecutionTimeoutStats> _stats = {};
  
  /// 活跃的执行任务
  final Map<String, Timer> _activeTimers = {};
  
  /// 执行拦截器方法并应用超时控制
  Future<T> executeWithTimeout<T>(
    String interceptorName,
    Future<T> Function() execution, {
    Duration? customTimeout,
    ExecutionTimeoutStrategy strategy = ExecutionTimeoutStrategy.continueWithWarning,
  }) async {
    if (!_config.enabled) {
      return await execution();
    }
    
    final timeout = customTimeout ?? _config.defaultTimeout;
    final taskId = '${interceptorName}_${DateTime.now().millisecondsSinceEpoch}';
    
    final completer = Completer<T>();
    final startTime = DateTime.now();
    
    // 设置超时定时器
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        final duration = DateTime.now().difference(startTime);
        _recordTimeout(interceptorName, duration, timeout);
        
        switch (strategy) {
          case ExecutionTimeoutStrategy.interrupt:
            completer.completeError(
              TimeoutException('拦截器 "$interceptorName" 执行超时', timeout)
            );
            break;
          case ExecutionTimeoutStrategy.continueWithWarning:
            _logger.warning('拦截器 "$interceptorName" 执行超时 ${duration.inMilliseconds}ms，但继续等待完成');
            break;
          case ExecutionTimeoutStrategy.skipAndContinue:
            _logger.warning('拦截器 "$interceptorName" 执行超时，跳过并继续');
            completer.completeError(
              InterceptorSkippedException('拦截器执行超时，已跳过')
            );
            break;
        }
      }
    });
    
    _activeTimers[taskId] = timer;
    
    try {
      // 执行拦截器方法
      final result = await execution();
      
      if (!completer.isCompleted) {
        final duration = DateTime.now().difference(startTime);
        _recordExecution(interceptorName, duration, true);
        
        // 检查是否超过警告阈值
        if (duration > _config.warningThreshold) {
          _logger.warning('拦截器 "$interceptorName" 执行时间较长: ${duration.inMilliseconds}ms');
        }
        
        completer.complete(result);
      }
      
      return result;
    } catch (e) {
      if (!completer.isCompleted) {
        final duration = DateTime.now().difference(startTime);
        _recordExecution(interceptorName, duration, false);
        completer.completeError(e);
      }
      rethrow;
    } finally {
      timer.cancel();
      _activeTimers.remove(taskId);
    }
  }
  
  /// 记录执行统计
  void _recordExecution(String interceptorName, Duration duration, bool success) {
    if (!_config.enableStatistics) return;
    
    _stats.putIfAbsent(interceptorName, () => ExecutionTimeoutStats());
    final stats = _stats[interceptorName]!;
    
    stats.totalExecutions++;
    stats.totalDuration += duration;
    
    if (success) {
      stats.successfulExecutions++;
    } else {
      stats.failedExecutions++;
    }
    
    if (duration > stats.maxDuration) {
      stats.maxDuration = duration;
    }
    
    if (stats.minDuration == Duration.zero || duration < stats.minDuration) {
      stats.minDuration = duration;
    }
  }
  
  /// 记录超时统计
  void _recordTimeout(String interceptorName, Duration actualDuration, Duration timeoutDuration) {
    if (!_config.enableStatistics) return;
    
    _stats.putIfAbsent(interceptorName, () => ExecutionTimeoutStats());
    final stats = _stats[interceptorName]!;
    
    stats.timeoutCount++;
    stats.lastTimeoutTime = DateTime.now();
    
    _logger.severe('拦截器 "$interceptorName" 执行超时: '
        '实际耗时=${actualDuration.inMilliseconds}ms, '
        '超时限制=${timeoutDuration.inMilliseconds}ms');
  }
  
  /// 获取拦截器执行统计
  Map<String, ExecutionTimeoutStats> getExecutionStats() {
    return Map.unmodifiable(_stats);
  }
  
  /// 获取特定拦截器的统计
  ExecutionTimeoutStats? getInterceptorStats(String interceptorName) {
    return _stats[interceptorName];
  }
  
  /// 清理统计数据
  void clearStats([String? interceptorName]) {
    if (interceptorName != null) {
      _stats.remove(interceptorName);
    } else {
      _stats.clear();
    }
  }
  
  /// 取消所有活跃的超时定时器
  void cancelAllTimers() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
  }
  
  /// 获取当前活跃的执行任务数量
  int get activeTaskCount => _activeTimers.length;
}

/// 拦截器执行统计
class ExecutionTimeoutStats {
  int totalExecutions = 0;
  int successfulExecutions = 0;
  int failedExecutions = 0;
  int timeoutCount = 0;
  Duration totalDuration = Duration.zero;
  Duration maxDuration = Duration.zero;
  Duration minDuration = Duration.zero;
  DateTime? lastTimeoutTime;
  
  /// 平均执行时间
  Duration get averageDuration {
    if (totalExecutions == 0) return Duration.zero;
    return Duration(microseconds: totalDuration.inMicroseconds ~/ totalExecutions);
  }
  
  /// 成功率
  double get successRate {
    if (totalExecutions == 0) return 0.0;
    return successfulExecutions / totalExecutions;
  }
  
  /// 超时率
  double get timeoutRate {
    if (totalExecutions == 0) return 0.0;
    return timeoutCount / totalExecutions;
  }
  
  Map<String, dynamic> toJson() {
    return {
      'totalExecutions': totalExecutions,
      'successfulExecutions': successfulExecutions,
      'failedExecutions': failedExecutions,
      'timeoutCount': timeoutCount,
      'averageDuration': averageDuration.inMilliseconds,
      'maxDuration': maxDuration.inMilliseconds,
      'minDuration': minDuration.inMilliseconds,
      'successRate': successRate,
      'timeoutRate': timeoutRate,
      'lastTimeoutTime': lastTimeoutTime?.toIso8601String(),
    };
  }
}

/// 拦截器跳过异常
class InterceptorSkippedException implements Exception {
  final String message;
  
  const InterceptorSkippedException(this.message);
  
  @override
  String toString() => 'InterceptorSkippedException: $message';
}

/// 增强的拦截器基类，支持执行超时控制
abstract class TimeoutAwareInterceptor extends PluginInterceptor {
  /// 执行超时配置
  ExecutionTimeoutConfig get timeoutConfig => const ExecutionTimeoutConfig();
  
  /// 超时处理策略
  ExecutionTimeoutStrategy get timeoutStrategy => ExecutionTimeoutStrategy.continueWithWarning;
  
  @override
  Future<RequestOptions> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    return await ExecutionTimeoutManager.instance.executeWithTimeout(
      name,
      () => onRequestWithTimeout(options, handler),
      customTimeout: timeoutConfig.defaultTimeout,
      strategy: timeoutStrategy,
    );
  }
  
  @override
  Future<Response> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    return await ExecutionTimeoutManager.instance.executeWithTimeout(
      name,
      () => onResponseWithTimeout(response, handler),
      customTimeout: timeoutConfig.defaultTimeout,
      strategy: timeoutStrategy,
    );
  }
  
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    return await ExecutionTimeoutManager.instance.executeWithTimeout(
      name,
      () => onErrorWithTimeout(err, handler),
      customTimeout: timeoutConfig.defaultTimeout,
      strategy: timeoutStrategy,
    );
  }
  
  /// 子类需要实现的超时感知方法
  Future<RequestOptions> onRequestWithTimeout(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    return options;
  }
  
  Future<Response> onResponseWithTimeout(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    return response;
  }
  
  Future<void> onErrorWithTimeout(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // 默认实现
  }
}