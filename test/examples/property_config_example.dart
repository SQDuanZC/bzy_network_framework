import '../../lib/src/core/config/config_manager.dart';
import '../../lib/src/core/config/environment.dart' as env;
import '../../lib/src/core/config/environment_config.dart';

/// 演示基于属性的配置管理功能 / Property-based Configuration Management Example
/// Demonstrates how to manage configuration based on properties
void main() async {
  final configManager = ConfigManager.instance;
  
  print('=== 基于属性的配置管理示例 / Property-based Configuration Management Example ===\n');
  
  // 1. 使用预设配置 / Example 1: Use preset configuration
  print('1. 当前开发环境配置 / Current development environment configuration:');
  final devConfig = configManager.currentConfig;
  if (devConfig != null) {
    print('   baseUrl: ${devConfig.baseUrl}');
    print('   connectTimeout / 连接超时: ${devConfig.connectTimeout}ms');
    print('   sendTimeout / 发送超时: ${devConfig.sendTimeout}ms');
    print('   enableCache / 缓存启用: ${devConfig.enableCache}');
    print('   cacheMaxAge / 缓存最大时间: ${devConfig.cacheMaxAge}s');
    print('   enableExponentialBackoff / 指数退避启用: ${devConfig.enableExponentialBackoff}');
  }
  
  // 2. 单个属性更改 / Example 2: Modify single property
  print('\n2. 修改单个属性 / Modify Single Property:');
  print('   修改 sendTimeout 从 / Modify sendTimeout from ${configManager.getEnvironmentProperty<int>(env.Environment.development, "sendTimeout")} 到 / to 25000ms');
  configManager.updateEnvironmentProperty(
    env.Environment.development, 
    'sendTimeout', 
    25000
  );
  
  print('   修改后的 sendTimeout / Modified sendTimeout: ${configManager.getEnvironmentProperty<int>(env.Environment.development, "sendTimeout")}ms');
  
  // 3. 批量属性更改 / Example 3: Batch modify properties
  print('\n3. 批量修改属性 / Batch Modify Properties:');
  final currentConfig = configManager.currentConfig;
  if (currentConfig != null) {
    final updatedConfig = currentConfig.copyWith(
      connectTimeout: 20000,
      receiveTimeout: 35000,
      enableCache: false,
    );
    
    configManager.setEnvironmentConfigObject(env.Environment.development, updatedConfig);
    print('   已批量更新 / Batch updated: connectTimeout=20000ms, receiveTimeout=35000ms, enableCache=false');
  }
  
  // 4. 获取所有可配置属性 / Get all configurable properties
  print('\n4. 所有可配置属性 / All Configurable Properties:');
  final propertyNames = EnvironmentConfigPresets.development.getAllPropertyNames();
  for (final name in propertyNames) {
    final value = configManager.getEnvironmentProperty(env.Environment.development, name);
    print('   $name: $value');
  }
  
  // 5. 自定义配置 / Custom configuration
  print('\n5. 创建自定义配置 / Create Custom Configuration:');
  final customConfig = EnvironmentConfig(
    baseUrl: 'https://custom-api.example.com',
    connectTimeout: 12000,
    receiveTimeout: 25000,
    sendTimeout: 20000,
    maxRetryCount: 5,
    enableLogging: true,
    enableCache: true,
    cacheMaxAge: 1800, // 30分钟
    enableExponentialBackoff: true,
  );
  
  configManager.setEnvironmentConfigObject(env.Environment.staging, customConfig);
  print('   已设置预发布环境的自定义配置 / Custom configuration set for staging environment');
  
  // 6. 配置验证 / Configuration validation
  print('\n6. 配置验证示例 / Configuration Validation Example:');
  try {
    // 尝试设置无效的超时值
    configManager.updateEnvironmentProperty(
      env.Environment.development, 
      'connectTimeout', 
      -1000 // 无效值
    );
  } catch (e) {
    print('   配置验证失败（预期）/ Configuration validation failed (expected): $e');
  }
  
  // 7. 环境切换 / Environment switching
  print('\n7. 环境切换 / Environment Switching:');
  print('   当前环境 / Current environment: ${configManager.currentEnvironment}');
  await configManager.switchEnvironment(env.Environment.production);
  print('   切换到生产环境 / Switched to production environment');
  
  final prodConfig = configManager.currentConfig;
  if (prodConfig != null) {
    print('   生产环境配置 / Production environment configuration:');
    print('     baseUrl: ${prodConfig.baseUrl}');
    print('     enableLogging / 日志启用: ${prodConfig.enableLogging}');
    print('     cacheMaxAge / 缓存最大时间: ${prodConfig.cacheMaxAge}s');
  }
  
  // 8. 配置监听 / Configuration listening
  print('\n8. 配置变更监听 / Configuration Change Listening:');
  configManager.configChanges.listen((event) {
    switch (event.type) {
      case ConfigChangeType.propertyUpdated:
        print('   属性更新 / Property updated: ${event.propertyName} = ${event.newValue}');
        break;
      case ConfigChangeType.environmentSwitched:
        print('   环境切换 / Environment switched: ${event.oldEnvironment} -> ${event.environment}');
        break;
      case ConfigChangeType.environmentConfigUpdated:
        print('   环境配置更新 / Environment config updated: ${event.environment}');
        break;
      default:
        print('   配置变更 / Configuration changed: ${event.type}');
    }
  });
  
  // 触发一些变更事件
  configManager.updateEnvironmentProperty(
    env.Environment.production, 
    'maxRetryCount', 
    5
  );
  
  await configManager.switchEnvironment(env.Environment.development);
  
  print('\n=== 示例完成 / Example Completed ===');
}

/// 演示配置预设的使用 / Demonstrate the use of configuration presets
void demonstratePresets() {
  print('\n=== 配置预设演示 / Configuration Presets Demonstration ===');
  
  // 获取所有预设
  final presets = {
    'development': EnvironmentConfigPresets.development,
    'testing': EnvironmentConfigPresets.testing,
    'staging': EnvironmentConfigPresets.staging,
    'production': EnvironmentConfigPresets.production,
  };
  
  for (final entry in presets.entries) {
    final name = entry.key;
    final config = entry.value;
    
    print('\n$name 环境预设 / Environment preset:');
    print('  baseUrl: ${config.baseUrl}');
    print('  超时配置 / Timeout config: connect=${config.connectTimeout}ms, receive=${config.receiveTimeout}ms, send=${config.sendTimeout}ms');
    print('  重试配置 / Retry config: maxRetryCount=${config.maxRetryCount}, enableExponentialBackoff=${config.enableExponentialBackoff}');
    print('  缓存配置 / Cache config: enableCache=${config.enableCache}, cacheMaxAge=${config.cacheMaxAge}s');
    print('  日志配置 / Logging config: enableLogging=${config.enableLogging}');
  }
}

/// 演示配置的复制和修改 / Demonstrate configuration copying and modification
void demonstrateConfigCopy() {
  print('\n=== 配置复制和修改演示 / Configuration Copy and Modification Demonstration ===');
  
  // 基于生产环境配置创建自定义配置
  final baseConfig = EnvironmentConfigPresets.production;
  print('\n原始生产环境配置 / Original production environment configuration:');
  print('  ${baseConfig.toString()}');
  
  // 创建修改版本
  final customConfig = baseConfig.copyWith(
    baseUrl: 'https://custom-prod-api.example.com',
    connectTimeout: 20000,
    enableLogging: true, // 生产环境启用日志
    maxRetryCount: 5,
  );
  
  print('\n自定义配置 / Custom configuration:');
  print('  ${customConfig.toString()}');
  
  // 逐步修改配置
  print('\n逐步修改配置 / Step-by-step configuration modification:');
  customConfig.updateProperty('cacheMaxAge', 1800); // 30分钟 / 30 minutes
  customConfig.updateProperty('enableExponentialBackoff', false);
  
  print('  修改后 / After modification: ${customConfig.toString()}');
  
  // 验证配置相等性
  final anotherConfig = EnvironmentConfig.fromMap(customConfig.toMap());
  print('\n配置相等性验证 / Configuration equality verification: ${customConfig == anotherConfig}');
}