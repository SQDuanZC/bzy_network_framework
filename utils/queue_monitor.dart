import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../requests/network_executor.dart';
import '../requests/base_network_request.dart';

/// 队列监控器 - 与NetworkExecutor完美集成的监控组件
class QueueMonitor {
  static QueueMonitor? _instance;
  late Timer _monitorTimer;
  final StreamController<QueueStatus> _statusController = StreamController<QueueStatus>.broadcast();
  final List<QueueMetrics> _metricsHistory = [];
  bool _isMonitoring = false;
  
  /// 监控配置
  Duration monitorInterval;
  int maxHistorySize;
  bool enableDetailedLogging;
  
  /// 单例实例
  static QueueMonitor get instance {
    _instance ??= QueueMonitor._internal();
    return _instance!;
  }
  
  QueueMonitor._internal({
    this.monitorInterval = const Duration(seconds: 1),
    this.maxHistorySize = 100,
    this.enableDetailedLogging = false,
  });
  
  /// 状态流 - 实时监控数据
  Stream<QueueStatus> get statusStream => _statusController.stream;
  
  /// 开始监控
  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _monitorTimer = Timer.periodic(monitorInterval, (timer) {
      _collectMetrics();
    });
    
    if (kDebugMode) {
      print('QueueMonitor: 开始监控网络请求队列');
    }
  }
  
  /// 停止监控
  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    _monitorTimer.cancel();
    
    if (kDebugMode) {
      print('QueueMonitor: 停止监控网络请求队列');
    }
  }
  
  /// 收集指标数据
  void _collectMetrics() {
    final executor = NetworkExecutor.instance;
    final status = executor.getStatus();
    final timestamp = DateTime.now();
    
    final metrics = QueueMetrics(
      timestamp: timestamp,
      pendingRequests: status['pendingRequests'] as int,
      queuedRequests: status['queuedRequests'] as int,
      isProcessingQueue: status['isProcessingQueue'] as bool,
      cacheSize: status['cacheSize'] as int,
    );
    
    // 添加到历史记录
    _metricsHistory.add(metrics);
    
    // 限制历史记录大小
    if (_metricsHistory.length > maxHistorySize) {
      _metricsHistory.removeAt(0);
    }
    
    // 创建状态对象
    final queueStatus = QueueStatus(
      currentMetrics: metrics,
      averageQueueSize: _calculateAverageQueueSize(),
      peakQueueSize: _calculatePeakQueueSize(),
      totalProcessedRequests: _calculateTotalProcessedRequests(),
      queueEfficiency: _calculateQueueEfficiency(),
      alerts: _generateAlerts(metrics),
    );
    
    // 发送状态更新
    _statusController.add(queueStatus);
    
    if (enableDetailedLogging) {
      _logMetrics(queueStatus);
    }
  }
  
  /// 计算平均队列大小
  double _calculateAverageQueueSize() {
    if (_metricsHistory.isEmpty) return 0.0;
    
    final totalQueueSize = _metricsHistory
        .map((m) => m.queuedRequests)
        .reduce((a, b) => a + b);
    
    return totalQueueSize / _metricsHistory.length;
  }
  
  /// 计算峰值队列大小
  int _calculatePeakQueueSize() {
    if (_metricsHistory.isEmpty) return 0;
    
    return _metricsHistory
        .map((m) => m.queuedRequests)
        .reduce((a, b) => a > b ? a : b);
  }
  
  /// 计算总处理请求数（估算）
  int _calculateTotalProcessedRequests() {
    // 这里可以根据实际需求实现更精确的统计
    return _metricsHistory.length;
  }
  
  /// 计算队列效率
  double _calculateQueueEfficiency() {
    if (_metricsHistory.length < 2) return 1.0;
    
    final recentMetrics = _metricsHistory.take(10).toList();
    final processingCount = recentMetrics.where((m) => m.isProcessingQueue).length;
    
    return processingCount / recentMetrics.length;
  }
  
  /// 生成告警信息
  List<QueueAlert> _generateAlerts(QueueMetrics metrics) {
    final alerts = <QueueAlert>[];
    
    // 队列积压告警
    if (metrics.queuedRequests > 50) {
      alerts.add(QueueAlert(
        type: AlertType.queueBacklog,
        severity: AlertSeverity.warning,
        message: '队列积压严重：${metrics.queuedRequests} 个请求等待处理',
        timestamp: metrics.timestamp,
      ));
    }
    
    // 队列停滞告警
    if (metrics.queuedRequests > 0 && !metrics.isProcessingQueue) {
      alerts.add(QueueAlert(
        type: AlertType.queueStalled,
        severity: AlertSeverity.error,
        message: '队列处理停滞：${metrics.queuedRequests} 个请求未被处理',
        timestamp: metrics.timestamp,
      ));
    }
    
    // 缓存过大告警
    if (metrics.cacheSize > 1000) {
      alerts.add(QueueAlert(
        type: AlertType.cacheOverflow,
        severity: AlertSeverity.info,
        message: '缓存大小过大：${metrics.cacheSize} 个缓存项',
        timestamp: metrics.timestamp,
      ));
    }
    
    return alerts;
  }
  
  /// 记录指标日志
  void _logMetrics(QueueStatus status) {
    if (!kDebugMode) return;
    
    final metrics = status.currentMetrics;
    if (kDebugMode) {
      print('QueueMonitor [${metrics.timestamp.toIso8601String()}]: '
          '待处理: ${metrics.pendingRequests}, '
          '队列中: ${metrics.queuedRequests}, '
          '缓存: ${metrics.cacheSize}');
    }
    
    // 输出告警信息
    for (final alert in status.alerts) {
      if (kDebugMode) {
        print('QueueMonitor ALERT [${alert.severity.name.toUpperCase()}]: ${alert.message}');
      }
    }
  }
  
  /// 获取历史指标
  List<QueueMetrics> getMetricsHistory({int? limit}) {
    if (limit == null) return List.from(_metricsHistory);
    
    final startIndex = _metricsHistory.length - limit;
    return _metricsHistory.sublist(startIndex.clamp(0, _metricsHistory.length));
  }
  
  /// 获取当前状态快照
  QueueStatus? getCurrentStatus() {
    if (_metricsHistory.isEmpty) return null;
    
    final currentMetrics = _metricsHistory.last;
    return QueueStatus(
      currentMetrics: currentMetrics,
      averageQueueSize: _calculateAverageQueueSize(),
      peakQueueSize: _calculatePeakQueueSize(),
      totalProcessedRequests: _calculateTotalProcessedRequests(),
      queueEfficiency: _calculateQueueEfficiency(),
      alerts: _generateAlerts(currentMetrics),
    );
  }
  
  /// 导出监控数据
  String exportMetrics({String format = 'json'}) {
    switch (format.toLowerCase()) {
      case 'json':
        return jsonEncode(_metricsHistory.map((m) => m.toJson()).toList());
      case 'csv':
        return _exportToCsv();
      default:
        throw ArgumentError('Unsupported format: $format');
    }
  }
  
  /// 导出为CSV格式
  String _exportToCsv() {
    final buffer = StringBuffer();
    buffer.writeln('timestamp,pendingRequests,queuedRequests,isProcessingQueue,cacheSize');
    
    for (final metrics in _metricsHistory) {
      buffer.writeln('${metrics.timestamp.toIso8601String()},'
          '${metrics.pendingRequests},'
          '${metrics.queuedRequests},'
          '${metrics.isProcessingQueue},'
          '${metrics.cacheSize}');
    }
    
    return buffer.toString();
  }
  
  /// 重置监控数据
  void reset() {
    _metricsHistory.clear();
    if (kDebugMode) {
      print('QueueMonitor: 监控数据已重置');
    }
  }
  
  /// 配置监控参数
  void configure({
    Duration? monitorInterval,
    int? maxHistorySize,
    bool? enableDetailedLogging,
  }) {
    if (monitorInterval != null) this.monitorInterval = monitorInterval;
    if (maxHistorySize != null) this.maxHistorySize = maxHistorySize;
    if (enableDetailedLogging != null) this.enableDetailedLogging = enableDetailedLogging;
    
    // 如果正在监控，重启以应用新配置
    if (_isMonitoring) {
      stopMonitoring();
      startMonitoring();
    }
  }
  
  /// 释放资源
  void dispose() {
    stopMonitoring();
    _statusController.close();
    _metricsHistory.clear();
  }
}

/// 队列指标数据
class QueueMetrics {
  final DateTime timestamp;
  final int pendingRequests;
  final int queuedRequests;
  final bool isProcessingQueue;
  final int cacheSize;
  
  const QueueMetrics({
    required this.timestamp,
    required this.pendingRequests,
    required this.queuedRequests,
    required this.isProcessingQueue,
    required this.cacheSize,
  });
  
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'pendingRequests': pendingRequests,
    'queuedRequests': queuedRequests,
    'isProcessingQueue': isProcessingQueue,
    'cacheSize': cacheSize,
  };
}

/// 队列状态
class QueueStatus {
  final QueueMetrics currentMetrics;
  final double averageQueueSize;
  final int peakQueueSize;
  final int totalProcessedRequests;
  final double queueEfficiency;
  final List<QueueAlert> alerts;
  
  const QueueStatus({
    required this.currentMetrics,
    required this.averageQueueSize,
    required this.peakQueueSize,
    required this.totalProcessedRequests,
    required this.queueEfficiency,
    required this.alerts,
  });
}

/// 队列告警
class QueueAlert {
  final AlertType type;
  final AlertSeverity severity;
  final String message;
  final DateTime timestamp;
  
  const QueueAlert({
    required this.type,
    required this.severity,
    required this.message,
    required this.timestamp,
  });
}

/// 告警类型
enum AlertType {
  queueBacklog,
  queueStalled,
  cacheOverflow,
  highLatency,
  errorRate,
}

/// 告警严重程度
enum AlertSeverity {
  info,
  warning,
  error,
  critical,
}