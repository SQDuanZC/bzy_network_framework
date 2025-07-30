# 统一QueryParameters方案

## 概述

本方案实现了统一使用 `queryParameters` 处理所有HTTP请求数据的功能。框架会根据HTTP方法自动决定数据的实际传输方式：

- **GET/DELETE请求**: `queryParameters` 作为URL查询参数
- **POST/PUT/PATCH请求**: `queryParameters` 自动转换为请求体数据

## 设计原理

### 1. 统一数据接口

所有请求类只需要实现 `queryParameters` getter，无需关心数据的实际传输方式：

```dart
class MyRequest extends BaseNetworkRequest<ResponseType> {
  @override
  Map<String, dynamic>? get queryParameters => {
    'key1': 'value1',
    'key2': 'value2',
  };
}
```

### 2. 自动数据转换

框架在 `BaseNetworkRequest.buildRequestOptions()` 方法中实现自动转换逻辑：

```dart
if (params != null && params.isNotEmpty) {
  switch (method) {
    case HttpMethod.get:
    case HttpMethod.delete:
      // GET/DELETE: 使用queryParameters作为URL参数
      finalQueryParams = params;
      finalData = data; // 保持原始data（通常为null）
      break;
      
    case HttpMethod.post:
    case HttpMethod.put:
    case HttpMethod.patch:
      // POST/PUT/PATCH: 将queryParameters转换为请求体
      finalQueryParams = null; // 清空URL参数
      finalData = params; // 使用queryParameters作为请求体
      break;
  }
}
```

### 3. 原始数据保存

`UnifiedNetworkFramework.execute()` 方法中的 `_getEffectiveRequestData()` 确保正确保存实际发送的数据：

```dart
dynamic _getEffectiveRequestData(BaseNetworkRequest request) {
  final params = request.queryParameters;
  
  if (params != null && params.isNotEmpty) {
    switch (request.method) {
      case HttpMethod.post:
      case HttpMethod.put:
      case HttpMethod.patch:
        return params; // POST/PUT/PATCH返回queryParameters
      default:
        return null; // GET/DELETE返回null
    }
  }
  
  return null;
}
```

## 使用示例

### GET请求

```dart
class GetUserRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String userId;
  final bool includeProfile;
  
  GetUserRequest({required this.userId, this.includeProfile = false});
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  String get path => '/users';
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'id': userId,
    'include_profile': includeProfile.toString(),
  };
  // 实际请求: GET /users?id=123&include_profile=true
}
```

### POST请求

```dart
class CreateUserRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String name;
  final String email;
  
  CreateUserRequest({required this.name, required this.email});
  
  @override
  HttpMethod get method => HttpMethod.post;
  
  @override
  String get path => '/users';
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'name': name,
    'email': email,
    'created_at': DateTime.now().toIso8601String(),
  };
  // 实际请求: POST /users + JSON请求体
}
```

## 方案优势

### 1. 统一接口
- 所有请求类使用相同的数据定义方式
- 减少开发者的认知负担
- 提高代码一致性

### 2. 自动转换
- 框架自动处理数据传输方式
- 开发者无需关心HTTP协议细节
- 减少错误和遗漏

### 3. 类型安全
- 保持强类型检查
- 编译时错误检测
- IDE智能提示支持

### 5. 调试友好
- `originalRequestData` 正确保存实际发送的数据
- 便于日志记录和错误追踪
- 支持请求重试和缓存

## 实际HTTP请求对比

### GET请求

**代码:**
```dart
final request = GetUserRequest(userId: '123', includeProfile: true);
```

**实际HTTP请求:**
```http
GET /users?id=123&include_profile=true HTTP/1.1
Host: api.example.com
Content-Type: application/json
```

### POST请求

**代码:**
```dart
final request = CreateUserRequest(name: '张三', email: 'zhangsan@example.com');
```

**实际HTTP请求:**
```http
POST /users HTTP/1.1
Host: api.example.com
Content-Type: application/json

{
  "name": "张三",
  "email": "zhangsan@example.com",
  "created_at": "2024-01-01T12:00:00.000Z"
}
```

## 迁移指南

### 现有代码迁移

**旧方式:**
```dart
class OldPostRequest extends BaseNetworkRequest<ResponseType> {
  @override
  HttpMethod get method => HttpMethod.post;
  
  @override
  dynamic get data => {
    'key1': 'value1',
    'key2': 'value2',
  };
}
```

**新方式:**
```dart
class NewPostRequest extends BaseNetworkRequest<ResponseType> {
  @override
  HttpMethod get method => HttpMethod.post;
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'key1': 'value1',
    'key2': 'value2',
  };
}
```

### 渐进式迁移

1. **保持兼容**: 现有使用 `data` 的代码继续工作
2. **新代码使用**: 新的请求类使用 `queryParameters`
3. **逐步迁移**: 根据需要逐步迁移现有代码

## 注意事项

1. **数据优先级**: 如果同时定义了 `queryParameters` 和 `data`，框架会优先使用 `queryParameters`
2. **空数据处理**: 如果 `queryParameters` 为空或null，框架会回退到使用 `data`
3. **类型转换**: 框架会自动处理数据的JSON序列化
4. **缓存兼容**: 缓存键生成会考虑实际发送的数据

## 测试验证

运行示例代码验证功能：

```bash
flutter test examples/unified_query_parameters_example.dart
```

查看控制台输出，验证：
- GET请求的 `originalRequestData` 为null（因为数据在URL中）
- POST请求的 `originalRequestData` 包含实际发送的JSON数据
- 所有请求都能正确执行和响应