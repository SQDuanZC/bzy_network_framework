import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 任务调度器
/// 支持优先级调度、依赖管理、并发控制、重试机制
class TaskScheduler {
  static TaskScheduler? _instance;
  
  // 配置
  SchedulerConfig _config = const SchedulerConfig();
  
  // 任务队列
  final PriorityQueue<NetworkTask> _taskQueue = PriorityQueue<NetworkTask>();
  
  // 正在执行的任务
  final Map<String, NetworkTask> _runningTasks = {};
  
  // 已完成的任务
  final Map<String, TaskResult> _completedTasks = {};
  
  // 任务依赖关系
  final Map<String, Set<String>> _taskDependencies = {};
  
  // 等待依赖的任务
  final Map<String, NetworkTask> _waitingTasks = {};
  
  // 并发控制
  late Semaphore _semaphore;
  
  // 调度器状态
  SchedulerState _status = SchedulerState.stopped;
  
  // 事件流控制器
  final StreamController<TaskEvent> _eventController =
      StreamController<TaskEvent>.broadcast();
  
  // 调度器定时器
  Timer? _schedulerTimer;
  
  // 统计信息
  int _totalSubmitted = 0;
  int _totalCompleted = 0;
  int _totalFailed = 0;
  int _totalCancelled = 0;
  
  // 私有构造函数
  TaskScheduler._() {
    _semaphore = Semaphore(_config.maxConcurrentTasks);
  }
  
  /// 获取单例实例
  static TaskScheduler get instance {
    _instance ??= TaskScheduler._();
    return _instance!;
  }
  
  /// 事件流
  Stream<TaskEvent> get eventStream => _eventController.stream;
  
  /// 启动调度器
  void start() {
    if (_status != SchedulerState.stopped) {
      return;
    }
    
    _status = SchedulerState.running;
    
    // 启动调度循环
    _schedulerTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _scheduleNextTask(),
    );
    
    _emitEvent(TaskEvent(
      type: TaskEventType.schedulerStarted,
      taskId: 'scheduler',
      timestamp: DateTime.now(),
    ));
    
    if (kDebugMode) {
        debugPrint('任务调度器已启动');
      }
  }
  
  /// 停止调度器
  void stop() {
    if (_status == SchedulerState.stopped) {
      return;
    }
    
    _status = SchedulerState.stopping;
    
    // 取消所有等待中的任务
    _cancelAllPendingTasks();
    
    // 等待正在执行的任务完成
    _waitForRunningTasks().then((_) {
      _status = SchedulerState.stopped;
      _schedulerTimer?.cancel();
      
      _emitEvent(TaskEvent(
        type: TaskEventType.schedulerStopped,
        taskId: 'scheduler',
        timestamp: DateTime.now(),
      ));
      
      if (kDebugMode) {
        debugPrint('任务调度器已停止');
      }
    });
  }
  

  
  /// 配置调度器
  void configure(SchedulerConfig config) {
    _config = config;
    
    // 更新并发控制
    _semaphore = Semaphore(_config.maxConcurrentTasks);
    
    if (kDebugMode) {
      debugPrint('任务调度器已重新配置: 最大并发数=${config.maxConcurrentTasks}');
    }
  }
  
  /// 提交任务
  Future<T> submitTask<T>(NetworkTask<T> task) async {
    if (_status != SchedulerState.running) {
      throw StateError('调度器未运行');
    }
    
    // 检查队列容量
    if (_taskQueue.length >= _config.maxQueueSize) {
      throw StateError('任务队列已满');
    }
    
    _totalSubmitted++;
    
    // 设置任务ID
    if (task.id.isEmpty) {
      task.id = _generateTaskId();
    }
    
    // 检查依赖
    if (task.dependencies.isNotEmpty) {
      final unmetDependencies = _checkDependencies(task.dependencies);
      if (unmetDependencies.isNotEmpty) {
        // 任务需要等待依赖完成
        _waitingTasks[task.id] = task;
        _taskDependencies[task.id] = unmetDependencies.toSet();
        
        _emitEvent(TaskEvent(
          type: TaskEventType.waitingForDependencies,
          taskId: task.id,
          dependencies: unmetDependencies,
          timestamp: DateTime.now(),
        ));
        
        // 等待依赖完成
        return _waitForDependencies<T>(task);
      }
    }
    
    // 添加到队列
    _taskQueue.add(task);
    
    _emitEvent(TaskEvent(
      type: TaskEventType.queued,
      taskId: task.id,
      priority: task.priority,
      timestamp: DateTime.now(),
    ));
    
    // 返回任务完成的Future
    return task.completer.future;
  }
  
  /// 提交任务组
  Future<List<T>> submitTaskGroup<T>(
    List<NetworkTask<T>> tasks, {
    bool waitForAll = true,
    Duration? timeout,
  }) async {
    final results = <T>[];
    final futures = <Future<T>>[];
    
    for (final task in tasks) {
      futures.add(submitTask(task));
    }
    
    if (waitForAll) {
      if (timeout != null) {
        final timeoutResults = await Future.wait(futures)
            .timeout(timeout, onTimeout: () => throw TimeoutException('任务组执行超时', timeout));
        results.addAll(timeoutResults);
      } else {
        final allResults = await Future.wait(futures);
        results.addAll(allResults);
      }
    } else {
      // 不等待所有任务完成，返回已完成的结果
      for (final future in futures) {
        try {
          final result = await future;
          results.add(result);
        } catch (e) {
          // 忽略单个任务的错误
        }
      }
    }
    
    return results;
  }
  
  /// 取消任务
  bool cancelTask(String taskId) {
    // 检查等待队列
    if (_waitingTasks.containsKey(taskId)) {
      final task = _waitingTasks.remove(taskId);
      _taskDependencies.remove(taskId);
      
      if (task != null) {
        task.cancel();
        _totalCancelled++;
        
        _emitEvent(TaskEvent(
          type: TaskEventType.cancelled,
          taskId: taskId,
          timestamp: DateTime.now(),
        ));
        
        return true;
      }
    }
    
    // 检查任务队列
    final queuedTask = _taskQueue.removeWhere((task) => task.id == taskId);
    if (queuedTask.isNotEmpty) {
      final task = queuedTask.first;
      task.cancel();
      _totalCancelled++;
      
      _emitEvent(TaskEvent(
        type: TaskEventType.cancelled,
        taskId: taskId,
        timestamp: DateTime.now(),
      ));
      
      return true;
    }
    
    // 检查正在执行的任务
    final runningTask = _runningTasks[taskId];
    if (runningTask != null) {
      runningTask.cancel();
      _totalCancelled++;
      
      _emitEvent(TaskEvent(
        type: TaskEventType.cancelled,
        taskId: taskId,
        timestamp: DateTime.now(),
      ));
      
      return true;
    }
    
    return false;
  }
  
  /// 获取调度器状态
  SchedulerStatus getStatus() {
    return SchedulerStatus(
      status: _status,
      queuedTaskCount: _taskQueue.length,
      runningTaskCount: _runningTasks.length,
      waitingTaskCount: _waitingTasks.length,
      completedTaskCount: _totalCompleted,
      failedTaskCount: _totalFailed,
      cancelledTaskCount: _totalCancelled,
      totalSubmittedCount: _totalSubmitted,
    );
  }
  
  /// 调度下一个任务
  void _scheduleNextTask() {
    if (_status != SchedulerState.running) {
      return;
    }
    
    // 检查是否有可用的执行槽位
    if (_runningTasks.length >= _config.maxConcurrentTasks) {
      return;
    }
    
    // 检查是否有等待执行的任务
    if (_taskQueue.isEmpty) {
      return;
    }
    
    // 获取下一个任务
    final task = _taskQueue.removeFirst();
    
    // 执行任务
    _executeTask(task);
  }
  
  /// 执行任务
  Future<void> _executeTask(NetworkTask task) async {
    _runningTasks[task.id] = task;
    
    _emitEvent(TaskEvent(
      type: TaskEventType.started,
      taskId: task.id,
      priority: task.priority,
      timestamp: DateTime.now(),
    ));
    
    try {
      // 获取执行许可
      await _semaphore.acquire();
      
      // 执行任务
      final result = await _executeTaskWithRetry(task);
      
      // 任务完成
      _completeTask(task, result);
      
    } catch (e) {
      // 任务失败
      _failTask(task, e);
    } finally {
      // 释放执行许可
      _semaphore.release();
      
      // 从运行列表中移除
      _runningTasks.remove(task.id);
    }
  }
  
  /// 带重试的任务执行
  Future<dynamic> _executeTaskWithRetry(NetworkTask task) async {
    int retryCount = 0;
    dynamic lastError;
    
    while (retryCount <= task.maxRetries) {
      try {
        // 检查任务是否被取消
        if (task.isCancelled) {
          throw const TaskCancelledException('任务已取消');
        }
        
        // 执行任务
        final result = await task.execute(task.cancelToken)
            .timeout(_config.defaultTimeout);
        
        return result;
        
      } catch (e) {
        lastError = e;
        
        // 检查是否需要重试
        if (retryCount < task.maxRetries && _shouldRetry(e)) {
          retryCount++;
          
          _emitEvent(TaskEvent(
            type: TaskEventType.retrying,
            taskId: task.id,
            retryCount: retryCount,
            error: e.toString(),
            timestamp: DateTime.now(),
          ));
          
          // 计算重试延迟
          final delay = _calculateRetryDelay(retryCount, task.retryDelay);
          await Future.delayed(Duration(milliseconds: delay));
          
        } else {
          // 不再重试，抛出错误
          rethrow;
        }
      }
    }
    
    throw lastError;
  }
  
  /// 完成任务
  void _completeTask(NetworkTask task, dynamic result) {
    _totalCompleted++;
    
    // 保存结果
    _completedTasks[task.id] = TaskResult(
      taskId: task.id,
      success: true,
      result: result,
      completedAt: DateTime.now(),
    );
    
    // 完成任务
    task.complete(result);
    
    _emitEvent(TaskEvent(
      type: TaskEventType.completed,
      taskId: task.id,
      timestamp: DateTime.now(),
    ));
    
    // 检查依赖此任务的其他任务
    _checkWaitingTasks(task.id);
  }
  
  /// 任务失败
  void _failTask(NetworkTask task, dynamic error) {
    _totalFailed++;
    
    // 保存错误
    _completedTasks[task.id] = TaskResult(
      taskId: task.id,
      success: false,
      error: error,
      completedAt: DateTime.now(),
    );
    
    // 失败任务
    task.fail(error);
    
    _emitEvent(TaskEvent(
      type: TaskEventType.failed,
      taskId: task.id,
      error: error.toString(),
      timestamp: DateTime.now(),
    ));
    
    // 检查依赖此任务的其他任务（失败的任务也会解除依赖）
    _checkWaitingTasks(task.id);
  }
  
  /// 检查依赖
  List<String> _checkDependencies(List<String> dependencies) {
    final unmetDependencies = <String>[];
    
    for (final dependency in dependencies) {
      if (!_completedTasks.containsKey(dependency)) {
        unmetDependencies.add(dependency);
      }
    }
    
    return unmetDependencies;
  }
  
  /// 等待依赖完成
  Future<T> _waitForDependencies<T>(NetworkTask<T> task) async {
    final completer = Completer<T>();
    Timer? dependencyTimer;
    
    // 定期检查依赖状态
    dependencyTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (task.isCancelled) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.completeError(const TaskCancelledException('任务已取消'));
        }
        return;
      }
      
      final unmetDependencies = _checkDependencies(task.dependencies);
      if (unmetDependencies.isEmpty) {
        timer.cancel();
        
        // 依赖已满足，提交任务
        _waitingTasks.remove(task.id);
        _taskDependencies.remove(task.id);
        
        _taskQueue.add(task);
        
        _emitEvent(TaskEvent(
          type: TaskEventType.queued,
          taskId: task.id,
          priority: task.priority,
          timestamp: DateTime.now(),
        ));
        
        // 等待任务完成
        task.completer.future.then(
          (result) {
            if (!completer.isCompleted) {
              completer.complete(result);
            }
          },
          onError: (error) {
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
        );
      }
    });
    
    // 确保在调度器停止时取消定时器
    completer.future.whenComplete(() {
      dependencyTimer?.cancel();
    });
    
    return completer.future;
  }
  
  /// 检查等待中的任务
  void _checkWaitingTasks(String completedTaskId) {
    final tasksToCheck = <String>[];
    
    // 找到依赖已完成任务的等待任务
    for (final entry in _taskDependencies.entries) {
      if (entry.value.contains(completedTaskId)) {
        entry.value.remove(completedTaskId);
        
        // 如果所有依赖都已满足
        if (entry.value.isEmpty) {
          tasksToCheck.add(entry.key);
        }
      }
    }
    
    // 将满足依赖的任务加入队列
    for (final taskId in tasksToCheck) {
      final task = _waitingTasks.remove(taskId);
      _taskDependencies.remove(taskId);
      
      if (task != null) {
        _taskQueue.add(task);
        
        _emitEvent(TaskEvent(
          type: TaskEventType.queued,
          taskId: taskId,
          priority: task.priority,
          timestamp: DateTime.now(),
        ));
      }
    }
  }
  
  /// 是否应该重试
  bool _shouldRetry(dynamic error) {
    if (error is TaskCancelledException) {
      return false;
    }
    
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true;
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          return statusCode != null && statusCode >= 500;
        default:
          return false;
      }
    }
    
    return true;
  }
  
  /// 计算重试延迟
  int _calculateRetryDelay(int retryCount, int baseDelay) {
    if (_config.retryPolicy != null) {
      final policy = _config.retryPolicy!;
      final delay = (policy.baseDelay.inMilliseconds * 
          pow(policy.backoffMultiplier, retryCount - 1)).round();
      return min(delay, policy.maxDelay.inMilliseconds);
    }
    
    return baseDelay * retryCount;
  }
  
  /// 生成任务ID
  String _generateTaskId() {
    return 'task_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }
  
  /// 发送事件
  void _emitEvent(TaskEvent event) {
    _eventController.add(event);
  }
  
  /// 取消所有等待中的任务
  void _cancelAllPendingTasks() {
    // 取消队列中的任务
    while (_taskQueue.isNotEmpty) {
      final task = _taskQueue.removeFirst();
      task.cancel();
      _totalCancelled++;
    }
    
    // 取消等待依赖的任务
    for (final task in _waitingTasks.values) {
      task.cancel();
      _totalCancelled++;
    }
    
    _waitingTasks.clear();
    _taskDependencies.clear();
  }
  
  /// 等待正在执行的任务完成
  Future<void> _waitForRunningTasks() async {
    while (_runningTasks.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
  
  /// 销毁调度器
  void dispose() {
    stop();
    
    // 取消所有等待中的任务
    _cancelAllPendingTasks();
    
    // 等待所有运行中的任务完成或超时
    _waitForRunningTasks();
    
    // 清理所有状态
    while (_taskQueue.isNotEmpty) {
      _taskQueue.removeFirst();
    }
    _completedTasks.clear();
    _runningTasks.clear();
    _waitingTasks.clear();
    _taskDependencies.clear();
    
    // 关闭事件流
    _eventController.close();
    
    // 取消定时器
    _schedulerTimer?.cancel();
    
    // 清空单例
    _instance = null;
  }
}

/// 网络任务基类
abstract class NetworkTask<T> {
  String id;
  final TaskPriority priority;
  final List<String> dependencies;
  final int maxRetries;
  final int retryDelay;
  final CancelToken cancelToken;
  final Completer<T> completer;
  
  bool _isCancelled = false;
  
  NetworkTask({
    String? id,
    this.priority = TaskPriority.normal,
    this.dependencies = const [],
    this.maxRetries = 3,
    this.retryDelay = 1000,
    CancelToken? cancelToken,
  }) : id = id ?? '',
       cancelToken = cancelToken ?? CancelToken(),
       completer = Completer<T>();
  
  /// 是否已取消
  bool get isCancelled => _isCancelled || cancelToken.isCancelled;
  
  /// 执行任务
  Future<T> execute(CancelToken cancelToken);
  
  /// 取消任务
  void cancel() {
    _isCancelled = true;
    cancelToken.cancel('任务已取消');
    
    if (!completer.isCompleted) {
      completer.completeError(const TaskCancelledException('任务已取消'));
    }
  }
  
  /// 完成任务
  void complete(T result) {
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }
  
  /// 任务失败
  void fail(dynamic error) {
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
  }
}

/// HTTP请求任务
class HttpRequestTask<T> extends NetworkTask<T> {
  final String method;
  final String path;
  final dynamic data;
  final Map<String, dynamic>? queryParameters;
  final Options? options;
  final T Function(dynamic)? fromJson;
  
  HttpRequestTask({
    required this.method,
    required this.path,
    this.data,
    this.queryParameters,
    this.options,
    this.fromJson,
    super.id,
    super.priority,
    super.dependencies,
    super.maxRetries,
    super.retryDelay,
  });
  
  @override
  Future<T> execute(CancelToken cancelToken) async {
    // 这里应该调用实际的HTTP客户端
    // 为了示例，这里返回一个模拟结果
    await Future.delayed(Duration(milliseconds: 100 + Random().nextInt(900)));
    
    if (fromJson != null) {
      return fromJson!({'id': 1, 'name': 'Test'});
    }
    
    return {'success': true} as T;
  }
}

/// 任务优先级
enum TaskPriority {
  low(1),
  normal(2),
  high(3),
  urgent(4);
  
  const TaskPriority(this.value);
  final int value;
}

/// 调度器配置
class SchedulerConfig {
  final int maxConcurrentTasks;
  final int maxQueueSize;
  final Duration defaultTimeout;
  final bool enablePriorityScheduling;
  final bool enableDependencyManagement;
  final RetryPolicy? retryPolicy;
  
  const SchedulerConfig({
    this.maxConcurrentTasks = 3,
    this.maxQueueSize = 100,
    this.defaultTimeout = const Duration(seconds: 30),
    this.enablePriorityScheduling = true,
    this.enableDependencyManagement = true,
    this.retryPolicy,
  });
}

/// 重试策略
class RetryPolicy {
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  
  const RetryPolicy({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 10),
    this.backoffMultiplier = 2.0,
  });
}

/// 调度器状态
class SchedulerStatus {
  final SchedulerState status;
  final int queuedTaskCount;
  final int runningTaskCount;
  final int waitingTaskCount;
  final int completedTaskCount;
  final int failedTaskCount;
  final int cancelledTaskCount;
  final int totalSubmittedCount;
  
  const SchedulerStatus({
    this.status = SchedulerState.stopped,
    this.queuedTaskCount = 0,
    this.runningTaskCount = 0,
    this.waitingTaskCount = 0,
    this.completedTaskCount = 0,
    this.failedTaskCount = 0,
    this.cancelledTaskCount = 0,
    this.totalSubmittedCount = 0,
  });
}

/// 调度器状态枚举
enum SchedulerState {
  stopped,
  running,
  stopping,
}

/// 任务结果
class TaskResult {
  final String taskId;
  final bool success;
  final dynamic result;
  final dynamic error;
  final DateTime completedAt;
  
  const TaskResult({
    required this.taskId,
    required this.success,
    this.result,
    this.error,
    required this.completedAt,
  });
}

/// 任务事件
class TaskEvent {
  final TaskEventType type;
  final String taskId;
  final TaskPriority? priority;
  final List<String>? dependencies;
  final int? retryCount;
  final String? error;
  final DateTime timestamp;
  
  const TaskEvent({
    required this.type,
    required this.taskId,
    this.priority,
    this.dependencies,
    this.retryCount,
    this.error,
    required this.timestamp,
  });
}

/// 任务事件类型
enum TaskEventType {
  queued,
  started,
  completed,
  failed,
  cancelled,
  retrying,
  waitingForDependencies,
  schedulerStarted,
  schedulerStopped,
}

/// 任务取消异常
class TaskCancelledException implements Exception {
  final String message;
  
  const TaskCancelledException(this.message);
  
  @override
  String toString() => 'TaskCancelledException: $message';
}

/// 优先级队列
class PriorityQueue<T extends NetworkTask> {
  final List<T> _items = [];
  
  /// 队列长度
  int get length => _items.length;
  
  /// 是否为空
  bool get isEmpty => _items.isEmpty;
  
  /// 是否不为空
  bool get isNotEmpty => _items.isNotEmpty;
  
  /// 添加元素
  void add(T item) {
    _items.add(item);
    _bubbleUp(_items.length - 1);
  }
  
  /// 移除并返回第一个元素
  T removeFirst() {
    if (_items.isEmpty) {
      throw StateError('队列为空');
    }
    
    final first = _items[0];
    final last = _items.removeLast();
    
    if (_items.isNotEmpty) {
      _items[0] = last;
      _bubbleDown(0);
    }
    
    return first;
  }
  
  /// 移除满足条件的元素
  List<T> removeWhere(bool Function(T) test) {
    final removed = <T>[];
    
    for (int i = _items.length - 1; i >= 0; i--) {
      if (test(_items[i])) {
        removed.add(_items.removeAt(i));
      }
    }
    
    // 重新构建堆
    _heapify();
    
    return removed;
  }
  
  /// 向上冒泡
  void _bubbleUp(int index) {
    while (index > 0) {
      final parentIndex = (index - 1) ~/ 2;
      
      if (_compare(_items[index], _items[parentIndex]) <= 0) {
        break;
      }
      
      _swap(index, parentIndex);
      index = parentIndex;
    }
  }
  
  /// 向下冒泡
  void _bubbleDown(int index) {
    while (true) {
      int largest = index;
      final leftChild = 2 * index + 1;
      final rightChild = 2 * index + 2;
      
      if (leftChild < _items.length && 
          _compare(_items[leftChild], _items[largest]) > 0) {
        largest = leftChild;
      }
      
      if (rightChild < _items.length && 
          _compare(_items[rightChild], _items[largest]) > 0) {
        largest = rightChild;
      }
      
      if (largest == index) {
        break;
      }
      
      _swap(index, largest);
      index = largest;
    }
  }
  
  /// 重新构建堆
  void _heapify() {
    for (int i = (_items.length ~/ 2) - 1; i >= 0; i--) {
      _bubbleDown(i);
    }
  }
  
  /// 交换元素
  void _swap(int i, int j) {
    final temp = _items[i];
    _items[i] = _items[j];
    _items[j] = temp;
  }
  
  /// 比较元素优先级
  int _compare(T a, T b) {
    return a.priority.value.compareTo(b.priority.value);
  }
}

/// 信号量
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();
  
  Semaphore(this.maxCount) : _currentCount = maxCount;
  
  /// 获取许可
  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }
    
    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }
  
  /// 释放许可
  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}