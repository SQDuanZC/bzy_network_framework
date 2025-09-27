# MetricsCollector 指标收集器文档

## 概述
`MetricsCollector` 是 BZY Network Framework 的性能指标收集器，提供实时监控网络框架各个组件的性能指标，包括队列统计、缓存性能、拦截器执行情况等关键数据。

## 文件位置
```
lib/src/metrics/metrics_collector.dart
```

## 核心特性

### 1. 实时监控
- **自动收集**: 自动收集各模块的性能指标
- **定时更新**: 支持配置监控间隔
- **实时通知**: 指标更新时实时通知订阅者

### 2. 多维度指标
- **队列指标**: 队列长度、处理速度、等待时间
- **缓存指标**: 命中率、存储使用、清理统计
- **拦截器指标**: 执行时间、调用次数、错误统计
- **网络指标**: 请求统计、响应时间、错误率

### 3. 数据统计
- **历史数据**: 保存历史指标数据
- **趋势分析**: 支持性能趋势分析
- **报告生成**: 生成完整的性能报告

### 4. 回调机制
- **更新回调**: 指标更新时触发回调
- **自定义处理**: 支持自定义指标处理逻辑
- **事件通知**: 重要事件的通知机制

## 主要组件

### 1. 指标数据结构
```dart
// 队列指标
Map<String, dynamic> queueMetrics = {
  'queueLength': 0,
  'processingCount': 0,
  'completedCount': 0,
  'averageWaitTime': 0.0,
  'averageProcessingTime': 0.0,
};

// 缓存指标
Map<String, dynamic> cacheMetrics = {
  'hitRate': 0.0,
  'missRate': 0.0,
  'totalRequests': 0,
  'cacheSize': 0,
  'memoryUsage': 0,
};

// 拦截器指标
Map<String, dynamic> interceptorMetrics = {
  'totalExecutions': 0,
  'averageExecutionTime': 0.0,
  'errorCount': 0,
  'successRate': 0.0,
};

// 网络指标
Map<String, dynamic> networkMetrics = {
  'totalRequests': 0,
  'successfulRequests': 0,
  'failedRequests': 0,
  'averageResponseTime': 0.0,
  'errorRate': 0.0,
};
```

### 2. 监控配置
```dart
class MetricsConfig {
  final Duration updateInterval;
  final bool enableDetailedMetrics;
  final int maxHistorySize;
  final bool enableFileLogging;
  
  const MetricsConfig({
    this.updateInterval = const Duration(seconds: 5),
    this.enableDetailedMetrics = true,
    this.maxHistorySize = 100,
    this.enableFileLogging = false,
  });
}
```

## 核心方法

### 1. 监控控制
```dart
// 开始监控
void startMonitoring({
  Duration? interval,
  bool enableDetailedMetrics = true,
});

// 停止监控
void stopMonitoring();

// 暂停监控
void pauseMonitoring();

// 恢复监控
void resumeMonitoring();
```

### 2. 指标获取
```dart
// 获取队列指标
Map<String, dynamic> get queueMetrics;

// 获取缓存指标
Map<String, dynamic> get cacheMetrics;

// 获取拦截器指标
Map<String, dynamic> get interceptorMetrics;

// 获取网络指标
Map<String, dynamic> get networkMetrics;

// 获取完整报告
Map<String, dynamic> getFullReport();
```

### 3. 回调管理
```dart
// 添加指标更新回调
void addMetricsUpdateCallback(Function(Map<String, dynamic>) callback);

// 移除指标更新回调
void removeMetricsUpdateCallback(Function(Map<String, dynamic>) callback);

// 清除所有回调
void clearMetricsUpdateCallbacks();
```

### 4. 数据管理
```dart
// 重置指标数据
void resetMetrics();

// 清除历史数据
void clearHistory();

// 导出指标数据
String exportMetrics({String format = 'json'});
```

## 指标详解

### 1. 队列指标 (Queue Metrics)
- **queueLength**: 当前队列长度
- **processingCount**: 正在处理的请求数
- **completedCount**: 已完成的请求总数
- **averageWaitTime**: 平均等待时间（毫秒）
- **averageProcessingTime**: 平均处理时间（毫秒）
- **throughput**: 吞吐量（请求/秒）

### 2. 缓存指标 (Cache Metrics)
- **hitRate**: 缓存命中率（百分比）
- **missRate**: 缓存未命中率（百分比）
- **totalRequests**: 总缓存请求数
- **cacheSize**: 当前缓存大小
- **memoryUsage**: 内存使用量（字节）
- **evictionCount**: 缓存淘汰次数

### 3. 拦截器指标 (Interceptor Metrics)
- **totalExecutions**: 总执行次数
- **averageExecutionTime**: 平均执行时间（毫秒）
- **errorCount**: 错误次数
- **successRate**: 成功率（百分比）
- **timeoutCount**: 超时次数

### 4. 网络指标 (Network Metrics)
- **totalRequests**: 总请求数
- **successfulRequests**: 成功请求数
- **failedRequests**: 失败请求数
- **averageResponseTime**: 平均响应时间（毫秒）
- **errorRate**: 错误率（百分比）
- **retryCount**: 重试次数

## 使用示例

### 1. 基本使用
```dart
import 'package:bzy_network_framework/bzy_network_framework.dart';

// 开始监控
MetricsCollector.instance.startMonitoring(
  interval: Duration(seconds: 3),
  enableDetailedMetrics: true,
);

// 获取指标数据
final queueMetrics = MetricsCollector.instance.queueMetrics;
print('队列长度: ${queueMetrics['queueLength']}');

final cacheMetrics = MetricsCollector.instance.cacheMetrics;
print('缓存命中率: ${cacheMetrics['hitRate']}%');

// 停止监控
MetricsCollector.instance.stopMonitoring();
```

### 2. 回调监听
```dart
// 添加指标更新回调
MetricsCollector.instance.addMetricsUpdateCallback((metrics) {
  print('指标更新: $metrics');
  
  // 检查性能阈值
  final queueLength = metrics['queue']['queueLength'] as int;
  if (queueLength > 100) {
    print('警告: 队列长度过长');
  }
  
  final hitRate = metrics['cache']['hitRate'] as double;
  if (hitRate < 50.0) {
    print('警告: 缓存命中率过低');
  }
});
```

### 3. 完整报告
```dart
// 获取完整性能报告
final report = MetricsCollector.instance.getFullReport();

print('=== 性能报告 ===');
print('队列指标: ${report['queue']}');
print('缓存指标: ${report['cache']}');
print('拦截器指标: ${report['interceptor']}');
print('网络指标: ${report['network']}');

// 导出报告
final jsonReport = MetricsCollector.instance.exportMetrics(format: 'json');
// 保存到文件或发送到服务器
```

### 4. 自定义配置
```dart
// 自定义监控配置
MetricsCollector.instance.startMonitoring(
  interval: Duration(seconds: 1), // 1秒更新一次
  enableDetailedMetrics: true,    // 启用详细指标
);

// 配置历史数据保留
MetricsCollector.instance.configure(
  maxHistorySize: 200,           // 保留200个历史记录
  enableFileLogging: true,       // 启用文件日志
);
```

## 性能监控最佳实践

### 1. 监控间隔设置
```dart
// 开发环境：频繁更新
MetricsCollector.instance.startMonitoring(
  interval: Duration(seconds: 1),
);

// 生产环境：适中更新
MetricsCollector.instance.startMonitoring(
  interval: Duration(seconds: 5),
);

// 性能敏感环境：较少更新
MetricsCollector.instance.startMonitoring(
  interval: Duration(seconds: 30),
);
```

### 2. 阈值监控
```dart
void monitorPerformanceThresholds() {
  MetricsCollector.instance.addMetricsUpdateCallback((metrics) {
    // 队列长度监控
    final queueLength = metrics['queue']['queueLength'] as int;
    if (queueLength > 50) {
      _handleHighQueueLength(queueLength);
    }
    
    // 缓存命中率监控
    final hitRate = metrics['cache']['hitRate'] as double;
    if (hitRate < 70.0) {
      _handleLowCacheHitRate(hitRate);
    }
    
    // 错误率监控
    final errorRate = metrics['network']['errorRate'] as double;
    if (errorRate > 5.0) {
      _handleHighErrorRate(errorRate);
    }
  });
}
```

### 3. 数据导出和分析
```dart
// 定期导出指标数据
Timer.periodic(Duration(hours: 1), (timer) {
  final report = MetricsCollector.instance.getFullReport();
  
  // 发送到监控服务
  _sendToMonitoringService(report);
  
  // 保存到本地文件
  _saveToLocalFile(report);
  
  // 清理历史数据
  MetricsCollector.instance.clearHistory();
});
```

## 错误处理

### 1. 监控异常处理
```dart
try {
  MetricsCollector.instance.startMonitoring();
} catch (e) {
  print('启动监控失败: $e');
  // 降级处理
}
```

### 2. 数据异常处理
```dart
MetricsCollector.instance.addMetricsUpdateCallback((metrics) {
  try {
    // 处理指标数据
    _processMetrics(metrics);
  } catch (e) {
    print('处理指标数据失败: $e');
  }
});
```

## 设计模式

### 1. 单例模式
- 确保全局唯一的指标收集器实例
- 统一的指标数据管理

### 2. 观察者模式
- 支持多个监听器订阅指标更新
- 解耦指标收集和处理逻辑

### 3. 策略模式
- 支持不同的指标收集策略
- 可配置的监控行为

## 注意事项

### 1. 性能影响
- 监控本身会消耗一定的系统资源
- 合理设置监控间隔，避免过于频繁
- 在性能敏感的场景中可以禁用详细监控

### 2. 内存管理
- 定期清理历史数据，避免内存泄漏
- 控制回调函数的数量和复杂度
- 及时移除不需要的监听器

### 3. 数据准确性
- 指标数据可能存在轻微延迟
- 在高并发场景下数据可能不完全精确
- 适合用于趋势分析而非精确计量

### 4. 生产环境使用
- 生产环境中建议使用较长的监控间隔
- 可以考虑只在特定条件下启用监控
- 重要指标可以发送到外部监控系统