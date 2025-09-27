# TaskScheduler 任务调度器文档

## 概述
`TaskScheduler` 是 BZY Network Framework 的任务调度器，负责管理和调度各种网络相关的任务，包括定时任务、延迟任务、周期性任务等。它提供了灵活的任务调度机制，支持优先级管理、资源控制和生命周期管理。

## 文件位置
```
lib/src/core/scheduler/task_scheduler.dart
```

## 核心特性

### 1. 多种调度模式
- **立即执行**: 任务立即执行
- **延迟执行**: 指定延迟时间后执行
- **定时执行**: 在指定时间点执行
- **周期执行**: 按指定间隔重复执行

### 2. 优先级管理
- **高优先级**: 紧急任务，优先执行
- **普通优先级**: 常规任务，正常排队
- **低优先级**: 后台任务，空闲时执行
- **动态调整**: 支持运行时调整任务优先级

### 3. 资源控制
- **并发限制**: 控制同时执行的任务数量
- **内存管理**: 监控和控制内存使用
- **CPU调度**: 合理分配CPU资源
- **负载均衡**: 平衡任务执行负载

### 4. 生命周期管理
- **任务创建**: 创建和注册任务
- **任务执行**: 按调度策略执行任务
- **任务监控**: 监控任务执行状态
- **任务清理**: 自动清理完成的任务

## 主要组件

### 1. 任务类型定义
```dart
enum TaskType {
  immediate,    // 立即执行
  delayed,      // 延迟执行
  scheduled,    // 定时执行
  periodic,     // 周期执行
  conditional,  // 条件执行
}

enum TaskPriority {
  critical,     // 关键任务
  high,         // 高优先级
  normal,       // 普通优先级
  low,          // 低优先级
  background,   // 后台任务
}

enum TaskStatus {
  pending,      // 等待执行
  running,      // 正在执行
  completed,    // 执行完成
  failed,       // 执行失败
  cancelled,    // 已取消
  paused,       // 已暂停
}
```

### 2. 任务定义
```dart
class ScheduledTask {
  final String id;
  final String name;
  final TaskType type;
  final TaskPriority priority;
  final Function() action;
  final Duration? delay;
  final DateTime? scheduledTime;
  final Duration? interval;
  final int? maxExecutions;
  final Map<String, dynamic>? metadata;
  
  TaskStatus status;
  DateTime? createdAt;
  DateTime? lastExecutedAt;
  int executionCount;
  dynamic lastResult;
  dynamic lastError;
}
```

### 3. 调度器配置
```dart
class SchedulerConfig {
  final int maxConcurrentTasks;
  final Duration cleanupInterval;
  final bool enableTaskLogging;
  final bool enablePerformanceMonitoring;
  final Duration taskTimeout;
  final int maxRetryAttempts;
  
  const SchedulerConfig({
    this.maxConcurrentTasks = 10,
    this.cleanupInterval = const Duration(minutes: 5),
    this.enableTaskLogging = true,
    this.enablePerformanceMonitoring = false,
    this.taskTimeout = const Duration(minutes: 1),
    this.maxRetryAttempts = 3,
  });
}
```

## 核心方法

### 1. 任务调度
```dart
// 立即执行任务
String scheduleImmediate(
  String name,
  Function() action, {
  TaskPriority priority = TaskPriority.normal,
  Map<String, dynamic>? metadata,
});

// 延迟执行任务
String scheduleDelayed(
  String name,
  Function() action,
  Duration delay, {
  TaskPriority priority = TaskPriority.normal,
  Map<String, dynamic>? metadata,
});

// 定时执行任务
String scheduleAt(
  String name,
  Function() action,
  DateTime scheduledTime, {
  TaskPriority priority = TaskPriority.normal,
  Map<String, dynamic>? metadata,
});

// 周期执行任务
String schedulePeriodic(
  String name,
  Function() action,
  Duration interval, {
  TaskPriority priority = TaskPriority.normal,
  int? maxExecutions,
  Map<String, dynamic>? metadata,
});
```

### 2. 任务管理
```dart
// 取消任务
bool cancelTask(String taskId);

// 暂停任务
bool pauseTask(String taskId);

// 恢复任务
bool resumeTask(String taskId);

// 获取任务状态
TaskStatus? getTaskStatus(String taskId);

// 获取任务信息
ScheduledTask? getTask(String taskId);

// 获取所有任务
List<ScheduledTask> getAllTasks();
```

### 3. 调度器控制
```dart
// 启动调度器
void start();

// 停止调度器
void stop();

// 暂停调度器
void pause();

// 恢复调度器
void resume();

// 清理已完成的任务
void cleanup();

// 获取调度器状态
bool get isRunning;
```

### 4. 统计和监控
```dart
// 获取执行统计
Map<String, dynamic> getExecutionStats();

// 获取性能指标
Map<String, dynamic> getPerformanceMetrics();

// 获取任务队列信息
Map<String, dynamic> getQueueInfo();
```

## 使用示例

### 1. 基本任务调度
```dart
import 'package:bzy_network_framework/bzy_network_framework.dart';

// 获取调度器实例
final scheduler = TaskScheduler.instance;

// 启动调度器
scheduler.start();

// 立即执行任务
final taskId1 = scheduler.scheduleImmediate(
  'immediate_task',
  () {
    print('立即执行的任务');
  },
  priority: TaskPriority.high,
);

// 延迟执行任务
final taskId2 = scheduler.scheduleDelayed(
  'delayed_task',
  () {
    print('延迟5秒执行的任务');
  },
  Duration(seconds: 5),
);

// 定时执行任务
final taskId3 = scheduler.scheduleAt(
  'scheduled_task',
  () {
    print('定时执行的任务');
  },
  DateTime.now().add(Duration(minutes: 10)),
);

// 周期执行任务
final taskId4 = scheduler.schedulePeriodic(
  'periodic_task',
  () {
    print('每30秒执行一次');
  },
  Duration(seconds: 30),
  maxExecutions: 10, // 最多执行10次
);
```

### 2. 网络相关任务调度
```dart
// 定期清理缓存
scheduler.schedulePeriodic(
  'cache_cleanup',
  () async {
    await CacheManager.instance.cleanup();
    print('缓存清理完成');
  },
  Duration(hours: 1),
  priority: TaskPriority.low,
);

// 定期检查网络状态
scheduler.schedulePeriodic(
  'network_health_check',
  () async {
    final isConnected = NetworkUtils.isNetworkConnected();
    if (!isConnected) {
      print('网络连接异常');
      // 触发网络恢复逻辑
    }
  },
  Duration(minutes: 5),
  priority: TaskPriority.normal,
);

// 延迟重试失败的请求
scheduler.scheduleDelayed(
  'retry_failed_requests',
  () async {
    await RequestQueueManager.instance.retryFailedRequests();
  },
  Duration(seconds: 30),
  priority: TaskPriority.high,
);
```

### 3. 任务管理
```dart
// 监控任务状态
Timer.periodic(Duration(seconds: 10), (timer) {
  final tasks = scheduler.getAllTasks();
  for (final task in tasks) {
    print('任务 ${task.name}: ${task.status}');
    
    // 检查长时间运行的任务
    if (task.status == TaskStatus.running) {
      final runningTime = DateTime.now().difference(task.lastExecutedAt!);
      if (runningTime > Duration(minutes: 5)) {
        print('警告: 任务 ${task.name} 运行时间过长');
        // 可以选择取消任务
        scheduler.cancelTask(task.id);
      }
    }
  }
});

// 取消特定任务
scheduler.cancelTask(taskId1);

// 暂停和恢复任务
scheduler.pauseTask(taskId2);
await Future.delayed(Duration(seconds: 30));
scheduler.resumeTask(taskId2);
```

### 4. 高级配置
```dart
// 自定义调度器配置
final config = SchedulerConfig(
  maxConcurrentTasks: 5,           // 最多同时执行5个任务
  cleanupInterval: Duration(minutes: 3), // 每3分钟清理一次
  enableTaskLogging: true,         // 启用任务日志
  enablePerformanceMonitoring: true, // 启用性能监控
  taskTimeout: Duration(seconds: 30), // 任务超时时间
  maxRetryAttempts: 2,             // 最大重试次数
);

// 应用配置
scheduler.configure(config);
```

## 任务调度策略

### 1. 优先级调度
```dart
// 高优先级任务会优先执行
scheduler.scheduleImmediate('critical_task', () {
  // 关键任务逻辑
}, priority: TaskPriority.critical);

scheduler.scheduleImmediate('normal_task', () {
  // 普通任务逻辑
}, priority: TaskPriority.normal);

// critical_task 会先于 normal_task 执行
```

### 2. 负载均衡
```dart
// 调度器会自动平衡任务负载
for (int i = 0; i < 20; i++) {
  scheduler.scheduleImmediate('task_$i', () {
    // 任务逻辑
  });
}
// 任务会根据配置的最大并发数分批执行
```

### 3. 资源控制
```dart
// 监控资源使用情况
scheduler.addResourceMonitor((usage) {
  if (usage.memoryUsage > 0.8) {
    // 内存使用率过高，暂停低优先级任务
    scheduler.pauseLowPriorityTasks();
  }
  
  if (usage.cpuUsage > 0.9) {
    // CPU使用率过高，减少并发任务数
    scheduler.reduceConcurrency();
  }
});
```

## 性能优化

### 1. 任务批处理
```dart
// 将多个小任务合并为批处理任务
final batchTasks = <Function()>[];
for (int i = 0; i < 100; i++) {
  batchTasks.add(() => processItem(i));
}

scheduler.scheduleImmediate('batch_task', () {
  for (final task in batchTasks) {
    task();
  }
}, priority: TaskPriority.normal);
```

### 2. 智能调度
```dart
// 根据系统负载动态调整调度策略
scheduler.enableAdaptiveScheduling(
  loadThreshold: 0.7,
  adaptationInterval: Duration(seconds: 30),
);
```

### 3. 内存优化
```dart
// 定期清理已完成的任务
scheduler.schedulePeriodic('cleanup', () {
  scheduler.cleanup();
}, Duration(minutes: 5));

// 限制任务历史记录
scheduler.setMaxTaskHistory(1000);
```

## 错误处理

### 1. 任务异常处理
```dart
scheduler.scheduleImmediate('error_prone_task', () {
  try {
    // 可能出错的任务逻辑
    riskyOperation();
  } catch (e) {
    print('任务执行失败: $e');
    // 错误处理逻辑
  }
});
```

### 2. 自动重试
```dart
scheduler.scheduleWithRetry(
  'retry_task',
  () async {
    // 可能需要重试的任务
    await unreliableOperation();
  },
  maxRetries: 3,
  retryDelay: Duration(seconds: 5),
);
```

### 3. 超时处理
```dart
scheduler.scheduleWithTimeout(
  'timeout_task',
  () async {
    // 可能超时的任务
    await longRunningOperation();
  },
  timeout: Duration(minutes: 2),
  onTimeout: () {
    print('任务执行超时');
  },
);
```

## 设计模式

### 1. 单例模式
- 确保全局唯一的调度器实例
- 统一的任务管理

### 2. 命令模式
- 将任务封装为命令对象
- 支持任务的撤销和重做

### 3. 观察者模式
- 任务状态变化通知
- 性能监控和统计

### 4. 策略模式
- 不同的调度策略
- 可配置的执行行为

## 注意事项

### 1. 资源管理
- 合理设置最大并发任务数
- 及时清理已完成的任务
- 监控内存和CPU使用情况

### 2. 任务设计
- 避免长时间运行的任务阻塞调度器
- 将大任务拆分为小任务
- 合理设置任务优先级

### 3. 异常处理
- 任务中的异常不应影响调度器运行
- 提供适当的错误恢复机制
- 记录和监控任务执行情况

### 4. 性能考虑
- 避免创建过多的任务
- 使用批处理优化性能
- 根据系统负载动态调整调度策略