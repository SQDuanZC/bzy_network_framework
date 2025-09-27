# 拦截器管理器 (InterceptorManager) 文档

## 概述
`InterceptorManager` 是网络框架的插件化拦截器管理系统，支持拦截器的动态注册、管理、执行顺序控制和性能监控。

## 文件位置
```
lib/src/core/interceptor/interceptor_manager.dart
```

## 核心特性

### 1. 插件化架构
- 支持动态注册和注销拦截器
- 每个拦截器都有独立的配置和状态管理
- 支持拦截器的启用/禁用控制

### 2. 执行顺序控制
- 支持基于优先级的拦截器排序
- 灵活的执行顺序管理
- 动态调整拦截器执行顺序

### 3. 配置管理
- 每个拦截器都有独立的配置对象
- 支持运行时配置更新
- 配置验证和默认值管理

### 4. 性能监控
- 拦截器执行统计
- 性能指标收集
- 异常监控和报告

## 主要组件

### InterceptorConfig 配置类
```dart
class InterceptorConfig {
  bool enabled;                    // 是否启用
  int priority;                   // 优先级
  Duration timeout;               // 超时时间
  Map<String, dynamic> metadata;  // 元数据
  
  // 配置验证
  bool validate();
}
```

### InterceptorStatistics 统计类
```dart
class InterceptorStatistics {
  int totalRegistered;      // 总注册数
  int totalEnabled;         // 启用数量
  int totalExecutions;      // 总执行次数
  int totalErrors;          // 错误次数
  Duration averageTime;     // 平均执行时间
  
  // 统计方法
  void recordExecution(String name, Duration time);
  void recordError(String name, Exception error);
}
```

## 核心方法

### 1. registerInterceptor() - 注册拦截器
```dart
void registerInterceptor(
  String name,
  PluginInterceptor interceptor, {
  InterceptorConfig? config,
  int? priority,
})
```

**功能**：
- 注册新的拦截器
- 设置拦截器配置
- 根据优先级安排执行顺序
- 记录注册日志

**参数**：
- `name`: 拦截器唯一名称
- `interceptor`: 拦截器实例
- `config`: 拦截器配置（可选）
- `priority`: 执行优先级（可选）

### 2. unregisterInterceptor() - 注销拦截器
```dart
bool unregisterInterceptor(String name)
```

**功能**：
- 移除指定的拦截器
- 清理相关配置和统计
- 更新执行顺序列表

### 3. enableInterceptor() / disableInterceptor() - 启用/禁用拦截器
```dart
bool enableInterceptor(String name)
bool disableInterceptor(String name)
```

**功能**：
- 动态控制拦截器的启用状态
- 不影响注册状态，只控制执行

### 4. updateInterceptorConfig() - 更新配置
```dart
bool updateInterceptorConfig(String name, InterceptorConfig config)
```

**功能**：
- 动态更新拦截器配置
- 配置验证和应用
- 触发配置变更事件

### 5. executeInterceptors() - 执行拦截器链
```dart
Future<void> executeInterceptors(
  InterceptorType type,
  RequestOptions options,
  ResponseInterceptorHandler handler,
)
```

**功能**：
- 按优先级顺序执行拦截器
- 性能监控和统计
- 异常处理和恢复

## 拦截器类型

### 1. 请求拦截器 (Request Interceptor)
在请求发送前执行，可以：
- 修改请求参数
- 添加请求头
- 请求验证
- 请求日志记录

### 2. 响应拦截器 (Response Interceptor)
在响应接收后执行，可以：
- 响应数据转换
- 响应验证
- 缓存处理
- 响应日志记录

### 3. 错误拦截器 (Error Interceptor)
在请求出错时执行，可以：
- 错误处理和转换
- 重试逻辑
- 错误日志记录
- 降级处理

## 执行顺序管理

### 优先级规则
- 数值越小，优先级越高
- 相同优先级按注册顺序执行
- 支持动态调整优先级

### 执行流程
1. **请求阶段**: 按优先级正序执行请求拦截器
2. **响应阶段**: 按优先级逆序执行响应拦截器
3. **错误阶段**: 按优先级正序执行错误拦截器

## 性能监控

### 统计指标
- 拦截器注册数量
- 启用/禁用状态统计
- 执行次数统计
- 执行时间统计
- 错误次数统计

### 性能优化
- 拦截器执行时间监控
- 异常拦截器识别
- 性能瓶颈分析
- 自动优化建议

## 使用示例

### 基本注册
```dart
// 注册日志拦截器
InterceptorManager.instance.registerInterceptor(
  'logging',
  LoggingInterceptor(),
  config: InterceptorConfig(
    enabled: true,
    priority: 100,
  ),
);

// 注册认证拦截器
InterceptorManager.instance.registerInterceptor(
  'auth',
  AuthInterceptor(),
  priority: 50, // 高优先级
);
```

### 动态管理
```dart
// 禁用日志拦截器
InterceptorManager.instance.disableInterceptor('logging');

// 更新配置
InterceptorManager.instance.updateInterceptorConfig(
  'auth',
  InterceptorConfig(
    enabled: true,
    priority: 10,
    timeout: Duration(seconds: 5),
  ),
);

// 注销拦截器
InterceptorManager.instance.unregisterInterceptor('logging');
```

### 批量管理
```dart
// 批量注册
final interceptors = {
  'retry': RetryInterceptor(),
  'cache': CacheInterceptor(),
  'timeout': TimeoutInterceptor(),
};

for (final entry in interceptors.entries) {
  InterceptorManager.instance.registerInterceptor(
    entry.key,
    entry.value,
  );
}
```

### 性能监控
```dart
// 获取统计信息
final stats = InterceptorManager.instance.statistics;
print('注册拦截器数量: ${stats.totalRegistered}');
print('平均执行时间: ${stats.averageTime}');
print('错误率: ${stats.totalErrors / stats.totalExecutions}');
```

## 内置拦截器

### 1. LoggingInterceptor - 日志拦截器
记录请求和响应的详细信息。

### 2. RetryInterceptor - 重试拦截器
自动重试失败的请求。

### 3. CacheInterceptor - 缓存拦截器
处理请求和响应的缓存。

### 4. AuthInterceptor - 认证拦截器
处理身份验证和授权。

### 5. TimeoutInterceptor - 超时拦截器
处理请求超时控制。

## 设计模式

### 1. 责任链模式
拦截器按链式结构执行，每个拦截器处理特定职责。

### 2. 策略模式
不同类型的拦截器实现不同的处理策略。

### 3. 观察者模式
拦截器可以观察和响应请求生命周期事件。

### 4. 装饰器模式
拦截器为原始请求添加额外的功能。

## 注意事项

1. **名称唯一性**: 拦截器名称必须唯一
2. **执行顺序**: 注意拦截器的执行顺序对结果的影响
3. **性能影响**: 过多的拦截器可能影响请求性能
4. **异常处理**: 拦截器异常不应影响其他拦截器
5. **资源管理**: 及时注销不需要的拦截器释放资源
6. **配置验证**: 确保拦截器配置的有效性
7. **线程安全**: 拦截器应该是线程安全的