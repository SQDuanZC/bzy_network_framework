# BZY Network Framework

English | [中文](README.md)

[![pub package](https://img.shields.io/pub/v/bzy_network_framework.svg)](https://pub.dev/packages/bzy_network_framework)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![Version](https://img.shields.io/badge/Version-v2.2.1-green.svg)](https://github.com/SQDuanZC/bzy_network_framework)

**BZY Network Framework** is a high-performance, easily extensible Flutter network request solution that provides comprehensive network requests, caching, interceptors, monitoring, and other features.

## 🆕 Latest Updates (v2.2.1)

- 🌐 **Internationalization**: Core framework comments fully translated to English
- 📚 **Documentation**: Added unified exception handling documentation
- 🧪 **Testing**: Enhanced exception handling test suite
- 🔧 **Code Quality**: Improved code documentation consistency and maintainability

## ✨ Features

- 🚀 **High Performance**: Built on Dio with support for concurrent requests and connection pooling
- 🔧 **Easy Extension**: Plugin-based architecture with support for custom interceptors and plugins
- 📦 **Smart Caching**: Multi-level caching strategy with memory and disk cache support
- 🔄 **Auto Retry**: Intelligent retry mechanism with exponential backoff algorithm
- 📊 **Performance Monitoring**: Real-time monitoring of network performance and error statistics
- 🛡️ **Type Safety**: Complete TypeScript-style type definitions
- 📱 **Mobile Optimized**: Optimized for mobile network environments
- 🔐 **Secure & Reliable**: Support for certificate pinning and request signing

## 🚀 Quick Start

### Installation

Install from GitHub repository:

```yaml
dependencies:
  bzy_network_framework:
    git:
      url: https://github.com/SQDuanZC/bzy_network_framework.git
      ref: main  # or specify a specific branch/tag
```

Then run:

```bash
flutter pub get
```

### Basic Configuration

```dart
import 'package:bzy_network_framework/bzy_network_framework.dart';

void main() async {
  // Initialize BZY Network Framework
  await UnifiedNetworkFramework.initialize(
    baseUrl: 'https://api.example.com',
    connectTimeout: Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 30),
    enableLogging: true,
    enableCache: true,
    maxRetries: 3,
  );
  
  runApp(MyApp());
}
```

### Creating Requests

#### 1. Define Data Models

```dart
// Define user model
class User {
  final String id;
  final String name;
  final String email;
  final String? avatar;
  
  User({
    required this.id, 
    required this.name, 
    required this.email,
    this.avatar,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatar: json['avatar'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar': avatar,
    };
  }
}
```

#### 2. GET Requests

```dart
// Get single user
class GetUserRequest extends BaseNetworkRequest<User> {
  final String userId;
  
  GetUserRequest(this.userId);
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  String get path => '/users/$userId';
  
  @override
  User parseResponse(Map<String, dynamic> json) {
    return User.fromJson(json['data']);
  }
}

// Get user list
class GetUsersRequest extends BaseNetworkRequest<List<User>> {
  final int page;
  final int limit;
  
  GetUsersRequest({this.page = 1, this.limit = 20});
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  String get path => '/users';
  
  @override
  Map<String, dynamic> get queryParameters => {
    'page': page,
    'limit': limit,
  };
  
  @override
  List<User> parseResponse(Map<String, dynamic> json) {
    final List<dynamic> data = json['data'];
    return data.map((item) => User.fromJson(item)).toList();
  }
}
```

#### 3. POST Requests

```dart
// Create user
class CreateUserRequest extends BaseNetworkRequest<User> {
  final String name;
  final String email;
  
  CreateUserRequest({required this.name, required this.email});
  
  @override
  HttpMethod get method => HttpMethod.post;
  
  @override
  String get path => '/users';
  
  @override
  Map<String, dynamic> get data => {
    'name': name,
    'email': email,
  };
  
  @override
  User parseResponse(Map<String, dynamic> json) {
    return User.fromJson(json['data']);
  }
}
```

#### 4. PUT/PATCH Requests

```dart
// Update user information
class UpdateUserRequest extends BaseNetworkRequest<User> {
  final String userId;
  final String? name;
  final String? email;
  
  UpdateUserRequest({
    required this.userId,
    this.name,
    this.email,
  });
  
  @override
  HttpMethod get method => HttpMethod.put;
  
  @override
  String get path => '/users/$userId';
  
  @override
  Map<String, dynamic> get data => {
    if (name != null) 'name': name,
    if (email != null) 'email': email,
  };
  
  @override
  User parseResponse(Map<String, dynamic> json) {
    return User.fromJson(json['data']);
  }
}
```

#### 5. DELETE Requests

```dart
// Delete user
class DeleteUserRequest extends BaseNetworkRequest<bool> {
  final String userId;
  
  DeleteUserRequest(this.userId);
  
  @override
  HttpMethod get method => HttpMethod.delete;
  
  @override
  String get path => '/users/$userId';
  
  @override
  bool parseResponse(Map<String, dynamic> json) {
    return json['success'] ?? false;
  }
}
```

#### 6. Execute Requests

```dart
// Basic request execution
final getUserRequest = GetUserRequest('123');
final response = await UnifiedNetworkFramework.instance.execute(getUserRequest);

if (response.isSuccess) {
  final user = response.data;
  print('User name: ${user?.name}');
} else {
  print('Request failed: ${response.message}');
  print('Error code: ${response.statusCode}');
}

// Request with error handling
try {
  final createRequest = CreateUserRequest(
    name: 'John Doe',
    email: 'john.doe@example.com',
  );
  
  final result = await UnifiedNetworkFramework.instance.execute(createRequest);
  
  if (result.isSuccess) {
    print('User created successfully: ${result.data?.name}');
  } else {
    // Handle business errors
    switch (result.statusCode) {
      case 400:
        print('Invalid request parameters');
        break;
      case 401:
        print('Unauthorized, please login again');
        break;
      case 409:
        print('User already exists');
        break;
      default:
        print('Creation failed: ${result.message}');
    }
  }
} catch (e) {
  // Handle network exceptions
  print('Network error: $e');
}
```

## 📖 Documentation

- [Quick Start Guide](doc/docs/QUICK_START_GUIDE.md)
- [Advanced Features](doc/docs/ADVANCED_FEATURES.md)
- [API Reference](doc/docs/API_REFERENCE.md)
- [Best Practices](doc/docs/BEST_PRACTICES.md)
- [Migration Guide](doc/docs/MIGRATION_GUIDE.md)

## 🏗️ Architecture

```
BZY Network Framework
├── Unified Framework Layer (UnifiedNetworkFramework)
├── Plugin System (Plugins)
├── Interceptor System (Interceptors)
├── Cache Manager (Cache Manager)
├── Queue Manager (Queue Manager)
├── Network Executor (Network Executor)
└── Configuration Manager (Config Manager)
```

## 🔧 Advanced Features

### File Upload

#### 1. Single File Upload

```dart
class UploadAvatarRequest extends UploadRequest<UploadResult> {
  final File imageFile;
  final String userId;
  
  UploadAvatarRequest(this.imageFile, this.userId);
  
  @override
  String get path => '/users/$userId/avatar';
  
  @override
  Map<String, dynamic> get files => {
    'avatar': MultipartFile.fromFileSync(
      imageFile.path,
      filename: 'avatar.jpg',
    ),
  };
  
  @override
  Map<String, dynamic> get data => {
    'userId': userId,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
  
  @override
  UploadResult parseResponse(Map<String, dynamic> json) {
    return UploadResult.fromJson(json['data']);
  }
}

// Execute upload
final uploadRequest = UploadAvatarRequest(imageFile, '123');
final result = await UnifiedNetworkFramework.instance.execute(uploadRequest);

if (result.isSuccess) {
  print('Upload successful: ${result.data?.url}');
}
```

#### 2. Multiple Files Upload

```dart
class UploadMultipleFilesRequest extends UploadRequest<List<UploadResult>> {
  final List<File> files;
  final String albumId;
  
  UploadMultipleFilesRequest(this.files, this.albumId);
  
  @override
  String get path => '/albums/$albumId/photos';
  
  @override
  Map<String, dynamic> get files {
    final Map<String, dynamic> fileMap = {};
    for (int i = 0; i < files.length; i++) {
      fileMap['photo_$i'] = MultipartFile.fromFileSync(
        files[i].path,
        filename: 'photo_$i.jpg',
      );
    }
    return fileMap;
  }
  
  @override
  List<UploadResult> parseResponse(Map<String, dynamic> json) {
    final List<dynamic> data = json['data'];
    return data.map((item) => UploadResult.fromJson(item)).toList();
  }
}
```

### File Download

```dart
class DownloadFileRequest extends DownloadRequest {
  final String fileId;
  final String savePath;
  
  DownloadFileRequest(this.fileId, this.savePath);
  
  @override
  String get path => '/files/$fileId/download';
  
  @override
  String get downloadPath => savePath;
  
  @override
  void onProgress(int received, int total) {
    final progress = (received / total * 100).toStringAsFixed(1);
    print('Download progress: $progress%');
  }
}

// Execute download
final downloadRequest = DownloadFileRequest('file123', '/path/to/save/file.pdf');
final result = await UnifiedNetworkFramework.instance.execute(downloadRequest);

if (result.isSuccess) {
  print('Download completed: ${downloadRequest.downloadPath}');
}
```

### Batch Requests

#### 1. Sequential Execution

```dart
final requests = [
  GetUserRequest('1'),
  GetUserRequest('2'),
  GetUserRequest('3'),
];

// Execute sequentially, one after another
final responses = await UnifiedNetworkFramework.instance.executeBatch(
  requests,
  sequential: true,
);

for (int i = 0; i < responses.length; i++) {
  if (responses[i].isSuccess) {
    print('User ${i + 1}: ${responses[i].data?.name}');
  }
}
```

#### 2. Concurrent Execution

```dart
final requests = [
  GetUserRequest('1'),
  GetUserRequest('2'),
  GetUserRequest('3'),
];

// Execute concurrently
final responses = await UnifiedNetworkFramework.instance.executeBatch(
  requests,
  sequential: false,
  maxConcurrency: 3,
);

// Process results
final successCount = responses.where((r) => r.isSuccess).length;
print('Successful requests: $successCount/${responses.length}');
```

### Custom Interceptors

#### 1. Authentication Interceptor

```dart
class AuthInterceptor extends Interceptor {
  String? _token;
  
  void setToken(String token) {
    _token = token;
  }
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_token != null) {
      options.headers['Authorization'] = 'Bearer $_token';
    }
    handler.next(options);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token expired, clear local token
      _token = null;
      // Trigger re-login logic here
    }
    handler.next(err);
  }
}

// Register interceptor
final authInterceptor = AuthInterceptor();
UnifiedNetworkFramework.instance.addInterceptor(authInterceptor);

// Set token
authInterceptor.setToken('your_access_token');
```

#### 2. Logging Interceptor

```dart
class CustomLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('🚀 Request: ${options.method} ${options.uri}');
    print('📤 Headers: ${options.headers}');
    if (options.data != null) {
      print('📦 Data: ${options.data}');
    }
    handler.next(options);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print('✅ Response: ${response.statusCode} ${response.requestOptions.uri}');
    print('📥 Data: ${response.data}');
    handler.next(response);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('❌ Error: ${err.message}');
    print('🔍 Request: ${err.requestOptions.uri}');
    handler.next(err);
  }
}
```

#### 3. Cache Interceptor

```dart
class CacheInterceptor extends Interceptor {
  final Map<String, CacheItem> _cache = {};
  final Duration cacheDuration;
  
  CacheInterceptor({this.cacheDuration = const Duration(minutes: 5)});
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Only cache GET requests
    if (options.method.toUpperCase() == 'GET') {
      final cacheKey = _generateCacheKey(options);
      final cacheItem = _cache[cacheKey];
      
      if (cacheItem != null && !cacheItem.isExpired) {
        // Return cached data
        final response = Response(
          requestOptions: options,
          data: cacheItem.data,
          statusCode: 200,
        );
        handler.resolve(response);
        return;
      }
    }
    
    handler.next(options);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Cache successful GET responses
    if (response.requestOptions.method.toUpperCase() == 'GET' && 
        response.statusCode == 200) {
      final cacheKey = _generateCacheKey(response.requestOptions);
      _cache[cacheKey] = CacheItem(
        data: response.data,
        expireTime: DateTime.now().add(cacheDuration),
      );
    }
    
    handler.next(response);
  }
  
  String _generateCacheKey(RequestOptions options) {
    return '${options.method}_${options.uri}';
  }
}

class CacheItem {
  final dynamic data;
  final DateTime expireTime;
  
  CacheItem({required this.data, required this.expireTime});
  
  bool get isExpired => DateTime.now().isAfter(expireTime);
}
```

## 📊 Performance Monitoring

BZY Network Framework has built-in performance monitoring:

```dart
// Get performance statistics
final stats = UnifiedNetworkFramework.instance.getPerformanceStats();
print('Average response time: ${stats.averageResponseTime}ms');
print('Success rate: ${stats.successRate}%');
print('Cache hit rate: ${stats.cacheHitRate}%');
```

## 🚧 Development Status

### Phase One (Q1-Q2): Intelligent Foundation - In Progress

**Completed Features**:
- ✅ Core network framework architecture
- ✅ Basic request types support (GET, POST, PUT, DELETE)
- ✅ File upload and download functionality
- ✅ Basic interceptor system
- ✅ Simple caching mechanism
- ✅ Basic configuration management

**In Development**:
- 🔄 Adaptive network strategies (network quality detection, adaptive timeout/retry strategies)
- 🔄 Weak network optimization (network state adaptation, intelligent cache optimization)
- 🔄 Mobile monitoring system (performance monitoring enhancement, exception monitoring, visualization panel)
- 🔄 Intelligent request scheduling (priority queue, dependency management, load balancing)
- 🔄 Network security enhancement (certificate pinning, request signing, data encryption)
- 🔄 Configuration hot updates (remote configuration, A/B testing support)
- 🔄 Error handling optimization (intelligent retry, error classification, user-friendly prompts)

**Needs Optimization**:
- 🔧 Basic performance monitoring system enhancement
- 🔧 Cache mechanism optimization
- 🔧 Network configuration management enhancement

### Next Steps

For detailed development plans and technical implementation, please refer to:
- [Phase One Development Plan](doc/docs/PHASE_ONE_DEVELOPMENT_PLAN.md)
- [Advanced Features Roadmap](doc/docs/ADVANCED_FEATURES.md)
- [Project Overview](doc/docs/PROJECT_OVERVIEW.md)

## 🤝 Contributing

We welcome all forms of contributions! Please check the [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the [MIT License](LICENSE).

## 🙏 Acknowledgments

Thanks to the following open source projects:

- [Dio](https://pub.dev/packages/dio) - HTTP Client
- [Logging](https://pub.dev/packages/logging) - Logging System
- [Shared Preferences](https://pub.dev/packages/shared_preferences) - Local Storage

---

**BZY Team** ❤️ **Flutter Community**