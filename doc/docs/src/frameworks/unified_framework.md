# 统一网络框架 (UnifiedNetworkFramework) 文档

## 概述
`UnifiedNetworkFramework` 是整个网络框架的核心入口点，采用插件化架构设计，提供统一的网络请求处理能力。

## 文件位置
```
lib/src/frameworks/unified_framework.dart
```

## 核心特性

### 1. 单例模式
框架采用单例模式确保全局唯一实例，避免重复初始化和资源浪费。

### 2. 插件化架构
支持动态注册和管理网络插件，每个插件可以：
- 提供自定义拦截器
- 处理请求生命周期事件
- 实现特定的网络功能

### 3. 全局拦截器管理
支持注册全局拦截器，对所有请求进行统一处理。

### 4. 统一异常处理
集成统一异常处理系统，提供一致的错误处理体验。

## 主要组件

### NetworkPlugin 抽象类
```dart
abstract class NetworkPlugin {
  String get name;           // 插件名称
  String get version;        // 插件版本
  String get description;    // 插件描述
  List<Interceptor> get interceptors; // 插件拦截器
  
  // 生命周期方法
  Future<void> initialize();
  Future<void> dispose();
  
  // 请求生命周期回调
  Future<void> onRequestStart(BaseNetworkRequest request);
  Future<void> onRequestComplete(BaseNetworkRequest request, NetworkResponse response);
  Future<void> onRequestError(BaseNetworkRequest request, Exception error);
}
```

### 核心方法

#### 1. initialize() - 框架初始化
```dart
void initialize({
  List<NetworkPlugin>? plugins,
  List<GlobalInterceptor>? interceptors,
}) async
```

**功能**：
- 注册网络插件
- 注册全局拦截器
- 重新配置网络执行器
- 设置初始化状态

**参数**：
- `plugins`: 要注册的插件列表
- `interceptors`: 全局拦截器列表

#### 2. registerPlugin() - 注册插件
```dart
Future<void> registerPlugin(NetworkPlugin plugin) async
```

**功能**：
- 验证插件有效性
- 初始化插件
- 注册插件拦截器
- 添加到插件映射表

#### 3. execute() - 执行网络请求
```dart
Future<NetworkResponse<T>> execute<T>(BaseNetworkRequest<T> request) async
```

**功能**：
- 预处理请求数据
- 执行插件请求预处理
- 执行网络请求
- 执行插件响应后处理
- 统一异常处理

#### 4. executeBatch() - 批量请求执行
```dart
Future<List<NetworkResponse>> executeBatch(List<BaseNetworkRequest> requests) async
```

**功能**：
- 并发执行多个请求
- 收集所有响应结果
- 统一错误处理

## 插件生命周期

### 1. 注册阶段
1. 验证插件名称唯一性
2. 调用插件的 `initialize()` 方法
3. 注册插件拦截器到网络执行器
4. 添加到插件管理映射

### 2. 请求处理阶段
1. `onRequestStart()` - 请求开始前调用
2. 执行网络请求
3. `onRequestComplete()` - 请求成功完成后调用
4. `onRequestError()` - 请求出错时调用

### 3. 注销阶段
1. 移除插件拦截器
2. 调用插件的 `dispose()` 方法
3. 从插件映射中移除

## 异常处理机制

### 1. 统一异常处理
所有网络请求异常都通过 `UnifiedExceptionHandler` 进行处理：
- 异常分类和转换
- 错误上下文信息收集
- 插件错误处理回调

### 2. 错误元数据
框架会收集以下错误元数据：
- 请求类型
- 请求路径
- HTTP方法
- 错误发生时间

## 使用示例

### 基本初始化
```dart
await UnifiedNetworkFramework.initialize();
```

### 带插件初始化
```dart
await UnifiedNetworkFramework.initialize(
  plugins: [
    MyCustomPlugin(),
    AuthenticationPlugin(),
  ],
  interceptors: [
    LoggingInterceptor(),
    RetryInterceptor(),
  ],
);
```

### 执行请求
```dart
final request = MyNetworkRequest('/api/data');
final response = await UnifiedNetworkFramework.instance.execute(request);
```

### 批量请求
```dart
final requests = [
  GetUserRequest('/users/1'),
  GetUserRequest('/users/2'),
  GetUserRequest('/users/3'),
];
final responses = await UnifiedNetworkFramework.instance.executeBatch(requests);
```

## 设计模式

### 1. 单例模式
确保框架全局唯一实例。

### 2. 插件模式
支持功能的动态扩展和组合。

### 3. 观察者模式
插件可以观察请求生命周期事件。

### 4. 门面模式
为复杂的网络处理提供简单统一的接口。

## 注意事项

1. **初始化检查**: 所有操作前都会检查框架是否已初始化
2. **空值安全**: 所有公共方法都进行严格的空值检查
3. **异常安全**: 插件异常不会影响框架核心功能
4. **线程安全**: 支持多线程环境下的并发操作
5. **资源管理**: 插件注销时会正确清理相关资源