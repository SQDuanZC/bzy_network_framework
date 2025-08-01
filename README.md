# BZY 网络框架

[English](README_EN.md) | 中文

[![pub package](https://img.shields.io/pub/v/bzy_network_framework.svg)](https://pub.dev/packages/bzy_network_framework)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![Version](https://img.shields.io/badge/Version-v1.0.1-green.svg)](https://github.com/SQDuanZC/bzy_network_framework)

**BZY 网络框架** 是一个高性能、易扩展的 Flutter 网络请求解决方案，提供完整的网络请求、缓存、拦截器、监控等功能。

## 🆕 最新更新 (v1.0.2)

- ⚡ **配置优化**: 优化超时配置（连接15s，接收/发送30s），调整缓存策略（开发5分钟，生产15分钟）
- 🔄 **智能重试**: 新增指数退避重试机制，最大重试3次，提升网络请求成功率
- 📋 **配置预设**: 新增多种配置预设模板（开发、生产、快速响应、重负载、离线优先、低带宽）
- 🛡️ **配置验证**: 增强配置验证器，支持指数退避配置验证
- 📚 **示例完善**: 新增配置预设使用示例，简化常见场景配置

### v1.0.1 更新
- 🔄 **统一 queryParameters 方案**: 实现统一使用 `queryParameters` 处理所有 HTTP 请求数据
- 🚀 **自动数据转换**: GET/DELETE 请求自动作为 URL 参数，POST/PUT/PATCH 请求自动转换为请求体
- 📚 **文档完善**: 新增统一方案的详细文档和示例代码
- 🛠️ **调试增强**: 自动保存原始请求数据，便于调试和日志记录

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

从 GitHub 仓库安装：

```yaml
dependencies:
  bzy_network_framework:
    git:
      url: https://github.com/SQDuanZC/bzy_network_framework.git
      ref: main  # 或指定特定的分支/标签
```

然后运行：

```bash
flutter pub get
```

### 基础配置

#### 方式一：使用配置预设（推荐）

```dart
import 'package:bzy_network_framework/bzy_network_framework.dart';

void main() async {
  // 使用开发环境预设
  NetworkConfig.instance.initializeFromPreset('development');
  
  // 或使用生产环境预设
  // NetworkConfig.instance.initializeFromPreset('production');
  
  // 设置基础URL
  NetworkConfig.instance.updateBaseUrl('https://api.example.com');
  
  // 初始化框架
  await UnifiedNetworkFramework.initialize();
  
  runApp(MyApp());
}
```

#### 可用的配置预设

- `development`: 开发环境（连接15s，缓存5分钟，启用日志）
- `production`: 生产环境（连接15s，缓存15分钟，禁用日志）
- `testing`: 测试环境（连接10s，禁用缓存）
- `fastResponse`: 快速响应（连接5s，接收10s）
- `heavyLoad`: 重负载（连接30s，接收60s，重试5次）
- `offlineFirst`: 离线优先（长缓存，多重试）
- `lowBandwidth`: 低带宽（短超时，启用缓存）

#### 方式二：手动配置

```dart
import 'package:bzy_network_framework/bzy_network_framework.dart';

void main() async {
  // 手动初始化配置
  NetworkConfig.instance.initialize(
    baseUrl: 'https://api.example.com',
    connectTimeout: 15000,  // 15秒
    receiveTimeout: 30000,  // 30秒
    sendTimeout: 30000,     // 30秒
    enableLogging: true,
    enableCache: true,
    defaultCacheDuration: 300,  // 5分钟
    maxRetries: 3,
    enableExponentialBackoff: true,  // 启用指数退避
  );
  
  // 初始化框架
  await UnifiedNetworkFramework.initialize();
  
  runApp(MyApp());
}
```

### 创建请求

#### 1. 定义数据模型

```dart
// 定义用户模型
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

#### 2. GET 请求

```dart
// 获取单个用户
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

// 获取用户列表
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

#### 3. POST 请求

```dart
// 创建用户
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

#### 4. PUT/PATCH 请求

```dart
// 更新用户信息
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

#### 5. DELETE 请求

```dart
// 删除用户
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

#### 6. 执行请求

```dart
// 基础请求执行
final getUserRequest = GetUserRequest('123');
final response = await UnifiedNetworkFramework.instance.execute(getUserRequest);

if (response.isSuccess) {
  final user = response.data;
  print('用户名: ${user?.name}');
} else {
  print('请求失败: ${response.message}');
  print('错误代码: ${response.statusCode}');
}

// 带错误处理的请求
try {
  final createRequest = CreateUserRequest(
    name: '张三',
    email: 'zhangsan@example.com',
  );
  
  final result = await UnifiedNetworkFramework.instance.execute(createRequest);
  
  if (result.isSuccess) {
    print('用户创建成功: ${result.data?.name}');
  } else {
    // 处理业务错误
    switch (result.statusCode) {
      case 400:
        print('请求参数错误');
        break;
      case 401:
        print('未授权，请重新登录');
        break;
      case 409:
        print('用户已存在');
        break;
      default:
        print('创建失败: ${result.message}');
    }
  }
} catch (e) {
  // 处理网络异常
  print('网络异常: $e');
}
```

## 📖 文档

- [快速开始指南](doc/docs/QUICK_START_GUIDE.md)
- [高级功能](doc/docs/ADVANCED_FEATURES.md)
- [API 文档](doc/docs/API_REFERENCE.md)
- [最佳实践](doc/ocs/BEST_PRACTICES.md)
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

### 文件上传

#### 1. 单文件上传

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

// 执行上传
final uploadRequest = UploadAvatarRequest(imageFile, '123');
final result = await UnifiedNetworkFramework.instance.execute(uploadRequest);

if (result.isSuccess) {
  print('上传成功: ${result.data?.url}');
}
```

#### 2. 多文件上传

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

### 批量请求

#### 1. 顺序执行

```dart
final requests = [
  GetUserRequest('1'),
  GetUserRequest('2'),
  GetUserRequest('3'),
];

// 顺序执行，一个接一个
final responses = await UnifiedNetworkFramework.instance.executeBatch(
  requests,
  sequential: true,
);

for (int i = 0; i < responses.length; i++) {
  if (responses[i].isSuccess) {
    print('用户 ${i + 1}: ${responses[i].data?.name}');
  }
}
```

#### 2. 并发执行

```dart
final requests = [
  GetUserRequest('1'),
  GetUserRequest('2'),
  GetUserRequest('3'),
];

// 并发执行，同时进行
final responses = await UnifiedNetworkFramework.instance.executeBatch(
  requests,
  sequential: false,
  maxConcurrency: 3,
);

// 处理结果
final successCount = responses.where((r) => r.isSuccess).length;
print('成功请求数: $successCount/${responses.length}');
```

### 文件下载

```dart
class DownloadFileRequest extends DownloadRequest<DownloadResponse> {
  final String fileUrl;
  final String localPath;
  
  DownloadFileRequest({
    required this.fileUrl,
    required this.localPath,
  });
  
  @override
  String get path => fileUrl;
  
  @override
  String get savePath => localPath;
  
  @override
  void Function(int received, int total)? get onProgress => (received, total) {
    final progress = (received / total * 100).toStringAsFixed(1);
    print('下载进度: $progress%');
  };
  
  @override
  DownloadResponse parseResponse(dynamic data) {
    return DownloadResponse.fromJson(data);
  }
  
  @override
  void onDownloadComplete(String filePath) {
    print('文件下载完成: $filePath');
  }
  
  @override
  void onDownloadError(String error) {
    print('文件下载失败: $error');
  }
}

// 使用示例
final downloadRequest = DownloadFileRequest(
  fileUrl: '/files/document.pdf',
  localPath: '/path/to/local/document.pdf',
);

final response = await UnifiedNetworkFramework.instance.execute(downloadRequest);
if (response.isSuccess) {
  print('文件下载成功: ${response.data?.filePath}');
}
```

### 自定义拦截器

#### 1. 认证拦截器

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
      // Token 过期，清除本地 token
      _token = null;
      // 可以在这里触发重新登录逻辑
    }
    handler.next(err);
  }
}

// 注册拦截器
final authInterceptor = AuthInterceptor();
UnifiedNetworkFramework.instance.addInterceptor(authInterceptor);

// 设置 token
authInterceptor.setToken('your_access_token');
```

#### 2. 日志拦截器

```dart
class CustomLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('🚀 请求: ${options.method} ${options.uri}');
    print('📤 请求头: ${options.headers}');
    if (options.data != null) {
      print('📦 请求体: ${options.data}');
    }
    handler.next(options);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print('✅ 响应: ${response.statusCode} ${response.requestOptions.uri}');
    print('📥 响应数据: ${response.data}');
    handler.next(response);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('❌ 错误: ${err.message}');
    print('🔍 请求: ${err.requestOptions.uri}');
    handler.next(err);
  }
}
```

#### 3. 缓存拦截器

```dart
class CacheInterceptor extends Interceptor {
  final Map<String, CacheItem> _cache = {};
  final Duration cacheDuration;
  
  CacheInterceptor({this.cacheDuration = const Duration(minutes: 5)});
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 只缓存 GET 请求
    if (options.method.toUpperCase() == 'GET') {
      final cacheKey = _generateCacheKey(options);
      final cacheItem = _cache[cacheKey];
      
      if (cacheItem != null && !cacheItem.isExpired) {
        // 返回缓存数据
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
    // 缓存成功的 GET 响应
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

## 📊 性能监控

BZY 网络框架内置性能监控功能：

```dart
// 获取性能统计
final stats = UnifiedNetworkFramework.instance.getPerformanceStats();
print('平均响应时间: ${stats.averageResponseTime}ms');
print('成功率: ${stats.successRate}%');
print('缓存命中率: ${stats.cacheHitRate}%');
```

## 🚧 开发状态

### 第一阶段（Q1-Q2）：智能化基础 - 进行中

**已完成功能**：
- ✅ 核心网络框架架构
- ✅ 基础请求类型支持（GET、POST、PUT、DELETE）
- ✅ 文件上传下载功能
- ✅ 基础拦截器系统
- ✅ 简单缓存机制
- ✅ 基础配置管理

**正在开发**：
- 🔄 自适应网络策略（网络质量检测、自适应超时/重试策略）
- 🔄 弱网优化增强（网络状态自适应、智能缓存优化）
- 🔄 移动端监控体系（性能监控增强、异常监控、可视化面板）
- 🔄 智能请求调度（优先级队列、依赖管理、负载均衡）
- 🔄 网络安全增强（证书锁定、请求签名、数据加密）
- 🔄 配置热更新（远程配置、A/B测试支持）
- 🔄 错误处理优化（智能重试、错误分类、用户友好提示）

**需要优化**：
- 🔧 基础性能监控系统完善
- 🔧 缓存机制优化
- 🔧 网络配置管理增强

### 接下来的计划

详细的开发计划和技术实现请参考：
- [第一阶段开发计划](doc/docs/PHASE_ONE_DEVELOPMENT_PLAN.md)
- [高级功能路线图](doc/docs/ADVANCED_FEATURES.md)
- [项目概览](doc/docs/PROJECT_OVERVIEW.md)

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