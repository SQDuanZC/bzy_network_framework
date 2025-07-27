import 'package:dio/dio.dart';
import '../model/network_response.dart';
import '../config/network_config.dart';
import '../core/exception/unified_exception_handler.dart';

/// HTTP method enumeration
enum HttpMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  delete('DELETE'),
  patch('PATCH'),
  head('HEAD'),
  options('OPTIONS');

  const HttpMethod(this.value);
  final String value;
}

/// Base network request class - Core implementation of "every network request is an object"
abstract class BaseNetworkRequest<T> {
  /// Request path
  String get path;
  
  /// HTTP method
  HttpMethod get method => HttpMethod.get;
  
  /// Request parameters
  Map<String, dynamic>? get queryParameters => null;
  
  /// Request body data
  dynamic get data => null;
  
  /// Request headers
  Map<String, dynamic>? get headers => null;
  
  /// Timeout duration (milliseconds)
  int? get timeout => null;
  
  /// Whether to enable cache
  bool get enableCache => false;
  
  /// Cache duration (seconds)
  int get cacheDuration => 300;
  
  /// Cache key
  String? get cacheKey => null;
  
  /// Retry count
  int get retryCount => 0;
  
  /// Retry delay (milliseconds)
  int get retryDelay => 1000;
  
  /// Request priority
  RequestPriority get priority => RequestPriority.normal;
  
  /// Whether authentication is required
  bool get requiresAuth => true;
  
  /// Custom interceptors
  List<Interceptor>? get customInterceptors => null;
  
  /// Response data parsing
  T parseResponse(dynamic data);
  
  /// Error handling (returns compatible NetworkException)
  NetworkException? handleError(DioException error) => null;
  
  /// Pre-request processing
  void onRequestStart() {}
  
  /// Request completion processing
  void onRequestComplete(NetworkResponse<T> response) {}
  
  /// Request failure processing
  void onRequestError(NetworkException error) {}
  
  /// Get complete request options
  RequestOptions buildRequestOptions() {
    final config = NetworkConfig.instance;
    
    return RequestOptions(
      path: path,
      method: method.value,
      queryParameters: queryParameters,
      data: data,
      headers: {
        ...?headers,
      },
      connectTimeout: Duration(milliseconds: timeout ?? config.connectTimeout),
      receiveTimeout: Duration(milliseconds: timeout ?? config.receiveTimeout),
      sendTimeout: Duration(milliseconds: timeout ?? config.sendTimeout),
    );
  }
  
  /// Get cache key
  String getCacheKey() {
    if (cacheKey != null) return cacheKey!;
    
    final params = queryParameters?.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&') ?? '';
    
    return '${method.value}:$path${params.isNotEmpty ? '?$params' : ''}';
  }
}

/// Request priority enumeration
enum RequestPriority {
  low,
  normal,
  high,
  critical,
}

/// Compatibility NetworkException class (for backward compatibility)
class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final dynamic originalError;
  
  const NetworkException({
    required this.message,
    this.statusCode,
    this.errorCode,
    this.originalError,
  });
  
  /// Create from UnifiedException
  factory NetworkException.fromUnified(UnifiedException exception) {
    return NetworkException(
      message: exception.message,
      statusCode: exception.statusCode,
      errorCode: exception.code.name,
      originalError: exception.originalError,
    );
  }
  
  @override
  String toString() {
    return 'NetworkException: $message (statusCode: $statusCode, errorCode: $errorCode)';
  }
}

/// File upload request base class
abstract class UploadRequest<T> extends BaseNetworkRequest<T> {
  @override
  HttpMethod get method => HttpMethod.post;
  /// Upload file path
  String get filePath;
  
  /// File field name
  String get fileFieldName => 'file';
  
  /// Upload progress callback
  void Function(int sent, int total)? get onProgress => null;
  
  @override
  dynamic get data {
    return FormData.fromMap({
      fileFieldName: MultipartFile.fromFileSync(filePath),
      ...?getFormData(),
    });
  }
  
  /// Get form data
  Map<String, dynamic>? getFormData() => null;
}

/// File download request base class
abstract class DownloadRequest<T> extends BaseNetworkRequest<T> {
  @override
  HttpMethod get method => HttpMethod.get;
  /// Download file save path
  String get savePath;
  
  /// Download progress callback
  void Function(int received, int total)? get onProgress => null;
  
  /// Whether to overwrite existing files
  bool get overwriteExisting => true;
  
  /// Download completion callback
  void Function(String filePath)? get onDownloadComplete => null;
  
  /// Download failure callback
  void Function(String error)? get onDownloadError => null;
  
  @override
  bool get enableCache => false; // Download requests are usually not cached
}