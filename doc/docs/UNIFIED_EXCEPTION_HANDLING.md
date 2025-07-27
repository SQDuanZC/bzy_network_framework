# 统一异常处理机制

本文档介绍 BZY Network Framework 的统一异常处理系统，包括设计理念、使用方法和最佳实践。

## 概述

统一异常处理系统提供了一套完整的异常分类、处理和管理机制，旨在：

- **统一异常格式**：所有异常都转换为 `UnifiedException` 格式
- **分类管理**：按照异常类型和错误码进行分类
- **全局处理**：支持注册全局异常处理器
- **统计监控**：提供异常统计和监控功能
- **日志记录**：自动记录异常日志

## 核心组件

### 1. UnifiedException

统一异常类，包含以下属性：

```dart
class UnifiedException implements Exception {
  final ExceptionType type;        // 异常类型
  final ErrorCode code;            // 错误码
  final String message;            // 错误消息
  final int statusCode;            // HTTP状态码
  final dynamic originalError;     // 原始异常
  final String? context;           // 上下文信息
  final Map<String, dynamic>? metadata; // 元数据
  final DateTime timestamp;        // 时间戳
}
```

### 2. ExceptionType

异常类型枚举：

```dart
enum ExceptionType {
  network,    // 网络异常
  server,     // 服务器异常
  client,     // 客户端异常
  auth,       // 认证异常
  data,       // 数据异常
  operation,  // 操作异常
  unknown,    // 未知异常
}
```

### 3. ErrorCode

错误码枚举，按类别分组：

```dart
enum ErrorCode {
  // 网络相关错误码 (1000-1999)
  connectionTimeout,
  sendTimeout,
  receiveTimeout,
  connectionError,
  networkUnavailable,
  requestTimeout,
  operationTimeout,
  
  // 认证相关错误码 (2000-2999)
  unauthorized,
  forbidden,
  tokenExpired,
  tokenInvalid,
  
  // 客户端错误码 (3000-3999)
  badRequest,
  notFound,
  methodNotAllowed,
  tooManyRequests,
  clientError,
  
  // 服务器错误码 (4000-4999)
  internalServerError,
  badGateway,
  serviceUnavailable,
  gatewayTimeout,
  serverError,
  
  // 数据相关错误码 (5000-5999)
  parseError,
  validationError,
  dataCorrupted,
  
  // 操作相关错误码 (6000-6999)
  requestCancelled,
  operationFailed,
  resourceBusy,
  
  // 未知错误码 (9000-9999)
  unknownError,
}
```

### 4. UnifiedExceptionHandler

统一异常处理器，提供以下功能：

- 异常转换和处理
- 全局异常处理器管理
- 异常统计
- 日志记录

## 使用方法

### 1. 基本使用

```dart
import 'package:bzy_network_framework/bzy_network_framework.dart';

void main() async {
  try {
    // 执行可能抛出异常的操作
    await someNetworkOperation();
  } catch (e) {
    // 处理异常
    final unifiedException = await UnifiedExceptionHandler.instance
        .handleException(e);
    
    print('异常类型: ${unifiedException.type}');
    print('错误码: ${unifiedException.code}');
    print('错误消息: ${unifiedException.message}');
  }
}
```

### 2. 注册全局异常处理器

```dart
class MyGlobalExceptionHandler implements GlobalExceptionHandler {
  @override
  Future<void> onException(UnifiedException exception) async {
    // 根据异常类型执行不同的处理逻辑
    switch (exception.type) {
      case ExceptionType.network:
        await _handleNetworkException(exception);
        break;
      case ExceptionType.auth:
        await _handleAuthException(exception);
        break;
      default:
        await _handleGenericException(exception);
    }
  }
  
  Future<void> _handleNetworkException(UnifiedException exception) async {
    // 网络异常处理逻辑
    print('网络异常: ${exception.message}');
    // 可以显示网络错误对话框、启动重试机制等
  }
  
  Future<void> _handleAuthException(UnifiedException exception) async {
    // 认证异常处理逻辑
    print('认证异常: ${exception.message}');
    // 可以引导用户重新登录、刷新令牌等
  }
  
  Future<void> _handleGenericException(UnifiedException exception) async {
    // 通用异常处理逻辑
    print('异常: ${exception.message}');
    // 可以显示通用错误提示、记录日志等
  }
}

// 注册全局异常处理器
void initializeExceptionHandling() {
  UnifiedExceptionHandler.instance.registerGlobalHandler(
    MyGlobalExceptionHandler(),
  );
}
```

### 3. 自定义异常

```dart
// 创建自定义异常
final customException = UnifiedException(
  type: ExceptionType.client,
  code: ErrorCode.validationError,
  message: '用户输入验证失败',
  statusCode: 400,
  metadata: {
    'field': 'email',
    'reason': '格式不正确',
  },
);

// 抛出自定义异常
throw customException;
```

### 4. 异常统计

```dart
// 获取异常统计
final stats = UnifiedExceptionHandler.instance.getExceptionStats();
print('异常统计: $stats');

// 清空异常统计
UnifiedExceptionHandler.instance.clearExceptionStats();
```

## 网络框架集成

统一异常处理系统已经集成到网络框架中：

### 1. 自动异常转换

所有 Dio 异常都会自动转换为 `UnifiedException`：

```dart
// DioException -> UnifiedException
// SocketException -> UnifiedException
// TimeoutException -> UnifiedException
// FormatException -> UnifiedException
```

### 2. 异常拦截器

`ExceptionInterceptor` 会自动拦截网络请求异常并进行处理：

```dart
// 异常拦截器会自动添加到 Dio 实例中
// 无需手动配置
```

### 3. 自定义错误处理

在请求类中可以自定义错误处理：

```dart
class MyApiRequest extends BaseNetworkRequest<MyData> {
  @override
  NetworkException? handleError(DioException error) {
    // 自定义错误处理逻辑
    if (error.response?.statusCode == 404) {
      return NetworkException(
        message: '请求的资源不存在',
        statusCode: 404,
        errorCode: 'RESOURCE_NOT_FOUND',
      );
    }
    return null; // 使用默认处理
  }
  
  @override
  void onRequestError(NetworkException error) {
    // 请求错误回调
    print('请求错误: ${error.message}');
  }
}
```

## 最佳实践

### 1. 异常分类

根据异常的性质和处理方式进行分类：

- **网络异常**：连接超时、网络不可用等，通常可以重试
- **认证异常**：未授权、令牌过期等，需要重新认证
- **客户端异常**：请求参数错误、资源不存在等，需要修正请求
- **服务器异常**：内部错误、服务不可用等，通常需要稍后重试
- **数据异常**：解析错误、数据损坏等，需要检查数据格式
- **操作异常**：请求取消、操作失败等，根据具体情况处理

### 2. 错误消息

提供用户友好的错误消息：

```dart
String getUserFriendlyMessage(UnifiedException exception) {
  switch (exception.type) {
    case ExceptionType.network:
      return '网络连接异常，请检查网络设置';
    case ExceptionType.auth:
      return '登录已过期，请重新登录';
    case ExceptionType.server:
      return '服务器繁忙，请稍后重试';
    default:
      return '操作失败，请稍后重试';
  }
}
```

### 3. 重试机制

根据异常类型决定是否重试：

```dart
bool shouldRetry(UnifiedException exception) {
  return exception.isRetryable && 
         (exception.type == ExceptionType.network || 
          exception.type == ExceptionType.server);
}
```

### 4. 日志记录

异常会自动记录日志，但可以添加额外的上下文信息：

```dart
try {
  await someOperation();
} catch (e) {
  final exception = await UnifiedExceptionHandler.instance.handleException(
    e,
    context: '用户登录操作',
    metadata: {
      'userId': currentUserId,
      'timestamp': DateTime.now().toIso8601String(),
    },
  );
  
  // 处理异常
}
```

### 5. 监控和统计

定期检查异常统计，识别常见问题：

```dart
void analyzeExceptionStats() {
  final stats = UnifiedExceptionHandler.instance.getExceptionStats();
  
  // 分析异常频率
  stats.forEach((key, count) {
    if (count > threshold) {
      print('高频异常: $key, 次数: $count');
      // 可以触发告警或自动处理
    }
  });
}
```

## 迁移指南

### 从旧的异常处理迁移

1. **替换异常类型**：
   ```dart
   // 旧代码
   catch (NetworkException e) {
     // 处理逻辑
   }
   
   // 新代码
   catch (e) {
     final unifiedException = await UnifiedExceptionHandler.instance
         .handleException(e);
     // 处理逻辑
   }
   ```

2. **更新错误处理逻辑**：
   ```dart
   // 旧代码
   if (e.type == NetworkErrorType.timeout) {
     // 处理超时
   }
   
   // 新代码
   if (unifiedException.type == ExceptionType.network && 
       unifiedException.code == ErrorCode.connectionTimeout) {
     // 处理超时
   }
   ```

3. **注册全局处理器**：
   ```dart
   // 替换分散的错误处理逻辑
   UnifiedExceptionHandler.instance.registerGlobalHandler(
     MyGlobalExceptionHandler(),
   );
   ```

## 示例代码

完整的使用示例请参考：
- `example/unified_exception_example.dart`

## 总结

统一异常处理机制提供了一套完整的异常管理解决方案，通过统一的异常格式、分类管理和全局处理，大大简化了异常处理的复杂性，提高了代码的可维护性和用户体验。

建议在项目初期就集成统一异常处理系统，并根据项目需求定制全局异常处理器，以确保异常处理的一致性和有效性。