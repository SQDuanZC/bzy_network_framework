/// Network configuration presets enumeration
enum NetworkConfigPreset {
  development('development'),
  production('production'),
  testing('testing'),
  staging('staging'),
  fastResponse('fast_response'),
  heavyLoad('heavy_load'),
  offlineFirst('offline_first'),
  lowBandwidth('low_bandwidth');
  
  const NetworkConfigPreset(this.value);
  
  /// The string value of the preset
  final String value;
  
  /// Get preset by string value
  static NetworkConfigPreset? fromString(String value) {
    for (NetworkConfigPreset preset in NetworkConfigPreset.values) {
      if (preset.value.toLowerCase() == value.toLowerCase() ||
          preset.value.replaceAll('_', '').toLowerCase() == value.replaceAll('_', '').toLowerCase()) {
        return preset;
      }
    }
    return null;
  }
  
  /// Get configuration map for this preset (without baseUrl)
  Map<String, dynamic>? getConfig() {
    // Note: baseUrl should be provided separately to avoid hardcoding
    switch (value) {
      case 'development':
        return {
          'connectTimeout': 15000,
          'receiveTimeout': 30000,
          'sendTimeout': 30000,
          'maxRetries': 3,
          'retryDelay': 1000,
          'enableLogging': true,
          'logLevel': LogLevel.debug,
          'enableCache': true,
          'defaultCacheDuration': 300,
          'maxCacheSize': 100,
          'environment': Environment.development,
          'enableExponentialBackoff': true,
        };
      case 'production':
        return {
          'connectTimeout': 15000,
          'receiveTimeout': 30000,
          'sendTimeout': 30000,
          'maxRetries': 3,
          'retryDelay': 1000,
          'enableLogging': false,
          'logLevel': LogLevel.error,
          'enableCache': true,
          'defaultCacheDuration': 900,
          'maxCacheSize': 100,
          'environment': Environment.production,
          'enableExponentialBackoff': true,
        };
      case 'testing':
        return {
          'connectTimeout': 10000,
          'receiveTimeout': 20000,
          'sendTimeout': 20000,
          'maxRetries': 2,
          'retryDelay': 500,
          'enableLogging': true,
          'logLevel': LogLevel.info,
          'enableCache': false,
          'defaultCacheDuration': 0,
          'maxCacheSize': 0,
          'environment': Environment.testing,
          'enableExponentialBackoff': false,
        };
      case 'staging':
        return {
          'connectTimeout': 15000,
          'receiveTimeout': 30000,
          'sendTimeout': 30000,
          'maxRetries': 3,
          'retryDelay': 1000,
          'enableLogging': true,
          'logLevel': LogLevel.warning,
          'enableCache': true,
          'defaultCacheDuration': 600,
          'maxCacheSize': 100,
          'environment': Environment.staging,
          'enableExponentialBackoff': true,
        };
      case 'fast_response':
        return {
          'connectTimeout': 5000,
          'receiveTimeout': 10000,
          'sendTimeout': 10000,
          'maxRetries': 1,
          'retryDelay': 200,
          'enableLogging': false,
          'logLevel': LogLevel.error,
          'enableCache': false,
          'defaultCacheDuration': 0,
          'maxCacheSize': 0,
          'environment': Environment.development,
          'enableExponentialBackoff': false,
        };
      case 'heavy_load':
        return {
          'connectTimeout': 30000,
          'receiveTimeout': 120000,
          'sendTimeout': 120000,
          'maxRetries': 5,
          'retryDelay': 2000,
          'enableLogging': true,
          'logLevel': LogLevel.info,
          'enableCache': false,
          'defaultCacheDuration': 0,
          'maxCacheSize': 0,
          'environment': Environment.production,
          'enableExponentialBackoff': true,
        };
      case 'offline_first':
        return {
          'connectTimeout': 15000,
          'receiveTimeout': 30000,
          'sendTimeout': 30000,
          'maxRetries': 3,
          'retryDelay': 1000,
          'enableLogging': true,
          'logLevel': LogLevel.info,
          'enableCache': true,
          'defaultCacheDuration': 3600,
          'maxCacheSize': 500,
          'environment': Environment.development,
          'enableExponentialBackoff': true,
        };
      case 'low_bandwidth':
        return {
          'connectTimeout': 20000,
          'receiveTimeout': 60000,
          'sendTimeout': 60000,
          'maxRetries': 5,
          'retryDelay': 3000,
          'enableLogging': true,
          'logLevel': LogLevel.warning,
          'enableCache': true,
          'defaultCacheDuration': 1800,
          'maxCacheSize': 100,
          'environment': Environment.production,
          'enableExponentialBackoff': true,
        };
      default:
        return null;
    }
  }
}

/// Network configuration class
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
  int _connectTimeout = 15000;
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
  
  /// Enable exponential backoff for retries
  bool _enableExponentialBackoff = true;
  bool get enableExponentialBackoff => _enableExponentialBackoff;
  
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
    bool? enableExponentialBackoff,
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
    if (enableExponentialBackoff != null) _enableExponentialBackoff = enableExponentialBackoff;
  }
  
  /// Initialize from preset configuration
  void initializeFromPreset(String presetName, {String? baseUrl}) {
    final preset = NetworkConfigPresets.getUnifiedPreset(presetName);
    if (preset == null) {
      throw ArgumentError('Unknown preset: $presetName');
    }
    
    initialize(
      baseUrl: baseUrl ?? _baseUrl,
      connectTimeout: preset['connectTimeout'],
      receiveTimeout: preset['receiveTimeout'],
      sendTimeout: preset['sendTimeout'],
      maxRetries: preset['maxRetries'],
      retryDelay: preset['retryDelay'],
      enableLogging: preset['enableLogging'],
      logLevel: preset['logLevel'],
      enableCache: preset['enableCache'],
      defaultCacheDuration: preset['defaultCacheDuration'],
      maxCacheSize: preset['maxCacheSize'],
      environment: preset['environment'],
      enableExponentialBackoff: preset['enableExponentialBackoff'],
    );
    
    // Validate configuration after initialization
    validateConfig();
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
  
  /// Validate configuration values
  void validateConfig() {
    if (_connectTimeout <= 0) {
      throw ArgumentError('connectTimeout must be positive');
    }
    if (_receiveTimeout <= 0) {
      throw ArgumentError('receiveTimeout must be positive');
    }
    if (_sendTimeout <= 0) {
      throw ArgumentError('sendTimeout must be positive');
    }
    if (_maxRetries < 0) {
      throw ArgumentError('maxRetries must be non-negative');
    }
    if (_retryDelay < 0) {
      throw ArgumentError('retryDelay must be non-negative');
    }
    if (_defaultCacheDuration < 0) {
      throw ArgumentError('defaultCacheDuration must be non-negative');
    }
    if (_maxCacheSize < 0) {
      throw ArgumentError('maxCacheSize must be non-negative');
    }
  }
  
  /// Set environment
  void setEnvironment(Environment environment) {
    _environment = environment;
  }
  
  /// Update exponential backoff setting
  void updateExponentialBackoff(bool enable) {
    _enableExponentialBackoff = enable;
  }
  
  /// Calculate retry delay with exponential backoff
  int calculateRetryDelay(int attemptNumber) {
    if (!_enableExponentialBackoff) {
      return _retryDelay;
    }
    // Exponential backoff: delay * (2^attemptNumber)
    return (_retryDelay * (1 << attemptNumber)).clamp(1000, 30000);
  }
  
  /// Reset to default configuration
  void reset() {
    _baseUrl = '';
    _connectTimeout = 15000;
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
    _enableExponentialBackoff = true;
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
      'enableExponentialBackoff': _enableExponentialBackoff,
    };
  }
  
  @override
  String toString() {
    return 'NetworkConfig{'
        'baseUrl: $_baseUrl, '
        'environment: ${_environment.name}, '
        'enableLogging: $_enableLogging, '
        'enableCache: $_enableCache,'
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
  static const Map<String, dynamic> development = {
    'connectTimeout': 15000,
    'receiveTimeout': 30000,
    'sendTimeout': 30000,
    'maxRetries': 3,
    'retryDelay': 1000,
    'enableLogging': true,
    'logLevel': LogLevel.debug,
    'enableCache': true,
    'defaultCacheDuration': 300, // 5 minutes
    'environment': Environment.development,
    'enableExponentialBackoff': true,
  };
  
  /// Production environment configuration
  static const Map<String, dynamic> production = {
    'connectTimeout': 15000,
    'receiveTimeout': 30000,
    'sendTimeout': 30000,
    'maxRetries': 3,
    'retryDelay': 1000,
    'enableLogging': false,
    'logLevel': LogLevel.error,
    'enableCache': true,
    'defaultCacheDuration': 900, // 15 minutes
    'environment': Environment.production,
    'enableExponentialBackoff': true,
  };
  
  /// Testing environment configuration
  static const Map<String, dynamic> testing = {
    'connectTimeout': 10000,
    'receiveTimeout': 20000,
    'sendTimeout': 20000,
    'maxRetries': 2,
    'retryDelay': 500,
    'enableLogging': true,
    'logLevel': LogLevel.info,
    'enableCache': false,
    'defaultCacheDuration': 0,
    'environment': Environment.testing,
    'enableExponentialBackoff': false,
  };
  
  /// Staging environment configuration
  static const Map<String, dynamic> staging = {
    'connectTimeout': 15000,
    'receiveTimeout': 30000,
    'sendTimeout': 30000,
    'maxRetries': 3,
    'retryDelay': 1000,
    'enableLogging': true,
    'logLevel': LogLevel.warning,
    'enableCache': true,
    'defaultCacheDuration': 600, // 10 minutes
    'environment': Environment.staging,
    'enableExponentialBackoff': true,
  };
  
  /// Fast response configuration (for real-time scenarios)
  static const Map<String, dynamic> fastResponse = {
    'connectTimeout': 5000,
    'receiveTimeout': 10000,
    'sendTimeout': 10000,
    'maxRetries': 1,
    'retryDelay': 200,
    'enableLogging': false,
    'logLevel': LogLevel.error,
    'enableCache': false,
    'defaultCacheDuration': 0,
    'environment': Environment.development,
    'enableExponentialBackoff': false,
  };
  
  /// Heavy load configuration (for large file transfers)
  static const Map<String, dynamic> heavyLoad = {
    'connectTimeout': 30000,
    'receiveTimeout': 120000, // 2 minutes
    'sendTimeout': 120000, // 2 minutes
    'maxRetries': 5,
    'retryDelay': 2000,
    'enableLogging': true,
    'logLevel': LogLevel.info,
    'enableCache': false,
    'defaultCacheDuration': 0,
    'environment': Environment.production,
    'enableExponentialBackoff': true,
  };
  
  /// Offline-first configuration (aggressive caching)
  static const Map<String, dynamic> offlineFirst = {
    'connectTimeout': 15000,
    'receiveTimeout': 30000,
    'sendTimeout': 30000,
    'maxRetries': 3,
    'retryDelay': 1000,
    'enableLogging': true,
    'logLevel': LogLevel.info,
    'enableCache': true,
    'defaultCacheDuration': 3600, // 1 hour
    'maxCacheSize': 500, // 500MB
    'environment': Environment.development,
    'enableExponentialBackoff': true,
  };
  
  /// Low bandwidth configuration (for poor network conditions)
  static const Map<String, dynamic> lowBandwidth = {
    'connectTimeout': 20000,
    'receiveTimeout': 60000,
    'sendTimeout': 60000,
    'maxRetries': 5,
    'retryDelay': 3000,
    'enableLogging': true,
    'logLevel': LogLevel.warning,
    'enableCache': true,
    'defaultCacheDuration': 1800, // 30 minutes
    'environment': Environment.production,
    'enableExponentialBackoff': true,
  };
  
  /// Get preset configuration by name
  static Map<String, dynamic>? getPreset(String presetName) {
    switch (presetName.toLowerCase()) {
      case 'development':
        return Map<String, dynamic>.from(development);
      case 'production':
        return Map<String, dynamic>.from(production);
      case 'testing':
        return Map<String, dynamic>.from(testing);
      case 'staging':
        return Map<String, dynamic>.from(staging);
      case 'fast_response':
      case 'fastresponse':
        return Map<String, dynamic>.from(fastResponse);
      case 'heavy_load':
      case 'heavyload':
        return Map<String, dynamic>.from(heavyLoad);
      case 'offline_first':
      case 'offlinefirst':
        return Map<String, dynamic>.from(offlineFirst);
      case 'low_bandwidth':
      case 'lowbandwidth':
        return Map<String, dynamic>.from(lowBandwidth);
      default:
        return null;
    }
  }
  
  /// Get preset configuration by enum
  static Map<String, dynamic>? getPresetByEnum(NetworkConfigPreset preset) {
    return getPreset(preset.value);
  }
  
  /// Get all available preset names
  static List<String> getAvailablePresets() {
    return NetworkConfigPreset.values.map((preset) => preset.value).toList();
  }
  
  /// Get all available presets as enum values
  static List<NetworkConfigPreset> getAvailablePresetEnums() {
    return NetworkConfigPreset.values;
  }
  
  /// Get unified configuration format
  static Map<String, dynamic>? getUnifiedPreset(String presetName) {
    // Try to get from NetworkConfigPresets first
    final preset = getPreset(presetName);
    if (preset != null) {
      return preset;
    }
    
    // Try to get from NetworkConfigPreset enum
    final enumPreset = NetworkConfigPreset.fromString(presetName);
    if (enumPreset != null) {
      return enumPreset.getConfig();
    }
    
    return null;
  }
}