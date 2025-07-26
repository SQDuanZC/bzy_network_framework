import 'dart:async';
import 'package:dio/dio.dart';
import 'network_config.dart';

/// 热更新配置管理器
/// 支持动态配置更新、配置监听、配置验证等功能
class HotConfigManager {
  static HotConfigManager? _instance;
  
  // 配置更新流控制器
  final StreamController<NetworkConfigUpdate> _configUpdateController = 
      StreamController<NetworkConfigUpdate>.broadcast();
  
  // 配置监听器
  final Map<String, List<ConfigListener>> _listeners = {};
  
  // 配置缓存
  final Map<String, dynamic> _configCache = {};
  
  // 配置版本
  int _configVersion = 1;
  
  // 配置更新间隔
  Duration _updateInterval = const Duration(minutes: 5);
  
  // 定时器
  Timer? _updateTimer;
  
  // 配置源URL
  String? _configSourceUrl;
  
  // 私有构造函数
  HotConfigManager._();
  
  /// 获取单例实例
  static HotConfigManager get instance {
    _instance ??= HotConfigManager._();
    return _instance!;
  }
  
  /// 配置更新流
  Stream<NetworkConfigUpdate> get configUpdateStream => _configUpdateController.stream;
  
  /// 初始化热更新配置
  void initialize({
    String? configSourceUrl,
    Duration? updateInterval,
    bool autoUpdate = true,
  }) {
    _configSourceUrl = configSourceUrl;
    if (updateInterval != null) {
      _updateInterval = updateInterval;
    }
    
    if (autoUpdate && _configSourceUrl != null) {
      startAutoUpdate();
    }
    
    // 热更新配置管理器已初始化
  }
  
  /// 开始自动更新
  void startAutoUpdate() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(_updateInterval, (timer) {
      _fetchAndUpdateConfig();
    });
    // 开始自动配置更新，间隔: ${_updateInterval.inMinutes}分钟
  }
  
  /// 停止自动更新
  void stopAutoUpdate() {
    if (_updateTimer?.isActive == true) {
      _updateTimer?.cancel();
    }
    _updateTimer = null;
    // 停止自动配置更新
  }
  
  /// 手动更新配置
  Future<bool> updateConfig() async {
    return await _fetchAndUpdateConfig();
  }
  
  /// 获取并更新配置
  Future<bool> _fetchAndUpdateConfig() async {
    if (_configSourceUrl == null) {
      // 配置源URL未设置
      return false;
    }
    
    try {
      final dio = Dio();
      final response = await dio.get(_configSourceUrl!);
      
      if (response.statusCode == 200) {
        final configData = response.data;
        return await _processConfigUpdate(configData);
      }
    } catch (e) {
      // 获取配置失败: $e
    }
    
    return false;
  }
  
  /// 处理配置更新
  Future<bool> _processConfigUpdate(Map<String, dynamic> configData) async {
    try {
      // 验证配置
      if (!_validateConfig(configData)) {
        // 配置验证失败
        return false;
      }
      
      // 检查版本
      final newVersion = configData['version'] ?? _configVersion;
      if (newVersion <= _configVersion) {
        // 配置版本未更新: $newVersion
        return false;
      }
      
      // 备份当前配置
      final oldConfig = _getCurrentConfig();
      
      // 应用新配置
      final success = await _applyConfig(configData);
      
      if (success) {
        _configVersion = newVersion;
        _configCache.addAll(configData);
        
        // 通知配置更新
        final update = NetworkConfigUpdate(
          oldConfig: oldConfig,
          newConfig: configData,
          version: newVersion,
          timestamp: DateTime.now(),
        );
        
        _configUpdateController.add(update);
        _notifyListeners(update);
        
        // 配置更新成功，版本: $newVersion
        return true;
      } else {
        // 配置应用失败
        return false;
      }
    } catch (e) {
      // 处理配置更新失败: $e
      return false;
    }
  }
  
  /// 验证配置
  bool _validateConfig(Map<String, dynamic> config) {
    // 检查必要字段
    final requiredFields = ['baseUrl', 'connectTimeout', 'receiveTimeout'];
    for (final field in requiredFields) {
      if (!config.containsKey(field)) {
        // 缺少必要配置字段: $field
        return false;
      }
    }
    
    // 验证URL格式
    final baseUrl = config['baseUrl'];
    if (baseUrl is String && (Uri.tryParse(baseUrl)?.hasAbsolutePath != true)) {
      // 无效的baseUrl: $baseUrl
      return false;
    }
    
    // 验证超时时间
    final timeouts = ['connectTimeout', 'receiveTimeout', 'sendTimeout'];
    for (final timeout in timeouts) {
      final value = config[timeout];
      if (value != null && (value is! int || value <= 0)) {
        // 无效的超时配置: $timeout = $value
        return false;
      }
    }
    
    return true;
  }
  
  /// 应用配置
  Future<bool> _applyConfig(Map<String, dynamic> config) async {
    try {
      final networkConfig = NetworkConfig.instance;
      
      // 应用网络配置
      networkConfig.configure(
        baseUrl: config['baseUrl'],
        connectTimeout: config['connectTimeout'],
        receiveTimeout: config['receiveTimeout'],
        sendTimeout: config['sendTimeout'],
        maxRetryCount: config['maxRetryCount'],
        retryDelay: config['retryDelay'],
        enableLogging: config['enableLogging'],
        environment: _parseEnvironment(config['environment']),
      );
      
      return true;
    } catch (e) {
      // 应用配置失败: $e
      return false;
    }
  }
  
  /// 解析环境配置
  Environment? _parseEnvironment(dynamic env) {
    if (env is String) {
      switch (env.toLowerCase()) {
        case 'development':
          return Environment.development;
        case 'staging':
          return Environment.staging;
        case 'production':
          return Environment.production;
      }
    }
    return null;
  }
  
  /// 获取当前配置
  Map<String, dynamic> _getCurrentConfig() {
    final config = NetworkConfig.instance;
    return {
      'baseUrl': config.baseUrl,
      'connectTimeout': config.connectTimeout,
      'receiveTimeout': config.receiveTimeout,
      'sendTimeout': config.sendTimeout,
      'maxRetryCount': config.maxRetryCount,
      'retryDelay': config.retryDelay,
      'enableLogging': config.enableLogging,
      'environment': config.environment.toString(),
      'version': _configVersion,
    };
  }
  
  /// 添加配置监听器
  void addConfigListener(String key, ConfigListener listener) {
    _listeners[key] ??= [];
    _listeners[key]!.add(listener);
  }
  
  /// 移除配置监听器
  void removeConfigListener(String key, ConfigListener listener) {
    _listeners[key]?.remove(listener);
    if (_listeners[key]?.isEmpty == true) {
      _listeners.remove(key);
    }
  }
  
  /// 通知监听器
  void _notifyListeners(NetworkConfigUpdate update) {
    for (final listeners in _listeners.values) {
      for (final listener in listeners) {
        try {
          listener(update);
        } catch (e) {
          // 配置监听器执行失败: $e
        }
      }
    }
  }
  
  /// 设置配置值
  void setConfig(String key, dynamic value) {
    _configCache[key] = value;
  }
  
  /// 获取配置值
  T? getConfig<T>(String key, [T? defaultValue]) {
    final value = _configCache[key];
    if (value is T) {
      return value;
    }
    return defaultValue;
  }
  
  /// 获取配置版本
  int get configVersion => _configVersion;
  
  /// 销毁管理器
  void dispose() {
    _updateTimer?.cancel();
    _configUpdateController.close();
    _listeners.clear();
    _configCache.clear();
  }
}

/// 配置更新事件
class NetworkConfigUpdate {
  final Map<String, dynamic> oldConfig;
  final Map<String, dynamic> newConfig;
  final int version;
  final DateTime timestamp;
  
  const NetworkConfigUpdate({
    required this.oldConfig,
    required this.newConfig,
    required this.version,
    required this.timestamp,
  });
  
  /// 获取变更的配置项
  Map<String, ConfigChange> getChanges() {
    final changes = <String, ConfigChange>{};
    
    // 检查新增和修改的配置
    for (final entry in newConfig.entries) {
      final key = entry.key;
      final newValue = entry.value;
      final oldValue = oldConfig[key];
      
      if (oldValue != newValue) {
        changes[key] = ConfigChange(
          key: key,
          oldValue: oldValue,
          newValue: newValue,
          changeType: oldValue == null ? ChangeType.added : ChangeType.modified,
        );
      }
    }
    
    // 检查删除的配置
    for (final key in oldConfig.keys) {
      if (!newConfig.containsKey(key)) {
        changes[key] = ConfigChange(
          key: key,
          oldValue: oldConfig[key],
          newValue: null,
          changeType: ChangeType.removed,
        );
      }
    }
    
    return changes;
  }
  
  @override
  String toString() {
    return 'NetworkConfigUpdate{version: $version, timestamp: $timestamp, changes: ${getChanges().length}}';
  }
}

/// 配置变更
class ConfigChange {
  final String key;
  final dynamic oldValue;
  final dynamic newValue;
  final ChangeType changeType;
  
  const ConfigChange({
    required this.key,
    required this.oldValue,
    required this.newValue,
    required this.changeType,
  });
  
  @override
  String toString() {
    return 'ConfigChange{key: $key, type: $changeType, old: $oldValue, new: $newValue}';
  }
}

/// 变更类型
enum ChangeType {
  added,
  modified,
  removed,
}

/// 配置监听器类型定义
typedef ConfigListener = void Function(NetworkConfigUpdate update);