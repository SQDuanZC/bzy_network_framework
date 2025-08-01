/// 环境配置类
/// 使用属性替代硬编码的Map配置，提供类型安全和单个属性更改支持
class EnvironmentConfig {
  String baseUrl;
  int connectTimeout;
  int receiveTimeout;
  int sendTimeout;
  int maxRetryCount;
  bool enableLogging;
  bool enableCache;
  int cacheMaxAge;
  bool enableExponentialBackoff;
  
  EnvironmentConfig({
    required this.baseUrl,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.sendTimeout,
    required this.maxRetryCount,
    required this.enableLogging,
    required this.enableCache,
    required this.cacheMaxAge,
    required this.enableExponentialBackoff,
  });
  
  /// 从Map创建配置
  factory EnvironmentConfig.fromMap(Map<String, dynamic> map) {
    return EnvironmentConfig(
      baseUrl: map['baseUrl'] as String,
      connectTimeout: map['connectTimeout'] as int,
      receiveTimeout: map['receiveTimeout'] as int,
      sendTimeout: map['sendTimeout'] as int,
      maxRetryCount: map['maxRetryCount'] as int,
      enableLogging: map['enableLogging'] as bool,
      enableCache: map['enableCache'] as bool,
      cacheMaxAge: map['cacheMaxAge'] as int,
      enableExponentialBackoff: map['enableExponentialBackoff'] as bool,
    );
  }
  
  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'baseUrl': baseUrl,
      'connectTimeout': connectTimeout,
      'receiveTimeout': receiveTimeout,
      'sendTimeout': sendTimeout,
      'maxRetryCount': maxRetryCount,
      'enableLogging': enableLogging,
      'enableCache': enableCache,
      'cacheMaxAge': cacheMaxAge,
      'enableExponentialBackoff': enableExponentialBackoff,
    };
  }
  
  /// 复制配置并允许修改特定属性
  EnvironmentConfig copyWith({
    String? baseUrl,
    int? connectTimeout,
    int? receiveTimeout,
    int? sendTimeout,
    int? maxRetryCount,
    bool? enableLogging,
    bool? enableCache,
    int? cacheMaxAge,
    bool? enableExponentialBackoff,
  }) {
    return EnvironmentConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      sendTimeout: sendTimeout ?? this.sendTimeout,
      maxRetryCount: maxRetryCount ?? this.maxRetryCount,
      enableLogging: enableLogging ?? this.enableLogging,
      enableCache: enableCache ?? this.enableCache,
      cacheMaxAge: cacheMaxAge ?? this.cacheMaxAge,
      enableExponentialBackoff: enableExponentialBackoff ?? this.enableExponentialBackoff,
    );
  }
  
  /// 更新单个属性
  void updateProperty(String propertyName, dynamic value) {
    switch (propertyName) {
      case 'baseUrl':
        if (value is String) baseUrl = value;
        break;
      case 'connectTimeout':
        if (value is int) connectTimeout = value;
        break;
      case 'receiveTimeout':
        if (value is int) receiveTimeout = value;
        break;
      case 'sendTimeout':
        if (value is int) sendTimeout = value;
        break;
      case 'maxRetryCount':
        if (value is int) maxRetryCount = value;
        break;
      case 'enableLogging':
        if (value is bool) enableLogging = value;
        break;
      case 'enableCache':
        if (value is bool) enableCache = value;
        break;
      case 'cacheMaxAge':
        if (value is int) cacheMaxAge = value;
        break;
      case 'enableExponentialBackoff':
        if (value is bool) enableExponentialBackoff = value;
        break;
      default:
        throw ArgumentError('Unknown property: $propertyName');
    }
  }
  
  /// 获取属性值
  dynamic getProperty(String propertyName) {
    switch (propertyName) {
      case 'baseUrl':
        return baseUrl;
      case 'connectTimeout':
        return connectTimeout;
      case 'receiveTimeout':
        return receiveTimeout;
      case 'sendTimeout':
        return sendTimeout;
      case 'maxRetryCount':
        return maxRetryCount;
      case 'enableLogging':
        return enableLogging;
      case 'enableCache':
        return enableCache;
      case 'cacheMaxAge':
        return cacheMaxAge;
      case 'enableExponentialBackoff':
        return enableExponentialBackoff;
      default:
        throw ArgumentError('Unknown property: $propertyName');
    }
  }
  
  /// 获取所有属性名称
  static List<String> get propertyNames => [
    'baseUrl',
    'connectTimeout',
    'receiveTimeout',
    'sendTimeout',
    'maxRetryCount',
    'enableLogging',
    'enableCache',
    'cacheMaxAge',
    'enableExponentialBackoff',
  ];
  
  /// 获取所有属性名称
  List<String> getAllPropertyNames() {
    return [
      'baseUrl',
      'connectTimeout', 
      'receiveTimeout',
      'sendTimeout',
      'maxRetryCount',
      'enableLogging',
      'enableCache',
      'cacheMaxAge',
      'enableExponentialBackoff',
    ];
  }
  
  @override
  String toString() {
    return 'EnvironmentConfig{'
        'baseUrl: $baseUrl, '
        'connectTimeout: $connectTimeout, '
        'receiveTimeout: $receiveTimeout, '
        'sendTimeout: $sendTimeout, '
        'maxRetryCount: $maxRetryCount, '
        'enableLogging: $enableLogging, '
        'enableCache: $enableCache, '
        'cacheMaxAge: $cacheMaxAge, '
        'enableExponentialBackoff: $enableExponentialBackoff'
        '}';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnvironmentConfig &&
        other.baseUrl == baseUrl &&
        other.connectTimeout == connectTimeout &&
        other.receiveTimeout == receiveTimeout &&
        other.sendTimeout == sendTimeout &&
        other.maxRetryCount == maxRetryCount &&
        other.enableLogging == enableLogging &&
        other.enableCache == enableCache &&
        other.cacheMaxAge == cacheMaxAge &&
        other.enableExponentialBackoff == enableExponentialBackoff;
  }
  
  @override
  int get hashCode {
    return Object.hash(
      baseUrl,
      connectTimeout,
      receiveTimeout,
      sendTimeout,
      maxRetryCount,
      enableLogging,
      enableCache,
      cacheMaxAge,
      enableExponentialBackoff,
    );
  }
}

/// 预定义的环境配置
class EnvironmentConfigPresets {
  /// 开发环境配置
  static EnvironmentConfig get development => EnvironmentConfig(
    baseUrl: 'https://dev-api.example.com',
    connectTimeout: 15000,
    receiveTimeout: 30000,
    sendTimeout: 30000,
    maxRetryCount: 2,
    enableLogging: true,
    enableCache: true,
    cacheMaxAge: 300, // 5分钟
    enableExponentialBackoff: true,
  );
  
  /// 测试环境配置
  static EnvironmentConfig get testing => EnvironmentConfig(
    baseUrl: 'https://test-api.example.com',
    connectTimeout: 15000,
    receiveTimeout: 30000,
    sendTimeout: 30000,
    maxRetryCount: 2,
    enableLogging: true,
    enableCache: false,
    cacheMaxAge: 0,
    enableExponentialBackoff: false,
  );
  
  /// 预发布环境配置
  static EnvironmentConfig get staging => EnvironmentConfig(
    baseUrl: 'https://staging-api.example.com',
    connectTimeout: 15000,
    receiveTimeout: 30000,
    sendTimeout: 30000,
    maxRetryCount: 3,
    enableLogging: true,
    enableCache: true,
    cacheMaxAge: 600, // 10分钟
    enableExponentialBackoff: true,
  );
  
  /// 生产环境配置
  static EnvironmentConfig get production => EnvironmentConfig(
    baseUrl: 'https://api.example.com',
    connectTimeout: 15000,
    receiveTimeout: 30000,
    sendTimeout: 30000,
    maxRetryCount: 3,
    enableLogging: false,
    enableCache: true,
    cacheMaxAge: 900, // 15分钟
    enableExponentialBackoff: true,
  );
}