/// 统一响应数据结构封装
/// 提供泛型支持，统一处理API响应格式
class BaseResponse<T> {
  final int code;
  final String message;
  final T? data;
  final bool success;
  final int? timestamp;
  
  const BaseResponse({
    required this.code,
    required this.message,
    this.data,
    required this.success,
    this.timestamp,
  });
  
  /// 从JSON创建响应对象
  factory BaseResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return BaseResponse<T>(
      code: json['code'] ?? json['status'] ?? 0,
      message: json['message'] ?? json['msg'] ?? '',
      data: json['data'] != null && fromJsonT != null 
          ? fromJsonT(json['data']) 
          : json['data'],
      success: _isSuccess(json['code'] ?? json['status'] ?? 0),
      timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'data': data,
      'success': success,
      'timestamp': timestamp,
    };
  }
  
  /// 判断请求是否成功
  static bool _isSuccess(int code) {
    return code == 200 || code == 0;
  }
  
  /// 创建成功响应
  factory BaseResponse.success({
    T? data,
    String message = '请求成功',
    int code = 200,
  }) {
    return BaseResponse<T>(
      code: code,
      message: message,
      data: data,
      success: true,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
  
  /// 创建失败响应
  factory BaseResponse.error({
    required String message,
    int code = -1,
    T? data,
  }) {
    return BaseResponse<T>(
      code: code,
      message: message,
      data: data,
      success: false,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
  
  @override
  String toString() {
    return 'BaseResponse{code: $code, message: $message, data: $data, success: $success}';
  }
}

/// 分页响应数据结构
class PageResponse<T> {
  final List<T> list;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;
  
  const PageResponse({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });
  
  factory PageResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final List<dynamic> listData = json['list'] ?? json['data'] ?? [];
    final List<T> items = listData
        .map((item) => fromJsonT(item as Map<String, dynamic>))
        .toList();
    
    final int total = json['total'] ?? 0;
    final int page = json['page'] ?? json['current'] ?? 1;
    final int pageSize = json['pageSize'] ?? json['size'] ?? 10;
    
    return PageResponse<T>(
      list: items,
      total: total,
      page: page,
      pageSize: pageSize,
      hasMore: (page * pageSize) < total,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'list': list,
      'total': total,
      'page': page,
      'pageSize': pageSize,
      'hasMore': hasMore,
    };
  }
}

/// 网络异常类
class NetworkException implements Exception {
  final String message;
  final int? code;
  final dynamic data;
  final NetworkErrorType type;
  
  const NetworkException({
    required this.message,
    this.code,
    this.data,
    this.type = NetworkErrorType.unknown,
  });
  
  @override
  String toString() {
    return 'NetworkException{message: $message, code: $code, type: $type}';
  }
}

/// 网络错误类型枚举
enum NetworkErrorType {
  timeout, // 超时
  noNetwork, // 无网络连接
  serverError, // 服务器错误
  unauthorized, // 未授权
  forbidden, // 禁止访问
  notFound, // 资源未找到
  parseError, // 解析错误
  unknown, // 未知错误
}