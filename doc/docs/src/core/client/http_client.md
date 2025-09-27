# HttpClient HTTP客户端文档

## 概述
`HttpClient` 是 BZY Network Framework 的核心HTTP客户端抽象层，提供统一的HTTP请求接口，支持多种HTTP客户端实现（如Dio、http等）。它封装了HTTP请求的复杂性，提供简洁易用的API，同时支持请求拦截、响应处理、错误管理等高级功能。

## 文件位置
```
lib/src/core/client/http_client.dart
lib/src/core/client/dio_http_client.dart
lib/src/core/client/default_http_client.dart
```

## 核心特性

### 1. 统一接口
- **抽象层设计**: 统一的HTTP客户端接口
- **多实现支持**: 支持不同的HTTP客户端库
- **透明切换**: 可以无缝切换不同实现
- **标准化API**: 提供标准化的请求方法

### 2. 请求管理
- **多种请求方法**: GET、POST、PUT、DELETE、PATCH等
- **请求配置**: 灵活的请求参数配置
- **请求头管理**: 统一的请求头处理
- **请求体处理**: 支持多种请求体格式

### 3. 响应处理
- **响应解析**: 自动响应数据解析
- **状态码处理**: 标准化状态码处理
- **错误映射**: HTTP错误到业务错误的映射
- **响应拦截**: 响应数据拦截和处理

### 4. 高级功能
- **请求重试**: 自动请求重试机制
- **超时控制**: 灵活的超时配置
- **并发控制**: 请求并发数量控制
- **连接池**: HTTP连接池管理

## 主要组件

### 1. HTTP客户端接口
```dart
abstract class HttpClient {
  // 基础请求方法
  Future<HttpResponse> request(HttpRequest request);
  
  // 便捷请求方法
  Future<HttpResponse> get(String url, {Map<String, dynamic>? queryParameters});
  Future<HttpResponse> post(String url, {dynamic data});
  Future<HttpResponse> put(String url, {dynamic data});
  Future<HttpResponse> delete(String url);
  Future<HttpResponse> patch(String url, {dynamic data});
  
  // 配置管理
  void configure(HttpClientConfig config);
  HttpClientConfig get config;
  
  // 拦截器管理
  void addInterceptor(HttpInterceptor interceptor);
  void removeInterceptor(HttpInterceptor interceptor);
  
  // 生命周期管理
  Future<void> close();
}
```

### 2. HTTP请求模型
```dart
class HttpRequest {
  final String url;
  final HttpMethod method;
  final Map<String, dynamic>? queryParameters;
  final Map<String, String>? headers;
  final dynamic data;
  final Duration? timeout;
  final bool followRedirects;
  final int maxRedirects;
  final ResponseType responseType;
  
  HttpRequest({
    required this.url,
    required this.method,
    this.queryParameters,
    this.headers,
    this.data,
    this.timeout,
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.responseType = ResponseType.json,
  });
}
```

### 3. HTTP响应模型
```dart
class HttpResponse {
  final int statusCode;
  final String statusMessage;
  final dynamic data;
  final Map<String, List<String>> headers;
  final HttpRequest request;
  final bool isRedirect;
  final List<RedirectRecord> redirects;
  final Duration duration;
  
  HttpResponse({
    required this.statusCode,
    required this.statusMessage,
    required this.data,
    required this.headers,
    required this.request,
    this.isRedirect = false,
    this.redirects = const [],
    required this.duration,
  });
  
  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isClientError => statusCode >= 400 && statusCode < 500;
  bool get isServerError => statusCode >= 500;
}
```

### 4. HTTP客户端配置
```dart
class HttpClientConfig {
  final String? baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final Map<String, String> defaultHeaders;
  final bool followRedirects;
  final int maxRedirects;
  final bool persistentConnection;
  final int maxConnectionsPerHost;
  final bool enableLogging;
  final LogLevel logLevel;
  
  HttpClientConfig({
    this.baseUrl,
    this.connectTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(seconds: 30),
    this.defaultHeaders = const {},
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.persistentConnection = true,
    this.maxConnectionsPerHost = 6,
    this.enableLogging = false,
    this.logLevel = LogLevel.info,
  });
}
```

## 核心方法

### 1. 基础请求方法
```dart
// 通用请求方法
Future<HttpResponse> request(HttpRequest request);

// GET请求
Future<HttpResponse> get(
  String url, {
  Map<String, dynamic>? queryParameters,
  Map<String, String>? headers,
  Duration? timeout,
});

// POST请求
Future<HttpResponse> post(
  String url, {
  dynamic data,
  Map<String, String>? headers,
  Duration? timeout,
});

// PUT请求
Future<HttpResponse> put(
  String url, {
  dynamic data,
  Map<String, String>? headers,
  Duration? timeout,
});

// DELETE请求
Future<HttpResponse> delete(
  String url, {
  Map<String, String>? headers,
  Duration? timeout,
});

// PATCH请求
Future<HttpResponse> patch(
  String url, {
  dynamic data,
  Map<String, String>? headers,
  Duration? timeout,
});
```

### 2. 高级请求方法
```dart
// 文件上传
Future<HttpResponse> upload(
  String url,
  String filePath, {
  String fieldName = 'file',
  Map<String, String>? fields,
  ProgressCallback? onProgress,
});

// 文件下载
Future<HttpResponse> download(
  String url,
  String savePath, {
  ProgressCallback? onProgress,
  bool deleteOnError = true,
});

// 批量请求
Future<List<HttpResponse>> batch(List<HttpRequest> requests);

// 并发请求
Future<List<HttpResponse>> concurrent(
  List<HttpRequest> requests, {
  int maxConcurrency = 3,
});
```

### 3. 配置管理
```dart
// 设置配置
void configure(HttpClientConfig config);

// 获取配置
HttpClientConfig get config;

// 更新基础URL
void setBaseUrl(String baseUrl);

// 设置默认头部
void setDefaultHeaders(Map<String, String> headers);

// 添加默认头部
void addDefaultHeader(String key, String value);

// 移除默认头部
void removeDefaultHeader(String key);
```

### 4. 拦截器管理
```dart
// 添加拦截器
void addInterceptor(HttpInterceptor interceptor);

// 移除拦截器
void removeInterceptor(HttpInterceptor interceptor);

// 清除所有拦截器
void clearInterceptors();

// 获取拦截器列表
List<HttpInterceptor> get interceptors;
```

## 使用示例

### 1. 基本HTTP请求
```dart
import 'package:bzy_network_framework/bzy_network_framework.dart';

// 创建HTTP客户端
final httpClient = DioHttpClient();

// 配置客户端
httpClient.configure(HttpClientConfig(
  baseUrl: 'https://api.example.com',
  connectTimeout: Duration(seconds: 30),
  receiveTimeout: Duration(seconds: 30),
  defaultHeaders: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
));

// GET请求
final getResponse = await httpClient.get('/users');
if (getResponse.isSuccess) {
  final users = getResponse.data as List;
  print('用户数量: ${users.length}');
}

// POST请求
final postResponse = await httpClient.post(
  '/users',
  data: {
    'name': 'John Doe',
    'email': 'john@example.com',
  },
);

if (postResponse.isSuccess) {
  print('用户创建成功: ${postResponse.data}');
}

// PUT请求
final putResponse = await httpClient.put(
  '/users/123',
  data: {
    'name': 'Jane Doe',
    'email': 'jane@example.com',
  },
);

// DELETE请求
final deleteResponse = await httpClient.delete('/users/123');
```

### 2. 高级请求配置
```dart
// 自定义请求
final request = HttpRequest(
  url: '/api/data',
  method: HttpMethod.post,
  queryParameters: {
    'page': 1,
    'limit': 20,
    'sort': 'created_at',
  },
  headers: {
    'Authorization': 'Bearer $token',
    'X-Custom-Header': 'custom-value',
  },
  data: {
    'filter': {
      'status': 'active',
      'category': 'electronics',
    },
  },
  timeout: Duration(seconds: 60),
);

final response = await httpClient.request(request);
```

### 3. 文件上传和下载
```dart
// 文件上传
final uploadResponse = await httpClient.upload(
  '/upload',
  '/path/to/file.jpg',
  fieldName: 'image',
  fields: {
    'description': '用户头像',
    'category': 'avatar',
  },
  onProgress: (sent, total) {
    final progress = (sent / total * 100).toStringAsFixed(1);
    print('上传进度: $progress%');
  },
);

if (uploadResponse.isSuccess) {
  print('文件上传成功: ${uploadResponse.data}');
}

// 文件下载
final downloadResponse = await httpClient.download(
  '/files/document.pdf',
  '/path/to/save/document.pdf',
  onProgress: (received, total) {
    if (total != -1) {
      final progress = (received / total * 100).toStringAsFixed(1);
      print('下载进度: $progress%');
    }
  },
);

if (downloadResponse.isSuccess) {
  print('文件下载成功');
}
```

### 4. 批量和并发请求
```dart
// 批量请求（顺序执行）
final batchRequests = [
  HttpRequest(url: '/api/users', method: HttpMethod.get),
  HttpRequest(url: '/api/products', method: HttpMethod.get),
  HttpRequest(url: '/api/orders', method: HttpMethod.get),
];

final batchResponses = await httpClient.batch(batchRequests);
for (int i = 0; i < batchResponses.length; i++) {
  print('请求 ${i + 1} 状态: ${batchResponses[i].statusCode}');
}

// 并发请求（并行执行）
final concurrentRequests = [
  HttpRequest(url: '/api/user/profile', method: HttpMethod.get),
  HttpRequest(url: '/api/user/settings', method: HttpMethod.get),
  HttpRequest(url: '/api/user/notifications', method: HttpMethod.get),
];

final concurrentResponses = await httpClient.concurrent(
  concurrentRequests,
  maxConcurrency: 2, // 最大并发数
);

for (final response in concurrentResponses) {
  if (response.isSuccess) {
    print('请求成功: ${response.request.url}');
  }
}
```

### 5. 拦截器使用
```dart
// 认证拦截器
class AuthInterceptor extends HttpInterceptor {
  final String token;
  
  AuthInterceptor(this.token);
  
  @override
  Future<HttpRequest> onRequest(HttpRequest request) async {
    // 添加认证头部
    final headers = Map<String, String>.from(request.headers ?? {});
    headers['Authorization'] = 'Bearer $token';
    
    return request.copyWith(headers: headers);
  }
  
  @override
  Future<HttpResponse> onResponse(HttpResponse response) async {
    // 检查认证状态
    if (response.statusCode == 401) {
      // 处理认证失效
      await _refreshToken();
    }
    
    return response;
  }
  
  @override
  Future<HttpResponse> onError(HttpError error) async {
    // 处理认证错误
    if (error.statusCode == 401) {
      // 重新认证后重试
      await _refreshToken();
      return await _retryRequest(error.request);
    }
    
    throw error;
  }
}

// 日志拦截器
class LoggingInterceptor extends HttpInterceptor {
  @override
  Future<HttpRequest> onRequest(HttpRequest request) async {
    print('请求: ${request.method} ${request.url}');
    return request;
  }
  
  @override
  Future<HttpResponse> onResponse(HttpResponse response) async {
    print('响应: ${response.statusCode} ${response.request.url}');
    return response;
  }
}

// 添加拦截器
httpClient.addInterceptor(AuthInterceptor(userToken));
httpClient.addInterceptor(LoggingInterceptor());
```

## 不同实现

### 1. Dio HTTP客户端
```dart
class DioHttpClient extends HttpClient {
  late final Dio _dio;
  
  DioHttpClient() {
    _dio = Dio();
    _setupInterceptors();
  }
  
  @override
  Future<HttpResponse> request(HttpRequest request) async {
    try {
      final response = await _dio.request(
        request.url,
        data: request.data,
        queryParameters: request.queryParameters,
        options: Options(
          method: request.method.name,
          headers: request.headers,
          sendTimeout: request.timeout,
          receiveTimeout: request.timeout,
        ),
      );
      
      return _mapResponse(response, request);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }
  
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 处理请求拦截
          handler.next(options);
        },
        onResponse: (response, handler) async {
          // 处理响应拦截
          handler.next(response);
        },
        onError: (error, handler) async {
          // 处理错误拦截
          handler.next(error);
        },
      ),
    );
  }
}
```

### 2. 默认HTTP客户端
```dart
class DefaultHttpClient extends HttpClient {
  late final http.Client _client;
  
  DefaultHttpClient() {
    _client = http.Client();
  }
  
  @override
  Future<HttpResponse> request(HttpRequest request) async {
    try {
      final uri = _buildUri(request);
      final headers = _buildHeaders(request);
      
      http.Response response;
      
      switch (request.method) {
        case HttpMethod.get:
          response = await _client.get(uri, headers: headers);
          break;
        case HttpMethod.post:
          response = await _client.post(
            uri,
            headers: headers,
            body: _encodeBody(request.data),
          );
          break;
        case HttpMethod.put:
          response = await _client.put(
            uri,
            headers: headers,
            body: _encodeBody(request.data),
          );
          break;
        case HttpMethod.delete:
          response = await _client.delete(uri, headers: headers);
          break;
        default:
          throw UnsupportedError('不支持的HTTP方法: ${request.method}');
      }
      
      return _mapResponse(response, request);
    } catch (e) {
      throw _mapError(e, request);
    }
  }
}
```

## 错误处理

### 1. HTTP错误映射
```dart
class HttpError extends NetworkException {
  final int? statusCode;
  final String? statusMessage;
  final HttpRequest request;
  final dynamic response;
  
  HttpError({
    required String message,
    this.statusCode,
    this.statusMessage,
    required this.request,
    this.response,
    Object? cause,
  }) : super(message, cause: cause);
  
  bool get isClientError => statusCode != null && statusCode! >= 400 && statusCode! < 500;
  bool get isServerError => statusCode != null && statusCode! >= 500;
  bool get isNetworkError => statusCode == null;
}

// 错误映射函数
HttpError _mapError(dynamic error, HttpRequest request) {
  if (error is SocketException) {
    return HttpError(
      message: '网络连接失败',
      request: request,
      cause: error,
    );
  } else if (error is TimeoutException) {
    return HttpError(
      message: '请求超时',
      request: request,
      cause: error,
    );
  } else if (error is DioException) {
    return HttpError(
      message: error.message ?? '请求失败',
      statusCode: error.response?.statusCode,
      statusMessage: error.response?.statusMessage,
      request: request,
      response: error.response?.data,
      cause: error,
    );
  } else {
    return HttpError(
      message: '未知错误: $error',
      request: request,
      cause: error,
    );
  }
}
```

### 2. 重试机制
```dart
class RetryInterceptor extends HttpInterceptor {
  final int maxRetries;
  final Duration retryDelay;
  final List<int> retryStatusCodes;
  
  RetryInterceptor({
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.retryStatusCodes = const [500, 502, 503, 504],
  });
  
  @override
  Future<HttpResponse> onError(HttpError error) async {
    if (_shouldRetry(error)) {
      return await _retryRequest(error.request);
    }
    
    throw error;
  }
  
  bool _shouldRetry(HttpError error) {
    return error.statusCode != null &&
           retryStatusCodes.contains(error.statusCode) &&
           _getRetryCount(error.request) < maxRetries;
  }
  
  Future<HttpResponse> _retryRequest(HttpRequest request) async {
    final retryCount = _getRetryCount(request) + 1;
    _setRetryCount(request, retryCount);
    
    // 延迟重试
    await Future.delayed(retryDelay * retryCount);
    
    // 重新发送请求
    return await httpClient.request(request);
  }
}
```

## 性能优化

### 1. 连接池管理
```dart
class ConnectionPoolConfig {
  final int maxConnections;
  final int maxConnectionsPerHost;
  final Duration idleTimeout;
  final bool keepAlive;
  
  ConnectionPoolConfig({
    this.maxConnections = 100,
    this.maxConnectionsPerHost = 6,
    this.idleTimeout = const Duration(seconds: 30),
    this.keepAlive = true,
  });
}
```

### 2. 请求缓存
```dart
class CacheInterceptor extends HttpInterceptor {
  final CacheManager _cacheManager;
  
  CacheInterceptor(this._cacheManager);
  
  @override
  Future<HttpResponse> onRequest(HttpRequest request) async {
    if (_shouldCache(request)) {
      final cached = await _cacheManager.get(_getCacheKey(request));
      if (cached != null) {
        return _deserializeResponse(cached);
      }
    }
    
    return super.onRequest(request);
  }
  
  @override
  Future<HttpResponse> onResponse(HttpResponse response) async {
    if (_shouldCache(response.request) && response.isSuccess) {
      await _cacheManager.set(
        _getCacheKey(response.request),
        _serializeResponse(response),
      );
    }
    
    return response;
  }
}
```

### 3. 请求压缩
```dart
class CompressionInterceptor extends HttpInterceptor {
  @override
  Future<HttpRequest> onRequest(HttpRequest request) async {
    if (_shouldCompress(request)) {
      final headers = Map<String, String>.from(request.headers ?? {});
      headers['Accept-Encoding'] = 'gzip, deflate';
      
      if (request.data != null && _isCompressibleData(request.data)) {
        final compressedData = _compressData(request.data);
        headers['Content-Encoding'] = 'gzip';
        
        return request.copyWith(
          headers: headers,
          data: compressedData,
        );
      }
      
      return request.copyWith(headers: headers);
    }
    
    return request;
  }
}
```

## 最佳实践

### 1. 客户端配置
```dart
// 创建生产环境配置
final productionConfig = HttpClientConfig(
  baseUrl: 'https://api.production.com',
  connectTimeout: Duration(seconds: 30),
  receiveTimeout: Duration(seconds: 30),
  sendTimeout: Duration(seconds: 30),
  defaultHeaders: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'MyApp/1.0.0',
  },
  followRedirects: true,
  maxRedirects: 3,
  enableLogging: false,
);

// 创建开发环境配置
final developmentConfig = HttpClientConfig(
  baseUrl: 'https://api.development.com',
  connectTimeout: Duration(seconds: 60),
  receiveTimeout: Duration(seconds: 60),
  sendTimeout: Duration(seconds: 60),
  enableLogging: true,
  logLevel: LogLevel.debug,
);
```

### 2. 错误处理策略
```dart
Future<T> _handleRequest<T>(
  Future<HttpResponse> Function() request,
  T Function(dynamic data) parser,
) async {
  try {
    final response = await request();
    
    if (response.isSuccess) {
      return parser(response.data);
    } else {
      throw HttpError(
        message: '请求失败: ${response.statusMessage}',
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        request: response.request,
        response: response.data,
      );
    }
  } on HttpError {
    rethrow;
  } catch (e) {
    throw HttpError(
      message: '网络请求异常: $e',
      request: HttpRequest(url: '', method: HttpMethod.get),
      cause: e,
    );
  }
}
```

### 3. 资源管理
```dart
class HttpClientManager {
  static final Map<String, HttpClient> _clients = {};
  
  static HttpClient getClient(String name) {
    return _clients[name] ??= _createClient(name);
  }
  
  static HttpClient _createClient(String name) {
    final client = DioHttpClient();
    
    // 配置客户端
    client.configure(_getConfigForClient(name));
    
    // 添加通用拦截器
    client.addInterceptor(LoggingInterceptor());
    client.addInterceptor(RetryInterceptor());
    
    return client;
  }
  
  static Future<void> closeAll() async {
    for (final client in _clients.values) {
      await client.close();
    }
    _clients.clear();
  }
}
```

## 注意事项

### 1. 内存管理
- 及时关闭HTTP客户端
- 避免创建过多客户端实例
- 合理配置连接池大小

### 2. 安全考虑
- 使用HTTPS进行敏感数据传输
- 验证SSL证书
- 避免在日志中记录敏感信息

### 3. 性能优化
- 复用HTTP客户端实例
- 合理设置超时时间
- 使用连接池和Keep-Alive

### 4. 错误处理
- 区分网络错误和业务错误
- 提供友好的错误信息
- 实现合理的重试策略