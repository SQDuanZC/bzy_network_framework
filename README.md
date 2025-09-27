# BZY 网络框架

[English](README_EN.md) | 中文

[![pub package](https://img.shields.io/pub/v/bzy_network_framework.svg)](https://pub.dev/packages/bzy_network_framework)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![Version](https://img.shields.io/badge/Version-v1.0.8-green.svg)](https://github.com/SQDuanZC/bzy_network_framework)

**BZY 网络框架** 是一个高性能、易扩展的 Flutter 网络请求解决方案，提供完整的网络请求、缓存、拦截器、监控等功能。

## 🆕 最新更新 (v1.0.8)

- 🌐 **跨平台存储完善**: 新增完整的跨平台存储测试套件，支持不同操作系统的缓存目录管理
- 📁 **平台检测增强**: 实现智能平台检测功能，自动适配 iOS、Android、Windows、macOS、Linux 等平台
- 🗂️ **目录管理优化**: 完善缓存和文档目录的创建、权限检查和可用空间监控功能
- 🔧 **文件系统兼容性**: 增强路径分隔符处理和路径标准化，确保跨平台文件操作的一致性
- 📊 **存储信息监控**: 新增 PlatformStorageInfo 类，提供详细的平台存储信息和磁盘空间统计
- 🧪 **测试稳定性提升**: 修复缓存一致性问题，确保所有15个存储相关测试稳定通过
- 🛡️ **错误处理增强**: 完善存储操作的异常处理和恢复机制，提高框架健壮性

### v1.0.7 更新

- 🔧 **拦截器优先级修复**: 修复了拦截器管理器中优先级排序逻辑错误，确保"数值越小优先级越高"的规则正确实现
- 🏷️ **缓存标签功能完善**: 修复了集成测试中缓存按标签清除功能，确保缓存管理的准确性
- 🧪 **测试覆盖率提升**: 完成全面的测试套件，13个测试文件中12个成功通过，测试覆盖率显著提升
- 📊 **测试报告生成**: 新增详细的测试报告和覆盖率分析，提供框架质量评估
- 🛡️ **稳定性增强**: 通过大量集成测试验证，核心功能稳定可靠，错误处理健壮

### v1.0.6 更新

- 📊 **性能指标监控模块**: 新增完整的性能指标监控系统，支持实时可视化
- 🔧 **配置优化**: 修复了 NetworkConfigPreset 和 NetworkConfigPresets 配置不一致问题
- 📝 **文档完善**: 新增指标监控模块详细文档和使用示例
- 🎯 **组件集成**: 提供 NetworkMetricsWidget 便于集成到 Flutter 应用中
- 🔄 **配置统一**: 标准化配置格式，添加缺失字段

### v1.0.4 更新

- 🛠️ **错误处理增强**: 添加统一错误处理机制，支持针对不同HTTP状态码的自定义错误处理
- 🔄 **请求生命周期跟踪**: 实现RequestLifecycleTracker，监控请求各个阶段（发送、接收、解析、完成）
- ⏱️ **超时处理优化**: 改进超时处理逻辑，避免将已成功完成的请求标记为超时
- 📊 **响应恢复机制**: 添加响应恢复机制，即使在类型转换错误的情况下也能尝试恢复响应数据
- 📝 **日志系统增强**: 改进日志系统，记录详细的请求/响应信息和性能指标
- 🧪 **测试框架改进**: 增强测试框架，使用模拟数据和灵活断言提高测试稳定性
- 🔒 **类型系统优化**: 改进泛型处理，减少类型转换错误

### v1.0.3 更新

- 🔒 **并发安全增强**: 细化锁粒度，将全局锁拆分为多个专用锁，减少锁竞争，提高并发吞吐量
- 🚀 **队列管理优化**: 使用高效的优先级队列替代多队列实现，提高处理效率
- ⏱️ **超时机制完善**: 添加全局超时监控，定期检查长时间未处理的请求
- 🔄 **重试机制改进**: 为不同类型的错误设计特定的重试策略，提高重试成功率
- 💾 **缓存管理优化**: 限制磁盘I/O队列大小，完善定时器管理，确保资源正确释放
- 🧠 **内存管理增强**: 优化资源释放机制，避免内存泄漏，提高长时间运行稳定性
- 📊 **监控能力提升**: 增加更详细的性能指标监控，支持请求耗时、成功率等统计

### v1.0.2 更新
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
- 🔍 **全面错误处理**: 统一错误处理机制，支持针对不同HTTP状态码的自定义错误处理
- 📝 **详细日志**: 增强的日志系统，记录请求/响应详情和性能指标

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

```dart
import 'package:bzy_network_framework/bzy_network_framework.dart';

void main() async {
  // 初始化 BZY 网络框架
  await UnifiedNetworkFramework.instance.initialize(
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
        message: '访问被拒绝',
        statusCode: 403,
        errorCode: 'ACCESS_DENIED',
      );
    }
    return null; // 让框架处理其他错误
  }
}
```

#### 3. 执行请求

```dart
// 基础请求执行
final getUserRequest = GetUserRequest('123');

// 使用 .then() 方式调用并处理错误
NetworkExecutor.instance.execute(getUserRequest).then((response) {
  // 检查状态码
  if (response.statusCode == 200) {
    final user = response.data;
    print('用户名: ${user?.name}');
  } else {
    print('请求失败: ${response.message}');
    print('错误代码: ${response.statusCode}');
  }
}).catchError((e) {
  // 处理网络异常
  if (e is NetworkException) {
    print('网络错误: ${e.message}, 状态码: ${e.statusCode}');
  } else {
    print('未知错误: $e');
  }
});

// 使用 async/await 和 try-catch
try {
  final response = await NetworkExecutor.instance.execute(getUserRequest);
  
  if (response.isSuccess) {
    print('用户名: ${response.data?.name}');
  } else {
    print('请求失败: ${response.message}');
  }
} catch (e) {
  print('错误: $e');
}
```

## 📖 文档

- [快速开始指南](doc/docs/QUICK_START_GUIDE.md)
- [高级功能](doc/docs/ADVANCED_FEATURES.md)
- [API 文档](doc/docs/API_REFERENCE.md)
- [最佳实践](doc/docs/BEST_PRACTICES.md)
- [迁移指南](doc/docs/MIGRATION_GUIDE.md)
- [改进建议](BZY网络框架改进建议.md)

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

### 错误处理

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
    // 根据状态码自定义错误处理
    if (error.response?.statusCode == 400) {
      return NetworkException(
        message: '请求参数无效',
        statusCode: 400,
        errorCode: 'INVALID_PARAMETERS',
      );
    } else if (error.response?.statusCode == 401) {
      return NetworkException(
        message: '未授权，请重新登录',
        statusCode: 401,
        errorCode: 'UNAUTHORIZED',
      );
    } else if (error.response?.statusCode == 403) {
      return NetworkException(
        message: '访问被拒绝',
        statusCode: 403,
        errorCode: 'ACCESS_DENIED',
      );
    } else if (error.response?.statusCode == 404) {
      return NetworkException(
        message: '资源不存在',
        statusCode: 404,
        errorCode: 'RESOURCE_NOT_FOUND',
      );
    } else if (error.response?.statusCode == 429) {
      return NetworkException(
        message: '请求过于频繁，请稍后再试',
        statusCode: 429,
        errorCode: 'RATE_LIMITED',
      );
    } else if (error.response?.statusCode == 500) {
      return NetworkException(
        message: '服务器错误，请稍后再试',
        statusCode: 500,
        errorCode: 'SERVER_ERROR',
      );
    }
    
    // 默认错误处理
    return NetworkException(
      message: error.message ?? '未知错误',
      statusCode: error.response?.statusCode ?? -1,
      errorCode: 'UNKNOWN_ERROR',
    );
  }
}
```

### 文件上传

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

### 文件下载

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
    print('下载进度: $progress%');
  }
}
```

### 批量请求

```dart
final requests = [
  GetUserRequest('1'),
  GetUserRequest('2'),
  GetUserRequest('3'),
];

// 并发执行
final responses = await UnifiedNetworkFramework.instance.executeBatch(
  requests,
  sequential: false,
  maxConcurrency: 3,
);

// 处理结果
final successCount = responses.where((r) => r.isSuccess).length;
print('成功请求数: $successCount/${responses.length}');
```

### 自定义拦截器

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

### 第一阶段（Q1-Q2）：智能化基础 - 已完成

**已完成功能**：
- ✅ 核心网络框架架构
- ✅ 基础请求类型支持（GET、POST、PUT、DELETE）
- ✅ 文件上传下载功能
- ✅ 基础拦截器系统
- ✅ 简单缓存机制
- ✅ 基础配置管理
- ✅ 错误处理优化
- ✅ 请求生命周期跟踪
- ✅ 响应恢复机制
- ✅ 增强日志系统

### 第二阶段（Q3-Q4）：高级功能 - 进行中

**正在开发**：
- 🔄 自适应网络策略（网络质量检测、自适应超时/重试策略）
- 🔄 弱网优化增强（网络状态自适应、智能缓存优化）
- 🔄 移动端监控体系（性能监控增强、异常监控、可视化面板）
- 🔄 智能请求调度（优先级队列、依赖管理、负载均衡）
- 🔄 网络安全增强（证书锁定、请求签名、数据加密）
- 🔄 配置热更新（远程配置、A/B测试支持）

**需要优化**：
- 🔧 类型系统进一步优化
- 🔧 缓存机制增强
- 🔧 可配置日志级别

### 接下来的计划

详细的开发计划和技术实现请参考：
- [第二阶段开发计划](doc/docs/PHASE_TWO_DEVELOPMENT_PLAN.md)
- [高级功能路线图](doc/docs/ADVANCED_FEATURES.md)
- [项目概览](doc/docs/PROJECT_OVERVIEW.md)
- [改进建议](BZY网络框架改进建议.md)

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