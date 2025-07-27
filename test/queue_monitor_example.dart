import 'dart:async';
import 'package:bzy_network_framework/src/requests/base_network_request.dart';
import 'package:bzy_network_framework/src/requests/network_executor.dart';
import 'package:bzy_network_framework/src/utils/queue_monitor.dart';
import 'package:bzy_network_framework/src/model/network_response.dart';

/// 队列监控使用示例
/// 展示如何与现有的NetworkExecutor和BaseNetworkRequest完美集成
class QueueMonitorExample {
  late QueueMonitor _monitor;
  late StreamSubscription<QueueStatus> _statusSubscription;
  
  /// 初始化监控
  void initializeMonitoring() {
    // 获取队列监控实例
    _monitor = QueueMonitor.instance;
    
    // 配置监控参数
    _monitor.configure(
      monitorInterval: const Duration(milliseconds: 500), // 500ms监控间隔
      maxHistorySize: 200, // 保留200条历史记录
      enableDetailedLogging: true, // 启用详细日志
    );
    
    // 订阅状态流
    _statusSubscription = _monitor.statusStream.listen(
      _onStatusUpdate,
      onError: _onMonitorError,
    );
    
    // 开始监控
    _monitor.startMonitoring();
    
    print('队列监控已启动，与NetworkExecutor完美集成');
  }
  
  /// 状态更新回调
  void _onStatusUpdate(QueueStatus status) {
    final metrics = status.currentMetrics;
    
    // 实时显示队列状态
    print('\n=== 队列状态更新 ===');
    print('时间: ${metrics.timestamp}');
    print('待处理请求: ${metrics.pendingRequests}');
    print('队列中请求: ${metrics.queuedRequests}');
    print('正在处理: ${metrics.isProcessingQueue ? "是" : "否"}');
    print('缓存大小: ${metrics.cacheSize}');
    print('平均队列大小: ${status.averageQueueSize.toStringAsFixed(2)}');
    print('峰值队列大小: ${status.peakQueueSize}');
    print('队列效率: ${(status.queueEfficiency * 100).toStringAsFixed(1)}%');
    
    // 处理告警
    if (status.alerts.isNotEmpty) {
      print('\n⚠️ 告警信息:');
      for (final alert in status.alerts) {
        print('  [${alert.severity.name.toUpperCase()}] ${alert.message}');
      }
    }
    
    print('==================\n');
  }
  
  /// 监控错误回调
  void _onMonitorError(dynamic error) {
    print('队列监控错误: $error');
  }
  
  /// 示例：创建多个不同优先级的请求来测试监控
  Future<void> demonstrateQueueMonitoring() async {
    print('开始演示队列监控功能...');
    
    final executor = NetworkExecutor.instance;
    
    // 创建不同优先级的测试请求
    final requests = [
      // 高优先级请求
      TestRequest('/api/critical', priority: RequestPriority.critical),
      TestRequest('/api/high1', priority: RequestPriority.high),
      TestRequest('/api/high2', priority: RequestPriority.high),
      
      // 普通优先级请求
      TestRequest('/api/normal1', priority: RequestPriority.normal),
      TestRequest('/api/normal2', priority: RequestPriority.normal),
      TestRequest('/api/normal3', priority: RequestPriority.normal),
      TestRequest('/api/normal4', priority: RequestPriority.normal),
      
      // 低优先级请求
      TestRequest('/api/low1', priority: RequestPriority.low),
      TestRequest('/api/low2', priority: RequestPriority.low),
      TestRequest('/api/low3', priority: RequestPriority.low),
    ];
    
    // 快速提交所有请求，观察队列变化
    print('提交 ${requests.length} 个请求到队列...');
    
    final futures = <Future<NetworkResponse<String>>>[];
    for (final request in requests) {
      futures.add(executor.execute(request));
      // 小延迟以便观察队列变化
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // 等待所有请求完成
    print('等待所有请求完成...');
    await Future.wait(futures);
    
    print('所有请求已完成');
  }
  
  /// 示例：批量请求监控
  Future<void> demonstrateBatchMonitoring() async {
    print('\n开始演示批量请求监控...');
    
    final executor = NetworkExecutor.instance;
    
    // 创建批量请求
    final batchRequests = List.generate(20, (index) => 
        TestRequest('/api/batch/$index', priority: RequestPriority.normal));
    
    print('提交批量请求 (${batchRequests.length} 个)...');
    
    // 执行批量请求
    final results = await executor.executeBatch(batchRequests);
    
    print('批量请求完成，成功: ${results.where((r) => r.success).length}/${results.length}');
  }
  
  /// 示例：并发请求监控
  Future<void> demonstrateConcurrentMonitoring() async {
    print('\n开始演示并发请求监控...');
    
    final executor = NetworkExecutor.instance;
    
    // 创建大量并发请求
    final concurrentRequests = List.generate(50, (index) => 
        TestRequest('/api/concurrent/$index', priority: RequestPriority.normal));
    
    print('提交并发请求 (${concurrentRequests.length} 个，最大并发数: 5)...');
    
    // 执行并发请求
    final results = await executor.executeConcurrent(
      concurrentRequests,
      maxConcurrency: 5,
    );
    
    print('并发请求完成，成功: ${results.where((r) => r.success).length}/${results.length}');
  }
  
  /// 获取监控报告
  void generateMonitoringReport() {
    print('\n=== 监控报告 ===');
    
    final currentStatus = _monitor.getCurrentStatus();
    if (currentStatus == null) {
      print('暂无监控数据');
      return;
    }
    
    print('当前状态:');
    print('  待处理请求: ${currentStatus.currentMetrics.pendingRequests}');
    print('  队列中请求: ${currentStatus.currentMetrics.queuedRequests}');
    print('  平均队列大小: ${currentStatus.averageQueueSize.toStringAsFixed(2)}');
    print('  峰值队列大小: ${currentStatus.peakQueueSize}');
    print('  队列效率: ${(currentStatus.queueEfficiency * 100).toStringAsFixed(1)}%');
    print('  总处理请求数: ${currentStatus.totalProcessedRequests}');
    
    // 获取历史数据
    final history = _monitor.getMetricsHistory(limit: 10);
    print('\n最近10次监控数据:');
    for (final metrics in history) {
      print('  ${metrics.timestamp.toIso8601String()}: '
          'Pending=${metrics.pendingRequests}, '
          'Queued=${metrics.queuedRequests}, '
          'Processing=${metrics.isProcessingQueue}');
    }
    
    print('================\n');
  }
  
  /// 导出监控数据
  void exportMonitoringData() {
    print('\n导出监控数据...');
    
    // 导出为JSON
    final jsonData = _monitor.exportMetrics(format: 'json');
    print('JSON数据长度: ${jsonData.length} 字符');
    
    // 导出为CSV
    final csvData = _monitor.exportMetrics(format: 'csv');
    print('CSV数据长度: ${csvData.length} 字符');
    
    // 在实际应用中，可以将数据保存到文件或发送到服务器
    print('监控数据导出完成');
  }
  
  /// 停止监控
  void stopMonitoring() {
    _statusSubscription.cancel();
    _monitor.stopMonitoring();
    print('队列监控已停止');
  }
  
  /// 清理资源
  void dispose() {
    _monitor.dispose();
    print('队列监控资源已清理');
  }
}

/// 测试请求类
class TestRequest extends BaseNetworkRequest<String> {
  final String _path;
  final RequestPriority _priority;
  
  TestRequest(this._path, {RequestPriority priority = RequestPriority.normal})
      : _priority = priority;
  
  @override
  String get path => _path;
  
  @override
  RequestPriority get priority => _priority;
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  String parseResponse(dynamic data) {
    // 模拟响应解析
    return 'Response for $_path';
  }
  
  @override
  void onRequestStart() {
    print('开始请求: $_path (优先级: ${_priority.name})');
  }
  
  @override
  void onRequestComplete(NetworkResponse<String> response) {
    print('请求完成: $_path (耗时: ${response.duration}ms)');
  }
  
  @override
  void onRequestError(NetworkException error) {
    print('请求失败: $_path (错误: ${error.message})');
  }
}

/// 使用示例主函数
Future<void> main() async {
  final example = QueueMonitorExample();
  
  try {
    // 初始化监控
    example.initializeMonitoring();
    
    // 等待一下让监控启动
    await Future.delayed(const Duration(seconds: 1));
    
    // 演示基本队列监控
    await example.demonstrateQueueMonitoring();
    
    // 等待队列处理完成
    await Future.delayed(const Duration(seconds: 3));
    
    // 演示批量请求监控
    await example.demonstrateBatchMonitoring();
    
    // 等待处理完成
    await Future.delayed(const Duration(seconds: 2));
    
    // 演示并发请求监控
    await example.demonstrateConcurrentMonitoring();
    
    // 等待处理完成
    await Future.delayed(const Duration(seconds: 3));
    
    // 生成监控报告
    example.generateMonitoringReport();
    
    // 导出监控数据
    example.exportMonitoringData();
    
    // 等待一段时间观察监控数据
    await Future.delayed(const Duration(seconds: 5));
    
  } finally {
    // 清理资源
    example.stopMonitoring();
    example.dispose();
  }
}