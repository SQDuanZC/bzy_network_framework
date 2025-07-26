import 'package:dio/dio.dart';
import '../config/network_config.dart';
import '../interceptor/logging_interceptor.dart';
import '../interceptor/header_interceptor.dart';
import '../interceptor/retry_interceptor.dart';

/// HTTP客户端封装
/// 封装Dio实例，注入拦截器，保持单例模式
class HttpClient {
  static HttpClient? _instance;
  late Dio _dio;
  late HeaderInterceptor _headerInterceptor;
  late LoggingInterceptor _loggingInterceptor;
  late RetryInterceptor _retryInterceptor;
  
  // 私有构造函数
  HttpClient._() {
    _initializeDio();
  }
  
  /// 获取单例实例
  static HttpClient get instance {
    _instance ??= HttpClient._();
    return _instance!;
  }
  
  /// 获取Dio实例
  Dio get dio => _dio;
  
  /// 获取请求头拦截器
  HeaderInterceptor get headerInterceptor => _headerInterceptor;
  
  /// 初始化Dio
  void _initializeDio() {
    _dio = Dio();
    
    // 基础配置
    _dio.options = BaseOptions(
      baseUrl: NetworkConfig.instance.baseUrl,
      connectTimeout: Duration(milliseconds: NetworkConfig.instance.connectTimeout),
      receiveTimeout: Duration(milliseconds: NetworkConfig.instance.receiveTimeout),
      sendTimeout: Duration(milliseconds: NetworkConfig.instance.sendTimeout),
      responseType: ResponseType.json,
      contentType: Headers.jsonContentType,
      validateStatus: (status) {
        // 200-299 和 304 认为是成功
        return (status != null && status >= 200 && status < 300) || status == 304;
      },
    );
    
    // 初始化拦截器
    _initializeInterceptors();
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
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
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
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
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
  void close({bool force = false}) {
    _dio.close(force: force);
  }
}