# ConfigManager 配置管理器文档

## 概述
`ConfigManager` 是 BZY Network Framework 的高级配置管理器，提供动态配置管理、热配置更新、环境配置切换、配置验证等功能。它扩展了基础的 `NetworkConfig`，提供更强大和灵活的配置管理能力。

## 文件位置
```
lib/src/core/config/config_manager.dart
```

## 核心特性

### 1. 动态配置管理
- **热更新**: 运行时动态更新配置
- **配置监听**: 配置变化实时通知
- **版本管理**: 配置版本控制和回滚
- **配置同步**: 多实例配置同步

### 2. 环境配置
- **多环境支持**: 开发、测试、生产环境配置
- **环境切换**: 运行时环境切换
- **配置继承**: 环境配置继承和覆盖
- **环境隔离**: 不同环境配置隔离

### 3. 配置验证
- **格式验证**: 配置格式和类型验证
- **业务验证**: 业务规则验证
- **依赖检查**: 配置依赖关系检查
- **完整性验证**: 配置完整性检查

### 4. 配置持久化
- **本地存储**: 配置本地持久化
- **远程同步**: 远程配置同步
- **缓存机制**: 配置缓存优化
- **备份恢复**: 配置备份和恢复

## 主要组件

### 1. 配置环境定义
```dart
enum ConfigEnvironment {
  development,   // 开发环境
  testing,       // 测试环境
  staging,       // 预发布环境
  production,    // 生产环境
  custom,        // 自定义环境
}
```

### 2. 配置项定义
```dart
class ConfigItem<T> {
  final String key;
  final T defaultValue;
  final String description;
  final bool isRequired;
  final bool isSecret;
  final List<T>? allowedValues;
  final bool Function(T)? validator;
  
  T _value;
  DateTime _lastUpdated;
  String _source;
}
```

### 3. 配置组定义
```dart
class ConfigGroup {
  final String name;
  final String description;
  final Map<String, ConfigItem> items;
  final List<String> dependencies;
  final bool isEnabled;
  
  ConfigGroup({
    required this.name,
    required this.description,
    required this.items,
    this.dependencies = const [],
    this.isEnabled = true,
  });
}
```

### 4. 配置变更事件
```dart
class ConfigChangeEvent {
  final String key;
  final dynamic oldValue;
  final dynamic newValue;
  final DateTime timestamp;
  final String source;
  final ConfigEnvironment environment;
  
  ConfigChangeEvent({
    required this.key,
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
    required this.source,
    required this.environment,
  });
}
```

## 核心方法

### 1. 配置管理
```dart
// 设置配置值
Future<bool> setConfig<T>(String key, T value, {String? source});

// 获取配置值
T? getConfig<T>(String key, {T? defaultValue});

// 批量设置配置
Future<bool> setConfigs(Map<String, dynamic> configs, {String? source});

// 批量获取配置
Map<String, dynamic> getConfigs(List<String> keys);

// 删除配置
Future<bool> removeConfig(String key);

// 检查配置是否存在
bool hasConfig(String key);
```

### 2. 环境管理
```dart
// 切换环境
Future<bool> switchEnvironment(ConfigEnvironment environment);

// 获取当前环境
ConfigEnvironment getCurrentEnvironment();

// 获取环境配置
Map<String, dynamic> getEnvironmentConfig(ConfigEnvironment environment);

// 设置环境配置
Future<bool> setEnvironmentConfig(
  ConfigEnvironment environment,
  Map<String, dynamic> config,
);
```

### 3. 配置监听
```dart
// 添加配置变更监听器
void addConfigListener(String key, Function(ConfigChangeEvent) listener);

// 移除配置变更监听器
void removeConfigListener(String key, Function(ConfigChangeEvent) listener);

// 添加全局配置监听器
void addGlobalConfigListener(Function(ConfigChangeEvent) listener);

// 移除全局配置监听器
void removeGlobalConfigListener(Function(ConfigChangeEvent) listener);
```

### 4. 配置验证
```dart
// 验证单个配置
ValidationResult validateConfig(String key, dynamic value);

// 验证所有配置
ValidationResult validateAllConfigs();

// 验证配置组
ValidationResult validateConfigGroup(String groupName);

// 检查配置依赖
List<String> checkConfigDependencies(String key);
```

### 5. 配置持久化
```dart
// 保存配置到本地
Future<bool> saveToLocal();

// 从本地加载配置
Future<bool> loadFromLocal();

// 同步远程配置
Future<bool> syncFromRemote(String url);

// 备份配置
Future<bool> backupConfig(String backupName);

// 恢复配置
Future<bool> restoreConfig(String backupName);
```

## 使用示例

### 1. 基本配置管理
```dart
import 'package:bzy_network_framework/bzy_network_framework.dart';

// 获取配置管理器实例
final configManager = ConfigManager.instance;

// 初始化配置管理器
await configManager.initialize();

// 设置配置
await configManager.setConfig('api.baseUrl', 'https://api.example.com');
await configManager.setConfig('api.timeout', 30000);
await configManager.setConfig('cache.enabled', true);

// 获取配置
final baseUrl = configManager.getConfig<String>('api.baseUrl');
final timeout = configManager.getConfig<int>('api.timeout', defaultValue: 10000);
final cacheEnabled = configManager.getConfig<bool>('cache.enabled');

print('API Base URL: $baseUrl');
print('Timeout: $timeout ms');
print('Cache Enabled: $cacheEnabled');
```

### 2. 环境配置管理
```dart
// 设置开发环境配置
await configManager.setEnvironmentConfig(
  ConfigEnvironment.development,
  {
    'api.baseUrl': 'https://dev-api.example.com',
    'api.timeout': 60000,
    'logging.level': 'DEBUG',
    'cache.ttl': 300,
  },
);

// 设置生产环境配置
await configManager.setEnvironmentConfig(
  ConfigEnvironment.production,
  {
    'api.baseUrl': 'https://api.example.com',
    'api.timeout': 30000,
    'logging.level': 'ERROR',
    'cache.ttl': 3600,
  },
);

// 切换到开发环境
await configManager.switchEnvironment(ConfigEnvironment.development);

// 获取当前环境
final currentEnv = configManager.getCurrentEnvironment();
print('当前环境: $currentEnv');
```

### 3. 配置监听
```dart
// 监听特定配置变更
configManager.addConfigListener('api.baseUrl', (event) {
  print('API Base URL 变更: ${event.oldValue} -> ${event.newValue}');
  
  // 重新配置网络客户端
  NetworkExecutor.instance.reconfigure();
});

// 监听缓存配置变更
configManager.addConfigListener('cache.enabled', (event) {
  final enabled = event.newValue as bool;
  if (enabled) {
    CacheManager.instance.enable();
  } else {
    CacheManager.instance.disable();
  }
});

// 全局配置监听
configManager.addGlobalConfigListener((event) {
  print('配置变更: ${event.key} = ${event.newValue}');
  
  // 记录配置变更日志
  NetworkLogger.general.info('配置变更: ${event.key}');
});
```

### 4. 配置验证
```dart
// 定义配置验证规则
configManager.defineConfigItem(
  'api.timeout',
  defaultValue: 30000,
  validator: (value) => value is int && value > 0 && value <= 300000,
  description: 'API请求超时时间（毫秒）',
  isRequired: true,
);

configManager.defineConfigItem(
  'api.baseUrl',
  defaultValue: '',
  validator: (value) => value is String && value.startsWith('https://'),
  description: 'API基础URL',
  isRequired: true,
);

// 验证配置
final result = configManager.validateAllConfigs();
if (!result.isValid) {
  print('配置验证失败:');
  for (final error in result.errors) {
    print('- ${error.key}: ${error.message}');
  }
}
```

### 5. 动态配置更新
```dart
// 从远程服务器同步配置
try {
  final success = await configManager.syncFromRemote(
    'https://config.example.com/api/config',
  );
  
  if (success) {
    print('配置同步成功');
  } else {
    print('配置同步失败');
  }
} catch (e) {
  print('配置同步异常: $e');
}

// 定期同步配置
Timer.periodic(Duration(minutes: 30), (timer) async {
  await configManager.syncFromRemote(
    'https://config.example.com/api/config',
  );
});
```

## 高级功能

### 1. 配置组管理
```dart
// 定义网络配置组
final networkGroup = ConfigGroup(
  name: 'network',
  description: '网络相关配置',
  items: {
    'baseUrl': ConfigItem<String>(
      key: 'network.baseUrl',
      defaultValue: 'https://api.example.com',
      description: 'API基础URL',
      isRequired: true,
    ),
    'timeout': ConfigItem<int>(
      key: 'network.timeout',
      defaultValue: 30000,
      description: '请求超时时间',
      validator: (value) => value > 0 && value <= 300000,
    ),
  },
);

// 注册配置组
configManager.registerConfigGroup(networkGroup);

// 验证配置组
final groupResult = configManager.validateConfigGroup('network');
```

### 2. 配置模板
```dart
// 定义配置模板
final developmentTemplate = {
  'api.baseUrl': 'https://dev-api.example.com',
  'api.timeout': 60000,
  'logging.enabled': true,
  'logging.level': 'DEBUG',
  'cache.enabled': true,
  'cache.ttl': 300,
  'retry.maxAttempts': 5,
};

final productionTemplate = {
  'api.baseUrl': 'https://api.example.com',
  'api.timeout': 30000,
  'logging.enabled': false,
  'logging.level': 'ERROR',
  'cache.enabled': true,
  'cache.ttl': 3600,
  'retry.maxAttempts': 3,
};

// 应用配置模板
await configManager.applyTemplate(developmentTemplate);
```

### 3. 配置加密
```dart
// 设置敏感配置（自动加密）
await configManager.setSecretConfig('api.key', 'secret-api-key');
await configManager.setSecretConfig('database.password', 'db-password');

// 获取敏感配置（自动解密）
final apiKey = configManager.getSecretConfig('api.key');
```

### 4. 配置版本管理
```dart
// 创建配置快照
final snapshotId = await configManager.createSnapshot('v1.0.0');

// 修改配置
await configManager.setConfig('api.baseUrl', 'https://new-api.example.com');

// 回滚到快照
await configManager.rollbackToSnapshot(snapshotId);

// 获取配置历史
final history = configManager.getConfigHistory('api.baseUrl');
```

## 配置最佳实践

### 1. 配置分层
```dart
// 基础配置
final baseConfig = {
  'app.name': 'BZY Network Framework',
  'app.version': '1.0.0',
};

// 环境特定配置
final envConfig = {
  ConfigEnvironment.development: {
    'api.baseUrl': 'https://dev-api.example.com',
    'logging.level': 'DEBUG',
  },
  ConfigEnvironment.production: {
    'api.baseUrl': 'https://api.example.com',
    'logging.level': 'ERROR',
  },
};

// 用户自定义配置
final userConfig = {
  'ui.theme': 'dark',
  'cache.size': 100,
};
```

### 2. 配置验证策略
```dart
// 定义验证规则
final validationRules = {
  'api.timeout': (value) => value is int && value > 0,
  'api.baseUrl': (value) => value is String && Uri.tryParse(value) != null,
  'cache.size': (value) => value is int && value >= 0 && value <= 1000,
};

// 应用验证规则
for (final entry in validationRules.entries) {
  configManager.setValidator(entry.key, entry.value);
}
```

### 3. 配置监控
```dart
// 监控关键配置变更
final criticalConfigs = ['api.baseUrl', 'api.key', 'database.url'];

for (final key in criticalConfigs) {
  configManager.addConfigListener(key, (event) {
    // 记录关键配置变更
    NetworkLogger.general.warning('关键配置变更: ${event.key}');
    
    // 发送告警通知
    _sendConfigChangeAlert(event);
  });
}
```

## 错误处理

### 1. 配置加载失败
```dart
try {
  await configManager.loadFromLocal();
} catch (e) {
  print('配置加载失败: $e');
  
  // 使用默认配置
  await configManager.loadDefaults();
}
```

### 2. 配置验证失败
```dart
final result = configManager.validateAllConfigs();
if (!result.isValid) {
  // 处理验证错误
  for (final error in result.errors) {
    if (error.severity == ValidationSeverity.error) {
      // 严重错误，使用默认值
      await configManager.setConfig(error.key, error.defaultValue);
    } else {
      // 警告，记录日志
      NetworkLogger.general.warning('配置警告: ${error.message}');
    }
  }
}
```

### 3. 远程同步失败
```dart
try {
  await configManager.syncFromRemote(remoteUrl);
} catch (e) {
  print('远程配置同步失败: $e');
  
  // 使用本地缓存配置
  await configManager.loadFromLocal();
}
```

## 设计模式

### 1. 单例模式
- 确保全局唯一的配置管理器实例
- 统一的配置访问入口

### 2. 观察者模式
- 配置变更通知机制
- 解耦配置使用者和管理者

### 3. 策略模式
- 不同的配置加载策略
- 可插拔的配置验证器

### 4. 模板方法模式
- 标准化的配置处理流程
- 可扩展的配置操作

## 注意事项

### 1. 性能考虑
- 避免频繁的配置读写操作
- 使用配置缓存提高访问性能
- 合理设置配置同步频率

### 2. 安全考虑
- 敏感配置信息加密存储
- 配置访问权限控制
- 配置变更审计日志

### 3. 可靠性考虑
- 配置备份和恢复机制
- 配置验证和容错处理
- 配置版本管理和回滚

### 4. 维护性考虑
- 清晰的配置命名规范
- 完善的配置文档说明
- 配置变更影响分析