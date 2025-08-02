import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:synchronized/synchronized.dart';


/// 请求队列管理器
/// 支持请求队列、并发控制、优先级调度、请求去重
class RequestQueueManager {
  static RequestQueueManager? _instance;
  
  // 队列配置
  late QueueConfig _config;
  
  // 并发锁
  final Lock _queueLock = Lock();
  final Lock _executingLock = Lock();
  
  // 请求队列（按优先级分组）
  final Map<RequestPriority, Queue<QueuedRequest>> _queues = {
    RequestPriority.critical: Queue<QueuedRequest>(),
    RequestPriority.high: Queue<QueuedRequest>(),
    RequestPriority.normal: Queue<QueuedRequest>(),
    RequestPriority.low: Queue<QueuedRequest>(),
  };
  
  // 正在执行的请求
  final Set<String> _executingRequests = {};
  
  // 请求去重映射
  final Map<String, List<QueuedRequest>> _duplicateRequests = {};
  
  // 队列处理定时器
  Timer? _processingTimer;
  
  // 队列统计
  final QueueStatistics _statistics = QueueStatistics();
  
  // 请求状态映射（防止重复处理）
  final Map<String, bool> _requestCompleted = {};
  
  // 私有构造函数
  RequestQueueManager._() {
    _config = const QueueConfig();
    _startProcessing();
  }
  
  /// 获取单例实例
  static RequestQueueManager get instance {
    _instance ??= RequestQueueManager._();
    return _instance!;
  }
  
  /// 队列配置
  QueueConfig get config => _config;
  
  /// 队列统计
  QueueStatistics get statistics => _statistics;
  
  /// 添加请求到队列
  Future<T> enqueue<T>(
    Future<Response> Function() requestFunction, {
    RequestPriority priority = RequestPriority.normal,
    String? requestId,
    Duration? timeout,
    bool enableDeduplication = true,
    Map<String, dynamic>? metadata,
  }) async {
    return await _queueLock.synchronized(() async {
      final effectiveRequestId = requestId ?? _generateRequestId();
      final completer = Completer<T>();
      
      final queuedRequest = QueuedRequest<T>(
        id: effectiveRequestId,
        requestFunction: requestFunction,
        completer: completer,
        priority: priority,
        timeout: timeout ?? _config.defaultTimeout,
        enableDeduplication: enableDeduplication,
        metadata: metadata ?? {},
        enqueuedAt: DateTime.now(),
      );
      
      // 检查请求去重
      if (enableDeduplication && _config.enableDeduplication) {
        final duplicateKey = _generateDeduplicationKey(queuedRequest);
        
        // 更严格的重复请求检查
        if (_duplicateRequests.containsKey(duplicateKey)) {
          final existingRequests = _duplicateRequests[duplicateKey]!;
          
          // 检查是否有正在执行的相同请求
          final hasExecutingRequest = existingRequests.any((req) => 
            _executingRequests.contains(req.id) && 
            _requestCompleted[req.id] != true
          );
          
          // 检查是否有等待中的相同请求
          final hasPendingRequest = existingRequests.any((req) => 
            _queues[req.priority]!.contains(req) && 
            _requestCompleted[req.id] != true
          );
          
          if (hasExecutingRequest || hasPendingRequest) {
            // 如果有正在执行或等待的相同请求，将新请求添加到重复列表
            existingRequests.add(queuedRequest);
            _statistics.duplicateRequests++;
            
            // 请求去重: $effectiveRequestId (去重键: $duplicateKey)
            return completer.future;
          } else {
            // 如果没有活跃的相同请求，清理旧的重复请求记录
            _duplicateRequests.remove(duplicateKey);
          }
        }
        
        // 创建新的重复请求列表
        _duplicateRequests[duplicateKey] = [queuedRequest];
      }
      
      // 添加到对应优先级队列
      _queues[priority]!.add(queuedRequest);
      _statistics.totalEnqueued++;
      _statistics.queueSizes[priority] = (_statistics.queueSizes[priority] ?? 0) + 1;
      
      // 请求已入队: $effectiveRequestId (优先级: $priority)
      
      // 立即尝试处理队列
      _processQueue();
      
      return completer.future;
    });
  }
  
  /// 取消请求
  Future<bool> cancelRequest(String requestId) async {
    return await _queueLock.synchronized(() {
      // 从队列中移除
      for (final queue in _queues.values) {
        final request = queue.cast<QueuedRequest?>().firstWhere(
          (req) => req?.id == requestId,
          orElse: () => null,
        );
        
        if (request != null) {
          queue.remove(request);
          request.completer.completeError(
            DioException(
              requestOptions: RequestOptions(path: ''),
              message: '请求已取消',
              type: DioExceptionType.cancel,
            ),
          );
          _statistics.cancelledRequests++;
          
          // 同时从重复请求映射中清理
          final duplicateKey = _generateDeduplicationKey(request);
          _duplicateRequests.remove(duplicateKey);
          
          return true;
        }
      }
      
      return false;
    });
  }
  
  /// 清空队列
  void clearQueue({RequestPriority? priority}) {
    _queueLock.synchronized(() {
      if (priority != null) {
        final queue = _queues[priority]!;
        while (queue.isNotEmpty) {
          final request = queue.removeFirst();
          request.completer.completeError(
            DioException(
              requestOptions: RequestOptions(path: ''),
              message: '队列已清空',
              type: DioExceptionType.cancel,
            ),
          );
        }
        _statistics.queueSizes[priority] = 0;
      } else {
        for (final entry in _queues.entries) {
          final queue = entry.value;
          while (queue.isNotEmpty) {
            final request = queue.removeFirst();
            request.completer.completeError(
              DioException(
                requestOptions: RequestOptions(path: ''),
                message: '队列已清空',
                type: DioExceptionType.cancel,
              ),
            );
          }
          _statistics.queueSizes[entry.key] = 0;
        }
      }
      
      _duplicateRequests.clear();
    });
  }
  
  /// 暂停队列处理
  void pauseQueue() {
    _processingTimer?.cancel();
    _processingTimer = null;
  }
  
  /// 恢复队列处理
  void resumeQueue() {
    if (_processingTimer == null) {
      _startProcessing();
    }
  }
  
  /// 开始处理队列
  void _startProcessing() {
    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(_config.processingInterval, (timer) {
      _processQueue();
    });
  }
  
  /// 处理队列
  void _processQueue() {
    _queueLock.synchronized(() {
      // 检查并发限制
      if (_executingRequests.length >= _config.maxConcurrentRequests) {
        return;
      }
      
      // 按优先级顺序处理请求
      for (final priority in RequestPriority.values) {
        final queue = _queues[priority]!;
        
        while (queue.isNotEmpty && _executingRequests.length < _config.maxConcurrentRequests) {
          final request = queue.removeFirst();
          _statistics.queueSizes[priority] = (_statistics.queueSizes[priority] ?? 0) - 1;
          
          // 检查请求是否超时
          if (_isRequestExpired(request)) {
            _handleExpiredRequest(request);
            continue;
          }
          
          // 执行请求
          _executeRequest(request);
        }
      }
    });
  }
  
  /// 执行请求
  void _executeRequest(QueuedRequest request) {
    // 原子操作：添加到执行中请求集合
    _executingLock.synchronized(() {
      _executingRequests.add(request.id);
      _statistics.totalExecuted++;
      _requestCompleted[request.id] = false;
    });
    
    final startTime = DateTime.now();
    
    // 设置超时
    Timer? timeoutTimer;
    if (request.timeout.inMilliseconds > 0) {
      timeoutTimer = Timer(request.timeout, () {
        _handleRequestTimeout(request);
      });
    }
    
    // 执行请求
    request.requestFunction().then((response) {
      timeoutTimer?.cancel();
      _handleRequestSuccess(request, response, startTime);
    }).catchError((error) {
      timeoutTimer?.cancel();
      _handleRequestError(request, error, startTime);
    });
  }
  
  /// 处理请求成功
  void _handleRequestSuccess(QueuedRequest request, Response response, DateTime startTime) {
    // 原子操作：检查和更新请求完成状态
    bool shouldProcess = false;
    _executingLock.synchronized(() {
      if (_requestCompleted[request.id] != true) {
        _requestCompleted[request.id] = true;
        shouldProcess = true;
      }
    });
    
    if (!shouldProcess) {
      return;
    }
    
    try {
      // 原子操作：更新执行状态和统计
      _executingLock.synchronized(() {
        _executingRequests.remove(request.id);
        _statistics.successfulRequests++;
        
        final duration = DateTime.now().difference(startTime);
        _statistics.updateExecutionTime(duration);
      });
      
      // 原子操作：处理重复请求
      List<QueuedRequest>? duplicateRequests;
      _queueLock.synchronized(() {
        final duplicateKey = _generateDeduplicationKey(request);
        duplicateRequests = _duplicateRequests[duplicateKey];
        if (duplicateRequests != null) {
          _duplicateRequests.remove(duplicateKey);
        }
      });
      
      if (duplicateRequests != null) {
        for (final duplicateRequest in duplicateRequests!) {
          try {
            if (!duplicateRequest.completer.isCompleted) {
              duplicateRequest.completer.complete(response.data);
            }
          } catch (e) {
            // 记录错误但不影响其他请求
            print('完成重复请求时发生错误: $e');
            // 如果完成失败，尝试用错误完成
            try {
              if (!duplicateRequest.completer.isCompleted) {
                duplicateRequest.completer.completeError(
                  Exception('处理重复请求响应时发生错误: $e')
                );
              }
            } catch (e2) {
              print('完成重复请求错误时再次发生错误: $e2');
            }
          }
        }
      }
      
      // 完成原始请求
      try {
        if (!request.completer.isCompleted) {
          request.completer.complete(response.data);
        }
      } catch (e) {
        print('完成原始请求时发生错误: $e');
        try {
          if (!request.completer.isCompleted) {
            request.completer.completeError(
              Exception('处理请求响应时发生错误: $e')
            );
          }
        } catch (e2) {
          print('完成原始请求错误时再次发生错误: $e2');
        }
      }
    } catch (e) {
      print('处理请求成功时发生未预期错误: $e');
      // 确保请求被标记为完成
      try {
        if (!request.completer.isCompleted) {
          request.completer.completeError(
            Exception('处理请求成功时发生内部错误: $e')
          );
        }
      } catch (e2) {
        print('处理内部错误时再次发生错误: $e2');
      }
    } finally {
      // 原子操作：清理状态
      _executingLock.synchronized(() {
        _requestCompleted.remove(request.id);
      });
    }
    
    // 请求执行成功: ${request.id} (耗时: ${DateTime.now().difference(startTime).inMilliseconds}ms)
  }
  
  /// 处理请求错误
  void _handleRequestError(QueuedRequest request, dynamic error, DateTime startTime) {
    // 原子操作：检查和更新请求完成状态
    bool shouldProcess = false;
    _executingLock.synchronized(() {
      if (_requestCompleted[request.id] != true) {
        _requestCompleted[request.id] = true;
        shouldProcess = true;
      }
    });
    
    if (!shouldProcess) {
      return;
    }
    
    try {
      // 原子操作：更新执行状态和统计
      _executingLock.synchronized(() {
        _executingRequests.remove(request.id);
        _statistics.failedRequests++;
        
        final duration = DateTime.now().difference(startTime);
        _statistics.updateExecutionTime(duration);
      });
      
      // 检查是否需要重试
      if (_shouldRetryRequest(request, error)) {
        // 原子操作：重置状态以允许重试
        _executingLock.synchronized(() {
          _requestCompleted[request.id] = false;
        });
        _retryRequest(request);
        return;
      }
      
      // 原子操作：处理重复请求
      List<QueuedRequest>? duplicateRequests;
      _queueLock.synchronized(() {
        final duplicateKey = _generateDeduplicationKey(request);
        duplicateRequests = _duplicateRequests[duplicateKey];
        if (duplicateRequests != null) {
          _duplicateRequests.remove(duplicateKey);
        }
      });
      
      if (duplicateRequests != null) {
        for (final duplicateRequest in duplicateRequests!) {
          try {
            if (!duplicateRequest.completer.isCompleted) {
              duplicateRequest.completer.completeError(error);
            }
          } catch (e) {
            // 记录错误但不影响其他请求
            print('完成重复请求错误时发生错误: $e');
            // 尝试用包装错误完成
            try {
              if (!duplicateRequest.completer.isCompleted) {
                duplicateRequest.completer.completeError(
                  Exception('处理重复请求错误时发生内部错误: $e, 原始错误: $error')
                );
              }
            } catch (e2) {
              print('完成重复请求包装错误时再次发生错误: $e2');
            }
          }
        }
      }
      
      // 完成原始请求
      try {
        if (!request.completer.isCompleted) {
          request.completer.completeError(error);
        }
      } catch (e) {
        print('完成原始请求错误时发生错误: $e');
        try {
          if (!request.completer.isCompleted) {
            request.completer.completeError(
              Exception('处理请求错误时发生内部错误: $e, 原始错误: $error')
            );
          }
        } catch (e2) {
          print('完成原始请求包装错误时再次发生错误: $e2');
        }
      }
    } catch (e) {
      print('处理请求错误时发生未预期错误: $e, 原始错误: $error');
      // 确保请求被标记为完成
      try {
        if (!request.completer.isCompleted) {
          request.completer.completeError(
            Exception('处理请求错误时发生内部错误: $e, 原始错误: $error')
          );
        }
      } catch (e2) {
        print('处理内部错误时再次发生错误: $e2');
      }
    } finally {
      // 清理状态
      _requestCompleted.remove(request.id);
    }
    
    // 请求执行失败: ${request.id} (耗时: ${DateTime.now().difference(startTime).inMilliseconds}ms, 错误: $error)
  }
  
  /// 处理请求超时
  void _handleRequestTimeout(QueuedRequest request) {
    // 检查是否已经处理过
    if (_requestCompleted[request.id] == true) {
      return;
    }
    _requestCompleted[request.id] = true;
    
    _executingRequests.remove(request.id);
    _statistics.timeoutRequests++;
    
    final error = DioException(
      requestOptions: RequestOptions(path: ''),
      message: '请求超时',
      type: DioExceptionType.receiveTimeout,
    );
    
    // 检查是否需要重试
    if (_shouldRetryRequest(request, error)) {
      // 重置状态以允许重试
      _requestCompleted[request.id] = false;
      _retryRequest(request);
      return;
    }
    
    // 处理重复请求
    final duplicateKey = _generateDeduplicationKey(request);
    final duplicateRequests = _duplicateRequests[duplicateKey];
    if (duplicateRequests != null) {
      for (final duplicateRequest in duplicateRequests) {
        try {
          if (!duplicateRequest.completer.isCompleted) {
            duplicateRequest.completer.completeError(error);
          }
        } catch (e) {
          // 记录错误但不影响其他请求
          // 完成请求超时时发生错误: $e
        }
      }
      _duplicateRequests.remove(duplicateKey);
    }
    
    // 清理状态
    _requestCompleted.remove(request.id);
    
    // 请求超时: ${request.id}
  }
  
  /// 处理过期请求
  void _handleExpiredRequest(QueuedRequest request) {
    _statistics.expiredRequests++;
    
    final error = DioException(
      requestOptions: RequestOptions(path: ''),
      message: '请求已过期',
      type: DioExceptionType.cancel,
    );
    
    request.completer.completeError(error);
    
    // 清理重复请求
    final duplicateKey = _generateDeduplicationKey(request);
    _duplicateRequests.remove(duplicateKey);
    
    // 请求已过期: ${request.id}
  }
  
  /// 重试请求
  void _retryRequest(QueuedRequest request) {
    request.retryCount++;
    
    if (request.retryCount <= _config.maxRetryCount) {
      // 计算重试延迟
      final delay = _calculateRetryDelay(request.retryCount);
      
      Timer(delay, () {
        // 重新入队
        _queues[request.priority]!.add(request);
        _statistics.queueSizes[request.priority] = (_statistics.queueSizes[request.priority] ?? 0) + 1;
        _statistics.retryRequests++;
        
        // 请求重试: ${request.id} (第${request.retryCount}次)
      });
    } else {
      // 重试次数用尽，返回错误
      final error = DioException(
        requestOptions: RequestOptions(path: ''),
        message: '重试次数用尽',
        type: DioExceptionType.unknown,
      );
      
      request.completer.completeError(error);
      
      // 清理重复请求
      final duplicateKey = _generateDeduplicationKey(request);
      _duplicateRequests.remove(duplicateKey);
    }
  }
  
  /// 检查是否应该重试请求
  bool _shouldRetryRequest(QueuedRequest request, dynamic error) {
    if (request.retryCount >= _config.maxRetryCount) {
      return false;
    }
    
    // 检查请求方法的幂等性
    final method = request.metadata['method']?.toString().toUpperCase() ?? 'UNKNOWN';
    if (!_isIdempotentMethod(method)) {
      // 非幂等请求不允许重试，除非是网络连接错误
      if (error is DioException) {
        switch (error.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.connectionError:
            // 连接级别的错误可以重试，因为请求可能没有到达服务器
            return true;
          default:
            return false;
        }
      }
      return false;
    }
    
    // 检查错误类型
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.connectionError:
          return true;
        case DioExceptionType.badResponse:
          // 5xx错误可以重试（仅限幂等请求）
          final statusCode = error.response?.statusCode;
          return statusCode != null && statusCode >= 500;
        default:
          return false;
      }
    }
    
    return false;
  }
  
  /// 检查HTTP方法是否为幂等
  bool _isIdempotentMethod(String method) {
    const idempotentMethods = {'GET', 'PUT', 'DELETE', 'HEAD', 'OPTIONS', 'TRACE'};
    return idempotentMethods.contains(method.toUpperCase());
  }
  
  /// 计算重试延迟
  Duration _calculateRetryDelay(int retryCount) {
    // 指数退避算法
    final baseDelay = _config.retryBaseDelay.inMilliseconds;
    final delay = baseDelay * (1 << (retryCount - 1)); // 2^(retryCount-1)
    final maxDelay = _config.retryMaxDelay.inMilliseconds;
    
    return Duration(milliseconds: delay.clamp(baseDelay, maxDelay));
  }
  
  /// 检查请求是否过期
  bool _isRequestExpired(QueuedRequest request) {
    final queueTime = DateTime.now().difference(request.enqueuedAt);
    return queueTime > _config.maxQueueTime;
  }
  
  /// 生成请求ID
  String _generateRequestId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'req_${timestamp}_$random';
  }
  
  /// 生成去重键
  String _generateDeduplicationKey(QueuedRequest request) {
    // 使用更可靠的去重策略
    final buffer = StringBuffer();
    
    // 添加请求方法和URL（从元数据中提取）
    final method = request.metadata['method'] ?? 'UNKNOWN';
    final url = request.metadata['url'] ?? request.metadata['path'] ?? '';
    buffer.write('$method:$url');
    buffer.write('-');
    
    // 添加请求体哈希（如果存在）
    final requestBody = request.metadata['data'];
    if (requestBody != null) {
      try {
        final bodyJson = jsonEncode(requestBody);
        buffer.write(bodyJson.hashCode);
      } catch (e) {
        buffer.write(requestBody.hashCode);
      }
    } else {
      buffer.write('no-body');
    }
    buffer.write('-');
    
    // 添加查询参数哈希（确保顺序一致）
    final queryParams = request.metadata['queryParameters'];
    if (queryParams != null && queryParams is Map) {
      final sortedParams = Map.fromEntries(
        queryParams.entries.toList()..sort((a, b) => a.key.toString().compareTo(b.key.toString()))
      );
      try {
        final paramsJson = jsonEncode(sortedParams);
        buffer.write(paramsJson.hashCode);
      } catch (e) {
        buffer.write(sortedParams.hashCode);
      }
    } else {
      buffer.write('no-params');
    }
    
    return buffer.toString();
  }
  
  /// 获取队列状态
  Map<String, dynamic> getQueueStatus() {
    final totalQueued = _queues.values.fold(0, (sum, queue) => sum + queue.length);
    
    return {
      'totalQueued': totalQueued,
      'executing': _executingRequests.length,
      'queueSizes': _statistics.queueSizes,
      'duplicateRequests': _duplicateRequests.length,
      'statistics': _statistics.toMap(),
    };
  }
  
  /// 更新配置
  void updateConfig(QueueConfig config) {
    _config = config;
    
    // 重启处理定时器
    _startProcessing();
  }
  
  /// 销毁队列管理器
  void dispose() {
    _processingTimer?.cancel();
    _processingTimer = null;
    
    // 清空所有队列
    clearQueue();
    
    // 清理执行状态
    _executingRequests.clear();
    _duplicateRequests.clear();
    _requestCompleted.clear();
    
    // 重置统计信息
    _statistics.reset();
    
    // 清空单例实例
    _instance = null;
  }
}

/// 队列中的请求
class QueuedRequest<T> {
  final String id;
  final Future<Response> Function() requestFunction;
  final Completer<T> completer;
  final RequestPriority priority;
  final Duration timeout;
  final bool enableDeduplication;
  final Map<String, dynamic> metadata;
  final DateTime enqueuedAt;
  int retryCount;
  
  QueuedRequest({
    required this.id,
    required this.requestFunction,
    required this.completer,
    required this.priority,
    required this.timeout,
    required this.enableDeduplication,
    required this.metadata,
    required this.enqueuedAt,
    this.retryCount = 0,
  });
}

/// 请求优先级
enum RequestPriority {
  critical,
  high,
  normal,
  low,
}

/// 队列配置
class QueueConfig {
  /// 最大并发请求数
  final int maxConcurrentRequests;
  
  /// 最大队列时间
  final Duration maxQueueTime;
  
  /// 默认超时时间
  final Duration defaultTimeout;
  
  /// 处理间隔
  final Duration processingInterval;
  
  /// 是否启用去重
  final bool enableDeduplication;
  
  /// 最大重试次数
  final int maxRetryCount;
  
  /// 重试基础延迟
  final Duration retryBaseDelay;
  
  /// 重试最大延迟
  final Duration retryMaxDelay;
  
  const QueueConfig({
    this.maxConcurrentRequests = 6,
    this.maxQueueTime = const Duration(minutes: 5),
    this.defaultTimeout = const Duration(seconds: 30),
    this.processingInterval = const Duration(milliseconds: 100),
    this.enableDeduplication = true,
    this.maxRetryCount = 3,
    this.retryBaseDelay = const Duration(seconds: 1),
    this.retryMaxDelay = const Duration(seconds: 30),
  });
}

/// 队列统计
class QueueStatistics {
  int totalEnqueued = 0;
  int totalExecuted = 0;
  int successfulRequests = 0;
  int failedRequests = 0;
  int timeoutRequests = 0;
  int cancelledRequests = 0;
  int expiredRequests = 0;
  int retryRequests = 0;
  int duplicateRequests = 0;
  
  final Map<RequestPriority, int> queueSizes = {
    RequestPriority.critical: 0,
    RequestPriority.high: 0,
    RequestPriority.normal: 0,
    RequestPriority.low: 0,
  };
  
  Duration totalExecutionTime = Duration.zero;
  int executionCount = 0;
  
  /// 平均执行时间
  Duration get averageExecutionTime {
    return executionCount > 0
        ? Duration(milliseconds: totalExecutionTime.inMilliseconds ~/ executionCount)
        : Duration.zero;
  }
  
  /// 成功率
  double get successRate {
    return totalExecuted > 0 ? successfulRequests / totalExecuted : 0.0;
  }
  
  /// 更新执行时间
  void updateExecutionTime(Duration duration) {
    totalExecutionTime += duration;
    executionCount++;
  }
  
  /// 重置统计
  void reset() {
    totalEnqueued = 0;
    totalExecuted = 0;
    successfulRequests = 0;
    failedRequests = 0;
    timeoutRequests = 0;
    cancelledRequests = 0;
    expiredRequests = 0;
    retryRequests = 0;
    duplicateRequests = 0;
    
    queueSizes.updateAll((key, value) => 0);
    
    totalExecutionTime = Duration.zero;
    executionCount = 0;
  }
  
  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'totalEnqueued': totalEnqueued,
      'totalExecuted': totalExecuted,
      'successfulRequests': successfulRequests,
      'failedRequests': failedRequests,
      'timeoutRequests': timeoutRequests,
      'cancelledRequests': cancelledRequests,
      'expiredRequests': expiredRequests,
      'retryRequests': retryRequests,
      'duplicateRequests': duplicateRequests,
      'queueSizes': queueSizes.map((key, value) => MapEntry(key.name, value)),
      'averageExecutionTime': averageExecutionTime.inMilliseconds,
      'successRate': successRate,
    };
  }
}