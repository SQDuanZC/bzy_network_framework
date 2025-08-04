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


/// 网络请求执行器 - 统一网络请求入口
/// 提供高效的并发控制和请求管理
class NetworkExecutor {
  static NetworkExecutor? _instance;
  late Dio _dio;
  final Map<String, dynamic> _cache = {};
  final Map<String, Timer> _cacheTimers = {};
  
  // 并发安全锁
  final Lock _pendingRequestsLock = Lock();
  final Lock _queueLock = Lock();
  final Lock _cacheLock = Lock();
  final Lock _processingLock = Lock();
  
  // 请求队列
  final Map<String, Completer<NetworkResponse<dynamic>>> _pendingRequests = {};
  final Map<RequestPriority, List<BaseNetworkRequest<dynamic>>> _requestQueues = {
    RequestPriority.critical: [],
    RequestPriority.high: [],
    RequestPriority.normal: [],
    RequestPriority.low: [],
  };
  bool _isProcessingQueue = false;
  
  // 批量请求标记，避免重复处理
  final Set<String> _batchRequestIds = {};
  final Lock _batchLock = Lock();
  
  /// 单例实例
  static NetworkExecutor get instance {
    _instance ??= NetworkExecutor._internal();
    return _instance!;
  }
  
  NetworkExecutor._internal() {
    _initializeDio();
  }
  
  /// 初始化Dio实例
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
  
  /// 设置拦截器
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
  
  /// 执行网络请求
  Future<NetworkResponse<T>> execute<T>(BaseNetworkRequest<T> request) async {
    if (request is BatchRequest) {
      final result = await _executeBatchRequest(request as BatchRequest) as NetworkResponse<T>;
      return result;
    }
    
    // 检查缓存
    if (request.enableCache) {
      final cachedResponse = await _getCachedResponse<T>(request);
      if (cachedResponse != null) {
        request.onRequestComplete(cachedResponse);
        return cachedResponse;
      }
    }
    
    // 检查是否有相同请求正在处理中
    final requestKey = _getRequestKey(request);
    final existingCompleter = await _pendingRequestsLock.synchronized(() {
      return _pendingRequests[requestKey];
    });
    
    if (existingCompleter != null) {
      try {
        final result = await existingCompleter.future;
        return result.cast<T>();
      } catch (e) {
        // 如果待处理的请求失败，重新抛出异常
        rethrow;
      }
    }
    
    // 根据优先级处理请求
    if (request.priority != RequestPriority.critical) {
      return await _enqueueRequest(request);
    }
    
    return await _executeRequest(request);
  }
  
  /// 执行特定网络请求
  Future<NetworkResponse<T>> _executeRequest<T>(BaseNetworkRequest<T> request, {bool isBatch = false}) async {
    final requestKey = _getRequestKey(request);
    final completer = Completer<NetworkResponse<T>>();
    
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
      
      // 检查是否为下载请求
      if (request is DownloadRequest) {
        final result = await _executeDownloadRequest<T>(request as DownloadRequest<T>);
        return result;
      }
      
      // 直接执行请求，避免拦截器链中的无限递归
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
      if (!isBatch) {
        completer.complete(networkResponse);
      }
      
      return networkResponse;
    } catch (e) {
      final error = e is DioException ? e : DioException(
        requestOptions: request.buildRequestOptions(),
        error: e
      );
      
      final networkException = UnifiedExceptionHandler.instance.createNetworkException(error);
      final customException = request.handleError(error);
      final finalException = customException ?? networkException;
      
      request.onRequestError(finalException as NetworkException);
      if (!isBatch) {
        completer.completeError(finalException);
      }
      
      throw finalException;
    } finally {
      // 确保在所有情况下都清理资源
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
    }
  }


  /// 执行批量请求
  Future<NetworkResponse<Map<String, dynamic>>> _executeBatchRequest(BatchRequest batchRequest) async {
    final batchId = 'batch_${DateTime.now().millisecondsSinceEpoch}_${batchRequest.hashCode}';
    
    // 检查批量请求是否已经在处理中
    final isAlreadyProcessing = await _batchLock.synchronized(() {
      if (_batchRequestIds.contains(batchId)) {
        return true;
      }
      _batchRequestIds.add(batchId);
      return false;
    });
    
    if (isAlreadyProcessing) {
      return NetworkResponse.error(
        statusCode: 409,
        message: '批量请求已在处理中',
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
        message: '批量请求成功',
      );
      batchRequest.onRequestComplete(response);
      return response;
    } catch (e) {
      final exception = e is NetworkException ? e : NetworkException(message: e.toString());
      batchRequest.onRequestError(exception);
      return NetworkResponse.error(
        statusCode: 500,
        message: '批量请求失败: ${exception.message}',
        errorCode: exception.errorCode,
      );
    } finally {
      // 清理批量请求标记
      await _batchLock.synchronized(() {
        _batchRequestIds.remove(batchId);
      });
    }
  }
  
  /// 执行批量请求
  Future<List<NetworkResponse>> executeBatch(List<BaseNetworkRequest> requests) async {
    final futures = requests.map((request) => execute(request)).toList();
    return await Future.wait(futures);
  }
  
  /// 执行并发请求（带并发限制）
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
  
  /// 处理错误
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
      context: '网络请求执行',
      metadata: {
        'path': request.path,
        'method': request.method.value,
        'enableCache': request.enableCache,
      },
    ));

    request.onRequestError(finalException as NetworkException);
    print('🔍 [DEBUG] 完成completer错误处理');
    completer.completeError(finalException);
  }
  
  /// 根据优先级入队请求
  Future<NetworkResponse<T>> _enqueueRequest<T>(BaseNetworkRequest<T> request) async {
    final completer = Completer<NetworkResponse<T>>();
    final requestKey = _getRequestKey(request);
    
    print('🔍 [DEBUG] _enqueueRequest called for ${request.runtimeType} with key: $requestKey');
    
    // 原子操作：添加到队列和待处理请求映射
    await _queueLock.synchronized(() {
      _requestQueues[request.priority]!.add(request);
      print('🔍 [DEBUG] Added to queue ${request.priority}, queue size: ${_requestQueues[request.priority]!.length}');
    });
    
    await _pendingRequestsLock.synchronized(() {
      _pendingRequests[requestKey] = completer as Completer<NetworkResponse<dynamic>>;
      print('🔍 [DEBUG] Added to _pendingRequests, total pending: ${_pendingRequests.length}');
    });
    
    // 如果队列未在处理中，开始处理队列
    await _processingLock.synchronized(() {
      if (!_isProcessingQueue) {
        print('🔍 [DEBUG] Starting queue processing');
        unawaited(_processRequestQueue());
      } else {
        print('🔍 [DEBUG] Queue processing already in progress');
      }
    });
    
    print('🔍 [DEBUG] Waiting for enqueued request completer...');
    
    // 添加超时处理，确保即使队列处理出现问题，请求也能在一定时间后完成
    try {
      return await completer.future.timeout(
        const Duration(seconds: 10), // 缩短超时时间
        onTimeout: () {
          print('🔍 [DEBUG] Request timed out, completing with error');
          // 如果超时，从队列和待处理请求中移除
          _queueLock.synchronized(() {
            _requestQueues[request.priority]!.removeWhere(
              (r) => _getRequestKey(r) == requestKey
            );
          });
          
          _pendingRequestsLock.synchronized(() {
            _pendingRequests.remove(requestKey);
          });
          
          throw TimeoutException('请求在10秒后超时');
        },
      );
    } catch (e) {
      if (e is TimeoutException) {
        return NetworkResponse<T>.error(
          message: '请求超时',
          statusCode: -999,
          errorCode: 'REQUEST_TIMEOUT',
        );
      }
      rethrow;
    }
  }
  
  /// 处理请求队列
  Future<void> _processRequestQueue() async {
    print('🔍 [DEBUG] _processRequestQueue called, _isProcessingQueue: $_isProcessingQueue');
    // 避免重复处理
    if (_isProcessingQueue) {
      print('🔍 [DEBUG] Queue processing already in progress, returning');
      return;
    }
    
    _isProcessingQueue = true;
    
    try {
      // 添加总体超时
      final timeout = const Duration(seconds: 10); // 缩短超时时间
      final stopTime = DateTime.now().add(timeout);
      
      // 持续处理直到所有队列为空或超时
      while (_hasQueuedRequests() && DateTime.now().isBefore(stopTime)) {
        // 按优先级处理请求（critical -> high -> normal -> low）
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
                  if (!completer.isCompleted) {
                    completer.complete(result.cast<dynamic>());
                  }
                  _pendingRequests.remove(requestKey);
                }
              });
            } catch (error) {
              // 原子操作：完成错误请求
              await _pendingRequestsLock.synchronized(() {
                if (_pendingRequests.containsKey(requestKey)) {
                  final completer = _pendingRequests[requestKey]! as Completer<NetworkResponse<dynamic>>;
                  if (!completer.isCompleted) {
                    completer.completeError(error);
                  }
                  _pendingRequests.remove(requestKey);
                }
              });
            }
            
            // 添加小延迟以避免请求过于频繁
            if (priority != RequestPriority.critical) {
              await Future.delayed(const Duration(milliseconds: 10));
            }
            
            // 中断循环，从最高优先级重新开始检查
            break;
          }
        }
        
        // 检查队列前的小延迟
        await Future.delayed(const Duration(milliseconds: 1));
      }
      
      // 如果超时后仍有请求，清理它们
      if (_hasQueuedRequests()) {
        print('🔍 [DEBUG] Queue processing timed out, cleaning up remaining requests');
        await cancelAllRequests();
      }
    } finally {
      _isProcessingQueue = false;
    }
  }
  
  /// 检查是否有排队的请求
  bool _hasQueuedRequests() {
    return _requestQueues.values.any((queue) => queue.isNotEmpty);
  }
  
  /// 取消请求
  void cancelRequest(BaseNetworkRequest request) {
    final requestKey = _getRequestKey(request);
    
    // 从待处理请求中移除
    final completer = _pendingRequests.remove(requestKey);
    if (completer != null && !completer.isCompleted) {
      completer.complete(NetworkResponse<dynamic>.error(
        message: '请求已取消',
        statusCode: -999,
        errorCode: 'CANCELLED',
      ));
    }
    
    // 从队列中移除
    for (final queue in _requestQueues.values) {
      queue.removeWhere((r) => _getRequestKey(r) == requestKey);
    }
  }
  
  /// 取消所有请求
  Future<void> cancelAllRequests() async {
    // 原子操作：取消所有待处理请求
    await _pendingRequestsLock.synchronized(() {
      for (final completer in _pendingRequests.values) {
        if (!completer.isCompleted) {
          completer.complete(NetworkResponse<dynamic>.error(
            message: '所有请求已取消',
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
    await _batchLock.synchronized(() {
      _batchRequestIds.clear();
    });
  }
  
  /// 获取缓存响应
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
          // 缓存数据解析失败，移除缓存
          _cache.remove(cacheKey);
          _cacheTimers[cacheKey]?.cancel();
          _cacheTimers.remove(cacheKey);
        }
      }
      
      return null;
    });
  }
  
  /// 缓存响应
  Future<void> _cacheResponse<T>(BaseNetworkRequest<T> request, NetworkResponse<T> response) async {
    if (response.success && response.data != null) {
      final cacheKey = request.getCacheKey();
      
      await _cacheLock.synchronized(() {
        _cache[cacheKey] = response.data;
        
        // 取消之前的定时器
        _cacheTimers[cacheKey]?.cancel();
        
        // 设置新的过期定时器
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
  
  /// 处理Dio错误（已弃用，请使用统一异常处理系统）
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
  
  /// 获取请求唯一键
  String _getRequestKey(BaseNetworkRequest request) {
    return '${request.method}:${request.path}:${request.queryParameters?.toString() ?? ''}';
  }
  
  /// 重新配置Dio
  void reconfigure() {
    _initializeDio();
  }
  
  /// 添加全局拦截器
  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }
  
  /// 移除全局拦截器
  void removeInterceptor(Interceptor interceptor) {
    _dio.interceptors.remove(interceptor);
  }
  
  /// 清理资源
  Future<void> dispose() async {
    await cancelAllRequests();
    
    // 取消所有缓存定时器
    for (final timer in _cacheTimers.values) {
      timer.cancel();
    }
    _cacheTimers.clear();
    
    _dio.close();
    _cache.clear();
  }
  
  /// 获取当前状态信息
  Map<String, dynamic> getStatus() {
    return {
      'pendingRequests': _pendingRequests.length,
      'queuedRequests': _requestQueues.values.fold(0, (sum, queue) => sum + queue.length),
      'isProcessingQueue': _isProcessingQueue,
      'cacheSize': _cache.length,
      'batchRequestsCount': _batchRequestIds.length,
    };
  }
  
  /// 执行文件下载请求
  Future<NetworkResponse<T>> _executeDownloadRequest<T>(DownloadRequest<T> request) async {
    final requestKey = _getRequestKey(request);
    final completer = Completer<NetworkResponse<dynamic>>();
    _pendingRequests[requestKey] = completer;
    
    try {
      request.onRequestStart();
      final startTime = DateTime.now();
      
      // 检查保存路径是否存在，如果不存在则创建
      final saveFile = File(request.savePath);
      final saveDir = saveFile.parent;
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
      
      // 检查文件是否已存在
      if (await saveFile.exists() && !request.overwriteExisting) {
        final errorResponse = NetworkResponse<T>.error(
          message: '文件已存在: ${request.savePath}',
          statusCode: 409,
          errorCode: 'FILE_EXISTS',
        );
        request.onDownloadError?.call('文件已存在');
        completer.complete(errorResponse);
        return errorResponse;
      }
      
      // 构建请求选项
      final options = request.buildRequestOptions();
      
      // 执行下载请求
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
      
      // 验证下载的文件
      if (await saveFile.exists()) {
        final fileSize = await saveFile.length();
        
        // 解析响应
        final parsedData = request.parseResponse({
          'filePath': request.savePath,
          'fileSize': fileSize,
          'success': true,
        });
        
        final networkResponse = NetworkResponse<T>.success(
          data: parsedData,
          statusCode: response.statusCode ?? 200,
          message: '文件下载成功',
          headers: response.headers.map,
          duration: duration,
        );
        
        request.onDownloadComplete?.call(request.savePath);
        request.onRequestComplete(networkResponse);
        completer.complete(networkResponse);
        
        return networkResponse;
      } else {
        throw Exception('文件下载失败: 文件未保存');
      }
      
    } catch (error) {
      // 使用统一异常处理系统
      final networkException = UnifiedExceptionHandler.instance.createNetworkException(error);

      // 尝试使用请求的自定义错误处理
      NetworkException? customException;
      if (error is DioException) {
        customException = request.handleError(error);
      }
      final finalException = customException ?? networkException;

      // 异步报告异常，不阻塞流程
      unawaited(UnifiedExceptionHandler.instance.handleException(
        error,
        context: '文件下载请求',
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