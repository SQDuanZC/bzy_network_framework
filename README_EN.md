# BZY Network Framework

[![pub package](https://img.shields.io/pub/v/bzy_network_framework.svg)](https://pub.dev/packages/bzy_network_framework)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)

**BZY Network Framework** is a high-performance, easily extensible Flutter network request solution that provides comprehensive network requests, caching, interceptors, monitoring, and other features.

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

Add dependency in `pubspec.yaml`:

```yaml
dependencies:
  bzy_network_framework: ^1.0.0
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

```dart
// Define user model
class User {
  final String id;
  final String name;
  final String email;
  
  User({required this.id, required this.name, required this.email});
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}

// Define GET request
class GetUserRequest extends GetRequest<User> {
  final String userId;
  
  GetUserRequest(this.userId);
  
  @override
  String get path => '/users/$userId';
  
  @override
  User parseResponse(Map<String, dynamic> json) {
    return User.fromJson(json['data']);
  }
}

// Execute request
final request = GetUserRequest('123');
final response = await UnifiedNetworkFramework.instance.execute(request);

if (response.success) {
  final user = response.data;
  print('User name: ${user.name}');
} else {
  print('Request failed: ${response.message}');
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

### Batch Requests

```dart
final requests = [
  GetUserRequest('1'),
  GetUserRequest('2'),
  GetUserRequest('3'),
];

final responses = await UnifiedNetworkFramework.instance.executeBatch(requests);
```

### File Upload

```dart
class UploadAvatarRequest extends UploadRequest<UploadResult> {
  final File imageFile;
  
  UploadAvatarRequest(this.imageFile);
  
  @override
  String get path => '/upload/avatar';
  
  @override
  Map<String, dynamic> get files => {
    'avatar': MultipartFile.fromFileSync(imageFile.path),
  };
}
```

### Custom Interceptors

```dart
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}

// Register interceptor
UnifiedNetworkFramework.instance.addInterceptor(AuthInterceptor());
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