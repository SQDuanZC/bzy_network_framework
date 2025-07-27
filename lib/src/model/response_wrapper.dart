/// Unified response data structure wrapper
/// Provides generic support for unified API response format handling
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
  
  /// Create response object from JSON
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
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'data': data,
      'success': success,
      'timestamp': timestamp,
    };
  }
  
  /// Check if request is successful
  static bool _isSuccess(int code) {
    return code == 200 || code == 0;
  }
  
  /// Create success response
  factory BaseResponse.success({
    T? data,
    String message = 'Request successful',
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
  
  /// Create error response
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

/// Paginated response data structure
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

// Network exception classes and error types have been moved to unified exception handling system
// Please use UnifiedException, ExceptionType and ErrorCode
// Import path: '../core/exception/unified_exception_handler.dart'