# 增强网络框架功能说明

**版本**: v2.1.0  
**更新日期**: 2024年  
**状态**: ✅ 生产就绪

本文档详细介绍了网络框架新增的热更新、灵活配置机制、调度队列与依赖任务管理功能。

## 🎯 v2.1.0 更新内容

- ✅ **参数修复**: 修正了所有配置类的参数定义
- ✅ **类型安全**: 确保100%类型安全
- ✅ **API统一**: 统一了所有方法签名
- ✅ **文档同步**: 更新了所有示例代码

## 🚀 新增功能概览

### 1. 热更新配置管理
- **动态配置更新**：支持运行时动态更新网络配置
- **配置验证**：内置配置验证机制，确保配置的有效性
- **配置监听**：支持配置变更监听和回调
- **远程配置**：支持从远程服务器获取配置更新

### 2. 灵活配置机制
- **多环境支持**：支持开发、测试、预发布、生产环境配置
- **运行时配置**：支持运行时动态设置和获取配置
- **配置导入导出**：支持配置的导入和导出功能
- **配置验证器**：自定义配置验证规则

### 3. 任务调度系统
- **优先级调度**：支持任务优先级调度
- **依赖管理**：支持任务依赖关系管理
- **并发控制**：可配置的并发任务数量控制
- **重试机制**：智能重试策略和退避算法
- **任务监控**：实时任务状态监控和事件通知

### 4. 增强网络管理器
- **统一接口**：集成所有新功能的统一网络请求接口
- **批量请求**：支持批量请求和依赖管理
- **请求合并**：自动合并重复请求
- **状态监控**：实时网络状态和性能监控

### 5. 安全缓存管理
- **并发安全**：使用锁机制确保多线程环境下的数据一致性
- **数据完整性**：文件完整性检查和数据验证机制
- **错误恢复**：自动检测和清理损坏的缓存文件
- **超时控制**：文件读取超时保护，防止长时间阻塞
- **内存优化**：大文件流式读取，避免内存溢出

## 📋 核心组件

### HotConfigManager
热更新配置管理器，负责动态配置的获取、验证和应用。

```dart
// 初始化热更新管理器
await HotConfigManager.instance.initialize(
  configSourceUrl: 'https://api.example.com/config',
  updateInterval: const Duration(minutes: 5),
  autoUpdate: true,
);

// 添加配置验证器
HotConfigManager.instance.addConfigValidator('baseUrl', (value) {
  return value is String && value.isNotEmpty && Uri.tryParse(value) != null;
});

// 监听配置更新
HotConfigManager.instance.configUpdateStream.listen((update) {
  print('配置更新: 版本 ${update.version}');
});
```

### ConfigManager
配置管理器，支持多环境配置和运行时配置管理。

```dart
// 切换环境
await ConfigManager.instance.switchEnvironment(Environment.production);

// 设置运行时配置
ConfigManager.instance.setRuntimeConfig('debug_mode', true);
ConfigManager.instance.setRuntimeConfig('api_version', 'v2');

// 获取运行时配置
final debugMode = ConfigManager.instance.getRuntimeConfig<bool>('debug_mode');

// 监听配置变更
ConfigManager.instance.configChangeStream.listen((event) {
  print('配置变更: ${event.type} - ${event.key}');
});
```

### TaskScheduler
任务调度器，支持优先级调度、依赖管理和并发控制。

```dart
// 配置调度器
final config = SchedulerConfig(
  maxConcurrentTasks: 5,
  maxQueueSize: 100,
  defaultTimeout: const Duration(seconds: 30),
  enablePriorityScheduling: true,
  enableDependencyManagement: true,
  retryPolicy: RetryPolicy(
    maxRetries: 3,
    baseDelay: const Duration(seconds: 1),
```

### CacheManager
安全缓存管理器，提供高性能、高可靠性的本地缓存解决方案。

```dart
// 配置缓存管理器
final cacheConfig = CacheConfig(
  enableMemoryCache: true,
  enableDiskCache: true,
  memoryMaxSize: 50 * 1024 * 1024, // 50MB
  diskMaxSize: 200 * 1024 * 1024, // 200MB
  defaultExpiration: const Duration(hours: 24),
  enableCompression: true,
  enableEncryption: true,
  enableTagging: true,
  diskIOBufferSize: 8192,
  enableAsyncDiskIO: true,
);

// 初始化缓存管理器
final cacheManager = CacheManager.instance;
await cacheManager.initialize(config: cacheConfig);

// 设置缓存
await cacheManager.set(
  'user_profile',
  {'id': 123, 'name': 'John'},
  expiration: const Duration(hours: 2),
  tags: ['user', 'profile'],
  priority: CachePriority.high,
);

// 获取缓存
final userProfile = await cacheManager.get('user_profile');

// 根据标签清理缓存
await cacheManager.clearByTag('user');

// 获取缓存统计信息
final stats = cacheManager.getStatistics();
print('缓存命中率: ${stats.hitRate.toStringAsFixed(2)}%');
```
  ),
);

TaskScheduler.instance.configure(config);
TaskScheduler.instance.start();

// 监听任务事件
TaskScheduler.instance.eventStream.listen((event) {
  switch (event.type) {
    case TaskEventType.completed:
      print('任务完成: ${event.taskId}');
      break;
    case TaskEventType.failed:
      print('任务失败: ${event.taskId} - ${event.error}');
      break;
  }
});
```

### EnhancedNetworkManager
增强网络管理器，集成所有新功能的统一接口。

```dart
// 配置增强网络管理器
EnhancedNetworkManager.instance.configure(
  // 热更新配置
  configSourceUrl: 'https://api.example.com/config',
  configUpdateInterval: const Duration(minutes: 5),
  autoConfigUpdate: true,
  
  // 任务调度配置
  schedulerConfig: SchedulerConfig(
    maxConcurrentTasks: 5,
    maxQueueSize: 100,
    enablePriorityScheduling: true,
    enableDependencyManagement: true,
  ),
);
```

## 🔧 使用示例

### 基本网络请求

```dart
// GET请求（支持缓存和请求合并）
final response = await EnhancedNetworkManager.instance.get<User>(
  '/users/1',
  fromJson: (json) => User.fromJson(json),
  cacheStrategy: CacheStrategy.cacheFirst,
  cacheExpiry: const Duration(minutes: 5),
  enableRequestMerging: true,
);

// POST请求
final createResponse = await EnhancedNetworkManager.instance.post<User>(
  '/users',
  data: {
    'name': '新用户',
    'email': 'newuser@example.com',
  },
  fromJson: (json) => User.fromJson(json),
);
```

### 任务调度请求

```dart
// 高优先级任务
final highPriorityResponse = await EnhancedNetworkManager.instance.get<User>(
  '/users/important',
  priority: TaskPriority.high,
  useScheduler: true,
  maxRetries: 2,
  fromJson: (json) => User.fromJson(json),
);

// 依赖任务
final dependentResponse = await EnhancedNetworkManager.instance.post<Post>(
  '/posts',
  data: {'title': '新文章', 'content': '文章内容'},
  priority: TaskPriority.normal,
  dependencies: ['user_task_1'], // 依赖用户任务
  useScheduler: true,
  fromJson: (json) => Post.fromJson(json),
);
```

### 批量请求

```dart
// 批量请求
final batchRequests = [
  BatchRequestItem<User>(
    method: 'GET',
    path: '/users/1',
    fromJson: (json) => User.fromJson(json),
  ),
  BatchRequestItem<User>(
    method: 'GET',
    path: '/users/2',
    fromJson: (json) => User.fromJson(json),
  ),
  BatchRequestItem<User>(
    method: 'GET',
    path: '/users/3',
    fromJson: (json) => User.fromJson(json),
  ),
];

final batchResults = await EnhancedNetworkManager.instance.batchRequests(
  batchRequests,
  waitForAll: true,
  timeout: const Duration(seconds: 30),
  priority: TaskPriority.normal,
);
```

### 环境切换

```dart
// 切换到测试环境
await ConfigManager.instance.switchEnvironment(Environment.testing);

// 设置运行时配置
ConfigManager.instance.setRuntimeConfig('debug_mode', true);
ConfigManager.instance.setRuntimeConfig('api_version', 'v2');

// 获取当前配置
final currentEnv = ConfigManager.instance.currentEnvironment;
final baseUrl = ConfigManager.instance.currentConfig.baseUrl;
```

### 热更新配置

```dart
// 手动触发配置更新
final updateSuccess = await EnhancedNetworkManager.instance.updateConfig();

// 添加配置监听器
EnhancedNetworkManager.instance.addConfigListener('baseUrl', (key, oldValue, newValue) {
  print('baseUrl配置变更: $oldValue -> $newValue');
});

// 模拟配置变更
final mockConfig = {
  'version': '1.2.0',
  'baseUrl': 'https://new-api.example.com',
  'timeout': 15000,
  'enableNewFeature': true,
};

await HotConfigManager.instance.processConfigUpdate(mockConfig);
```

## 📊 状态监控

### 调度器状态

```dart
// 获取调度器状态
final schedulerStatus = EnhancedNetworkManager.instance.getSchedulerStatus();
print('队列中任务数: ${schedulerStatus.queuedTaskCount}');
print('执行中任务数: ${schedulerStatus.runningTaskCount}');
print('已完成任务数: ${schedulerStatus.completedTaskCount}');
print('失败任务数: ${schedulerStatus.failedTaskCount}');
```

### 配置摘要

```dart
// 获取配置摘要
final configSummary = ConfigManager.instance.getConfigSummary();
print('当前环境: ${configSummary['currentEnvironment']}');
print('环境配置数: ${configSummary['environmentCount']}');
print('运行时配置数: ${configSummary['runtimeConfigCount']}');
print('配置有效性: ${configSummary['isValid']}');
```

## 🏗️ 架构设计

### 核心架构

```
┌─────────────────────────────────────────────────────────────┐
│                 EnhancedNetworkManager                      │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ │
│  │  ConfigManager  │ │ HotConfigManager│ │  TaskScheduler  │ │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    HttpClient                               │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ │
│  │HeaderInterceptor│ │LoggingInterceptor│ │RetryInterceptor │ │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 数据流

```
请求发起 → 任务调度 → 依赖检查 → 优先级排序 → 并发控制 → 网络请求 → 响应处理
    ↓           ↓           ↓           ↓           ↓           ↓
配置管理 → 热更新监听 → 环境切换 → 运行时配置 → 状态监控 → 事件通知
```

## 🔒 安全特性

1. **配置验证**：所有配置更新都经过验证器验证
2. **权限控制**：支持配置访问权限控制
3. **数据脱敏**：敏感数据自动脱敏处理
4. **安全传输**：配置更新使用安全传输协议

## 🚀 性能优化

1. **请求合并**：自动合并重复请求，减少网络开销
2. **智能缓存**：多级缓存策略，提升响应速度
3. **并发控制**：可配置的并发数量，避免资源过度消耗
4. **连接池**：HTTP连接池复用，减少连接建立开销
5. **压缩传输**：支持请求和响应数据压缩

## 📈 监控指标

### 任务调度指标
- 任务队列长度
- 任务执行时间
- 任务成功率
- 任务重试次数
- 并发任务数量

### 网络请求指标
- 请求响应时间
- 请求成功率
- 网络错误率
- 缓存命中率
- 请求合并率

### 配置管理指标
- 配置更新频率
- 配置验证成功率
- 环境切换次数
- 热更新成功率

## 🛠️ 最佳实践

### 1. 配置管理
- 为不同环境设置合适的配置参数
- 使用配置验证器确保配置的有效性
- 定期备份重要配置
- 监控配置变更，及时发现异常

### 2. 任务调度
- 合理设置任务优先级，避免低优先级任务饥饿
- 控制并发任务数量，避免资源过度消耗
- 设置合适的重试策略，平衡成功率和性能
- 监控任务执行状态，及时处理异常

### 3. 网络请求
- 使用适当的缓存策略，提升用户体验
- 启用请求合并，减少重复请求
- 设置合理的超时时间
- 处理网络异常，提供友好的错误提示

### 5. 缓存安全
- 启用数据加密保护敏感信息
- 设置合理的缓存过期时间
- 定期清理过期和损坏的缓存文件
- 监控缓存命中率和性能指标
- 使用标签管理相关缓存数据
- 在并发环境下确保数据一致性

### 4. 性能优化
- 定期清理过期缓存
- 监控内存使用情况
- 优化大数据传输
- 使用连接池复用连接

## 🔧 故障排查

### 常见问题

1. **配置更新失败**
   - 检查网络连接
   - 验证配置源URL
   - 检查配置格式

2. **任务执行缓慢**
   - 检查并发设置
   - 查看任务依赖关系
   - 监控网络状况

3. **内存使用过高**
   - 检查缓存设置
   - 清理过期数据
   - 优化数据结构

### 调试工具

```dart
// 启用详细日志
ConfigManager.instance.setRuntimeConfig('debug_mode', true);

// 获取详细状态信息
final status = EnhancedNetworkManager.instance.getSchedulerStatus();
final summary = ConfigManager.instance.getConfigSummary();

// 导出配置用于分析
final configExport = ConfigManager.instance.exportConfig();
```

## 📝 更新日志

### v2.0.0 (当前版本)
- ✨ 新增热更新配置管理
- ✨ 新增灵活配置机制
- ✨ 新增任务调度系统
- ✨ 新增增强网络管理器
- 🚀 性能优化和稳定性提升
- 📚 完善文档和示例

## 🤝 贡献指南

欢迎提交Issue和Pull Request来改进这个框架。在贡献代码之前，请确保：

1. 代码符合项目的编码规范
2. 添加适当的测试用例
3. 更新相关文档
4. 确保所有测试通过

## 📄 许可证

本项目采用 MIT 许可证。详情请参阅 LICENSE 文件。