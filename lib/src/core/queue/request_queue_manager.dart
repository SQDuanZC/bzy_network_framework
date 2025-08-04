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
  
  // 细化锁粒度，将大锁拆分为多个小锁
  final Lock _queueStateLock = Lock(); // 队列状态锁
  final Lock _requestStateLock = Lock(); // 请求状态锁
  final Lock _duplicateLock = Lock(); // 去重映射锁
  final Lock _statisticsLock = Lock(); // 统计信息锁
  
  // 使用优先级队列数据结构
  final PriorityQueue<QueuedRequest> _priorityQueue = PriorityQueue<QueuedRequest>(
    (a, b) => a.priority.index.compareTo(b.priority.index)
  );
  
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
    
    // 检查请求去重 - 使用专用锁
    if (enableDeduplication && _config.enableDeduplication) {
      final duplicateKey = _generateDeduplicationKey(queuedRequest);
      
      bool hasDuplicate = false;
      await _duplicateLock.synchronized(() async {
        // 更严格的重复请求检查
        if (_duplicateRequests.containsKey(duplicateKey)) {
          final existingRequests = _duplicateRequests[duplicateKey]!;
          
          // 检查是否有正在执行的相同请求
          final hasExecutingRequest = await _requestStateLock.synchronized(() {
            return existingRequests.any((req) => 
              _executingRequests.contains(req.id) && 
              _requestCompleted[req.id] != true
            );
          });
          
          // 检查是否有等待中的相同请求
          final hasPendingRequest = existingRequests.any((req) => 
            !_executingRequests.contains(req.id) && 
            !req.completer.isCompleted
          );
          
          if (hasExecutingRequest || hasPendingRequest) {
            // 如果有正在执行或等待的相同请求，将新请求添加到重复列表
            existingRequests.add(queuedRequest);
            
            await _statisticsLock.synchronized(() {
              _statistics.duplicateRequests++;
            });
            
            hasDuplicate = true;
          } else {
            // 如果没有活跃的相同请求，清理旧的重复请求记录
            _duplicateRequests.remove(duplicateKey);
          }
        }
        
        // 创建新的重复请求列表
        if (!hasDuplicate) {
          _duplicateRequests[duplicateKey] = [queuedRequest];
        }
      });
      
      if (hasDuplicate) {
        return completer.future;
      }
    }
    
    // 检查队列大小限制 - 使用队列状态锁
    await _queueStateLock.synchronized(() async {
      final totalQueueSize = _priorityQueue.length;
      if (totalQueueSize >= _config.maxQueueSize) {
        // 队列已满，根据溢出策略处理
        final handled = await _handleQueueOverflow(queuedRequest);
        if (!handled) {
          // 拒绝新请求
          queuedRequest.completer.completeError(
            DioException(
              requestOptions: RequestOptions(path: ''),
              message: '队列已满，请求被拒绝 (当前队列大小: $totalQueueSize, 最大: ${_config.maxQueueSize})',
              type: DioExceptionType.cancel,
            ),
          );
          
          await _statisticsLock.synchronized(() {
            _statistics.rejectedRequests++;
          });
          
          return;
        }
      }
      
      // 添加到优先级队列
      _priorityQueue.add(queuedRequest);
      
      await _statisticsLock.synchronized(() {
        _statistics.totalEnqueued++;
        _statistics.queueSizes[priority] = (_statistics.queueSizes[priority] ?? 0) + 1;
      });
    });
    
    // 立即尝试处理队列
    _processQueue();
      
    return completer.future;
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
    
    // 添加队列超时监控
    _startQueueTimeoutMonitoring();
  }
  
  /// 开始队列超时监控
  void _startQueueTimeoutMonitoring() {
    Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkQueueTimeout();
    });
  }
  
  /// 检查队列处理超时
  Future<void> _checkQueueTimeout() async {
    final now = DateTime.now();
    
    await _queueStateLock.synchronized(() async {
      // 检查队列中长时间未处理的请求
      final requestsToKeep = <QueuedRequest>[];
      final requestsToTimeout = <QueuedRequest>[];
      
      while (_priorityQueue.isNotEmpty) {
        final request = _priorityQueue.removeFirst();
        final queueTime = now.difference(request.enqueuedAt);
        
        if (queueTime > _config.maxQueueTime) {
          requestsToTimeout.add(request);
        } else {
          requestsToKeep.add(request);
        }
      }
      
      // 将保留的请求重新添加到队列
      for (final request in requestsToKeep) {
        _priorityQueue.add(request);
      }
      
      // 处理超时请求
      for (final request in requestsToTimeout) {
        _handleExpiredRequest(request);
      }
    });
    
    // 检查执行中但可能卡住的请求
    await _requestStateLock.synchronized(() async {
      final executingCopy = Set<String>.from(_executingRequests);
      for (final requestId in executingCopy) {
        final isCompleted = _requestCompleted[requestId] == true;
        if (!isCompleted) {
          // 这里可以添加额外的检查逻辑，例如检查请求执行时间
          // 如果需要强制完成卡住的请求，可以在这里实现
        }
      }
    });
  }
  
  /// 处理队列
  Future<void> _processQueue() async {
    // 检查并发限制
    int availableSlots = 0;
    
    await _requestStateLock.synchronized(() {
      availableSlots = _config.maxConcurrentRequests - _executingRequests.length;
    });
    
    if (availableSlots <= 0) {
      return;
    }
    
    // 处理队列中的请求
    final requestsToExecute = <QueuedRequest>[];
    
    await _queueStateLock.synchronized(() async {
      // 从队列中取出请求
      while (_priorityQueue.isNotEmpty && requestsToExecute.length < availableSlots) {
        final request = _priorityQueue.removeFirst();
        
        // 检查请求是否超时
        if (_isRequestExpired(request)) {
          _handleExpiredRequest(request);
          continue;
        }
        
        requestsToExecute.add(request);
        
        await _statisticsLock.synchronized(() {
          final priority = request.priority;
          _statistics.queueSizes[priority] = 
              (_statistics.queueSizes[priority] ?? 0) - 1;
        });
      }
    });
    
    // 执行请求
    for (final request in requestsToExecute) {
      _executeRequest(request);
    }
  }
  
  /// 执行请求
  Future<void> _executeRequest(QueuedRequest request) async {
    // 原子操作：添加到执行中请求集合
    await _requestStateLock.synchronized(() {
      _executingRequests.add(request.id);
      _requestCompleted[request.id] = false;
    });
    
    await _statisticsLock.synchronized(() {
      _statistics.totalExecuted++;
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
    try {
      final response = await request.requestFunction();
      timeoutTimer?.cancel();
      await _handleRequestSuccess(request, response, startTime);
    } catch (error) {
      timeoutTimer?.cancel();
      await _handleRequestError(request, error, startTime);
    }
  }
  
  /// 处理请求成功
  Future<void> _handleRequestSuccess(QueuedRequest request, Response response, DateTime startTime) async {
    // 原子操作：检查和更新请求完成状态
    bool shouldProcess = false;
    
    await _requestStateLock.synchronized(() {
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
      await _requestStateLock.synchronized(() {
        _executingRequests.remove(request.id);
      });
      
      final duration = DateTime.now().difference(startTime);
      
      await _statisticsLock.synchronized(() {
        _statistics.successfulRequests++;
        _statistics.updateExecutionTime(duration);
      });
      
      // 原子操作：处理重复请求
      List<QueuedRequest>? duplicateRequests;
      
      await _duplicateLock.synchronized(() {
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
      await _requestStateLock.synchronized(() {
        _requestCompleted.remove(request.id);
      });
    }
  }
  
  /// 处理请求错误
  Future<void> _handleRequestError(QueuedRequest request, dynamic error, DateTime startTime) async {
    // 原子操作：检查和更新请求完成状态
    bool shouldProcess = false;
    
    await _requestStateLock.synchronized(() {
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
      await _requestStateLock.synchronized(() {
        _executingRequests.remove(request.id);
      });
      
      final duration = DateTime.now().difference(startTime);
      
      await _statisticsLock.synchronized(() {
        _statistics.failedRequests++;
        _statistics.updateExecutionTime(duration);
      });
      
      // 检查是否需要重试
      if (await _shouldRetryRequest(request, error)) {
        // 原子操作：重置状态以允许重试
        await _requestStateLock.synchronized(() {
          _requestCompleted[request.id] = false;
        });
        
        await _retryRequest(request);
        return;
      }
      
      // 原子操作：处理重复请求
      List<QueuedRequest>? duplicateRequests;
      
      await _duplicateLock.synchronized(() {
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
      await _requestStateLock.synchronized(() {
        _requestCompleted.remove(request.id);
      });
    }
  }
  
  /// 处理请求超时
  Future<void> _handleRequestTimeout(QueuedRequest request) async {
    // 检查是否已经处理过
    bool shouldProcess = false;
    
    await _requestStateLock.synchronized(() {
      if (_requestCompleted[request.id] != true) {
        _requestCompleted[request.id] = true;
        _executingRequests.remove(request.id);
        shouldProcess = true;
      }
    });
    
    if (!shouldProcess) {
      return;
    }
    
    await _statisticsLock.synchronized(() {
      _statistics.timeoutRequests++;
    });
    
    final error = DioException(
      requestOptions: RequestOptions(path: ''),
      message: '请求超时',
      type: DioExceptionType.receiveTimeout,
    );
    
    // 检查是否需要重试
    if (await _shouldRetryRequest(request, error)) {
      // 重置状态以允许重试
      await _requestStateLock.synchronized(() {
        _requestCompleted[request.id] = false;
      });
      
      await _retryRequest(request);
      return;
    }
    
    // 处理重复请求
    List<QueuedRequest>? duplicateRequests;
    
    await _duplicateLock.synchronized(() {
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
          print('完成请求超时时发生错误: $e');
        }
      }
    }
    
    // 完成原始请求
    try {
      if (!request.completer.isCompleted) {
        request.completer.completeError(error);
      }
    } catch (e) {
      print('完成原始请求超时时发生错误: $e');
    }
    
    // 清理状态
    await _requestStateLock.synchronized(() {
      _requestCompleted.remove(request.id);
    });
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
  Future<void> _retryRequest(QueuedRequest request) async {
    request.retryCount++;
    
    await _statisticsLock.synchronized(() {
      _statistics.retryRequests++;
    });
    
    if (request.retryCount <= _config.maxRetryCount) {
      // 计算重试延迟
      final delay = _calculateRetryDelay(request.retryCount);
      
      await Future.delayed(delay);
      
      // 重新入队
      await _queueStateLock.synchronized(() {
        _priorityQueue.add(request);
        
        _statisticsLock.synchronized(() {
          final priority = request.priority;
          _statistics.queueSizes[priority] = 
              (_statistics.queueSizes[priority] ?? 0) + 1;
        });
      });
      
      // 立即尝试处理队列
      _processQueue();
    } else {
      // 重试次数用尽，返回错误
      final error = DioException(
        requestOptions: RequestOptions(path: ''),
        message: '重试次数用尽',
        type: DioExceptionType.unknown,
      );
      
      request.completer.completeError(error);
      
      // 清理重复请求
      await _duplicateLock.synchronized(() {
        final duplicateKey = _generateDeduplicationKey(request);
        _duplicateRequests.remove(duplicateKey);
      });
    }
  }
  
  /// 检查是否应该重试请求
  Future<bool> _shouldRetryRequest(QueuedRequest request, dynamic error) async {
    if (request.retryCount >= _config.maxRetryCount) {
      return false;
    }
    
    // 检查请求方法的幂等性
    final method = request.metadata['method']?.toString().toUpperCase() ?? 'UNKNOWN';
    
    // 增强幂等性判断，考虑请求内容和上下文
    bool isIdempotent = _isIdempotentMethod(method);
    
    // 检查自定义幂等性标记
    final customIdempotent = request.metadata['idempotent'];
    if (customIdempotent != null) {
      isIdempotent = customIdempotent == true;
    }
    
    if (!isIdempotent) {
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
    
    // 差异化重试策略：为不同类型的错误设计特定的重试策略
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          // 超时错误：使用指数退避策略
          return true;
          
        case DioExceptionType.connectionError:
          // 连接错误：立即重试
          return true;
          
        case DioExceptionType.badResponse:
          // 服务器错误：仅重试5xx错误
          final statusCode = error.response?.statusCode;
          if (statusCode != null && statusCode >= 500) {
            // 对于服务器错误，使用递增延迟
            return true;
          }
          return false;
          
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
    
    // 添加请求头哈希（如果存在）- 增强去重机制
    final headers = request.metadata['headers'];
    if (headers != null && headers is Map) {
      // 只考虑可能影响请求唯一性的关键请求头
      final relevantHeaders = <String, dynamic>{};
      final keysToCheck = ['Authorization', 'Content-Type', 'Accept', 'X-Api-Key'];
      
      for (final key in keysToCheck) {
        if (headers.containsKey(key)) {
          relevantHeaders[key] = headers[key];
        }
      }
      
      if (relevantHeaders.isNotEmpty) {
        try {
          final headersJson = jsonEncode(relevantHeaders);
          buffer.write('-');
          buffer.write(headersJson.hashCode);
        } catch (e) {
          buffer.write('-');
          buffer.write(relevantHeaders.hashCode);
        }
      }
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
  
  /// 获取总队列大小
  int _getTotalQueueSize() {
    return _queues.values.fold(0, (sum, queue) => sum + queue.length);
  }
  
  /// 处理队列溢出
  Future<bool> _handleQueueOverflow(QueuedRequest queuedRequest) async {
    switch (_config.overflowStrategy) {
      case QueueOverflowStrategy.rejectNew:
        return false; // 拒绝新请求
        
      case QueueOverflowStrategy.dropOldest:
        return await _dropOldestRequest();
        
      case QueueOverflowStrategy.dropOldestSamePriority:
        return await _dropOldestSamePriorityRequest(queuedRequest.priority);
    }
  }
  
  /// 丢弃最旧的低优先级请求
  Future<bool> _dropOldestRequest() async {
    // 收集所有请求并按优先级和入队时间排序
    final allRequests = <QueuedRequest>[];
    
    await _queueStateLock.synchronized(() {
      while (_priorityQueue.isNotEmpty) {
        allRequests.add(_priorityQueue.removeFirst());
      }
    });
    
    if (allRequests.isEmpty) {
      return false; // 没有可丢弃的请求
    }
    
    // 按优先级从低到高排序，同优先级按入队时间排序
    allRequests.sort((a, b) {
      final priorityCompare = a.priority.index.compareTo(b.priority.index);
      if (priorityCompare != 0) return priorityCompare;
      return a.enqueuedAt.compareTo(b.enqueuedAt);
    });
    
    // 找到最旧的低优先级请求
    final oldestRequest = allRequests.removeAt(0);
    
    // 将其他请求重新添加到队列
    await _queueStateLock.synchronized(() {
      for (final request in allRequests) {
        _priorityQueue.add(request);
      }
    });
    
    // 通知被丢弃的请求
    oldestRequest.completer.completeError(
      DioException(
        requestOptions: RequestOptions(path: ''),
        message: '请求因队列溢出被丢弃',
        type: DioExceptionType.cancel,
      ),
    );
    
    await _statisticsLock.synchronized(() {
      _statistics.cancelledRequests++;
      final priority = oldestRequest.priority;
      _statistics.queueSizes[priority] = 
          (_statistics.queueSizes[priority] ?? 0) - 1;
    });
    
    return true; // 成功腾出空间
  }
  
  /// 丢弃最旧的同优先级请求
  Future<bool> _dropOldestSamePriorityRequest(RequestPriority priority) async {
    // 收集所有请求
    final allRequests = <QueuedRequest>[];
    final samepriorityRequests = <QueuedRequest>[];
    
    await _queueStateLock.synchronized(() {
      while (_priorityQueue.isNotEmpty) {
        final request = _priorityQueue.removeFirst();
        if (request.priority == priority) {
          samepriorityRequests.add(request);
        } else {
          allRequests.add(request);
        }
      }
    });
    
    if (samepriorityRequests.isEmpty) {
      // 没有同优先级的请求，将所有请求放回队列
      await _queueStateLock.synchronized(() {
        for (final request in allRequests) {
          _priorityQueue.add(request);
        }
      });
      return false;
    }
    
    // 按入队时间排序
    samepriorityRequests.sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
    
    // 找到最旧的同优先级请求
    final oldestRequest = samepriorityRequests.removeAt(0);
    
    // 将其他请求重新添加到队列
    await _queueStateLock.synchronized(() {
      for (final request in allRequests) {
        _priorityQueue.add(request);
      }
      for (final request in samepriorityRequests) {
        _priorityQueue.add(request);
      }
    });
    
    // 通知被丢弃的请求
    oldestRequest.completer.completeError(
      DioException(
        requestOptions: RequestOptions(path: ''),
        message: '请求因队列溢出被丢弃（同优先级）',
        type: DioExceptionType.cancel,
      ),
    );
    
    await _statisticsLock.synchronized(() {
      _statistics.cancelledRequests++;
      _statistics.queueSizes[priority] = 
          (_statistics.queueSizes[priority] ?? 0) - 1;
    });
    
    return true; // 成功腾出空间
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

/// 队列溢出策略
enum QueueOverflowStrategy {
  /// 拒绝新请求
  rejectNew,
  /// 丢弃最旧的低优先级请求
  dropOldest,
  /// 丢弃最旧的同优先级请求
  dropOldestSamePriority,
}

/// 队列配置
class QueueConfig {
  /// 最大并发请求数
  final int maxConcurrentRequests;
  
  /// 最大队列大小（总队列大小限制）
  final int maxQueueSize;
  
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
  
  /// 队列溢出策略
  final QueueOverflowStrategy overflowStrategy;
  
  const QueueConfig({
    this.maxConcurrentRequests = 6,
    this.maxQueueSize = 100,
    this.maxQueueTime = const Duration(minutes: 5),
    this.defaultTimeout = const Duration(seconds: 30),
    this.processingInterval = const Duration(milliseconds: 100),
    this.enableDeduplication = true,
    this.maxRetryCount = 3,
    this.retryBaseDelay = const Duration(seconds: 1),
    this.retryMaxDelay = const Duration(seconds: 30),
    this.overflowStrategy = QueueOverflowStrategy.rejectNew,
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
  int rejectedRequests = 0;
  
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
    rejectedRequests = 0;
    
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
      'rejectedRequests': rejectedRequests,
      'queueSizes': queueSizes.map((key, value) => MapEntry(key.name, value)),
      'averageExecutionTime': averageExecutionTime.inMilliseconds,
      'successRate': successRate,
    };
  }
}