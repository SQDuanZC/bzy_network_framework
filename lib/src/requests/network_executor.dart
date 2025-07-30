import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'base_network_request.dart';
import '../model/network_response.dart';
import '../config/network_config.dart';
import '../core/exception/unified_exception_handler.dart';

/// Network request executor - unified network request entry point
class NetworkExecutor {
  static NetworkExecutor? _instance;
  late Dio _dio;
  final Map<String, dynamic> _cache = {};
  final Map<String, Completer<NetworkResponse<dynamic>>> _pendingRequests = {};
  final Map<RequestPriority, List<BaseNetworkRequest>> _requestQueues = {
    RequestPriority.critical: [],
    RequestPriority.high: [],
    RequestPriority.normal: [],
    RequestPriority.low: [],
  };
  final Map<String, Timer> _cacheTimers = {};
  bool _isProcessingQueue = false;
  
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
    // Check cache
    if (request.enableCache) {
      final cachedResponse = await _getCachedResponse<T>(request);
      if (cachedResponse != null) {
        request.onRequestComplete(cachedResponse);
        return cachedResponse;
      }
    }
    
    // Check if same request is in progress
    final requestKey = _getRequestKey(request);
    if (_pendingRequests.containsKey(requestKey)) {
      final result = await _pendingRequests[requestKey]!.future;
      return result as NetworkResponse<T>;
    }
    
    // Handle request based on priority
    if (request.priority != RequestPriority.critical) {
      return await _enqueueRequest(request);
    }
    
    return await _executeRequest(request);
  }
  
  /// Execute specific network request
  Future<NetworkResponse<T>> _executeRequest<T>(BaseNetworkRequest<T> request) async {
    final requestKey = _getRequestKey(request);
    final completer = Completer<NetworkResponse<T>>();
    _pendingRequests[requestKey] = completer;
    
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
        return await _executeDownloadRequest<T>(request as DownloadRequest<T>);
      }
      
      // Execute normal request
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
      
      // Parse response
      final parsedData = request.parseResponse(response.data);
      
      final networkResponse = NetworkResponse<T>.success(
        data: parsedData,
        statusCode: response.statusCode ?? 200,
        message: response.statusMessage ?? 'Success',
        headers: response.headers.map,
        duration: duration,
      );
      
      // Cache response
      if (request.enableCache) {
        await _cacheResponse(request, networkResponse);
      }
      
      request.onRequestComplete(networkResponse);
      completer.complete(networkResponse);
      
      return networkResponse;
      
    } catch (error) {
      // Use unified exception handling system
      final unifiedException = await UnifiedExceptionHandler.instance.handleException(
        error,
        context: 'Network request execution',
        metadata: {
          'path': request.path,
          'method': request.method.value,
          'enableCache': request.enableCache,
        },
      );
      
      // Try to use request's custom error handling
      NetworkException? customException;
      if (error is DioException) {
        customException = request.handleError(error);
      }
      
      final errorResponse = NetworkResponse<T>.error(
        message: customException?.message ?? unifiedException.message,
        statusCode: customException?.statusCode ?? unifiedException.statusCode,
        errorCode: customException?.errorCode ?? unifiedException.code.name,
      );
      
      // Create compatible NetworkException for callback
      final networkException = NetworkException(
        message: unifiedException.message,
        statusCode: unifiedException.statusCode,
        errorCode: unifiedException.code.name,
        originalError: unifiedException.originalError,
      );
      
      request.onRequestError(networkException);
      completer.complete(errorResponse);
      
      return errorResponse;
      
    } finally {
      _pendingRequests.remove(requestKey);
      
      // Remove custom interceptors
      if (request.customInterceptors != null) {
        for (final interceptor in request.customInterceptors!) {
          _dio.interceptors.remove(interceptor);
        }
      }
    }
  }
  
  /// Enqueue request
  Future<NetworkResponse<T>> _enqueueRequest<T>(BaseNetworkRequest<T> request) async {
    // Execute request directly, without using queue mechanism (simplified implementation)
    return await _executeRequest(request);
  }
  
  /// Process request queue
  void _processRequestQueue() async {
    if (_isProcessingQueue) return;
    
    _isProcessingQueue = true;
    
    try {
      // Process requests by priority
      for (final priority in RequestPriority.values.reversed) {
        final queue = _requestQueues[priority]!;
        
        while (queue.isNotEmpty) {
          final request = queue.removeAt(0);
          await _executeRequest(request);
          
          // Add small delay to avoid too frequent requests
          if (priority != RequestPriority.critical) {
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }
      }
    } finally {
      _isProcessingQueue = false;
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
      completer.complete(NetworkResponse.error(
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
  void cancelAllRequests() {
    // Cancel all pending requests
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
    
    // Clear all queues
    for (final queue in _requestQueues.values) {
      queue.clear();
    }
  }
  
  /// Get cached response
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
        // Cache data parsing failed, remove cache
        _cache.remove(cacheKey);
      }
    }
    
    return null;
  }
  
  /// Cache response
  Future<void> _cacheResponse<T>(BaseNetworkRequest<T> request, NetworkResponse<T> response) async {
    if (response.success && response.data != null) {
      final cacheKey = request.getCacheKey();
      _cache[cacheKey] = response.data;
      
      // Cancel previous timer
      _cacheTimers[cacheKey]?.cancel();
      
      // Set new expiration timer
      _cacheTimers[cacheKey] = Timer(Duration(seconds: request.cacheDuration), () {
        _cache.remove(cacheKey);
        _cacheTimers.remove(cacheKey);
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
    final completer = Completer<NetworkResponse<T>>();
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
        options: Options(
          method: options.method,
          headers: options.headers,
          sendTimeout: options.sendTimeout,
          receiveTimeout: options.receiveTimeout,
        ),
        queryParameters: options.queryParameters,
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
      final unifiedException = await UnifiedExceptionHandler.instance.handleException(
        error,
        context: 'File download request',
        metadata: {
          'path': request.path,
          'savePath': request.savePath,
          'overwriteExisting': request.overwriteExisting,
        },
      );
      
      // Try to use request's custom error handling
      NetworkException? customException;
      if (error is DioException) {
        customException = request.handleError(error);
      }
      
      final errorResponse = NetworkResponse<T>.error(
        message: customException?.message ?? unifiedException.message,
        statusCode: customException?.statusCode ?? unifiedException.statusCode,
        errorCode: customException?.errorCode ?? unifiedException.code.name,
      );
      
      // Create compatible NetworkException for callback
      final networkException = NetworkException(
        message: unifiedException.message,
        statusCode: unifiedException.statusCode,
        errorCode: unifiedException.code.name,
        originalError: unifiedException.originalError,
      );
      
      request.onDownloadError?.call(networkException.message);
      request.onRequestError(networkException);
      completer.complete(errorResponse);
      
      return errorResponse;
      
    } finally {
      _pendingRequests.remove(requestKey);
    }
  }
}