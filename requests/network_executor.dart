import 'dart:async';
import 'package:dio/dio.dart';
import 'base_network_request.dart';
import '../model/network_response.dart';
import '../config/network_config.dart';

/// 网络请求执行器 - 统一的网络请求入口点
class NetworkExecutor {
  static NetworkExecutor? _instance;
  late Dio _dio;
  final Map<String, dynamic> _cache = {};
  final Map<String, Completer<NetworkResponse>> _pendingRequests = {};
  final Map<RequestPriority, List<BaseNetworkRequest>> _requestQueues = {
    RequestPriority.critical: [],
    RequestPriority.high: [],
    RequestPriority.normal: [],
    RequestPriority.low: [],
  };
  final Map<String, Timer> _cacheTimers = {};
  bool _isProcessingQueue = false;
  
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
    
    // 添加拦截器
    _setupInterceptors();
  }
  
  /// 设置拦截器
  void _setupInterceptors() {
    final config = NetworkConfig.instance;
    
    // 基础拦截器设置
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
    // 检查缓存
    if (request.enableCache) {
      final cachedResponse = await _getCachedResponse<T>(request);
      if (cachedResponse != null) {
        request.onRequestComplete(cachedResponse);
        return cachedResponse;
      }
    }
    
    // 检查是否有相同的请求正在进行
    final requestKey = _getRequestKey(request);
    if (_pendingRequests.containsKey(requestKey)) {
      return await _pendingRequests[requestKey]!.future as NetworkResponse<T>;
    }
    
    // 根据优先级处理请求
    if (request.priority != RequestPriority.critical) {
      return await _enqueueRequest(request);
    }
    
    return await _executeRequest(request);
  }
  
  /// 执行具体的网络请求
  Future<NetworkResponse<T>> _executeRequest<T>(BaseNetworkRequest<T> request) async {
    final requestKey = _getRequestKey(request);
    final completer = Completer<NetworkResponse<T>>();
    _pendingRequests[requestKey] = completer as Completer<NetworkResponse>;
    
    try {
      request.onRequestStart();
      final startTime = DateTime.now();
      
      // 构建请求选项
      final options = request.buildRequestOptions();
      
      // 添加自定义拦截器
      if (request.customInterceptors != null) {
        for (final interceptor in request.customInterceptors!) {
          _dio.interceptors.add(interceptor);
        }
      }
      
      // 执行请求
      final response = await _dio.request(
        options.path,
        options: Options(
          method: options.method,
          headers: options.headers,
          sendTimeout: options.sendTimeout,
          receiveTimeout: options.receiveTimeout,
        ),
        queryParameters: options.queryParameters,
        data: options.data,
      );
      
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      
      // 解析响应
      final parsedData = request.parseResponse(response.data);
      
      final networkResponse = NetworkResponse<T>.success(
        data: parsedData,
        statusCode: response.statusCode ?? 200,
        message: response.statusMessage ?? 'Success',
        headers: response.headers.map,
        duration: duration,
      );
      
      // 缓存响应
      if (request.enableCache) {
        await _cacheResponse(request, networkResponse);
      }
      
      request.onRequestComplete(networkResponse);
      completer.complete(networkResponse);
      
      return networkResponse;
      
    } catch (error) {
      NetworkException networkException;
      
      if (error is DioException) {
        // 尝试使用请求的自定义错误处理
        networkException = request.handleError(error) ?? _handleDioError(error);
      } else {
        networkException = NetworkException(
          message: error.toString(),
          originalError: error,
        );
      }
      
      final errorResponse = NetworkResponse<T>.error(
        message: networkException.message,
        statusCode: networkException.statusCode ?? -1,
        errorCode: networkException.errorCode,
      );
      
      request.onRequestError(networkException);
      completer.complete(errorResponse);
      
      return errorResponse;
      
    } finally {
      _pendingRequests.remove(requestKey);
      
      // 移除自定义拦截器
      if (request.customInterceptors != null) {
        for (final interceptor in request.customInterceptors!) {
          _dio.interceptors.remove(interceptor);
        }
      }
    }
  }
  
  /// 将请求加入队列
  Future<NetworkResponse<T>> _enqueueRequest<T>(BaseNetworkRequest<T> request) async {
    final completer = Completer<NetworkResponse<T>>();
    
    // 将请求添加到对应优先级队列
    _requestQueues[request.priority]!.add(request);
    
    // 开始处理队列
    _processRequestQueue();
    
    return completer.future;
  }
  
  /// 处理请求队列
  void _processRequestQueue() async {
    if (_isProcessingQueue) return;
    
    _isProcessingQueue = true;
    
    try {
      // 按优先级处理请求
      for (final priority in RequestPriority.values.reversed) {
        final queue = _requestQueues[priority]!;
        
        while (queue.isNotEmpty) {
          final request = queue.removeAt(0);
          await _executeRequest(request);
          
          // 添加小延迟避免过于频繁的请求
          if (priority != RequestPriority.critical) {
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }
  
  /// 批量执行请求
  Future<List<NetworkResponse>> executeBatch(List<BaseNetworkRequest> requests) async {
    final futures = requests.map((request) => execute(request)).toList();
    return await Future.wait(futures);
  }
  
  /// 并发执行请求（限制并发数）
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
  
  /// 取消请求
  void cancelRequest(BaseNetworkRequest request) {
    final requestKey = _getRequestKey(request);
    
    // 从待处理请求中移除
    final completer = _pendingRequests.remove(requestKey);
    if (completer != null && !completer.isCompleted) {
      completer.complete(NetworkResponse.error(
        message: 'Request cancelled',
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
  void cancelAllRequests() {
    // 取消所有待处理的请求
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.complete(NetworkResponse.error(
          message: 'All requests cancelled',
          statusCode: -999,
          errorCode: 'ALL_CANCELLED',
        ));
      }
    }
    _pendingRequests.clear();
    
    // 清空所有队列
    for (final queue in _requestQueues.values) {
      queue.clear();
    }
  }
  
  /// 获取缓存的响应
  Future<NetworkResponse<T>?> _getCachedResponse<T>(BaseNetworkRequest<T> request) async {
    final cacheKey = request.getCacheKey();
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
      }
    }
    
    return null;
  }
  
  /// 缓存响应
  Future<void> _cacheResponse<T>(BaseNetworkRequest<T> request, NetworkResponse<T> response) async {
    if (response.success && response.data != null) {
      final cacheKey = request.getCacheKey();
      _cache[cacheKey] = response.data;
      
      // 取消之前的定时器
      _cacheTimers[cacheKey]?.cancel();
      
      // 设置新的过期定时器
      _cacheTimers[cacheKey] = Timer(Duration(seconds: request.cacheDuration), () {
        _cache.remove(cacheKey);
        _cacheTimers.remove(cacheKey);
      });
    }
  }
  
  /// 处理Dio错误
  NetworkException _handleDioError(DioException error) {
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
    return '${request.method}:${request.path}:${request.queryParameters?.toString() ?? ''}:${request.data?.toString() ?? ''}';
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
  void dispose() {
    cancelAllRequests();
    
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
    };
  }
}