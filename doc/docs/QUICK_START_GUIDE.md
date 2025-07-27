# 快速开始指南

## 概述

本指南将帮助您快速上手使用优化后的统一网络框架。框架经过全面优化，具备生产级别的代码质量、性能和可维护性。

## 安装和配置

### 1. 添加依赖

在 `pubspec.yaml` 中添加必要的依赖：

```yaml
dependencies:
  dio: ^5.3.0
  logging: ^1.2.0
  collection: ^1.17.0
  
dev_dependencies:
  test: ^1.24.0
  mockito: ^5.4.0
  build_runner: ^2.4.0
```

### 2. 基础配置

```dart
import 'package:bzy_network_framework/bzy_network_framework.dart';
import 'package:bzy_network_framework/utils/network_logger.dart';

void main() async {
  // 1. 配置日志系统
  NetworkLogger.configure(
    level: Level.INFO,
    enableConsoleOutput: true,
  );
  
  // 2. 初始化网络框架
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

## 基础用法

### 1. 创建简单请求

```dart
// 定义请求类
class GetUserRequest extends BaseNetworkRequest<UserModel> {
  @override
  HttpMethod get method => HttpMethod.get;
  final String userId;
  
  GetUserRequest(this.userId);
  
  @override
  String get path => '/users/$userId';
  
  @override
  UserModel parseResponse(Map<String, dynamic> json) {
    return UserModel.fromJson(json['data']);
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

### 2. POST 请求示例

```dart
class CreateUserRequest extends BaseNetworkRequest<UserModel> {
  @override
  HttpMethod get method => HttpMethod.post;
  final String name;
  final String email;
  
  CreateUserRequest({
    required this.name,
    required this.email,
  });
  
  @override
  String get path => '/users';
  
  @override
  Map<String, dynamic> get data => {
    'name': name,
    'email': email,
  };
  
  @override
  UserModel parseResponse(Map<String, dynamic> json) {
    return UserModel.fromJson(json['data']);
  }
}

// 使用
final request = CreateUserRequest(
  name: '张三',
  email: 'zhangsan@example.com',
);
final response = await UnifiedNetworkFramework.instance.execute(request);
```

### 3. 分页请求

```dart
class GetUsersListRequest extends BaseNetworkRequest<List<UserModel>> {
  final int page;
  final int pageSize;
  final String? searchKeyword;
  
  GetUsersListRequest({
    required this.page,
    this.pageSize = 20,
    this.searchKeyword,
  });
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  String get path => '/users';
  
  @override
  Map<String, dynamic> get queryParameters => {
    'page': page,
    'pageSize': pageSize,
    if (searchKeyword != null) 'search': searchKeyword,
  };
  
  @override
  PagedResponse<List<UserModel>> parseResponse(Map<String, dynamic> json) {
    final users = (json['data']['items'] as List)
        .map((item) => UserModel.fromJson(item))
        .toList();
    
    return PagedResponse.fromJson(
      json['data'],
      (data) => users,
    );
  }
}

// 使用
final request = GetUsersListRequest(
  page: 1,
  searchKeyword: '张',
);
final response = await UnifiedNetworkFramework.instance.execute(request);

if (response.success) {
  final pagedData = response.data;
  print('总数: ${pagedData.total}');
  print('当前页: ${pagedData.currentPage}');
  print('用户列表: ${pagedData.data.length} 个用户');
}
```

## 高级功能

### 1. 批量请求

```dart
final requests = [
  GetUserRequest('1'),
  GetUserRequest('2'),
  GetUserRequest('3'),
];

final responses = await UnifiedNetworkFramework.instance.executeBatch(requests);

for (int i = 0; i < responses.length; i++) {
  final response = responses[i];
  if (response.success) {
    print('用户 ${i + 1}: ${response.data.name}');
  } else {
    print('用户 ${i + 1} 请求失败: ${response.message}');
  }
}
```

### 2. 并发请求

```dart
final requests = [
  GetUserRequest('1'),
  GetUserProfileRequest('1'),
  GetUserPostsRequest('1'),
];

final responses = await UnifiedNetworkFramework.instance.executeConcurrent(requests);

final user = responses[0].data;
final profile = responses[1].data;
final posts = responses[2].data;

print('用户: ${user.name}');
print('简介: ${profile.bio}');
print('帖子数: ${posts.length}');
```

### 3. 文件上传

```dart
class UploadAvatarRequest extends UploadRequest<UploadResult> {
  final File imageFile;
  final String userId;
  
  UploadAvatarRequest({
    required this.imageFile,
    required this.userId,
  });
  
  @override
  String get path => '/users/$userId/avatar';
  
  @override
  Map<String, dynamic> get files => {
    'avatar': imageFile,
  };
  
  @override
  UploadResult parseResponse(Map<String, dynamic> json) {
    return UploadResult.fromJson(json['data']);
  }
}

// 使用
final file = File('/path/to/avatar.jpg');
final request = UploadAvatarRequest(
  imageFile: file,
  userId: '123',
);

final response = await UnifiedNetworkFramework.instance.execute(request);
if (response.success) {
  print('头像上传成功: ${response.data.url}');
}
```

### 4. 缓存控制

```dart
// 启用缓存的请求
class GetUserRequest extends GetRequest<UserModel> {
  final String userId;
  
  GetUserRequest(this.userId);
  
  @override
  String get path => '/users/$userId';
  
  @override
  bool get enableCache => true; // 启用缓存
  
  @override
  Duration get cacheDuration => Duration(minutes: 5); // 缓存5分钟
  
  @override
  UserModel parseResponse(Map<String, dynamic> json) {
    return UserModel.fromJson(json['data']);
  }
}

// 强制刷新缓存
final request = GetUserRequest('123');
final response = await UnifiedNetworkFramework.instance.execute(
  request,
  forceRefresh: true, // 忽略缓存，强制请求
);
```

### 5. 请求优先级

```dart
class CriticalRequest extends BaseNetworkRequest<Data> {
  @override
  HttpMethod get method => HttpMethod.get;
  @override
  String get path => '/critical-data';
  
  @override
  RequestPriority get priority => RequestPriority.critical; // 最高优先级
  
  @override
  Data parseResponse(Map<String, dynamic> json) {
    return Data.fromJson(json);
  }
}

class BackgroundRequest extends BaseNetworkRequest<Data> {
  @override
  HttpMethod get method => HttpMethod.get;
  @override
  String get path => '/background-data';
  
  @override
  RequestPriority get priority => RequestPriority.low; // 低优先级
  
  @override
  Data parseResponse(Map<String, dynamic> json) {
    return Data.fromJson(json);
  }
}
```

## 插件系统

### 1. 注册插件

```dart
// 注册认证插件
final authPlugin = AuthPlugin(
  tokenProvider: () => getAuthToken(),
  onTokenExpired: () => refreshToken(),
);

UnifiedNetworkFramework.instance.registerPlugin(
  'auth',
  authPlugin,
  config: AuthConfig(
    autoRefresh: true,
    tokenHeader: 'Authorization',
  ),
);

// 注册日志插件
final loggingPlugin = LoggingPlugin();
UnifiedNetworkFramework.instance.registerPlugin(
  'logging',
  loggingPlugin,
  config: LoggingConfig(
    logLevel: LogLevel.debug,
    logRequestBody: true,
    logResponseBody: true,
  ),
);
```

### 2. 全局拦截器

```dart
// 添加全局请求拦截器
UnifiedNetworkFramework.instance.addGlobalInterceptor(
  RequestInterceptor(
    onRequest: (request) {
      // 添加通用请求头
      request.headers['X-App-Version'] = '1.0.0';
      request.headers['X-Platform'] = 'iOS';
      return request;
    },
  ),
);

// 添加全局响应拦截器
UnifiedNetworkFramework.instance.addGlobalInterceptor(
  ResponseInterceptor(
    onResponse: (response) {
      // 统一处理响应
      if (response.statusCode == 401) {
        // 处理未授权
        handleUnauthorized();
      }
      return response;
    },
  ),
);
```

## 错误处理

### 1. 统一错误处理

```dart
try {
  final response = await UnifiedNetworkFramework.instance.execute(request);
  
  if (response.success) {
    // 处理成功响应
    handleSuccess(response.data);
  } else {
    // 处理业务错误
    handleBusinessError(response.message, response.errorCode);
  }
} on NetworkException catch (e) {
  // 处理网络异常
  switch (e.type) {
    case NetworkExceptionType.timeout:
      showMessage('请求超时，请检查网络连接');
      break;
    case NetworkExceptionType.noInternet:
      showMessage('网络连接不可用');
      break;
    case NetworkExceptionType.serverError:
      showMessage('服务器错误，请稍后重试');
      break;
    default:
      showMessage('网络请求失败: ${e.message}');
  }
} catch (e) {
  // 处理其他异常
  showMessage('未知错误: $e');
}
```

### 2. 自定义错误处理

```dart
class CustomErrorHandler extends ErrorHandler {
  @override
  Future<ErrorHandlingResult> handleError(
    Exception error,
    RequestContext context,
  ) async {
    if (error is DioException) {
      switch (error.response?.statusCode) {
        case 401:
          // 尝试刷新token
          final refreshed = await refreshAuthToken();
          if (refreshed) {
            return ErrorHandlingResult.retry();
          }
          return ErrorHandlingResult.fail(
            NetworkException.unauthorized('登录已过期'),
          );
        
        case 429:
          // 限流，延迟重试
          return ErrorHandlingResult.retry(
            delay: Duration(seconds: 5),
          );
        
        case 500:
        case 502:
        case 503:
          // 服务器错误，重试
          if (context.attemptCount < 3) {
            return ErrorHandlingResult.retry(
              delay: Duration(seconds: context.attemptCount * 2),
            );
          }
          break;
      }
    }
    
    return ErrorHandlingResult.fail(error);
  }
}

// 注册自定义错误处理器
UnifiedNetworkFramework.instance.setErrorHandler(CustomErrorHandler());
```

## 配置管理

### 1. 环境配置

```dart
// 开发环境
if (kDebugMode) {
  await UnifiedNetworkFramework.initialize(
    baseUrl: 'https://dev-api.example.com',
    enableLogging: true,
    logLevel: LogLevel.debug,
    enableCache: false, // 开发时禁用缓存
  );
}

// 生产环境
else {
  await UnifiedNetworkFramework.initialize(
    baseUrl: 'https://api.example.com',
    enableLogging: false,
    enableCache: true,
    maxRetries: 3,
  );
}
```

### 2. 动态配置更新

```dart
// 更新基础URL
UnifiedNetworkFramework.instance.updateConfig(
  baseUrl: 'https://new-api.example.com',
);

// 更新超时设置
UnifiedNetworkFramework.instance.updateConfig(
  connectTimeout: Duration(seconds: 15),
  receiveTimeout: Duration(seconds: 45),
);

// 更新认证token
UnifiedNetworkFramework.instance.updateConfig(
  authToken: newToken,
);
```

## 性能优化

### 1. 请求去重

```dart
// 框架自动处理相同请求的去重
final request1 = GetUserRequest('123');
final request2 = GetUserRequest('123');

// 同时发起相同请求，框架会自动去重
final future1 = UnifiedNetworkFramework.instance.execute(request1);
final future2 = UnifiedNetworkFramework.instance.execute(request2);

final results = await Future.wait([future1, future2]);
// 实际只会发起一次网络请求
```

### 2. 请求取消

```dart
// 创建可取消的请求
final cancelToken = CancelToken();
final request = GetUserRequest('123');

final future = UnifiedNetworkFramework.instance.execute(
  request,
  cancelToken: cancelToken,
);

// 在需要时取消请求
cancelToken.cancel('用户取消了请求');
```

### 3. 内存管理

```dart
// 在应用退出时清理资源
void dispose() {
  UnifiedNetworkFramework.disposeInstance();
}

// 清理缓存
UnifiedNetworkFramework.instance.clearCache();

// 取消所有待处理的请求
UnifiedNetworkFramework.instance.cancelAllRequests();
```

## 测试支持

### 1. Mock 测试

```dart
// 在测试中使用Mock
void main() {
  group('User Service Tests', () {
    late MockUnifiedNetworkFramework mockFramework;
    
    setUp(() {
      mockFramework = MockUnifiedNetworkFramework();
      // 注入Mock实例
      ServiceLocator.instance.registerSingleton(mockFramework);
    });
    
    test('should get user successfully', () async {
      // 设置Mock响应
      final mockUser = UserModel(id: '123', name: '测试用户');
      mockFramework.setMockResponse(
        GetUserRequest('123'),
        NetworkResponse.success(data: mockUser),
      );
      
      // 执行测试
      final userService = UserService();
      final user = await userService.getUser('123');
      
      expect(user.name, equals('测试用户'));
    });
  });
}
```

### 2. 集成测试

```dart
void main() {
  group('Network Integration Tests', () {
    setUpAll(() async {
      // 初始化测试环境
      await UnifiedNetworkFramework.initialize(
        baseUrl: 'https://test-api.example.com',
        enableLogging: true,
      );
    });
    
    test('should handle real API calls', () async {
      final request = GetUserRequest('test-user-id');
      final response = await UnifiedNetworkFramework.instance.execute(request);
      
      expect(response.success, isTrue);
      expect(response.data, isNotNull);
    });
  });
}
```

## 最佳实践

### 1. 请求类组织

```dart
// 按模块组织请求类
// lib/network/requests/user/
//   ├── get_user_request.dart
//   ├── create_user_request.dart
//   ├── update_user_request.dart
//   └── delete_user_request.dart

// lib/network/requests/post/
//   ├── get_posts_request.dart
//   ├── create_post_request.dart
//   └── like_post_request.dart
```

### 2. 服务层封装

```dart
class UserService {
  final UnifiedNetworkFramework _framework = UnifiedNetworkFramework.instance;
  
  Future<UserModel> getUser(String userId) async {
    final request = GetUserRequest(userId);
    final response = await _framework.execute(request);
    
    if (response.success) {
      return response.data;
    } else {
      throw UserServiceException(response.message);
    }
  }
  
  Future<List<UserModel>> getUsers({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    final request = GetUsersListRequest(
      page: page,
      pageSize: pageSize,
      searchKeyword: search,
    );
    
    final response = await _framework.execute(request);
    
    if (response.success) {
      return response.data.data;
    } else {
      throw UserServiceException(response.message);
    }
  }
}
```

### 3. 错误处理策略

```dart
// 创建统一的错误处理mixin
mixin ErrorHandlingMixin {
  void handleNetworkError(NetworkException error) {
    switch (error.type) {
      case NetworkExceptionType.timeout:
        showSnackBar('请求超时，请重试');
        break;
      case NetworkExceptionType.noInternet:
        showSnackBar('网络连接不可用');
        break;
      case NetworkExceptionType.unauthorized:
        navigateToLogin();
        break;
      default:
        showSnackBar('网络错误: ${error.message}');
    }
  }
  
  void showSnackBar(String message);
  void navigateToLogin();
}

// 在页面中使用
class UserListPage extends StatefulWidget with ErrorHandlingMixin {
  // ...
}
```

## 故障排除

### 常见问题

1. **请求超时**
   - 检查网络连接
   - 调整超时设置
   - 确认服务器响应时间

2. **缓存问题**
   - 使用 `forceRefresh: true` 强制刷新
   - 检查缓存配置
   - 清理缓存数据

3. **认证失败**
   - 检查token是否有效
   - 确认认证插件配置
   - 验证请求头设置

4. **内存泄漏**
   - 确保调用 `dispose()` 方法
   - 检查请求是否正确取消
   - 监控内存使用情况

### 调试技巧

```dart
// 启用详细日志
NetworkLogger.configure(
  level: Level.ALL,
  enableConsoleOutput: true,
);

// 添加请求拦截器进行调试
UnifiedNetworkFramework.instance.addGlobalInterceptor(
  RequestInterceptor(
    onRequest: (request) {
      print('🚀 Request: ${request.method} ${request.path}');
      print('📤 Headers: ${request.headers}');
      print('📤 Data: ${request.data}');
      return request;
    },
  ),
);

UnifiedNetworkFramework.instance.addGlobalInterceptor(
  ResponseInterceptor(
    onResponse: (response) {
      print('✅ Response: ${response.statusCode}');
      print('📥 Data: ${response.data}');
      return response;
    },
    onError: (error) {
      print('❌ Error: ${error.message}');
      return error;
    },
  ),
);
```

## 总结

通过本快速开始指南，您应该能够：

1. ✅ 正确配置和初始化网络框架
2. ✅ 创建和执行各种类型的网络请求
3. ✅ 使用高级功能如缓存、优先级、批量请求
4. ✅ 实现错误处理和异常管理
5. ✅ 集成插件系统和拦截器
6. ✅ 编写测试和进行调试

框架经过全面优化，具备生产级别的性能和稳定性。如需更详细的信息，请参考：

- [API 文档](API_DOCUMENTATION.md)
- [架构设计](ARCHITECTURE.md)
- [优化实施指南](OPTIMIZATION_IMPLEMENTATION_GUIDE.md)
- [代码优化分析报告](CODE_OPTIMIZATION_REPORT.md)

如有问题，请查看故障排除部分或联系开发团队。