import 'package:dio/dio.dart';
import '../model/network_response.dart';
import '../config/network_config.dart';

/// HTTP方法枚举
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

/// 网络请求基类 - "每个网络请求都是对象"的核心实现
abstract class BaseNetworkRequest<T> {
  /// 请求路径
  String get path;
  
  /// HTTP方法
  HttpMethod get method => HttpMethod.get;
  
  /// 请求参数
  Map<String, dynamic>? get queryParameters => null;
  
  /// 请求体数据
  dynamic get data => null;
  
  /// 请求头
  Map<String, dynamic>? get headers => null;
  
  /// 超时时间（毫秒）
  int? get timeout => null;
  
  /// 是否启用缓存
  bool get enableCache => false;
  
  /// 缓存时长（秒）
  int get cacheDuration => 300;
  
  /// 缓存键
  String? get cacheKey => null;
  
  /// 重试次数
  int get retryCount => 0;
  
  /// 重试间隔（毫秒）
  int get retryDelay => 1000;
  
  /// 请求优先级
  RequestPriority get priority => RequestPriority.normal;
  
  /// 是否需要认证
  bool get requiresAuth => true;
  
  /// 自定义拦截器
  List<Interceptor>? get customInterceptors => null;
  
  /// 响应数据解析
  T parseResponse(dynamic data);
  
  /// 错误处理
  NetworkException? handleError(DioException error) => null;
  
  /// 请求前置处理
  void onRequestStart() {}
  
  /// 请求完成处理
  void onRequestComplete(NetworkResponse<T> response) {}
  
  /// 请求失败处理
  void onRequestError(NetworkException error) {}
  
  /// 获取完整的请求选项
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
  
  /// 获取缓存键
  String getCacheKey() {
    if (cacheKey != null) return cacheKey!;
    
    final params = queryParameters?.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&') ?? '';
    
    return '${method.value}:$path${params.isNotEmpty ? '?$params' : ''}';
  }
}

/// 请求优先级枚举
enum RequestPriority {
  low,
  normal,
  high,
  critical,
}

/// 网络异常类
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
  
  @override
  String toString() {
    return 'NetworkException: $message (statusCode: $statusCode, errorCode: $errorCode)';
  }
}

/// 文件上传请求基类
abstract class UploadRequest<T> extends BaseNetworkRequest<T> {
  @override
  HttpMethod get method => HttpMethod.post;
  /// 上传文件路径
  String get filePath;
  
  /// 文件字段名
  String get fileFieldName => 'file';
  
  /// 上传进度回调
  void Function(int sent, int total)? get onProgress => null;
  
  @override
  dynamic get data {
    return FormData.fromMap({
      fileFieldName: MultipartFile.fromFileSync(filePath),
      ...?getFormData(),
    });
  }
  
  /// 获取表单数据
  Map<String, dynamic>? getFormData() => null;
}

/// 文件下载请求基类
abstract class DownloadRequest<T> extends BaseNetworkRequest<T> {
  @override
  HttpMethod get method => HttpMethod.get;
  /// 下载文件保存路径
  String get savePath;
  
  /// 下载进度回调
  void Function(int received, int total)? get onProgress => null;
  
  /// 是否覆盖已存在的文件
  bool get overwriteExisting => true;
  
  /// 下载完成回调
  void Function(String filePath)? get onDownloadComplete => null;
  
  /// 下载失败回调
  void Function(String error)? get onDownloadError => null;
  
  @override
  bool get enableCache => false; // 下载请求通常不缓存
}