# 统一异常处理器 (UnifiedExceptionHandler) 文档

## 概述
`UnifiedExceptionHandler` 是网络框架的核心异常处理系统，提供统一的异常分类、错误码定义、异常处理机制和全局异常管理功能，确保应用的异常处理一致性和可维护性。

## 文件位置
```
lib/src/core/exception/unified_exception_handler.dart
```

## 核心特性

### 1. 统一异常分类
- 网络异常 (Network)
- 服务器异常 (Server)
- 客户端异常 (Client)
- 认证异常 (Auth)
- 数据异常 (Data)
- 操作异常 (Operation)
- 未知异常 (Unknown)

### 2. 标准化错误码
- 预定义的错误码体系
- HTTP状态码映射
- 自定义错误码支持

### 3. 全局异常处理
- 全局异常处理器注册
- 异常统计和监控
- 异常日志记录

### 4. 异常转换机制
- Dio异常转换
- Socket异常转换
- 超时异常转换
- 格式异常转换

## 主要组件

### ExceptionType 异常类型枚举
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

### ErrorCode 错误码枚举
```dart
enum ErrorCode {
  // 网络相关错误
  connectionTimeout,    // 连接超时
  sendTimeout,         // 发送超时
  receiveTimeout,      // 接收超时
  connectionError,     // 连接错误
  
  // HTTP状态码相关
  badRequest,          // 400 错误请求
  unauthorized,        // 401 未授权
  forbidden,           // 403 禁止访问
  notFound,            // 404 未找到
  
  // 服务器错误
  internalServerError, // 500 内部服务器错误
  badGateway,          // 502 网关错误
  serviceUnavailable,  // 503 服务不可用
  
  // 客户端错误
  requestCancelled,    // 请求取消
  dataParseError,      // 数据解析错误
  unknownError,        // 未知错误
}
```

### UnifiedException 统一异常类
```dart
class UnifiedException {
  final ExceptionType type;              // 异常类型
  final ErrorCode code;                  // 错误码
  final String message;                  // 错误消息
  final int statusCode;                  // HTTP状态码
  final dynamic originalError;           // 原始错误对象
  final String? context;                 // 异常上下文
  final Map<String, dynamic>? metadata;  // 元数据
  final DateTime timestamp;              // 异常时间戳
}
```

### GlobalExceptionHandler 全局异常处理器接口
```dart
abstract class GlobalExceptionHandler {
  /// 处理异常
  Future<void> onException(UnifiedException exception);
}
```

## 核心方法

### 1. createNetworkException() - 创建网络异常
```dart
NetworkException createNetworkException(dynamic error)
```

**功能**：
- 将各种错误类型转换为NetworkException
- 统一异常格式和错误码
- 保留原始错误信息

### 2. handleException() - 处理异常
```dart
Future<UnifiedException> handleException(
  dynamic error, {
  String? context,
  Map<String, dynamic>? metadata,
}) async
```

**功能**：
- 创建统一异常对象
- 添加上下文信息
- 记录异常统计
- 调用全局异常处理器
- 记录异常日志

### 3. registerGlobalHandler() - 注册全局处理器
```dart
void registerGlobalHandler(GlobalExceptionHandler handler)
```

**功能**：
- 注册全局异常处理器
- 支持多个处理器链式调用
- 异常处理的扩展机制

### 4. _handleDioException() - 处理Dio异常
```dart
UnifiedException _handleDioException(DioException error)
```

**功能**：
- 将Dio异常转换为统一异常
- 根据异常类型分类处理
- 映射HTTP状态码

## 异常分类处理

### 网络异常处理
```dart
case DioExceptionType.connectionTimeout:
  return UnifiedException(
    type: ExceptionType.network,
    code: ErrorCode.connectionTimeout,
    message: 'Connection timeout, please check network connection',
    originalError: error,
    statusCode: -1001,
  );

case DioExceptionType.connectionError:
  return UnifiedException(
    type: ExceptionType.network,
    code: ErrorCode.connectionError,
    message: 'Network connection error, please check network settings',
    originalError: error,
    statusCode: -1004,
  );
```

### HTTP状态码处理
```dart
UnifiedException _handleHttpStatusCode(int statusCode, DioException error) {
  switch (statusCode) {
    case 400:
      return UnifiedException(
        type: ExceptionType.client,
        code: ErrorCode.badRequest,
        message: 'Bad request parameters',
        originalError: error,
        statusCode: statusCode,
      );
      
    case 401:
      return UnifiedException(
        type: ExceptionType.auth,
        code: ErrorCode.unauthorized,
        message: 'Authentication failed, please login again',
        originalError: error,
        statusCode: statusCode,
      );
      
    case 500:
      return UnifiedException(
        type: ExceptionType.server,
        code: ErrorCode.internalServerError,
        message: 'Internal server error, please try again later',
        originalError: error,
        statusCode: statusCode,
      );
  }
}
```

### Socket异常处理
```dart
UnifiedException _handleSocketException(SocketException error) {
  return UnifiedException(
    type: ExceptionType.network,
    code: ErrorCode.connectionError,
    message: 'Network connection failed: ${error.message}',
    originalError: error,
    statusCode: -1005,
  );
}
```

### 超时异常处理
```dart
UnifiedException _handleTimeoutException(TimeoutException error) {
  return UnifiedException(
    type: ExceptionType.network,
    code: ErrorCode.receiveTimeout,
    message: 'Operation timeout: ${error.message}',
    originalError: error,
    statusCode: -1003,
  );
}
```

## 全局异常处理器

### 默认全局处理器
```dart
class DefaultGlobalExceptionHandler implements GlobalExceptionHandler {
  @override
  Future<void> onException(UnifiedException exception) async {
    // 记录异常日志
    _logException(exception);
    
    // 上报异常统计
    _reportException(exception);
    
    // 用户提示处理
    _showUserMessage(exception);
  }
}
```

### 自定义全局处理器
```dart
class CustomGlobalExceptionHandler implements GlobalExceptionHandler {
  @override
  Future<void> onException(UnifiedException exception) async {
    // 自定义异常处理逻辑
    switch (exception.type) {
      case ExceptionType.auth:
        await _handleAuthException(exception);
        break;
      case ExceptionType.network:
        await _handleNetworkException(exception);
        break;
      default:
        await _handleGenericException(exception);
    }
  }
}
```

## 异常统计和监控

### 异常统计
```dart
void _recordExceptionStats(UnifiedException exception) {
  final key = '${exception.type.name}_${exception.code.name}';
  _exceptionStats[key] = (_exceptionStats[key] ?? 0) + 1;
}
```

### 统计查询
```dart
Map<String, int> getExceptionStats() {
  return Map.unmodifiable(_exceptionStats);
}

int getExceptionCount(ExceptionType type, ErrorCode code) {
  final key = '${type.name}_${code.name}';
  return _exceptionStats[key] ?? 0;
}
```

### 异常日志
```dart
void _logException(UnifiedException exception) {
  final logLevel = _getLogLevel(exception.type);
  final message = 'Exception: ${exception.code.name} - ${exception.message}';
  
  switch (logLevel) {
    case Level.SEVERE:
      NetworkLogger.general.severe(message, exception.originalError);
      break;
    case Level.WARNING:
      NetworkLogger.general.warning(message);
      break;
    case Level.INFO:
      NetworkLogger.general.info(message);
      break;
  }
}
```

## 使用示例

### 基本异常处理
```dart
try {
  final response = await networkRequest();
  return response;
} catch (error) {
  // 使用统一异常处理器
  final unifiedException = await UnifiedExceptionHandler.instance.handleException(
    error,
    context: 'User profile fetch',
    metadata: {
      'userId': userId,
      'timestamp': DateTime.now().toIso8601String(),
    },
  );
  
  // 根据异常类型处理
  switch (unifiedException.type) {
    case ExceptionType.auth:
      // 跳转到登录页面
      navigateToLogin();
      break;
    case ExceptionType.network:
      // 显示网络错误提示
      showNetworkError();
      break;
    default:
      // 显示通用错误提示
      showGenericError(unifiedException.message);
  }
  
  throw unifiedException;
}
```

### 注册全局异常处理器
```dart
// 注册默认全局处理器
UnifiedExceptionHandler.instance.registerGlobalHandler(
  DefaultGlobalExceptionHandler(),
);

// 注册自定义处理器
UnifiedExceptionHandler.instance.registerGlobalHandler(
  CustomAnalyticsExceptionHandler(),
);

// 注册崩溃报告处理器
UnifiedExceptionHandler.instance.registerGlobalHandler(
  CrashReportingExceptionHandler(),
);
```

### 创建网络异常
```dart
// 从Dio异常创建
try {
  await dio.get('/api/data');
} on DioException catch (e) {
  final networkException = UnifiedExceptionHandler.instance.createNetworkException(e);
  throw networkException;
}

// 从其他异常创建
try {
  await someOperation();
} catch (e) {
  final networkException = UnifiedExceptionHandler.instance.createNetworkException(e);
  throw networkException;
}
```

### 异常统计查询
```dart
// 获取所有异常统计
final stats = UnifiedExceptionHandler.instance.getExceptionStats();
print('异常统计: $stats');

// 获取特定异常计数
final authErrors = UnifiedExceptionHandler.instance.getExceptionCount(
  ExceptionType.auth,
  ErrorCode.unauthorized,
);
print('认证失败次数: $authErrors');

// 重置统计
UnifiedExceptionHandler.instance.resetStats();
```

### 自定义异常处理器
```dart
class AnalyticsExceptionHandler implements GlobalExceptionHandler {
  @override
  Future<void> onException(UnifiedException exception) async {
    // 上报异常到分析平台
    await Analytics.reportException(
      type: exception.type.name,
      code: exception.code.name,
      message: exception.message,
      context: exception.context,
      metadata: exception.metadata,
    );
  }
}

class UserNotificationHandler implements GlobalExceptionHandler {
  @override
  Future<void> onException(UnifiedException exception) async {
    // 根据异常类型显示用户提示
    switch (exception.type) {
      case ExceptionType.network:
        ToastService.showNetworkError();
        break;
      case ExceptionType.auth:
        ToastService.showAuthError();
        break;
      case ExceptionType.server:
        ToastService.showServerError();
        break;
    }
  }
}
```

## 错误码映射

### HTTP状态码映射表
| HTTP状态码 | 异常类型 | 错误码 | 描述 |
|-----------|---------|--------|------|
| 400 | Client | badRequest | 错误请求 |
| 401 | Auth | unauthorized | 未授权 |
| 403 | Auth | forbidden | 禁止访问 |
| 404 | Client | notFound | 未找到 |
| 408 | Network | requestTimeout | 请求超时 |
| 500 | Server | internalServerError | 内部服务器错误 |
| 502 | Server | badGateway | 网关错误 |
| 503 | Server | serviceUnavailable | 服务不可用 |

### 自定义错误码
```dart
// 扩展错误码枚举
enum CustomErrorCode {
  businessLogicError,
  dataValidationError,
  resourceLimitExceeded,
}

// 创建自定义异常
final customException = UnifiedException(
  type: ExceptionType.client,
  code: ErrorCode.unknownError, // 使用通用错误码
  message: 'Business logic validation failed',
  statusCode: -2001,
  metadata: {
    'customCode': 'BUSINESS_LOGIC_ERROR',
    'validationErrors': validationErrors,
  },
);
```

## 性能优化

### 1. 异常缓存
- 避免重复创建相同异常对象
- 缓存常见异常实例
- 减少内存分配

### 2. 异步处理
- 异常处理器异步执行
- 避免阻塞主线程
- 批量处理异常统计

### 3. 内存管理
- 定期清理异常统计
- 限制异常历史记录
- 优化异常对象大小

## 设计模式

### 1. 单例模式
确保全局唯一的异常处理器实例。

### 2. 策略模式
不同类型异常的处理策略。

### 3. 观察者模式
全局异常处理器的注册和通知。

### 4. 工厂模式
异常对象的创建和转换。

### 5. 责任链模式
多个全局处理器的链式调用。

## 注意事项

1. **异常分类**: 正确分类异常类型，便于统一处理
2. **错误码管理**: 维护清晰的错误码体系
3. **性能影响**: 异常处理不应影响正常业务性能
4. **内存泄漏**: 及时清理异常统计和处理器
5. **日志记录**: 合理设置日志级别避免日志泛滥
6. **用户体验**: 提供友好的错误提示信息
7. **异常上报**: 重要异常及时上报到监控系统