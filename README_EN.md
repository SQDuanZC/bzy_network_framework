# BZY Network Framework

English | [中文](README.md)

[![pub package](https://img.shields.io/pub/v/bzy_network_framework.svg)](https://pub.dev/packages/bzy_network_framework)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![Version](https://img.shields.io/badge/Version-v1.0.4-green.svg)](https://github.com/SQDuanZC/bzy_network_framework)

**BZY Network Framework** is a high-performance, easily extensible Flutter network request solution that provides comprehensive network requests, caching, interceptors, monitoring, and other features.

## 🆕 Latest Updates (v1.0.4)

- 🛠️ **Error Handling Enhancement**: Added unified error handling mechanism with custom error handling for different HTTP status codes
- 🔄 **Request Lifecycle Tracking**: Implemented RequestLifecycleTracker to monitor request stages (sending, receiving, parsing, completion)
- ⏱️ **Timeout Handling Optimization**: Improved timeout handling logic to avoid marking successfully completed requests as timed out
- 📊 **Response Recovery Mechanism**: Added response recovery mechanism to retrieve data even when type conversion errors occur
- 📝 **Enhanced Logging System**: Improved logging with detailed request/response information and performance metrics
- 🧪 **Test Framework Improvement**: Enhanced test framework with mock data and flexible assertions for better test stability
- 🔒 **Type System Optimization**: Improved generic handling to reduce type conversion errors

### v1.0.3 Updates

- 🔒 **Concurrency Safety Enhancement**: Refined lock granularity by replacing global locks with specialized locks, reducing lock contention and improving concurrent throughput
- 🚀 **Queue Management Optimization**: Implemented efficient priority queue to replace multiple queue implementation, improving processing efficiency
- ⏱️ **Timeout Mechanism Improvement**: Added global timeout monitoring to periodically check long-pending requests
- 🔄 **Retry Mechanism Enhancement**: Designed specific retry strategies for different types of errors, improving retry success rate
- 💾 **Cache Management Optimization**: Limited disk I/O queue size, improved timer management, and ensured proper resource release
- 🧠 **Memory Management Enhancement**: Optimized resource release mechanisms to prevent memory leaks and improve long-running stability
- 📊 **Monitoring Capability Upgrade**: Added more detailed performance metrics monitoring, supporting request time consumption, success rate, and other statistics

### v1.0.2 Updates
- ⚡ **Configuration Optimization**: Optimized timeout settings (connection 15s, receive/send 30s), adjusted cache strategy (development 5 minutes, production 15 minutes)
- 🔄 **Smart Retry**: Added exponential backoff retry mechanism, maximum 3 retries, improving network request success rate
- 📋 **Configuration Presets**: Added multiple configuration preset templates (development, production, fast response, heavy load, offline first, low bandwidth)
- 🛡️ **Configuration Validation**: Enhanced configuration validator, supporting exponential backoff configuration validation
- 📚 **Example Enhancement**: Added configuration preset usage examples, simplifying common scenario configurations

### v1.0.1 Updates
- 🔄 **Unified queryParameters Approach**: Implemented unified use of `queryParameters` for all HTTP request data
- 🚀 **Automatic Data Conversion**: GET/DELETE requests automatically use URL parameters, POST/PUT/PATCH requests automatically convert to request body
- 📚 **Enhanced Documentation**: Added comprehensive documentation and examples for the unified approach
- 🛠️ **Debug Enhancement**: Automatic preservation of original request data for debugging and logging

## ✨ Features

- 🚀 **High Performance**: Built on Dio with support for concurrent requests and connection pooling
- 🔧 **Easy Extension**: Plugin-based architecture with support for custom interceptors and plugins
- 📦 **Smart Caching**: Multi-level caching strategy with memory and disk cache support
- 🔄 **Auto Retry**: Intelligent retry mechanism with exponential backoff algorithm
- 📊 **Performance Monitoring**: Real-time monitoring of network performance and error statistics
- 🛡️ **Type Safety**: Complete TypeScript-style type definitions
- 📱 **Mobile Optimized**: Optimized for mobile network environments
- 🔐 **Secure & Reliable**: Support for certificate pinning and request signing
- 🔍 **Comprehensive Error Handling**: Unified error handling with custom error handling for different HTTP status codes
- 📝 **Detailed Logging**: Enhanced logging system with request/response details and performance metrics

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
    config: {
      'connectTimeout': 100000,
      'receiveTimeout': 100000,
      'enableLogging': true,
      'enableCache': true,
      'environment': Environment.development,
    },
    plugins: [
      NetworkPluginFactory.createCachePlugin(),
      NetworkPluginFactory.createRetryPlugin(),
      NetworkPluginFactory.createLoggingPlugin(),
    ],
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
  User parseResponse(dynamic data) {
    if (data is String) {
      final jsonData = json.decode(data) as Map<String, dynamic>;
      return User.fromJson(jsonData['data']);
    }
    return User.fromJson((data as Map<String, dynamic>)['data']);
  }
  
  @override
  NetworkException? handleError(DioException error) {
    if (error.response?.statusCode == 403) {
      return NetworkException(
        message: 'Access denied',
        statusCode: 403,
        errorCode: 'ACCESS_DENIED',
      );
    }
    return null; // Let the framework handle other errors
  }
}
```

#### 3. Execute Requests

```dart
// Basic request execution
final getUserRequest = GetUserRequest('123');

// Using .then() approach with error handling
NetworkExecutor.instance.execute(getUserRequest).then((response) {
  // Check status code
  if (response.statusCode == 200) {
    final user = response.data;
    print('User name: ${user?.name}');
  } else {
    print('Request failed: ${response.message}');
    print('Error code: ${response.statusCode}');
  }
}).catchError((e) {
  // Handle network exceptions
  if (e is NetworkException) {
    print('Network error: ${e.message}, Status code: ${e.statusCode}');
  } else {
    print('Unknown error: $e');
  }
});

// Using async/await with try-catch
try {
  final response = await NetworkExecutor.instance.execute(getUserRequest);
  
  if (response.isSuccess) {
    print('User name: ${response.data?.name}');
  } else {
    print('Request failed: ${response.message}');
  }
} catch (e) {
  print('Error: $e');
}
```

## 📖 Documentation

- [Quick Start Guide](doc/docs/QUICK_START_GUIDE.md)
- [Advanced Features](doc/docs/ADVANCED_FEATURES.md)
- [API Reference](doc/docs/API_REFERENCE.md)
- [Best Practices](doc/docs/BEST_PRACTICES.md)
- [Migration Guide](doc/docs/MIGRATION_GUIDE.md)
- [Improvement Suggestions](BZY网络框架改进建议.md)

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

### Error Handling

```dart
class CustomErrorRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  String get path => '/api/endpoint';
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    if (data is String) {
      return json.decode(data) as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }
  
  @override
  NetworkException? handleError(DioException error) {
    // Custom error handling based on status code
    if (error.response?.statusCode == 400) {
      return NetworkException(
        message: 'Invalid request parameters',
        statusCode: 400,
        errorCode: 'INVALID_PARAMETERS',
      );
    } else if (error.response?.statusCode == 401) {
      return NetworkException(
        message: 'Unauthorized, please login again',
        statusCode: 401,
        errorCode: 'UNAUTHORIZED',
      );
    } else if (error.response?.statusCode == 403) {
      return NetworkException(
        message: 'Access denied',
        statusCode: 403,
        errorCode: 'ACCESS_DENIED',
      );
    } else if (error.response?.statusCode == 404) {
      return NetworkException(
        message: 'Resource not found',
        statusCode: 404,
        errorCode: 'RESOURCE_NOT_FOUND',
      );
    } else if (error.response?.statusCode == 429) {
      return NetworkException(
        message: 'Too many requests, please try again later',
        statusCode: 429,
        errorCode: 'RATE_LIMITED',
      );
    } else if (error.response?.statusCode == 500) {
      return NetworkException(
        message: 'Server error, please try again later',
        statusCode: 500,
        errorCode: 'SERVER_ERROR',
      );
    }
    
    // Default error handling
    return NetworkException(
      message: error.message ?? 'Unknown error',
      statusCode: error.response?.statusCode ?? -1,
      errorCode: 'UNKNOWN_ERROR',
    );
  }
}
```

### File Upload

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
  UploadResult parseResponse(dynamic data) {
    if (data is String) {
      final jsonData = json.decode(data) as Map<String, dynamic>;
      return UploadResult.fromJson(jsonData['data']);
    }
    return UploadResult.fromJson((data as Map<String, dynamic>)['data']);
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
```

### Batch Requests

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

### Phase One (Q1-Q2): Intelligent Foundation - Completed

**Completed Features**:
- ✅ Core network framework architecture
- ✅ Basic request types support (GET, POST, PUT, DELETE)
- ✅ File upload and download functionality
- ✅ Basic interceptor system
- ✅ Simple caching mechanism
- ✅ Basic configuration management
- ✅ Error handling optimization
- ✅ Request lifecycle tracking
- ✅ Response recovery mechanism
- ✅ Enhanced logging system

### Phase Two (Q3-Q4): Advanced Features - In Progress

**In Development**:
- 🔄 Adaptive network strategies (network quality detection, adaptive timeout/retry strategies)
- 🔄 Weak network optimization (network state adaptation, intelligent cache optimization)
- 🔄 Mobile monitoring system (performance monitoring enhancement, exception monitoring, visualization panel)
- 🔄 Intelligent request scheduling (priority queue, dependency management, load balancing)
- 🔄 Network security enhancement (certificate pinning, request signing, data encryption)
- 🔄 Configuration hot updates (remote configuration, A/B testing support)

**Needs Optimization**:
- 🔧 Type system further optimization
- 🔧 Cache mechanism enhancement
- 🔧 Configurable logging levels

### Next Steps

For detailed development plans and technical implementation, please refer to:
- [Phase Two Development Plan](doc/docs/PHASE_TWO_DEVELOPMENT_PLAN.md)
- [Advanced Features Roadmap](doc/docs/ADVANCED_FEATURES.md)
- [Project Overview](doc/docs/PROJECT_OVERVIEW.md)
- [Improvement Suggestions](BZY网络框架改进建议.md)

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