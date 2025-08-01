/// 网络请求配置类
/// 统一管理网络请求的基础配置项
class NetworkConfig {
  // 私有构造函数，确保单例
  NetworkConfig._();
  
  static final NetworkConfig _instance = NetworkConfig._();
  static NetworkConfig get instance => _instance;
  
  // 基础配置
  String baseUrl = 'https://api.example.com';
  int connectTimeout = 15000; // 连接超时时间（毫秒）
  int receiveTimeout = 15000; // 接收超时时间（毫秒）
  int sendTimeout = 15000; // 发送超时时间（毫秒）
  int maxRetryCount = 3; // 最大重试次数
  int retryDelay = 1000; // 重试延迟时间（毫秒）
  bool enableExponentialBackoff = true; // 是否启用指数退避重试
  bool enableLogging = true; // 是否启用日志
  
  // 环境配置
  Environment _environment = Environment.development;
  
  // 缓存配置
  bool enableCache = true;
  int cacheMaxAge = 300; // 缓存最大存活时间（秒）
  
  // Environment getter and setter with special logic
  Environment get environment => _environment;
  set environment(Environment value) {
    _environment = value;
    _updateConfigForEnvironment();
  }
  
  // 配置方法
  void configure({
    String? baseUrl,
    int? connectTimeout,
    int? receiveTimeout,
    int? sendTimeout,
    int? maxRetryCount,
    int? retryDelay,
    bool? enableExponentialBackoff,
    bool? enableLogging,
    Environment? environment,
    bool? enableCache,
    int? cacheMaxAge,
  }) {
    if (baseUrl != null) this.baseUrl = baseUrl;
    if (connectTimeout != null) this.connectTimeout = connectTimeout;
    if (receiveTimeout != null) this.receiveTimeout = receiveTimeout;
    if (sendTimeout != null) this.sendTimeout = sendTimeout;
    if (maxRetryCount != null) this.maxRetryCount = maxRetryCount;
    if (retryDelay != null) this.retryDelay = retryDelay;
    if (enableExponentialBackoff != null) this.enableExponentialBackoff = enableExponentialBackoff;
    if (enableLogging != null) this.enableLogging = enableLogging;
    if (environment != null) {
      _environment = environment;
      _updateConfigForEnvironment();
    }
    if (enableCache != null) this.enableCache = enableCache;
    if (cacheMaxAge != null) this.cacheMaxAge = cacheMaxAge;
  }
  
  // 根据环境更新配置
  void _updateConfigForEnvironment() {
    switch (_environment) {
      case Environment.development:
        baseUrl = 'https://dev-api.example.com';
        enableLogging = true;
        break;
      case Environment.testing:
        baseUrl = 'https://test-api.example.com';
        enableLogging = true;
        break;
      case Environment.staging:
        baseUrl = 'https://staging-api.example.com';
        enableLogging = true;
        break;
      case Environment.production:
        baseUrl = 'https://api.example.com';
        enableLogging = false;
        break;
    }
  }
  
  /// 计算指数退避重试延迟
  int calculateRetryDelay(int retryAttempt) {
    if (!enableExponentialBackoff) {
      return retryDelay;
    }
    
    // 指数退避算法：baseDelay * (2 ^ retryAttempt)
    // 添加最大延迟限制，避免延迟过长
    final exponentialDelay = retryDelay * (1 << retryAttempt);
    const maxDelay = 30000; // 最大延迟30秒
    
    return exponentialDelay > maxDelay ? maxDelay : exponentialDelay;
  }
}

/// 环境枚举
enum Environment {
  development,
  testing,
  staging,
  production,
}

/// 缓存策略枚举
enum CacheStrategy {
  noCache, // 不使用缓存
  cacheFirst, // 优先使用缓存
  networkFirst, // 优先网络请求
  cacheOnly, // 仅使用缓存
}

/// 请求类型枚举（用于重试策略）
enum RequestType {
  idempotent, // 幂等请求（GET、PUT、DELETE）
  nonIdempotent, // 非幂等请求（POST）
}