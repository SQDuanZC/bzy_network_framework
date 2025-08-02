import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'interceptor_manager.dart';
import '../config/network_config.dart';
import '../network/network_adapter.dart';
import '../network/network_connectivity_monitor.dart';

/// 连接超时拦截器配置
class TimeoutInterceptorConfig {
  /// 是否启用超时拦截器
  final bool enabled;
  
  /// 是否启用动态超时调整
  final bool enableDynamicTimeout;
  
  /// 是否启用网络质量检测
  final bool enableNetworkQualityCheck;
  
  /// 基础连接超时时间（毫秒）
  final int baseConnectTimeout;
  
  /// 基础接收超时时间（毫秒）
  final int baseReceiveTimeout;
  
  /// 基础发送超时时间（毫秒）
  final int baseSendTimeout;
  
  /// 超时重试次数
  final int timeoutRetryCount;
  
  /// 超时重试间隔（毫秒）
  final int timeoutRetryDelay;
  
  /// 是否启用指数退避重试
  final bool enableExponentialBackoff;
  
  /// 最大超时时间（毫秒）
  final int maxTimeout;
  
  /// 最小超时时间（毫秒）
  final int minTimeout;
  
  /// 超时错误处理策略
  final TimeoutErrorStrategy errorStrategy;

  const TimeoutInterceptorConfig({
    this.enabled = true,
    this.enableDynamicTimeout = true,
    this.enableNetworkQualityCheck = true,
    this.baseConnectTimeout = 15000,
    this.baseReceiveTimeout = 30000,
    this.baseSendTimeout = 30000,
    this.timeoutRetryCount = 2,
    this.timeoutRetryDelay = 1000,
    this.enableExponentialBackoff = true,
    this.maxTimeout = 120000,
    this.minTimeout = 3000,
    this.errorStrategy = TimeoutErrorStrategy.retryWithBackoff,
  });
}

/// 超时错误处理策略
enum TimeoutErrorStrategy {
  /// 立即失败
  failImmediately,
  /// 重试
  retry,
  /// 带退避的重试
  retryWithBackoff,
  /// 调整超时后重试
  adjustTimeoutAndRetry,
}

/// 连接超时拦截器
class TimeoutInterceptor extends PluginInterceptor {
  final TimeoutInterceptorConfig _config;
  final Logger _logger = Logger('TimeoutInterceptor');
  final NetworkAdapter _networkAdapter;
  final NetworkConnectivityMonitor _connectivityMonitor;
  
  /// 超时统计
  final Map<String, int> _timeoutCounts = {};
  final Map<String, DateTime> _lastTimeoutTime = {};
  
  TimeoutInterceptor({
    TimeoutInterceptorConfig? config,
    NetworkAdapter? networkAdapter,
    NetworkConnectivityMonitor? connectivityMonitor,
  }) : _config = config ?? const TimeoutInterceptorConfig(),
        _networkAdapter = networkAdapter ?? NetworkAdapter(),
        _connectivityMonitor = connectivityMonitor ?? NetworkConnectivityMonitor();

  @override
  String get name => 'timeout';

  @override
  String get version => '1.0.0';

  @override
  String get description => '连接超时拦截器';

  @override
  bool get supportsRequestInterception => true;

  @override
  bool get supportsErrorInterception => true;

  @override
  Future<RequestOptions> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_config.enabled) {
      return options;
    }

    try {
      // 动态调整超时时间
      if (_config.enableDynamicTimeout) {
        await _adjustTimeouts(options);
      } else {
        // 使用基础超时配置
        _applyBaseTimeouts(options);
      }

      _logger.fine('Applied timeouts - Connect: ${options.connectTimeout}ms, '
          'Receive: ${options.receiveTimeout}ms, Send: ${options.sendTimeout}ms');
      
      return options;
    } catch (e) {
      _logger.severe('Error adjusting timeouts: $e');
      // 发生错误时使用基础配置
      _applyBaseTimeouts(options);
      return options;
    }
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_config.enabled) {
      return;
    }

    try {
      // 检查是否为超时错误
      if (_isTimeoutError(err)) {
        _logger.warning('Timeout error detected: ${err.message}');
        
        final url = err.requestOptions.uri.toString();
        _recordTimeout(url);
        
        // 根据策略处理超时错误
        final shouldRetry = await _handleTimeoutError(err);
        
        if (shouldRetry) {
          _logger.info('Retrying request after timeout');
          // 这里不直接重试，而是让重试拦截器处理
          return;
        }
      }
    } catch (e) {
      _logger.severe('Error handling timeout: $e');
    }
  }

  /// 动态调整超时时间
  Future<void> _adjustTimeouts(RequestOptions options) async {
    Duration? recommendedTimeout;
    
    // 检查网络质量
    if (_config.enableNetworkQualityCheck) {
      try {
        final quality = await _networkAdapter.checkNetworkQuality();
        recommendedTimeout = _networkAdapter.getRecommendedTimeout(
          baseTimeout: Duration(milliseconds: _config.baseConnectTimeout),
        );
        
        _logger.fine('Network quality: ${quality.qualityLevel}, '
            'Recommended timeout: ${recommendedTimeout.inMilliseconds}ms');
      } catch (e) {
        _logger.warning('Failed to check network quality: $e');
      }
    }
    
    // 应用推荐的超时时间
    if (recommendedTimeout != null) {
      final timeoutMs = recommendedTimeout.inMilliseconds
          .clamp(_config.minTimeout, _config.maxTimeout);
      
      options.connectTimeout = Duration(milliseconds: timeoutMs);
      options.receiveTimeout = Duration(milliseconds: (timeoutMs * 2).clamp(_config.minTimeout, _config.maxTimeout));
      options.sendTimeout = Duration(milliseconds: timeoutMs);
    } else {
      _applyBaseTimeouts(options);
    }
  }

  /// 应用基础超时配置
  void _applyBaseTimeouts(RequestOptions options) {
    options.connectTimeout = Duration(milliseconds: _config.baseConnectTimeout);
    options.receiveTimeout = Duration(milliseconds: _config.baseReceiveTimeout);
    options.sendTimeout = Duration(milliseconds: _config.baseSendTimeout);
  }

  /// 检查是否为超时错误
  bool _isTimeoutError(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
           err.type == DioExceptionType.receiveTimeout ||
           err.type == DioExceptionType.sendTimeout ||
           (err.error is SocketException && 
            (err.error as SocketException).message.contains('timed out'));
  }

  /// 记录超时统计
  void _recordTimeout(String url) {
    _timeoutCounts[url] = (_timeoutCounts[url] ?? 0) + 1;
    _lastTimeoutTime[url] = DateTime.now();
  }

  /// 处理超时错误
  Future<bool> _handleTimeoutError(DioException err) async {
    final url = err.requestOptions.uri.toString();
    final timeoutCount = _timeoutCounts[url] ?? 0;
    
    switch (_config.errorStrategy) {
      case TimeoutErrorStrategy.failImmediately:
        return false;
        
      case TimeoutErrorStrategy.retry:
        return timeoutCount < _config.timeoutRetryCount;
        
      case TimeoutErrorStrategy.retryWithBackoff:
        if (timeoutCount < _config.timeoutRetryCount) {
          final delay = _calculateBackoffDelay(timeoutCount);
          _logger.info('Waiting ${delay}ms before retry');
          await Future.delayed(Duration(milliseconds: delay));
          return true;
        }
        return false;
        
      case TimeoutErrorStrategy.adjustTimeoutAndRetry:
        if (timeoutCount < _config.timeoutRetryCount) {
          // 增加超时时间
          final newTimeout = _calculateAdjustedTimeout(err.requestOptions, timeoutCount);
          err.requestOptions.connectTimeout = newTimeout;
          err.requestOptions.receiveTimeout = Duration(milliseconds: newTimeout.inMilliseconds * 2);
          
          _logger.info('Adjusted timeout to ${newTimeout.inMilliseconds}ms for retry');
          return true;
        }
        return false;
    }
  }

  /// 计算退避延迟
  int _calculateBackoffDelay(int retryCount) {
    if (!_config.enableExponentialBackoff) {
      return _config.timeoutRetryDelay;
    }
    
    // 指数退避：delay * (2^retryCount)
    final delay = _config.timeoutRetryDelay * (1 << retryCount);
    return delay.clamp(_config.timeoutRetryDelay, 30000); // 最大30秒
  }

  /// 计算调整后的超时时间
  Duration _calculateAdjustedTimeout(RequestOptions options, int timeoutCount) {
    final currentTimeout = options.connectTimeout?.inMilliseconds ?? _config.baseConnectTimeout;
    final adjustedTimeout = (currentTimeout * (1.5 + timeoutCount * 0.5)).round();
    
    return Duration(milliseconds: adjustedTimeout.clamp(_config.minTimeout, _config.maxTimeout));
  }

  /// 获取超时统计信息
  Map<String, dynamic> getTimeoutStatistics() {
    return {
      'totalTimeouts': _timeoutCounts.values.fold(0, (sum, count) => sum + count),
      'timeoutsByUrl': Map.from(_timeoutCounts),
      'lastTimeoutTimes': _lastTimeoutTime.map((url, time) => 
          MapEntry(url, time.toIso8601String())),
    };
  }

  /// 清理超时统计
  void clearTimeoutStatistics() {
    _timeoutCounts.clear();
    _lastTimeoutTime.clear();
  }

  /// 重置特定URL的超时计数
  void resetTimeoutCount(String url) {
    _timeoutCounts.remove(url);
    _lastTimeoutTime.remove(url);
  }
}