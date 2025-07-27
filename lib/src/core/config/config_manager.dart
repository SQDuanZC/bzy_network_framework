import 'dart:async';
import 'package:dio/dio.dart';
import 'environment.dart' as env;
import 'network_config.dart';

/// 配置管理器
/// 支持多环境配置、动态配置切换、配置验证
class ConfigManager {
  static ConfigManager? _instance;
  
  // 当前环境
  env.Environment _currentEnvironment = env.Environment.development;
  
  // 环境配置映射
  final Map<env.Environment, Map<String, dynamic>> _environmentConfigs = {};
  
  // 运行时配置
  final Map<String, dynamic> _runtimeConfigs = {};
  
  // 配置监听器
  final Map<String, List<ConfigChangeListener>> _listeners = {};
  
  // 配置验证器
  final Map<String, ConfigValidator> _validators = {};
  
  // 配置变更事件流
  final StreamController<ConfigChangeEvent> _eventController =
      StreamController<ConfigChangeEvent>.broadcast();
  
  // 私有构造函数
  ConfigManager._() {
    _initializeDefaultConfigs();
  }
  
  /// 获取单例实例
  static ConfigManager get instance {
    _instance ??= ConfigManager._();
    return _instance!;
  }
  
  /// 当前环境
  env.Environment get currentEnvironment => _currentEnvironment;
  
  /// 当前配置
  Map<String, dynamic> get currentConfig => 
      _environmentConfigs[_currentEnvironment] ?? {};
  
  /// 配置变更事件流
  Stream<ConfigChangeEvent> get configChangeStream => _eventController.stream;
  
  /// 初始化默认配置
  void _initializeDefaultConfigs() {
    // 开发环境配置
    _environmentConfigs[env.Environment.development] = {
      'baseUrl': 'https://dev-api.example.com',
      'connectTimeout': 15000,
      'receiveTimeout': 15000,
      'sendTimeout': 15000,
      'maxRetryCount': 3,
      'enableLogging': true,
      'enableCache': true,
      'cacheMaxAge': 300,
    };
    
    // 测试环境配置
    _environmentConfigs[env.Environment.testing] = {
      'baseUrl': 'https://test-api.example.com',
      'connectTimeout': 10000,
      'receiveTimeout': 10000,
      'sendTimeout': 10000,
      'maxRetryCount': 2,
      'enableLogging': true,
      'enableCache': true,
      'cacheMaxAge': 180,
    };
    
    // 预发布环境配置
    _environmentConfigs[env.Environment.staging] = {
      'baseUrl': 'https://staging-api.example.com',
      'connectTimeout': 20000,
      'receiveTimeout': 20000,
      'sendTimeout': 20000,
      'maxRetryCount': 5,
      'enableLogging': true,
      'enableCache': true,
      'cacheMaxAge': 600,
    };
    
    // 生产环境配置
    _environmentConfigs[env.Environment.production] = {
      'baseUrl': 'https://api.example.com',
      'connectTimeout': 30000,
      'receiveTimeout': 30000,
      'sendTimeout': 30000,
      'maxRetryCount': 3,
      'enableLogging': false,
      'enableCache': true,
      'cacheMaxAge': 900,
    };
  }
  
  /// 设置环境配置
  void setEnvironmentConfig(env.Environment environment, Map<String, dynamic> config) {
    final oldConfig = _environmentConfigs[environment];
    _environmentConfigs[environment] = Map.from(config);
    
    // 如果是当前环境，立即应用配置
    if (environment == _currentEnvironment) {
      _applyConfig(config);
    }
    
    // 发送配置变更事件
    _notifyConfigChange(
      ConfigChangeEvent(
        type: ConfigChangeType.environmentConfigUpdated,
        environment: environment,
        oldConfig: oldConfig,
        newConfig: config,
      ),
    );
  }
  
  /// 切换环境
  Future<void> switchEnvironment(env.Environment environment) async {
    if (_currentEnvironment == environment) {
      return;
    }
    
    final oldEnvironment = _currentEnvironment;
    final oldConfig = currentConfig;
    
    _currentEnvironment = environment;
    final newConfig = currentConfig;
    
    // 应用新配置
    await _applyConfig(newConfig);
    
    // 发送环境切换事件
    _notifyConfigChange(
      ConfigChangeEvent(
        type: ConfigChangeType.environmentSwitched,
        environment: environment,
        oldEnvironment: oldEnvironment,
        oldConfig: oldConfig,
        newConfig: newConfig,
      ),
    );
    
    // 环境已切换: $oldEnvironment -> $environment
  }
  
  /// 应用配置
  Future<void> _applyConfig(Map<String, dynamic> config) async {
    // 更新全局网络配置
    NetworkConfig.instance.configure(
      baseUrl: config['baseUrl'] as String?,
      connectTimeout: config['connectTimeout'] as int?,
      receiveTimeout: config['receiveTimeout'] as int?,
      sendTimeout: config['sendTimeout'] as int?,
      maxRetryCount: config['maxRetryCount'] as int?,
      enableLogging: config['enableLogging'] as bool?,
      enableCache: config['enableCache'] as bool?,
      cacheMaxAge: config['cacheMaxAge'] as int?,
      environment: _convertEnvironment(_currentEnvironment),
    );
  }
  
  /// 转换环境类型
  Environment _convertEnvironment(env.Environment envType) {
    switch (envType) {
      case env.Environment.development:
        return Environment.development;
      case env.Environment.testing:
        return Environment.testing;
      case env.Environment.staging:
        return Environment.staging;
      case env.Environment.production:
        return Environment.production;
    }
  }
  
  /// 设置运行时配置
  void setRuntimeConfig(String key, dynamic value) {
    // 验证配置值
    if (_validators.containsKey(key)) {
      final validator = _validators[key]!;
      if (!validator.validate(value)) {
        throw ArgumentError('配置值验证失败: $key = $value');
      }
    }
    
    final oldValue = _runtimeConfigs[key];
    _runtimeConfigs[key] = value;
    
    // 通知监听器
    _notifyListeners(key, oldValue, value);
    
    // 发送配置变更事件
    _notifyConfigChange(
      ConfigChangeEvent(
        type: ConfigChangeType.runtimeConfigUpdated,
        key: key,
        oldValue: oldValue,
        newValue: value,
      ),
    );
  }
  
  /// 获取运行时配置
  T? getRuntimeConfig<T>(String key, [T? defaultValue]) {
    final value = _runtimeConfigs[key];
    if (value is T) {
      return value;
    }
    return defaultValue;
  }
  
  /// 批量设置运行时配置
  void setRuntimeConfigs(Map<String, dynamic> configs) {
    for (final entry in configs.entries) {
      setRuntimeConfig(entry.key, entry.value);
    }
  }
  
  /// 移除运行时配置
  void removeRuntimeConfig(String key) {
    final oldValue = _runtimeConfigs.remove(key);
    
    if (oldValue != null) {
      // 通知监听器
      _notifyListeners(key, oldValue, null);
      
      // 发送配置变更事件
      _notifyConfigChange(
        ConfigChangeEvent(
          type: ConfigChangeType.runtimeConfigRemoved,
          key: key,
          oldValue: oldValue,
        ),
      );
    }
  }
  
  /// 添加配置监听器
  void addConfigListener(String key, ConfigChangeListener listener) {
    _listeners.putIfAbsent(key, () => []).add(listener);
  }
  
  /// 移除配置监听器
  void removeConfigListener(String key, ConfigChangeListener listener) {
    _listeners[key]?.remove(listener);
    if (_listeners[key]?.isEmpty == true) {
      _listeners.remove(key);
    }
  }
  
  /// 添加配置验证器
  void addConfigValidator(String key, ConfigValidator validator) {
    _validators[key] = validator;
  }
  
  /// 移除配置验证器
  void removeConfigValidator(String key) {
    _validators.remove(key);
  }
  
  /// 从远程加载配置
  Future<void> loadRemoteConfig(String url, {Duration? timeout}) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        url,
        options: Options(
          receiveTimeout: timeout ?? const Duration(seconds: 10),
        ),
      );
      
      if (response.statusCode == 200) {
        final remoteConfig = response.data as Map<String, dynamic>;
        await _processRemoteConfig(remoteConfig);
        // 远程配置加载成功
      }
    } catch (e) {
      // 远程配置加载失败: $e
      rethrow;
    }
  }
  
  /// 处理远程配置
  Future<void> _processRemoteConfig(Map<String, dynamic> remoteConfig) async {
    // 验证远程配置
    if (!_validateRemoteConfig(remoteConfig)) {
      throw ArgumentError('远程配置格式无效');
    }
    
    // 应用远程配置
    for (final entry in remoteConfig.entries) {
      if (entry.key == 'environments') {
        final environments = entry.value as Map<String, dynamic>;
        for (final envEntry in environments.entries) {
          final environment = env.Environment.values.firstWhere(
            (e) => e.name == envEntry.key,
            orElse: () => env.Environment.development,
          );
          setEnvironmentConfig(environment, envEntry.value as Map<String, dynamic>);
        }
      } else {
        setRuntimeConfig(entry.key, entry.value);
      }
    }
  }
  
  /// 验证远程配置
  bool _validateRemoteConfig(Map<String, dynamic> config) {
    // 基本格式验证
    if (config.isEmpty) {
      return false;
    }
    
    // 验证环境配置
    if (config.containsKey('environments')) {
      final environments = config['environments'];
      if (environments is! Map<String, dynamic>) {
        return false;
      }
    }
    
    return true;
  }
  
  /// 导出配置
  Map<String, dynamic> exportConfig() {
    return {
      'currentEnvironment': _currentEnvironment.name,
      'environments': _environmentConfigs.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'runtimeConfigs': Map.from(_runtimeConfigs),
    };
  }
  
  /// 导入配置
  Future<void> importConfig(Map<String, dynamic> config) async {
    try {
      // 导入环境配置
      if (config.containsKey('environments')) {
        final environments = config['environments'] as Map<String, dynamic>;
        for (final entry in environments.entries) {
          final environment = env.Environment.values.firstWhere(
            (e) => e.name == entry.key,
            orElse: () => env.Environment.development,
          );
          setEnvironmentConfig(environment, entry.value as Map<String, dynamic>);
        }
      }
      
      // 导入运行时配置
      if (config.containsKey('runtimeConfigs')) {
        final runtimeConfigs = config['runtimeConfigs'] as Map<String, dynamic>;
        setRuntimeConfigs(runtimeConfigs);
      }
      
      // 切换到指定环境
      if (config.containsKey('currentEnvironment')) {
        final envName = config['currentEnvironment'] as String;
        final environment = env.Environment.values.firstWhere(
          (e) => e.name == envName,
          orElse: () => env.Environment.development,
        );
        await switchEnvironment(environment);
      }
      
      // 配置导入成功
    } catch (e) {
      // 配置导入失败: $e
      rethrow;
    }
  }
  
  /// 重置配置
  void resetConfig() {
    _runtimeConfigs.clear();
    _initializeDefaultConfigs();
    _currentEnvironment = env.Environment.development;
    _applyConfig(currentConfig);
    
    _notifyConfigChange(
      ConfigChangeEvent(
        type: ConfigChangeType.configReset,
      ),
    );
    
    // 配置已重置
  }
  
  /// 验证当前配置
  bool validateCurrentConfig() {
    final config = currentConfig;
    
    // 验证必需字段
    final requiredFields = ['baseUrl', 'connectTimeout', 'receiveTimeout'];
    for (final field in requiredFields) {
      if (!config.containsKey(field) || config[field] == null) {
        return false;
      }
    }
    
    // 验证字段类型和值
    if (config['baseUrl'] is! String || (config['baseUrl'] as String).isEmpty) {
      return false;
    }
    
    if (config['connectTimeout'] is! int || (config['connectTimeout'] as int) <= 0) {
      return false;
    }
    
    if (config['receiveTimeout'] is! int || (config['receiveTimeout'] as int) <= 0) {
      return false;
    }
    
    return true;
  }
  
  /// 获取配置摘要
  Map<String, dynamic> getConfigSummary() {
    return {
      'currentEnvironment': _currentEnvironment.name,
      'environmentConfigCount': _environmentConfigs.length,
      'runtimeConfigCount': _runtimeConfigs.length,
      'listenerCount': _listeners.values.fold(0, (sum, list) => sum + list.length),
      'validatorCount': _validators.length,
      'isValid': validateCurrentConfig(),
    };
  }
  
  /// 通知监听器
  void _notifyListeners(String key, dynamic oldValue, dynamic newValue) {
    final listeners = _listeners[key];
    if (listeners != null) {
      for (final listener in listeners) {
        try {
          listener(key, oldValue, newValue);
        } catch (e) {
          // 配置监听器执行失败: $e
        }
      }
    }
  }
  
  /// 通知配置变更
  void _notifyConfigChange(ConfigChangeEvent event) {
    _eventController.add(event);
  }
  
  /// 销毁管理器
  void dispose() {
    _listeners.clear();
    _validators.clear();
    _eventController.close();
  }
}

/// 配置变更监听器
typedef ConfigChangeListener = void Function(String key, dynamic oldValue, dynamic newValue);

/// 配置验证器
abstract class ConfigValidator {
  bool validate(dynamic value);
}

/// 字符串配置验证器
class StringConfigValidator extends ConfigValidator {
  final int? minLength;
  final int? maxLength;
  final RegExp? pattern;
  
  StringConfigValidator({
    this.minLength,
    this.maxLength,
    this.pattern,
  });
  
  @override
  bool validate(dynamic value) {
    if (value is! String) {
      return false;
    }
    
    if (minLength != null && value.length < minLength!) {
      return false;
    }
    
    if (maxLength != null && value.length > maxLength!) {
      return false;
    }
    
    if (pattern != null && !pattern!.hasMatch(value)) {
      return false;
    }
    
    return true;
  }
}

/// 数字配置验证器
class NumberConfigValidator extends ConfigValidator {
  final num? min;
  final num? max;
  
  NumberConfigValidator({
    this.min,
    this.max,
  });
  
  @override
  bool validate(dynamic value) {
    if (value is! num) {
      return false;
    }
    
    if (min != null && value < min!) {
      return false;
    }
    
    if (max != null && value > max!) {
      return false;
    }
    
    return true;
  }
}

/// 配置变更事件
class ConfigChangeEvent {
  final ConfigChangeType type;
  final String? key;
  final dynamic oldValue;
  final dynamic newValue;
  final env.Environment? environment;
  final env.Environment? oldEnvironment;
  final Map<String, dynamic>? oldConfig;
  final Map<String, dynamic>? newConfig;
  
  const ConfigChangeEvent({
    required this.type,
    this.key,
    this.oldValue,
    this.newValue,
    this.environment,
    this.oldEnvironment,
    this.oldConfig,
    this.newConfig,
  });
}

/// 配置变更类型
enum ConfigChangeType {
  environmentSwitched,
  environmentConfigUpdated,
  runtimeConfigUpdated,
  runtimeConfigRemoved,
  configReset,
}