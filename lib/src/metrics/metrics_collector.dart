import 'dart:async';
import 'package:bzy_network_framework/src/core/queue/request_queue_manager.dart';
import 'package:bzy_network_framework/src/core/cache/cache_manager.dart';
import 'package:bzy_network_framework/src/core/interceptor/interceptor_manager.dart';
import 'package:bzy_network_framework/src/config/network_config.dart';
import 'package:bzy_network_framework/src/utils/queue_monitor.dart';
import 'package:bzy_network_framework/src/utils/network_logger.dart';

/// 网络框架指标收集器
/// 用于收集和监控网络框架的各种性能指标
class MetricsCollector {
  static MetricsCollector? _instance;
  
  /// 单例实例
  static MetricsCollector get instance {
    _instance ??= MetricsCollector._internal();
    return _instance!;
  }
  
  MetricsCollector._internal();
  
  /// 指标数据
  Map<String, dynamic> _queueMetrics = {};
  Map<String, dynamic> _cacheMetrics = {};
  Map<String, dynamic> _interceptorMetrics = {};
  Map<String, dynamic> _networkMetrics = {};
  
  /// 指标更新回调
  final List<Function(Map<String, dynamic>)> _metricsUpdateCallbacks = [];
  
  /// 是否正在监控
  bool _isMonitoring = false;
  
  /// 监控定时器
  Timer? _monitoringTimer;
  
  /// 获取队列指标
  Map<String, dynamic> get queueMetrics => Map.from(_queueMetrics);
  
  /// 获取缓存指标
  Map<String, dynamic> get cacheMetrics => Map.from(_cacheMetrics);
  
  /// 获取拦截器指标
  Map<String, dynamic> get interceptorMetrics => Map.from(_interceptorMetrics);
  
  /// 获取网络配置指标
  Map<String, dynamic> get networkMetrics => Map.from(_networkMetrics);
  
  /// 是否正在监控
  bool get isMonitoring => _isMonitoring;
  
  /// 开始监控
  void startMonitoring({Duration interval = const Duration(seconds: 1)}) {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _monitoringTimer = Timer.periodic(interval, (timer) {
      _collectMetrics();
    });
    
    // 立即收集一次指标
    _collectMetrics();
  }
  
  /// 停止监控
  void stopMonitoring() {
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }
  
  /// 收集所有指标
  void _collectMetrics() {
    _queueMetrics = _collectQueueMetrics();
    _cacheMetrics = _collectCacheMetrics();
    _interceptorMetrics = _collectInterceptorMetrics();
    _networkMetrics = _collectNetworkMetrics();
    
    // 通知回调
    _notifyMetricsUpdate();
  }
  
  /// 收集队列指标
  Map<String, dynamic> _collectQueueMetrics() {
    try {
      final queueManager = RequestQueueManager.instance;
      final stats = queueManager.statistics;
      final monitor = QueueMonitor.instance;
      
      return {
        'totalEnqueued': stats.totalEnqueued,
        'totalExecuted': stats.totalExecuted,
        'successfulRequests': stats.successfulRequests,
        'failedRequests': stats.failedRequests,
        'timeoutRequests': stats.timeoutRequests,
        'cancelledRequests': stats.cancelledRequests,
        'expiredRequests': stats.expiredRequests,
        'retryRequests': stats.retryRequests,
        'duplicateRequests': stats.duplicateRequests,
        'rejectedRequests': stats.rejectedRequests,
        'averageExecutionTime': stats.averageExecutionTime.inMilliseconds,
        'totalExecutionTime': stats.totalExecutionTime.inMilliseconds,
        'executionCount': stats.executionCount,
        'successRate': _calculateSuccessRate(stats.successfulRequests, stats.totalExecuted),
        'queueUtilization': _calculateQueueUtilization(stats),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      NetworkLogger.framework.warning('收集队列指标失败: $e');
      return {};
    }
  }
  
  /// 收集缓存指标
  Map<String, dynamic> _collectCacheMetrics() {
    try {
      final cacheManager = CacheManager.instance;
      final stats = cacheManager.statistics;
      
      return {
        'totalRequests': stats.totalRequests,
        'memoryHits': stats.memoryHits,
        'diskHits': stats.diskHits,
        'misses': stats.misses,
        'totalSets': stats.totalSets,
        'errors': stats.errors,
        'memoryHitRate': (stats.memoryHitRate * 100),
        'diskHitRate': (stats.diskHitRate * 100),
        'totalHitRate': (stats.totalHitRate * 100),
        'missRate': (stats.missRate * 100),
        'efficiency': _getCacheEfficiency(stats.totalHitRate),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      NetworkLogger.framework.warning('收集缓存指标失败: $e');
      return {};
    }
  }
  
  /// 收集拦截器指标
  Map<String, dynamic> _collectInterceptorMetrics() {
    try {
      final interceptorManager = InterceptorManager.instance;
      final stats = interceptorManager.statistics;
      final allMetrics = stats.getAllMetrics();
      
      // 计算总体统计
      int totalExecutions = 0;
      int totalSuccessful = 0;
      int totalFailed = 0;
      
      for (final interceptorMetrics in allMetrics.values) {
        for (final typeMetrics in interceptorMetrics.values) {
          totalExecutions += (typeMetrics['totalExecutions'] ?? 0) as int;
          totalSuccessful += (typeMetrics['successfulExecutions'] ?? 0) as int;
          totalFailed += (typeMetrics['failedExecutions'] ?? 0) as int;
        }
      }
      
      return {
        'totalInterceptors': allMetrics.length,
        'activeInterceptors': allMetrics.length, // 简化处理
        'executionCount': totalExecutions,
        'errorCount': totalFailed,
        'errorRate': totalExecutions > 0 ? (totalFailed / totalExecutions * 100) : 0,
        'successRate': totalExecutions > 0 ? (totalSuccessful / totalExecutions * 100) : 0,
        'detailedMetrics': allMetrics,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      NetworkLogger.framework.warning('收集拦截器指标失败: $e');
      return {};
    }
  }
  
  /// 收集网络配置指标
  Map<String, dynamic> _collectNetworkMetrics() {
    try {
      final config = NetworkConfig.instance;
      
      return {
        'baseUrl': config.baseUrl,
        'connectTimeout': config.connectTimeout,
        'receiveTimeout': config.receiveTimeout,
        'sendTimeout': config.sendTimeout,
        'maxRetries': config.maxRetries,
        'retryDelay': config.retryDelay,
        'enableCache': config.enableCache,
        'enableLogging': config.enableLogging,
        'defaultCacheDuration': config.defaultCacheDuration,
        'enableExponentialBackoff': config.enableExponentialBackoff,
        'environment': config.environment.name,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      NetworkLogger.framework.warning('收集网络配置指标失败: $e');
      return {};
    }
  }
  
  /// 计算成功率
  double _calculateSuccessRate(int success, int total) {
    return total > 0 ? (success / total * 100) : 0;
  }
  
  /// 计算队列利用率
  double _calculateQueueUtilization(dynamic stats) {
    try {
      // 这里需要根据实际的 QueueStatistics 结构来调整
      return 0.0; // 临时返回，需要根据实际实现调整
    } catch (e) {
      return 0.0;
    }
  }
  
  /// 获取缓存效率评级
  String _getCacheEfficiency(double hitRate) {
    if (hitRate >= 0.8) return '优秀';
    if (hitRate >= 0.6) return '良好';
    if (hitRate >= 0.4) return '一般';
    return '需要优化';
  }
  
  /// 添加指标更新回调
  void addMetricsUpdateCallback(Function(Map<String, dynamic>) callback) {
    _metricsUpdateCallbacks.add(callback);
  }
  
  /// 移除指标更新回调
  void removeMetricsUpdateCallback(Function(Map<String, dynamic>) callback) {
    _metricsUpdateCallbacks.remove(callback);
  }
  
  /// 通知指标更新
  void _notifyMetricsUpdate() {
    final allMetrics = {
      'queue': _queueMetrics,
      'cache': _cacheMetrics,
      'interceptors': _interceptorMetrics,
      'network': _networkMetrics,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    for (final callback in _metricsUpdateCallbacks) {
      try {
        callback(allMetrics);
      } catch (e) {
        NetworkLogger.framework.warning('指标更新回调执行失败: $e');
      }
    }
  }
  
  /// 获取完整指标报告
  Map<String, dynamic> getFullReport() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'queue': _queueMetrics,
      'cache': _cacheMetrics,
      'interceptors': _interceptorMetrics,
      'network': _networkMetrics,
    };
  }
  
  /// 重置所有指标
  void resetMetrics() {
    try {
      RequestQueueManager.instance.statistics.reset();
      CacheManager.instance.statistics.reset();
      InterceptorManager.instance.statistics.reset();
      
      _collectMetrics();
    } catch (e) {
      NetworkLogger.framework.warning('重置指标失败: $e');
    }
  }
  
  /// 释放资源
  void dispose() {
    stopMonitoring();
    _metricsUpdateCallbacks.clear();
  }
} 