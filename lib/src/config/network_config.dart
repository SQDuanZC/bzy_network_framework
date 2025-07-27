/// 网络配置管理类
class NetworkConfig {
  static NetworkConfig? _instance;
  
  /// 单例实例
  static NetworkConfig get instance {
    _instance ??= NetworkConfig._internal();
    return _instance!;
  }
  
  NetworkConfig._internal();
  
  /// 基础URL
  String _baseUrl = '';
  String get baseUrl => _baseUrl;
  
  /// 连接超时时间（毫秒）
  int _connectTimeout = 30000;
  int get connectTimeout => _connectTimeout;
  
  /// 接收超时时间（毫秒）
  int _receiveTimeout = 30000;
  int get receiveTimeout => _receiveTimeout;
  
  /// 发送超时时间（毫秒）
  int _sendTimeout = 30000;
  int get sendTimeout => _sendTimeout;
  
  /// 默认请求头
  Map<String, dynamic> _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  Map<String, dynamic> get defaultHeaders => Map.from(_defaultHeaders);
  
  /// 重试配置
  int _maxRetries = 3;
  int get maxRetries => _maxRetries;
  
  /// 重试间隔（毫秒）
  int _retryDelay = 1000;
  int get retryDelay => _retryDelay;
  
  /// 是否启用日志
  bool _enableLogging = true;
  bool get enableLogging => _enableLogging;
  
  /// 日志级别
  LogLevel _logLevel = LogLevel.info;
  LogLevel get logLevel => _logLevel;
  
  /// 缓存配置
  bool _enableCache = true;
  bool get enableCache => _enableCache;
  
  /// 默认缓存时长（秒）
  int _defaultCacheDuration = 300;
  int get defaultCacheDuration => _defaultCacheDuration;
  
  /// 最大缓存大小（MB）
  int _maxCacheSize = 100;
  int get maxCacheSize => _maxCacheSize;
  
  /// 环境配置
  Environment _environment = Environment.development;
  Environment get environment => _environment;
  
  /// 认证token
  String? _authToken;
  String? get authToken => _authToken;
  
  /// 用户代理
  String _userAgent = 'Flutter Network Framework';
  String get userAgent => _userAgent;
  
  /// 初始化配置
  void initialize({
    required String baseUrl,
    int? connectTimeout,
    int? receiveTimeout,
    int? sendTimeout,
    Map<String, dynamic>? defaultHeaders,
    int? maxRetries,
    int? retryDelay,
    bool? enableLogging,
    LogLevel? logLevel,
    bool? enableCache,
    int? defaultCacheDuration,
    int? maxCacheSize,
    Environment? environment,
    String? authToken,
    String? userAgent,
  }) {
    _baseUrl = baseUrl;
    if (connectTimeout != null) _connectTimeout = connectTimeout;
    if (receiveTimeout != null) _receiveTimeout = receiveTimeout;
    if (sendTimeout != null) _sendTimeout = sendTimeout;
    if (defaultHeaders != null) {
      _defaultHeaders = {..._defaultHeaders, ...defaultHeaders};
    }
    if (maxRetries != null) _maxRetries = maxRetries;
    if (retryDelay != null) _retryDelay = retryDelay;
    if (enableLogging != null) _enableLogging = enableLogging;
    if (logLevel != null) _logLevel = logLevel;
    if (enableCache != null) _enableCache = enableCache;
    if (defaultCacheDuration != null) _defaultCacheDuration = defaultCacheDuration;
    if (maxCacheSize != null) _maxCacheSize = maxCacheSize;
    if (environment != null) _environment = environment;
    if (authToken != null) _authToken = authToken;
    if (userAgent != null) _userAgent = userAgent;
  }
  
  /// 更新基础URL
  void updateBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
  }
  
  /// 设置认证token
  void setAuthToken(String? token) {
    _authToken = token;
    if (token != null) {
      _defaultHeaders['Authorization'] = 'Bearer $token';
    } else {
      _defaultHeaders.remove('Authorization');
    }
  }
  
  /// 添加默认请求头
  void addDefaultHeader(String key, String value) {
    _defaultHeaders[key] = value;
  }
  
  /// 移除默认请求头
  void removeDefaultHeader(String key) {
    _defaultHeaders.remove(key);
  }
  
  /// 更新超时配置
  void updateTimeouts({
    int? connectTimeout,
    int? receiveTimeout,
    int? sendTimeout,
  }) {
    if (connectTimeout != null) _connectTimeout = connectTimeout;
    if (receiveTimeout != null) _receiveTimeout = receiveTimeout;
    if (sendTimeout != null) _sendTimeout = sendTimeout;
  }
  
  /// 更新重试配置
  void updateRetryConfig({
    int? maxRetries,
    int? retryDelay,
  }) {
    if (maxRetries != null) _maxRetries = maxRetries;
    if (retryDelay != null) _retryDelay = retryDelay;
  }
  
  /// 更新缓存配置
  void updateCacheConfig({
    bool? enableCache,
    int? defaultCacheDuration,
    int? maxCacheSize,
  }) {
    if (enableCache != null) _enableCache = enableCache;
    if (defaultCacheDuration != null) _defaultCacheDuration = defaultCacheDuration;
    if (maxCacheSize != null) _maxCacheSize = maxCacheSize;
  }
  
  /// 更新日志配置
  void updateLogConfig({
    bool? enableLogging,
    LogLevel? logLevel,
  }) {
    if (enableLogging != null) _enableLogging = enableLogging;
    if (logLevel != null) _logLevel = logLevel;
  }
  
  /// 设置环境
  void setEnvironment(Environment environment) {
    _environment = environment;
  }
  
  /// 重置为默认配置
  void reset() {
    _baseUrl = '';
    _connectTimeout = 30000;
    _receiveTimeout = 30000;
    _sendTimeout = 30000;
    _defaultHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    _maxRetries = 3;
    _retryDelay = 1000;
    _enableLogging = true;
    _logLevel = LogLevel.info;
    _enableCache = true;
    _defaultCacheDuration = 300;
    _maxCacheSize = 100;
    _environment = Environment.development;
    _authToken = null;
    _userAgent = 'Flutter Network Framework';
  }
  
  /// 获取完整的配置信息
  Map<String, dynamic> toMap() {
    return {
      'baseUrl': _baseUrl,
      'connectTimeout': _connectTimeout,
      'receiveTimeout': _receiveTimeout,
      'sendTimeout': _sendTimeout,
      'defaultHeaders': _defaultHeaders,
      'maxRetries': _maxRetries,
      'retryDelay': _retryDelay,
      'enableLogging': _enableLogging,
      'logLevel': _logLevel.name,
      'enableCache': _enableCache,
      'defaultCacheDuration': _defaultCacheDuration,
      'maxCacheSize': _maxCacheSize,
      'environment': _environment.name,
      'authToken': _authToken,
      'userAgent': _userAgent,
    };
  }
  
  @override
  String toString() {
    return 'NetworkConfig{'
        'baseUrl: $_baseUrl, '
        'environment: ${_environment.name}, '
        'enableLogging: $_enableLogging, '
        'enableCache: $_enableCache'
        '}';
  }
}

/// 日志级别枚举
enum LogLevel {
  none,
  error,
  warning,
  info,
  debug,
  verbose,
}

/// 环境枚举
enum Environment {
  development,
  testing,
  staging,
  production,
}

/// 网络配置预设
class NetworkConfigPresets {
  /// 开发环境配置
  static Map<String, dynamic> development = {
    'connectTimeout': 30000,
    'receiveTimeout': 30000,
    'sendTimeout': 30000,
    'maxRetries': 3,
    'retryDelay': 1000,
    'enableLogging': true,
    'logLevel': LogLevel.debug,
    'enableCache': true,
    'defaultCacheDuration': 300,
    'environment': Environment.development,
  };
  
  /// 生产环境配置
  static Map<String, dynamic> production = {
    'connectTimeout': 15000,
    'receiveTimeout': 15000,
    'sendTimeout': 15000,
    'maxRetries': 2,
    'retryDelay': 2000,
    'enableLogging': false,
    'logLevel': LogLevel.error,
    'enableCache': true,
    'defaultCacheDuration': 600,
    'environment': Environment.production,
  };
  
  /// 测试环境配置
  static Map<String, dynamic> testing = {
    'connectTimeout': 10000,
    'receiveTimeout': 10000,
    'sendTimeout': 10000,
    'maxRetries': 1,
    'retryDelay': 500,
    'enableLogging': true,
    'logLevel': LogLevel.info,
    'enableCache': false,
    'defaultCacheDuration': 0,
    'environment': Environment.testing,
  };
}