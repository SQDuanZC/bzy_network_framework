/// Network configuration management class
class NetworkConfig {
  static NetworkConfig? _instance;
  
  /// Singleton instance
  static NetworkConfig get instance {
    _instance ??= NetworkConfig._internal();
    return _instance!;
  }
  
  NetworkConfig._internal();
  
  /// Base URL
  String _baseUrl = '';
  String get baseUrl => _baseUrl;
  
  /// Connection timeout (milliseconds)
  int _connectTimeout = 30000;
  int get connectTimeout => _connectTimeout;
  
  /// Receive timeout (milliseconds)
  int _receiveTimeout = 30000;
  int get receiveTimeout => _receiveTimeout;
  
  /// Send timeout (milliseconds)
  int _sendTimeout = 30000;
  int get sendTimeout => _sendTimeout;
  
  /// Default request headers
  Map<String, dynamic> _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  Map<String, dynamic> get defaultHeaders => Map.from(_defaultHeaders);
  
  /// Retry configuration
  int _maxRetries = 3;
  int get maxRetries => _maxRetries;
  
  /// Retry delay (milliseconds)
  int _retryDelay = 1000;
  int get retryDelay => _retryDelay;
  
  /// Whether to enable logging
  bool _enableLogging = true;
  bool get enableLogging => _enableLogging;
  
  /// Log level
  LogLevel _logLevel = LogLevel.info;
  LogLevel get logLevel => _logLevel;
  
  /// Cache configuration
  bool _enableCache = true;
  bool get enableCache => _enableCache;
  
  /// Default cache duration (seconds)
  int _defaultCacheDuration = 300;
  int get defaultCacheDuration => _defaultCacheDuration;
  
  /// Maximum cache size (MB)
  int _maxCacheSize = 100;
  int get maxCacheSize => _maxCacheSize;
  
  /// Environment configuration
  Environment _environment = Environment.development;
  Environment get environment => _environment;
  
  /// Authentication token
  String? _authToken;
  String? get authToken => _authToken;
  
  /// User agent
  String _userAgent = 'Flutter Network Framework';
  String get userAgent => _userAgent;
  
  /// Initialize configuration
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
  
  /// Update base URL
  void updateBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
  }
  
  /// Set authentication token
  void setAuthToken(String? token) {
    _authToken = token;
    if (token != null) {
      _defaultHeaders['Authorization'] = 'Bearer $token';
    } else {
      _defaultHeaders.remove('Authorization');
    }
  }
  
  /// Add default request header
  void addDefaultHeader(String key, String value) {
    _defaultHeaders[key] = value;
  }
  
  /// Remove default request header
  void removeDefaultHeader(String key) {
    _defaultHeaders.remove(key);
  }
  
  /// Update timeout configuration
  void updateTimeouts({
    int? connectTimeout,
    int? receiveTimeout,
    int? sendTimeout,
  }) {
    if (connectTimeout != null) _connectTimeout = connectTimeout;
    if (receiveTimeout != null) _receiveTimeout = receiveTimeout;
    if (sendTimeout != null) _sendTimeout = sendTimeout;
  }
  
  /// Update retry configuration
  void updateRetryConfig({
    int? maxRetries,
    int? retryDelay,
  }) {
    if (maxRetries != null) _maxRetries = maxRetries;
    if (retryDelay != null) _retryDelay = retryDelay;
  }
  
  /// Update cache configuration
  void updateCacheConfig({
    bool? enableCache,
    int? defaultCacheDuration,
    int? maxCacheSize,
  }) {
    if (enableCache != null) _enableCache = enableCache;
    if (defaultCacheDuration != null) _defaultCacheDuration = defaultCacheDuration;
    if (maxCacheSize != null) _maxCacheSize = maxCacheSize;
  }
  
  /// Update log configuration
  void updateLogConfig({
    bool? enableLogging,
    LogLevel? logLevel,
  }) {
    if (enableLogging != null) _enableLogging = enableLogging;
    if (logLevel != null) _logLevel = logLevel;
  }
  
  /// Set environment
  void setEnvironment(Environment environment) {
    _environment = environment;
  }
  
  /// Reset to default configuration
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
  
  /// Get complete configuration information
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

/// Log level enumeration
enum LogLevel {
  none,
  error,
  warning,
  info,
  debug,
  verbose,
}

/// Environment enumeration
enum Environment {
  development,
  testing,
  staging,
  production,
}

/// Network configuration presets
class NetworkConfigPresets {
  /// Development environment configuration
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
  
  /// Production environment configuration
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
  
  /// Testing environment configuration
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