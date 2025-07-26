# BZY 网络框架

[![pub package](https://img.shields.io/pub/v/bzy_network_framework.svg)](https://pub.dev/packages/bzy_network_framework)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)

**BZY 网络框架** 是一个高性能、易扩展的 Flutter 网络请求解决方案，提供完整的网络请求、缓存、拦截器、监控等功能。

## ✨ 特性

- 🚀 **高性能**: 基于 Dio 构建，支持并发请求和连接池
- 🔧 **易扩展**: 插件化架构，支持自定义拦截器和插件
- 📦 **智能缓存**: 多级缓存策略，支持内存和磁盘缓存
- 🔄 **自动重试**: 智能重试机制，支持指数退避算法
- 📊 **性能监控**: 实时监控网络性能和错误统计
- 🛡️ **类型安全**: 完整的 TypeScript 风格类型定义
- 📱 **移动优化**: 针对移动网络环境优化
- 🔐 **安全可靠**: 支持证书锁定和请求签名

## 🚀 快速开始

### 安装

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  bzy_network_framework: ^1.0.0
```

### 基础配置

```dart
import 'package:bzy_network_framework/bzy_network_framework.dart';

void main() async {
  // 初始化 BZY 网络框架
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

### 创建请求

```dart
// 定义用户模型
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

// 定义 GET 请求
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

// 执行请求
final request = GetUserRequest('123');
final response = await UnifiedNetworkFramework.instance.execute(request);

if (response.success) {
  final user = response.data;
  print('用户名: ${user.name}');
} else {
  print('请求失败: ${response.message}');
}
```

## 📖 文档

- [快速开始指南](doc/docs/QUICK_START_GUIDE.md)
- [高级功能](doc/docs/ADVANCED_FEATURES.md)
- [API 文档](doc/docs/API_REFERENCE.md)
- [最佳实践](doc/docs/BEST_PRACTICES.md)
- [迁移指南](doc/docs/MIGRATION_GUIDE.md)

## 🏗️ 架构

```
BZY 网络框架
├── 统一框架层 (UnifiedNetworkFramework)
├── 插件系统 (Plugins)
├── 拦截器系统 (Interceptors)
├── 缓存管理 (Cache Manager)
├── 队列管理 (Queue Manager)
├── 网络执行器 (Network Executor)
└── 配置管理 (Config Manager)
```

## 🔧 高级功能

### 批量请求

```dart
final requests = [
  GetUserRequest('1'),
  GetUserRequest('2'),
  GetUserRequest('3'),
];

final responses = await UnifiedNetworkFramework.instance.executeBatch(requests);
```

### 文件上传

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

### 自定义拦截器

```dart
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}

// 注册拦截器
UnifiedNetworkFramework.instance.addInterceptor(AuthInterceptor());
```

## 📊 性能监控

BZY 网络框架内置性能监控功能：

```dart
// 获取性能统计
final stats = UnifiedNetworkFramework.instance.getPerformanceStats();
print('平均响应时间: ${stats.averageResponseTime}ms');
print('成功率: ${stats.successRate}%');
print('缓存命中率: ${stats.cacheHitRate}%');
```

## 🤝 贡献

我们欢迎所有形式的贡献！请查看 [贡献指南](CONTRIBUTING.md) 了解详情。

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE)。

## 🙏 致谢

感谢以下开源项目：

- [Dio](https://pub.dev/packages/dio) - HTTP 客户端
- [Logging](https://pub.dev/packages/logging) - 日志系统
- [Shared Preferences](https://pub.dev/packages/shared_preferences) - 本地存储

---

**BZY 团队** ❤️ **Flutter 社区**