import 'package:dio/dio.dart';
import '../../config/network_config.dart';
import '../interceptor/logging_interceptor.dart';
import '../interceptor/header_interceptor.dart';
import '../interceptor/retry_interceptor.dart';
import '../exception/unified_exception_handler.dart';
import '../../utils/network_logger.dart';

/// HTTP客户端封装
/// 封装Dio实例，注入拦截器，保持单例模式
class HttpClient {
  static HttpClient? _instance;
  late Dio _dio;
  late HeaderInterceptor _headerInterceptor;
  late LoggingInterceptor _loggingInterceptor;
  late RetryInterceptor _retryInterceptor;
  
  // 配置和统计
  NetworkConfig? _config;
  final HttpClientStats _stats = HttpClientStats();
  bool _isInitialized = false;
  
  // 私有构造函数
  HttpClient._();
  
  /// 获取单例实例
  static HttpClient get instance {
    _instance ??= HttpClient._();
    return _instance!;
  }
  
  /// 异步初始化
  Future<void> initialize(NetworkConfig config) async {
    if (_isInitialized) return;
    
    _config = config;
    _validateConfig(config);
    _initializeDio(config);
    _initializeInterceptors();
    _isInitialized = true;
    
    NetworkLogger.executor.info('HTTP客户端初始化完成');
  }
  
  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 获取统计信息
  HttpClientStats get stats => _stats;
  
  /// 获取Dio实例
  Dio get dio => _dio;
  
  /// 获取请求头拦截器
  HeaderInterceptor get headerInterceptor => _headerInterceptor;
  
  /// 验证配置
  void _validateConfig(NetworkConfig config) {
    if (config.baseUrl.isEmpty) {
      throw ArgumentError('baseUrl cannot be empty');
    }
    if (config.connectTimeout <= 0) {
      throw ArgumentError('connectTimeout must be positive');
    }
    if (config.receiveTimeout <= 0) {
      throw ArgumentError('receiveTimeout must be positive');
    }
    if (config.sendTimeout <= 0) {
      throw ArgumentError('sendTimeout must be positive');
    }
  }
  
  /// 初始化Dio
  void _initializeDio(NetworkConfig config) {
    _dio = Dio();
    
    // 基础配置
    _dio.options = BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: Duration(milliseconds: config.connectTimeout),
      receiveTimeout: Duration(milliseconds: config.receiveTimeout),
      sendTimeout: Duration(milliseconds: config.sendTimeout),
      responseType: ResponseType.json,
      contentType: Headers.jsonContentType,
      validateStatus: (status) {
        // 200-299 和 304 认为是成功
        return (status != null && status >= 200 && status < 300) || status == 304;
      },
    );
  }
  
  /// 初始化拦截器
  void _initializeInterceptors() {
    // 清除现有拦截器
    _dio.interceptors.clear();
    
    // 请求头拦截器（第一个执行）
    _headerInterceptor = HeaderInterceptor();
    _dio.interceptors.add(_headerInterceptor);
    
    // 重试拦截器
    _retryInterceptor = RetryInterceptor();
    _dio.interceptors.add(_retryInterceptor);
    
    // 日志拦截器（最后执行，记录最终结果）
    _loggingInterceptor = LoggingInterceptor();
    _dio.interceptors.add(_loggingInterceptor);
  }
  
  /// 统一错误处理
  Exception _handleError(dynamic error) {
    if (error is DioException) {
      return UnifiedExceptionHandler.instance.createNetworkException(error);
    }
    return Exception('HTTP请求失败: ${error.toString()}');
  }
  
  /// 重新配置客户端
  void reconfigure({
    String? baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Map<String, dynamic>? headers,
  }) {
    if (baseUrl != null) {
      _dio.options.baseUrl = baseUrl;
    }
    if (connectTimeout != null) {
      _dio.options.connectTimeout = connectTimeout;
    }
    if (receiveTimeout != null) {
      _dio.options.receiveTimeout = receiveTimeout;
    }
    if (sendTimeout != null) {
      _dio.options.sendTimeout = sendTimeout;
    }
    if (headers != null) {
      _dio.options.headers.addAll(headers);
    }
  }
  
  /// 添加拦截器
  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }
  
  /// 移除拦截器
  void removeInterceptor(Interceptor interceptor) {
    _dio.interceptors.remove(interceptor);
  }
  
  /// 清除所有拦截器
  void clearInterceptors() {
    _dio.interceptors.clear();
  }
  
  /// 重置拦截器为默认配置
  void resetInterceptors() {
    _initializeInterceptors();
  }
  
  /// 配置拦截器顺序
  void configureInterceptors(InterceptorConfig config) {
    _dio.interceptors.clear();
    
    // 按配置顺序添加拦截器
    final sortedInterceptors = config.interceptors.toList()
      ..sort((a, b) {
        final orderA = config.order[a.runtimeType.toString()] ?? 0;
        final orderB = config.order[b.runtimeType.toString()] ?? 0;
        return orderA.compareTo(orderB);
      });
    
    for (final interceptor in sortedInterceptors) {
      _dio.interceptors.add(interceptor);
    }
  }
  
  /// 设置Token
  void setToken(String? token) {
    _headerInterceptor.setToken(token);
  }
  
  /// 设置刷新Token
  void setRefreshToken(String? refreshToken) {
    _headerInterceptor.setRefreshToken(refreshToken);
  }
  
  /// 清除Token
  void clearTokens() {
    _headerInterceptor.clearTokens();
  }
  
  /// 获取当前Token
  String? get token => _headerInterceptor.token;
  
  /// 获取刷新Token
  String? get refreshToken => _headerInterceptor.refreshToken;
  
  /// GET请求
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      
      _stats.recordRequest('GET', response.statusCode ?? 0);
      return response;
    } catch (e) {
      _stats.recordError('GET', e.runtimeType.toString());
      throw _handleError(e);
    }
  }
  
  /// POST请求
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      
      _stats.recordRequest('POST', response.statusCode ?? 0);
      return response;
    } catch (e) {
      _stats.recordError('POST', e.runtimeType.toString());
      throw _handleError(e);
    }
  }
  
  /// PUT请求
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }
  
  /// DELETE请求
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
  
  /// PATCH请求
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }
  
  /// HEAD请求
  Future<Response<T>> head<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.head<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
  
  /// 下载文件
  Future<Response> download(
    String urlPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    Options? options,
  }) {
    return _dio.download(
      urlPath,
      savePath,
      onReceiveProgress: onReceiveProgress,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      deleteOnError: deleteOnError,
      lengthHeader: lengthHeader,
      options: options,
    );
  }
  
  /// 关闭客户端
  Future<void> close({bool force = false}) async {
    _dio.close(force: force);
  }
  
  /// 销毁客户端
  Future<void> dispose() async {
    // 等待所有请求完成
    _dio.close(force: false);
    
    // 清理拦截器
    _dio.interceptors.clear();
    
    // 清空单例实例
    _instance = null;
  }
}

/// HTTP客户端统计信息
class HttpClientStats {
  int totalRequests = 0;
  int successfulRequests = 0;
  int failedRequests = 0;
  final Map<String, int> requestCounts = {};
  final Map<int, int> statusCodeCounts = {};
  final Map<String, int> errorCounts = {};
  
  /// 记录请求
  void recordRequest(String method, int statusCode) {
    totalRequests++;
    requestCounts[method] = (requestCounts[method] ?? 0) + 1;
    statusCodeCounts[statusCode] = (statusCodeCounts[statusCode] ?? 0) + 1;
    
    if (statusCode >= 200 && statusCode < 300) {
      successfulRequests++;
    } else {
      failedRequests++;
    }
  }
  
  /// 记录错误
  void recordError(String method, String errorType) {
    errorCounts[errorType] = (errorCounts[errorType] ?? 0) + 1;
  }
  
  /// 重置统计
  void reset() {
    totalRequests = 0;
    successfulRequests = 0;
    failedRequests = 0;
    requestCounts.clear();
    statusCodeCounts.clear();
    errorCounts.clear();
  }
  
  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'totalRequests': totalRequests,
      'successfulRequests': successfulRequests,
      'failedRequests': failedRequests,
      'requestCounts': requestCounts,
      'statusCodeCounts': statusCodeCounts,
      'errorCounts': errorCounts,
      'successRate': totalRequests > 0 ? successfulRequests / totalRequests : 0.0,
    };
  }
}

/// 拦截器配置
class InterceptorConfig {
  final List<Interceptor> interceptors;
  final Map<String, int> order;
  
  const InterceptorConfig({
    required this.interceptors,
    this.order = const {},
  });
}