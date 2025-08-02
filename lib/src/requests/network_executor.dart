import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart' show unawaited;
import 'package:synchronized/synchronized.dart';
import 'base_network_request.dart';
import '../model/network_response.dart';
import '../config/network_config.dart';
import '../core/exception/unified_exception_handler.dart';
import '../core/interceptor/interceptor_manager.dart';
import 'batch_request.dart';


/// Network request executor - unified network request entry point
class NetworkExecutor {
  static NetworkExecutor? _instance;
  late Dio _dio;
  final Map<String, dynamic> _cache = {};
  final Map<String, Completer<NetworkResponse<dynamic>>> _pendingRequests = {};
  final Map<RequestPriority, List<BaseNetworkRequest<dynamic>>> _requestQueues = {
    RequestPriority.critical: [],
    RequestPriority.high: [],
    RequestPriority.normal: [],
    RequestPriority.low: [],
  };
  final Map<String, Timer> _cacheTimers = {};
  bool _isProcessingQueue = false;
  
  // 并发安全锁
  final Lock _pendingRequestsLock = Lock();
  final Lock _queueLock = Lock();
  final Lock _cacheLock = Lock();
  final Lock _processingLock = Lock();
  
  // 批量请求标记，避免重复处理
  final Set<String> _batchRequestIds = {};
  
  /// Singleton instance
  static NetworkExecutor get instance {
    _instance ??= NetworkExecutor._internal();
    return _instance!;
  }
  
  NetworkExecutor._internal() {
    _initializeDio();
  }
  
  /// Initialize Dio instance
  void _initializeDio() {
    final config = NetworkConfig.instance;
    
    _dio = Dio(BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: Duration(milliseconds: config.connectTimeout),
      receiveTimeout: Duration(milliseconds: config.receiveTimeout),
      sendTimeout: Duration(milliseconds: config.sendTimeout),
      headers: config.defaultHeaders,
    ));
    
    // Add interceptors
    _setupInterceptors();
  }
  
  /// Setup interceptors
  void _setupInterceptors() {
    final config = NetworkConfig.instance;
    
    // Basic interceptor setup
    if (config.enableLogging) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ));
    }
  }
  
  /// Execute network request
  Future<NetworkResponse<T>> execute<T>(BaseNetworkRequest<T> request) async {
    if (request is BatchRequest) {
      final result = await _executeBatchRequest(request as BatchRequest) as NetworkResponse<T>;
      return result;
    }
    
    // Check cache
    if (request.enableCache) {
      final cachedResponse = await _getCachedResponse<T>(request);
      if (cachedResponse != null) {
        request.onRequestComplete(cachedResponse);
        return cachedResponse;
      }
    }
    
    // Check if same request is in progress (with lock protection)
    final requestKey = _getRequestKey(request);
    final existingCompleter = await _pendingRequestsLock.synchronized(() {
      return _pendingRequests[requestKey];
    });
    
    if (existingCompleter != null) {
      try {
        final result = await existingCompleter.future;
        return result.cast<T>();
      } catch (e) {
        // If the pending request fails, re-throw the exception
        rethrow;
      }
    }
    
    // Handle request based on priority
    if (request.priority != RequestPriority.critical) {
      return await _enqueueRequest(request);
    }
    
    return await _executeRequest(request);
  }
  
  /// Execute specific network request
  Future<NetworkResponse<T>> _executeRequest<T>(BaseNetworkRequest<T> request, {bool isBatch = false}) async {
    final requestKey = _getRequestKey(request);
    final completer = Completer<NetworkResponse<dynamic>>();
    
    // 原子操作：添加到待处理请求映射
    if (!isBatch) {
      await _pendingRequestsLock.synchronized(() {
        _pendingRequests[requestKey] = completer;
      });
    }
    
    try {
      request.onRequestStart();
      final startTime = DateTime.now();
      
      // Build request options
      final options = request.buildRequestOptions();
      
      // Add custom interceptors
      if (request.customInterceptors != null) {
        for (final interceptor in request.customInterceptors!) {
          _dio.interceptors.add(interceptor);
        }
      }
      
      // Check if it's a download request
      if (request is DownloadRequest) {
        final result = await _executeDownloadRequest<T>(request as DownloadRequest<T>);
        
        // 清理资源
        if (!isBatch) {
          await _pendingRequestsLock.synchronized(() {
            _pendingRequests.remove(requestKey);
          });
        }
        
        // Remove custom interceptors
        if (request.customInterceptors != null) {
          for (final interceptor in request.customInterceptors!) {
            _dio.interceptors.remove(interceptor);
          }
        }
        
        return result;
      }
      
      // Directly execute the request without interceptor chain to avoid infinite recursion
      final response = await _dio.fetch<dynamic>(options);
      
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      final parsedData = request.parseResponse(response.data);
      final networkResponse = NetworkResponse<T>.success(
        data: parsedData,
        statusCode: response.statusCode ?? 200,
        message: response.statusMessage ?? 'Success',
        headers: response.headers.map,
        duration: duration,
      );
      
      if (request.enableCache) {
        _cacheResponse(request, networkResponse);
      }
      
      request.onRequestComplete(networkResponse);
      
      // 清理资源
      if (!isBatch) {
        await _pendingRequestsLock.synchronized(() {
          _pendingRequests.remove(requestKey);
        });
      }
      
      // Remove custom interceptors
      if (request.customInterceptors != null) {
        for (final interceptor in request.customInterceptors!) {
          _dio.interceptors.remove(interceptor);
        }
      }
      
      return networkResponse.cast<T>();
      
      final result = await completer.future.then((value) => value.cast<T>());
      
      // 原子操作：从待处理请求映射中移除
      if (!isBatch) {
        await _pendingRequestsLock.synchronized(() {
          _pendingRequests.remove(requestKey);
        });
      }
      
      // Remove custom interceptors
      if (request.customInterceptors != null) {
        for (final interceptor in request.customInterceptors!) {
          _dio.interceptors.remove(interceptor);
        }
      }
      
      return result;
    } catch (e) {
      // 确保在异常情况下也清理资源
      if (!isBatch) {
        await _pendingRequestsLock.synchronized(() {
          _pendingRequests.remove(requestKey);
        });
      }
      
      // Remove custom interceptors
      if (request.customInterceptors != null) {
        for (final interceptor in request.customInterceptors!) {
          _dio.interceptors.remove(interceptor);
        }
      }
      
      rethrow;
    }
  }

  void _handleError<T>(
    dynamic error,
    BaseNetworkRequest<T> request,
    Completer<NetworkResponse<dynamic>> completer,
  ) {
    print('🔍 [DEBUG] _handleError called with error: $error');
    final dioError = error is DioException
        ? error
        : DioException(requestOptions: request.buildRequestOptions(), error: error);

    final networkException = UnifiedExceptionHandler.instance.createNetworkException(dioError);

    final customException = request.handleError(dioError);
    final finalException = customException ?? networkException;

    unawaited(UnifiedExceptionHandler.instance.handleException(
      dioError,
      context: 'Network request execution',
      metadata: {
        'path': request.path,
        'method': request.method.value,
        'enableCache': request.enableCache,
      },
    ));

    request.onRequestError(finalException as NetworkException);
    print('🔍 [DEBUG] Completing completer with error');
    completer.completeError(finalException);
  }
  
  /// Enqueue request based on priority
  Future<NetworkResponse<T>> _enqueueRequest<T>(BaseNetworkRequest<T> request) async {
    final completer = Completer<NetworkResponse<dynamic>>();
    final requestKey = _getRequestKey(request);
    
    print('🔍 [DEBUG] _enqueueRequest called for ${request.runtimeType} with key: $requestKey');
    
    // 原子操作：添加到队列和待处理请求映射
    await _queueLock.synchronized(() {
      _requestQueues[request.priority]!.add(request);
      print('🔍 [DEBUG] Added to queue ${request.priority}, queue size: ${_requestQueues[request.priority]!.length}');
    });
    
    await _pendingRequestsLock.synchronized(() {
      _pendingRequests[requestKey] = completer;
      print('🔍 [DEBUG] Added to _pendingRequests, total pending: ${_pendingRequests.length}');
    });
    
    // Start processing queue if not already processing
    await _processingLock.synchronized(() {
      if (!_isProcessingQueue) {
        print('🔍 [DEBUG] Starting queue processing');
        unawaited(_processRequestQueue());
      } else {
        print('🔍 [DEBUG] Queue processing already in progress');
      }
    });
    
    print('🔍 [DEBUG] Waiting for enqueued request completer...');
    return (await completer.future).cast<T>();
  }
  
  /// Process request queue
  Future<void> _processRequestQueue() async {
    print('🔍 [DEBUG] _processRequestQueue called, _isProcessingQueue: $_isProcessingQueue');
    // 避免重复处理
    if (_isProcessingQueue) {
      print('🔍 [DEBUG] Queue processing already in progress, returning');
      return;
    }
    
    _isProcessingQueue = true;
    
    try {
      // Keep processing until all queues are empty
      while (_hasQueuedRequests()) {
        // Process requests by priority (critical -> high -> normal -> low)
        for (final priority in RequestPriority.values.reversed) {
          // 原子操作：从队列中取出请求
          BaseNetworkRequest<dynamic>? request;
          await _queueLock.synchronized(() {
            final queue = _requestQueues[priority]!;
            if (queue.isNotEmpty) {
              request = queue.removeAt(0);
            }
          });
          
          if (request != null) {
            final requestKey = _getRequestKey(request!);
            
            try {
              final result = await _executeRequest(request!);
              
              // 原子操作：完成待处理请求
              await _pendingRequestsLock.synchronized(() {
                if (_pendingRequests.containsKey(requestKey)) {
                  final completer = _pendingRequests[requestKey]! as Completer<NetworkResponse<dynamic>>;
                  completer.complete(result.cast<dynamic>());
                  _pendingRequests.remove(requestKey);
                }
              });
            } catch (error) {
              // 原子操作：完成错误请求
              await _pendingRequestsLock.synchronized(() {
                if (_pendingRequests.containsKey(requestKey)) {
                  final completer = _pendingRequests[requestKey]! as Completer<NetworkResponse<dynamic>>;
                  completer.completeError(error);
                  _pendingRequests.remove(requestKey);
                }
              });
            }
            
            // Add small delay to avoid too frequent requests
            if (priority != RequestPriority.critical) {
              await Future.delayed(const Duration(milliseconds: 10));
            }
            
            // Break to restart priority checking from highest priority
            break;
          }
        }
        
        // Small delay before checking queues again
        await Future.delayed(const Duration(milliseconds: 1));
      }
    } finally {
      _isProcessingQueue = false;
    }
  }
  
  /// Check if there are any queued requests
  bool _hasQueuedRequests() {
    return _requestQueues.values.any((queue) => queue.isNotEmpty);
  }

  Future<NetworkResponse<Map<String, dynamic>>> _executeBatchRequest(BatchRequest batchRequest) async {
    final batchId = 'batch_${DateTime.now().millisecondsSinceEpoch}_${batchRequest.hashCode}';
    
    // 检查批量请求是否已经在处理中
    final isAlreadyProcessing = await _pendingRequestsLock.synchronized(() {
      if (_batchRequestIds.contains(batchId)) {
        return true;
      }
      _batchRequestIds.add(batchId);
      return false;
    });
    
    if (isAlreadyProcessing) {
      return NetworkResponse.error(
        statusCode: 409,
        message: 'Batch request already in progress',
        errorCode: 'BATCH_DUPLICATE',
      );
    }
    
    try {
      // 为批量请求的子请求添加特殊标记
      final futures = batchRequest.requests.map((req) {
        // 为子请求添加批量标记，避免重复处理
        return _executeRequest(req, isBatch: true);
      }).toList();

      final responses = await Future.wait(futures);
      
      final results = responses.map((res) => res.data).toList();
      final combinedData = {
        'results': results,
        'successCount': responses.where((res) => res.success).length,
        'totalCount': responses.length,
        'batchId': batchId,
      };

      // 使用BatchRequest的parseResponse方法处理数据
      final parsedData = batchRequest.parseResponse(combinedData);
      
      final response = NetworkResponse.success(
        data: parsedData,
        statusCode: 200,
        message: 'Batch request successful',
      );
      batchRequest.onRequestComplete(response);
      return response;
    } catch (e) {
      final exception = e is NetworkException ? e : NetworkException(message: e.toString());
      batchRequest.onRequestError(exception);
      return NetworkResponse.error(
        statusCode: 500,
        message: 'Batch request failed: ${exception.message}',
        errorCode: exception.errorCode,
      );
    } finally {
      // 清理批量请求标记
      await _pendingRequestsLock.synchronized(() {
        _batchRequestIds.remove(batchId);
      });
    }
  }
  
  /// Execute batch requests
  Future<List<NetworkResponse>> executeBatch(List<BaseNetworkRequest> requests) async {
    final futures = requests.map((request) => execute(request)).toList();
    return await Future.wait(futures);
  }
  
  /// Execute concurrent requests (with concurrency limit)
  Future<List<NetworkResponse>> executeConcurrent(
    List<BaseNetworkRequest> requests, {
    int maxConcurrency = 3,
  }) async {
    final results = <NetworkResponse>[];
    
    for (int i = 0; i < requests.length; i += maxConcurrency) {
      final batch = requests.skip(i).take(maxConcurrency).toList();
      final batchResults = await executeBatch(batch);
      results.addAll(batchResults);
    }
    
    return results;
  }
  
  /// Cancel request
  void cancelRequest(BaseNetworkRequest request) {
    final requestKey = _getRequestKey(request);
    
    // Remove from pending requests
    final completer = _pendingRequests.remove(requestKey);
    if (completer != null && !completer.isCompleted) {
      completer.complete(NetworkResponse<dynamic>.error(
        message: 'Request cancelled',
        statusCode: -999,
        errorCode: 'CANCELLED',
      ));
    }
    
    // Remove from queue
    for (final queue in _requestQueues.values) {
      queue.removeWhere((r) => _getRequestKey(r) == requestKey);
    }
  }
  
  /// Cancel all requests
  Future<void> cancelAllRequests() async {
    // 原子操作：取消所有待处理请求
    await _pendingRequestsLock.synchronized(() {
      for (final completer in _pendingRequests.values) {
        if (!completer.isCompleted) {
          completer.complete(NetworkResponse<dynamic>.error(
            message: 'All requests cancelled',
            statusCode: -999,
            errorCode: 'ALL_CANCELLED',
          ));
        }
      }
      _pendingRequests.clear();
    });
    
    // 原子操作：清空所有队列
    await _queueLock.synchronized(() {
      for (final queue in _requestQueues.values) {
        queue.clear();
      }
    });
    
    // 清理批量请求标记
    await _pendingRequestsLock.synchronized(() {
      _batchRequestIds.clear();
    });
  }
  
  /// Get cached response
  Future<NetworkResponse<T>?> _getCachedResponse<T>(BaseNetworkRequest<T> request) async {
    final cacheKey = request.getCacheKey();
    
    return await _cacheLock.synchronized(() {
      final cachedData = _cache[cacheKey];
      
      if (cachedData != null) {
        try {
          final parsedData = request.parseResponse(cachedData);
          return NetworkResponse<T>.fromCache(
            data: parsedData,
            message: 'From Cache',
          );
        } catch (e) {
          // Cache data parsing failed, remove cache
          _cache.remove(cacheKey);
          _cacheTimers[cacheKey]?.cancel();
          _cacheTimers.remove(cacheKey);
        }
      }
      
      return null;
    });
  }
  
  /// Cache response
  Future<void> _cacheResponse<T>(BaseNetworkRequest<T> request, NetworkResponse<T> response) async {
    if (response.success && response.data != null) {
      final cacheKey = request.getCacheKey();
      
      await _cacheLock.synchronized(() {
        _cache[cacheKey] = response.data;
        
        // Cancel previous timer
        _cacheTimers[cacheKey]?.cancel();
        
        // Set new expiration timer
        _cacheTimers[cacheKey] = Timer(Duration(seconds: request.cacheDuration), () {
          // 缓存过期时也需要原子操作
          _cacheLock.synchronized(() {
            _cache.remove(cacheKey);
            _cacheTimers.remove(cacheKey);
          });
        });
      });
    }
  }
  
  /// Handle Dio error (deprecated, use unified exception handling system)
  @Deprecated('Use UnifiedExceptionHandler.instance.handleException instead')
  NetworkException _handleDioError(DioException error) {
    // Keep this method to ensure backward compatibility
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return const NetworkException(
          message: 'Connection timeout',
          statusCode: -1,
          errorCode: 'CONNECTION_TIMEOUT',
        );
      case DioExceptionType.sendTimeout:
        return const NetworkException(
          message: 'Send timeout',
          statusCode: -2,
          errorCode: 'SEND_TIMEOUT',
        );
      case DioExceptionType.receiveTimeout:
        return const NetworkException(
          message: 'Receive timeout',
          statusCode: -3,
          errorCode: 'RECEIVE_TIMEOUT',
        );
      case DioExceptionType.badResponse:
        return NetworkException(
          message: error.response?.statusMessage ?? 'Bad response',
          statusCode: error.response?.statusCode,
          errorCode: 'BAD_RESPONSE',
          originalError: error,
        );
      case DioExceptionType.cancel:
        return const NetworkException(
          message: 'Request cancelled',
          statusCode: -999,
          errorCode: 'CANCELLED',
        );
      case DioExceptionType.connectionError:
        return const NetworkException(
          message: 'Connection error',
          statusCode: -4,
          errorCode: 'CONNECTION_ERROR',
        );
      default:
        return NetworkException(
          message: error.message ?? 'Unknown error',
          statusCode: -5,
          errorCode: 'UNKNOWN_ERROR',
          originalError: error,
        );
    }
  }
  
  /// Get request unique key
  String _getRequestKey(BaseNetworkRequest request) {
    return '${request.method}:${request.path}:${request.queryParameters?.toString() ?? ''}';
  }
  
  /// Reconfigure Dio
  void reconfigure() {
    _initializeDio();
  }
  
  /// Add global interceptor
  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }
  
  /// Remove global interceptor
  void removeInterceptor(Interceptor interceptor) {
    _dio.interceptors.remove(interceptor);
  }
  
  /// Clean up resources
  void dispose() {
    cancelAllRequests();
    
    // Cancel all cache timers
    for (final timer in _cacheTimers.values) {
      timer.cancel();
    }
    _cacheTimers.clear();
    
    _dio.close();
    _cache.clear();
  }
  
  /// Get current status information
  Map<String, dynamic> getStatus() {
    return {
      'pendingRequests': _pendingRequests.length,
      'queuedRequests': _requestQueues.values.fold(0, (sum, queue) => sum + queue.length),
      'isProcessingQueue': _isProcessingQueue,
      'cacheSize': _cache.length,
    };
  }
  
  /// Execute file download request
  Future<NetworkResponse<T>> _executeDownloadRequest<T>(DownloadRequest<T> request) async {
    final requestKey = _getRequestKey(request);
    final completer = Completer<NetworkResponse<dynamic>>();
    _pendingRequests[requestKey] = completer;
    
    try {
      request.onRequestStart();
      final startTime = DateTime.now();
      
      // Check if save path exists, create if not
      final saveFile = File(request.savePath);
      final saveDir = saveFile.parent;
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
      
      // Check if file already exists
      if (await saveFile.exists() && !request.overwriteExisting) {
        final errorResponse = NetworkResponse<T>.error(
          message: 'File already exists: ${request.savePath}',
          statusCode: 409,
          errorCode: 'FILE_EXISTS',
        );
        request.onDownloadError?.call('File already exists');
        completer.complete(errorResponse);
        return errorResponse;
      }
      
      // Build request options
      final options = request.buildRequestOptions();
      
      // Execute download request
      final response = await _dio.download(
        options.path,
        request.savePath,
        data: options.data,
        queryParameters: options.queryParameters,
        options: Options(
          method: options.method,
          headers: options.headers,
          sendTimeout: options.sendTimeout,
          receiveTimeout: options.receiveTimeout,
        ),
        onReceiveProgress: (received, total) {
          if (request.onProgress != null && total != -1) {
            request.onProgress!(received, total);
          }
        },
      );
      
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      
      // Validate downloaded file
      if (await saveFile.exists()) {
        final fileSize = await saveFile.length();
        
        // Parse response
        final parsedData = request.parseResponse({
          'filePath': request.savePath,
          'fileSize': fileSize,
          'success': true,
        });
        
        final networkResponse = NetworkResponse<T>.success(
          data: parsedData,
          statusCode: response.statusCode ?? 200,
          message: 'File download successful',
          headers: response.headers.map,
          duration: duration,
        );
        
        request.onDownloadComplete?.call(request.savePath);
        request.onRequestComplete(networkResponse);
        completer.complete(networkResponse);
        
        return networkResponse;
      } else {
        throw Exception('File download failed: file not saved');
      }
      
    } catch (error) {
      // Use unified exception handling system
      final networkException = UnifiedExceptionHandler.instance.createNetworkException(error);

      // Try to use request's custom error handling
      NetworkException? customException;
      if (error is DioException) {
        customException = request.handleError(error);
      }
      final finalException = customException ?? networkException;

      // Asynchronously report the exception without blocking the flow
      unawaited(UnifiedExceptionHandler.instance.handleException(
        error,
        context: 'File download request',
        metadata: {
          'path': request.path,
          'savePath': request.savePath,
          'overwriteExisting': request.overwriteExisting,
        },
      ));

      final errorResponse = NetworkResponse<T>.error(
        message: (finalException as NetworkException).message,
        statusCode: (finalException as NetworkException).statusCode ?? -1,
        errorCode: (finalException as NetworkException).errorCode,
      );
      
      request.onDownloadError?.call((finalException as NetworkException).message);
      request.onRequestError(finalException as NetworkException);
      completer.complete(errorResponse);

      return errorResponse;
      
    } finally {
      _pendingRequests.remove(requestKey);
    }
  }
}