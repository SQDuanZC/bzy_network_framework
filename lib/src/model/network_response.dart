/// 网络响应统一封装类
class NetworkResponse<T> {
  /// 响应数据
  final T? data;
  
  /// 响应状态码
  final int statusCode;
  
  /// 响应消息
  final String message;
  
  /// 是否成功
  final bool success;
  
  /// 错误代码
  final String? errorCode;
  
  /// 响应头
  final Map<String, dynamic>? headers;
  
  /// 请求耗时（毫秒）
  final int? duration;
  
  /// 是否来自缓存
  final bool fromCache;
  
  /// 时间戳
  final DateTime timestamp;
  
  const NetworkResponse({
    this.data,
    required this.statusCode,
    required this.message,
    required this.success,
    this.errorCode,
    this.headers,
    this.duration,
    this.fromCache = false,
    required this.timestamp,
  });
  
  /// 成功响应构造函数
  factory NetworkResponse.success({
    T? data,
    int statusCode = 200,
    String message = 'Success',
    Map<String, dynamic>? headers,
    int? duration,
    bool fromCache = false,
  }) {
    return NetworkResponse<T>(
      data: data,
      statusCode: statusCode,
      message: message,
      success: true,
      headers: headers,
      duration: duration,
      fromCache: fromCache,
      timestamp: DateTime.now(),
    );
  }
  
  /// 失败响应构造函数
  factory NetworkResponse.error({
    required String message,
    int statusCode = -1,
    String? errorCode,
    Map<String, dynamic>? headers,
    int? duration,
  }) {
    return NetworkResponse<T>(
      statusCode: statusCode,
      message: message,
      success: false,
      errorCode: errorCode,
      headers: headers,
      duration: duration,
      timestamp: DateTime.now(),
    );
  }
  
  /// 从缓存创建响应
  factory NetworkResponse.fromCache({
    T? data,
    int statusCode = 200,
    String message = 'From Cache',
  }) {
    return NetworkResponse<T>(
      data: data,
      statusCode: statusCode,
      message: message,
      success: true,
      fromCache: true,
      timestamp: DateTime.now(),
    );
  }
  
  /// 转换数据类型
  NetworkResponse<R> transform<R>(R Function(T?) transformer) {
    return NetworkResponse<R>(
      data: transformer(data),
      statusCode: statusCode,
      message: message,
      success: success,
      errorCode: errorCode,
      headers: headers,
      duration: duration,
      fromCache: fromCache,
      timestamp: timestamp,
    );
  }
  
  /// 复制并修改部分属性
  NetworkResponse<T> copyWith({
    T? data,
    int? statusCode,
    String? message,
    bool? success,
    String? errorCode,
    Map<String, dynamic>? headers,
    int? duration,
    bool? fromCache,
    DateTime? timestamp,
  }) {
    return NetworkResponse<T>(
      data: data ?? this.data,
      statusCode: statusCode ?? this.statusCode,
      message: message ?? this.message,
      success: success ?? this.success,
      errorCode: errorCode ?? this.errorCode,
      headers: headers ?? this.headers,
      duration: duration ?? this.duration,
      fromCache: fromCache ?? this.fromCache,
      timestamp: timestamp ?? this.timestamp,
    );
  }
  
  @override
  String toString() {
    return 'NetworkResponse{'
        'success: $success, '
        'statusCode: $statusCode, '
        'message: $message, '
        'errorCode: $errorCode, '
        'fromCache: $fromCache, '
        'duration: ${duration}ms'
        '}';
  }

  NetworkResponse<R> cast<R>() {
    return NetworkResponse<R>(
      data: data as R?,
      statusCode: statusCode,
      message: message,
      success: success,
      errorCode: errorCode,
      headers: headers,
      duration: duration,
      fromCache: fromCache,
      timestamp: timestamp,
    );
  }
}