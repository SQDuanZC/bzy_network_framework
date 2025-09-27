# 网络配置 (NetworkConfig) 文档

## 概述
`NetworkConfig` 是网络框架的核心配置管理器，提供灵活的配置预设、动态配置更新和环境适配能力。

## 文件位置
```
lib/src/config/network_config.dart
```

## 核心特性

### 1. 配置预设系统
提供多种预定义的网络配置预设，适应不同的使用场景：

#### 预设类型
- **development** - 开发环境配置
- **production** - 生产环境配置  
- **testing** - 测试环境配置
- **staging** - 预发布环境配置
- **fastResponse** - 快速响应配置
- **heavyLoad** - 重负载配置
- **offlineFirst** - 离线优先配置
- **lowBandwidth** - 低带宽配置

### 2. 动态配置管理
支持运行时动态修改配置参数，无需重启应用。

### 3. 环境适配
根据不同环境自动调整配置参数，确保最佳性能。

## 配置预设详解

### Development 配置
```dart
{
  'connectTimeout': 15000,      // 连接超时15秒
  'receiveTimeout': 30000,      // 接收超时30秒
  'sendTimeout': 30000,         // 发送超时30秒
  'maxRetries': 3,              // 最大重试3次
  'retryDelay': 1000,           // 重试延迟1秒
  'enableLogging': true,        // 启用日志
  'logLevel': LogLevel.debug,   // 调试级别日志
  'enableCache': true,          // 启用缓存
  'defaultCacheDuration': 300,  // 默认缓存5分钟
  'maxCacheSize': 100,          // 最大缓存100项
  'environment': Environment.development,
  'enableExponentialBackoff': true, // 启用指数退避
}
```

### Production 配置
```dart
{
  'connectTimeout': 15000,
  'receiveTimeout': 30000,
  'sendTimeout': 30000,
  'maxRetries': 3,
  'retryDelay': 1000,
  'enableLogging': false,       // 生产环境关闭日志
  'logLevel': LogLevel.error,   // 只记录错误日志
  'enableCache': true,
  'defaultCacheDuration': 900,  // 缓存15分钟
  'maxCacheSize': 100,
  'environment': Environment.production,
  'enableExponentialBackoff': true,
}
```

### Testing 配置
```dart
{
  'connectTimeout': 10000,      // 更短的超时时间
  'receiveTimeout': 20000,
  'sendTimeout': 20000,
  'maxRetries': 2,              // 减少重试次数
  'retryDelay': 500,            // 更短的重试延迟
  'enableLogging': true,
  'logLevel': LogLevel.info,
  'enableCache': false,         // 测试环境禁用缓存
  'defaultCacheDuration': 0,
  'maxCacheSize': 0,
  'environment': Environment.testing,
  'enableExponentialBackoff': false,
}
```

### Fast Response 配置
```dart
{
  'connectTimeout': 5000,       // 快速连接
  'receiveTimeout': 10000,      // 快速响应
  'sendTimeout': 10000,
  'maxRetries': 1,              // 最少重试
  'retryDelay': 200,            // 最短延迟
  'enableLogging': false,       // 关闭日志提升性能
  'enableCache': true,          // 启用缓存加速
  'defaultCacheDuration': 1800, // 长缓存时间
}
```

### Heavy Load 配置
```dart
{
  'connectTimeout': 30000,      // 更长的超时时间
  'receiveTimeout': 60000,      // 适应重负载
  'sendTimeout': 60000,
  'maxRetries': 5,              // 更多重试次数
  'retryDelay': 2000,           // 更长的重试间隔
  'enableExponentialBackoff': true,
  'maxConcurrentRequests': 3,   // 限制并发数
}
```

## 主要功能

### 1. 预设配置获取
```dart
// 通过字符串获取预设
NetworkConfigPreset? preset = NetworkConfigPreset.fromString('development');

// 获取预设配置
Map<String, dynamic>? config = preset?.getConfig();
```

### 2. 配置应用
```dart
// 应用预设配置
NetworkConfig.instance.applyPreset(NetworkConfigPreset.development, baseUrl: 'https://api.dev.example.com');

// 自定义配置
NetworkConfig.instance.configure(
  baseUrl: 'https://api.example.com',
  connectTimeout: 15000,
  receiveTimeout: 30000,
  enableLogging: true,
);
```

### 3. 动态配置更新
```dart
// 更新单个配置项
NetworkConfig.instance.updateTimeout(connectTimeout: 20000);

// 批量更新配置
NetworkConfig.instance.updateConfig({
  'maxRetries': 5,
  'retryDelay': 2000,
});
```

## 配置参数说明

### 网络超时配置
- `connectTimeout`: 连接超时时间（毫秒）
- `receiveTimeout`: 接收数据超时时间（毫秒）
- `sendTimeout`: 发送数据超时时间（毫秒）

### 重试配置
- `maxRetries`: 最大重试次数
- `retryDelay`: 重试延迟时间（毫秒）
- `enableExponentialBackoff`: 是否启用指数退避算法

### 日志配置
- `enableLogging`: 是否启用日志记录
- `logLevel`: 日志级别（debug/info/warning/error）

### 缓存配置
- `enableCache`: 是否启用缓存
- `defaultCacheDuration`: 默认缓存持续时间（秒）
- `maxCacheSize`: 最大缓存项数量

### 并发控制
- `maxConcurrentRequests`: 最大并发请求数
- `queueSize`: 请求队列大小

### 环境配置
- `environment`: 运行环境（development/production/testing/staging）

## 使用示例

### 基本配置
```dart
// 使用预设配置
await NetworkConfig.instance.applyPreset(
  NetworkConfigPreset.production,
  baseUrl: 'https://api.example.com',
);
```

### 自定义配置
```dart
await NetworkConfig.instance.configure(
  baseUrl: 'https://api.example.com',
  connectTimeout: 15000,
  receiveTimeout: 30000,
  maxRetries: 3,
  enableLogging: true,
  enableCache: true,
);
```

### 环境特定配置
```dart
// 根据环境选择配置
if (kDebugMode) {
  await NetworkConfig.instance.applyPreset(
    NetworkConfigPreset.development,
    baseUrl: 'https://api.dev.example.com',
  );
} else {
  await NetworkConfig.instance.applyPreset(
    NetworkConfigPreset.production,
    baseUrl: 'https://api.example.com',
  );
}
```

### 动态配置调整
```dart
// 根据网络状况动态调整
if (isSlowNetwork) {
  NetworkConfig.instance.updateConfig({
    'connectTimeout': 30000,
    'receiveTimeout': 60000,
    'maxRetries': 5,
  });
}
```

## 设计原则

1. **预设优先**: 提供常用场景的预设配置
2. **灵活定制**: 支持细粒度的配置定制
3. **环境适配**: 根据环境自动优化配置
4. **动态调整**: 支持运行时配置修改
5. **向后兼容**: 保持API的向后兼容性

## 注意事项

1. **baseUrl独立**: baseUrl需要单独设置，不包含在预设中
2. **配置验证**: 所有配置参数都会进行有效性验证
3. **性能考虑**: 频繁的配置更新可能影响性能
4. **线程安全**: 配置更新操作是线程安全的
5. **默认值**: 未设置的配置项会使用合理的默认值