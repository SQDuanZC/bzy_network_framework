# 请求队列管理器 (RequestQueueManager) 文档

## 概述
`RequestQueueManager` 是网络框架的核心队列管理系统，提供请求队列、并发控制、优先级调度、请求去重等高级功能。

## 文件位置
```
lib/src/core/queue/request_queue_manager.dart
```

## 核心特性

### 1. 多优先级队列系统
- **Critical**: 关键请求，最高优先级
- **High**: 高优先级请求
- **Normal**: 普通优先级请求（默认）
- **Low**: 低优先级请求

### 2. 并发控制
- 可配置的最大并发请求数
- 智能的请求调度算法
- 资源使用优化

### 3. 请求去重
- 基于请求特征的智能去重
- 避免重复请求浪费资源
- 支持可选的去重控制

### 4. 超时监控
- 请求超时自动检测
- 超时请求自动清理
- 可配置的超时策略

### 5. 性能统计
- 详细的队列性能指标
- 请求处理时间统计
- 队列状态监控

## 主要组件

### RequestPriority 优先级枚举
```dart
enum RequestPriority {
  critical(0),  // 关键请求
  high(1),      // 高优先级
  normal(2),    // 普通优先级
  low(3),       // 低优先级
}
```

### QueuedRequest 队列请求类
```dart
class QueuedRequest<T> {
  final String id;                              // 请求ID
  final Future<Response> Function() requestFunction; // 请求函数
  final Completer<T> completer;                 // 完成器
  final RequestPriority priority;               // 优先级
  final Duration timeout;                       // 超时时间
  final bool enableDeduplication;               // 是否启用去重
  final Map<String, dynamic> metadata;         // 元数据
  final DateTime enqueuedAt;                    // 入队时间
}
```

### QueueConfig 队列配置类
```dart
class QueueConfig {
  final int maxConcurrentRequests;    // 最大并发数
  final Duration defaultTimeout;      // 默认超时时间
  final bool enableDeduplication;     // 启用去重
  final Duration processingInterval;  // 处理间隔
  final Duration timeoutCheckInterval; // 超时检查间隔
  final int maxQueueSize;             // 最大队列大小
}
```

### QueueStatistics 队列统计类
```dart
class QueueStatistics {
  int totalEnqueued;        // 总入队数
  int totalProcessed;       // 总处理数
  int totalCompleted;       // 总完成数
  int totalFailed;          // 总失败数
  int totalTimeout;         // 总超时数
  int totalDuplicated;      // 总去重数
  int currentQueueSize;     // 当前队列大小
  int currentExecuting;     // 当前执行数
  Duration averageWaitTime; // 平均等待时间
  Duration averageProcessTime; // 平均处理时间
}
```

## 核心方法

### 1. enqueue() - 请求入队
```dart
Future<T> enqueue<T>(
  Future<Response> Function() requestFunction, {
  RequestPriority priority = RequestPriority.normal,
  String? requestId,
  Duration? timeout,
  bool enableDeduplication = true,
  Map<String, dynamic>? metadata,
}) async
```

**功能**：
- 将请求添加到对应优先级队列
- 执行请求去重检查
- 返回Future用于获取结果
- 记录入队统计信息

**参数**：
- `requestFunction`: 请求执行函数
- `priority`: 请求优先级
- `requestId`: 自定义请求ID
- `timeout`: 请求超时时间
- `enableDeduplication`: 是否启用去重
- `metadata`: 请求元数据

### 2. cancelRequest() - 取消请求
```dart
bool cancelRequest(String requestId)
```

**功能**：
- 取消指定ID的请求
- 从队列中移除请求
- 通知等待的调用者

### 3. clearQueue() - 清空队列
```dart
void clearQueue({RequestPriority? priority})
```

**功能**：
- 清空指定优先级队列
- 如果不指定优先级，清空所有队列
- 取消所有等待的请求

### 4. pauseProcessing() / resumeProcessing() - 暂停/恢复处理
```dart
void pauseProcessing()
void resumeProcessing()
```

**功能**：
- 暂停队列处理（不影响正在执行的请求）
- 恢复队列处理

## 队列处理机制

### 1. 优先级调度
```dart
// 处理顺序：Critical -> High -> Normal -> Low
for (final priority in RequestPriority.values) {
  final queue = _queues[priority]!;
  if (queue.isNotEmpty && _canProcessMore()) {
    final request = queue.removeFirst();
    _processRequest(request);
  }
}
```

### 2. 并发控制
- 维护当前执行请求数量
- 根据配置限制最大并发数
- 智能调度等待请求

### 3. 去重机制
```dart
// 基于请求特征生成去重键
String _generateDeduplicationKey(QueuedRequest request) {
  return '${request.method}_${request.url}_${request.dataHash}';
}
```

### 4. 超时处理
- 定期检查请求超时
- 自动取消超时请求
- 清理相关资源

## 使用示例

### 基本使用
```dart
// 普通优先级请求
final response = await RequestQueueManager.instance.enqueue<Map<String, dynamic>>(
  () => dio.get('/api/data'),
);

// 高优先级请求
final urgentResponse = await RequestQueueManager.instance.enqueue<String>(
  () => dio.post('/api/urgent', data: {'key': 'value'}),
  priority: RequestPriority.high,
);
```

### 带配置的请求
```dart
final response = await RequestQueueManager.instance.enqueue<UserModel>(
  () => dio.get('/api/user/123'),
  priority: RequestPriority.normal,
  requestId: 'get_user_123',
  timeout: Duration(seconds: 10),
  enableDeduplication: true,
  metadata: {
    'userId': 123,
    'source': 'profile_page',
  },
);
```

### 批量请求
```dart
final futures = <Future>[];

for (int i = 0; i < 10; i++) {
  final future = RequestQueueManager.instance.enqueue(
    () => dio.get('/api/item/$i'),
    priority: RequestPriority.low,
  );
  futures.add(future);
}

final results = await Future.wait(futures);
```

### 队列管理
```dart
// 暂停处理
RequestQueueManager.instance.pauseProcessing();

// 清空低优先级队列
RequestQueueManager.instance.clearQueue(priority: RequestPriority.low);

// 恢复处理
RequestQueueManager.instance.resumeProcessing();

// 取消特定请求
RequestQueueManager.instance.cancelRequest('get_user_123');
```

### 配置管理
```dart
// 更新队列配置
RequestQueueManager.instance.updateConfig(QueueConfig(
  maxConcurrentRequests: 5,
  defaultTimeout: Duration(seconds: 30),
  enableDeduplication: true,
  processingInterval: Duration(milliseconds: 100),
));
```

### 统计监控
```dart
// 获取队列统计
final stats = RequestQueueManager.instance.statistics;
print('队列大小: ${stats.currentQueueSize}');
print('正在执行: ${stats.currentExecuting}');
print('平均等待时间: ${stats.averageWaitTime}');
print('成功率: ${stats.totalCompleted / stats.totalProcessed}');
```

## 性能优化

### 1. 锁粒度优化
- 使用多个细粒度锁替代单一大锁
- 减少锁竞争和等待时间
- 提高并发处理能力

### 2. 内存管理
- 及时清理完成的请求
- 限制队列最大大小
- 防止内存泄漏

### 3. 处理效率
- 智能的处理间隔调整
- 批量处理优化
- 减少不必要的检查

## 错误处理

### 1. 请求失败
- 自动记录失败统计
- 通知等待的调用者
- 清理相关资源

### 2. 超时处理
- 自动检测和处理超时
- 取消超时请求
- 更新统计信息

### 3. 队列溢出
- 检查队列大小限制
- 拒绝新的请求入队
- 返回适当的错误信息

## 设计模式

### 1. 单例模式
确保全局唯一的队列管理器实例。

### 2. 生产者-消费者模式
请求入队（生产）和处理（消费）分离。

### 3. 优先级队列模式
基于优先级的请求调度。

### 4. 观察者模式
统计信息的实时更新和通知。

## 注意事项

1. **内存使用**: 大量排队请求可能消耗较多内存
2. **超时设置**: 合理设置超时时间避免请求积压
3. **并发控制**: 根据设备性能调整最大并发数
4. **去重策略**: 理解去重机制避免意外的请求合并
5. **优先级使用**: 合理使用优先级避免低优先级请求饥饿
6. **错误处理**: 正确处理队列相关的异常
7. **资源清理**: 及时取消不需要的请求释放资源