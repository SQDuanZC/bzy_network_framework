import 'dart:async';
import 'package:dio/dio.dart';
import '../requests/base_network_request.dart';
import '../requests/network_executor.dart';
import '../model/network_response.dart';
import '../config/network_config.dart';
import '../utils/network_logger.dart';
import '../core/exception/unified_exception_handler.dart';
import '../core/interceptor/interceptor_manager.dart';

/// Unified network framework - core entry point for plugin architecture
class UnifiedNetworkFramework {
  static UnifiedNetworkFramework? _instance;
  late NetworkExecutor _executor;
  final Map<String, NetworkPlugin> _plugins = {};
  final List<GlobalInterceptor> _globalInterceptors = [];
  bool _isInitialized = false;
  
  /// Singleton instance
  static UnifiedNetworkFramework get instance {
    _instance ??= UnifiedNetworkFramework._internal();
    return _instance!;
  }
  
  UnifiedNetworkFramework._internal() {
    _executor = NetworkExecutor.instance;
    _initializeExceptionHandling();
  }
  
  /// Initialize exception handling
  void _initializeExceptionHandling() {
    // Add exception interceptor to network executor
    _executor.addInterceptor(ExceptionInterceptor());
    InterceptorManager.instance.registerInterceptor('retry', RetryInterceptor());
    
    // Register default global exception handler
    UnifiedExceptionHandler.instance.registerGlobalHandler(
      DefaultGlobalExceptionHandler(),
    );
  }
  
  /// Initialize framework
  Future<void> initialize({
    List<NetworkPlugin>? plugins,
    List<GlobalInterceptor>? interceptors,
  }) async {  
    if (_isInitialized) {
      throw StateError('UnifiedNetworkFramework is already initialized');
    }

    // Register plugins
    if (plugins != null) {
      for (final plugin in plugins) {
        await registerPlugin(plugin);
      }
    }
    
    // Register global interceptors
    if (interceptors != null) {
      for (final interceptor in interceptors) {
        registerGlobalInterceptor(interceptor);
      }
    }
    
    // Reconfigure executor
    _executor.reconfigure();
    
    _isInitialized = true;
  }
  
  /// Register plugin
  Future<void> registerPlugin(NetworkPlugin plugin) async {
    // 空值检查
    if (plugin == null) {
      NetworkLogger.framework.warning('注册插件: plugin 为空');
      throw ArgumentError('plugin cannot be null');
    }
    
    if (plugin.name == null || plugin.name.isEmpty) {
      NetworkLogger.framework.warning('注册插件: plugin.name 为空');
      throw ArgumentError('plugin.name cannot be null or empty');
    }
    
    if (_plugins.containsKey(plugin.name)) {
      throw ArgumentError('Plugin ${plugin.name} is already registered');
    }
    
    await plugin.initialize();
    _plugins[plugin.name] = plugin;
    
    // Register plugin interceptors
    for (final interceptor in plugin.interceptors) {
      _executor.addInterceptor(interceptor);
    }
  }
  
  /// Unregister plugin
  Future<void> unregisterPlugin(String pluginName) async {
    // 空值检查
    if (pluginName == null || pluginName.isEmpty) {
      NetworkLogger.framework.warning('注销插件: pluginName 为空');
      throw ArgumentError('pluginName cannot be null or empty');
    }
    
    final plugin = _plugins.remove(pluginName);
    if (plugin != null) {
      // Remove plugin interceptors
      for (final interceptor in plugin.interceptors) {
        _executor.removeInterceptor(interceptor);
      }
      
      await plugin.dispose();
    }
  }
  
  /// Register global interceptor
  void registerGlobalInterceptor(GlobalInterceptor interceptor) {
    // 空值检查
    if (interceptor == null) {
      NetworkLogger.framework.warning('注册全局拦截器: interceptor 为空');
      throw ArgumentError('interceptor cannot be null');
    }
    
    _globalInterceptors.add(interceptor);
    _executor.addInterceptor(interceptor);
  }
  
  /// Remove global interceptor
  void removeGlobalInterceptor(GlobalInterceptor interceptor) {
    // 空值检查
    if (interceptor == null) {
      NetworkLogger.framework.warning('移除全局拦截器: interceptor 为空');
      throw ArgumentError('interceptor cannot be null');
    }
    
    _globalInterceptors.remove(interceptor);
    _executor.removeInterceptor(interceptor);
  }
  
  /// Execute network request
  Future<NetworkResponse<T>> execute<T>(BaseNetworkRequest<T> request) async {
    // 空值检查
    if (request == null) {
      NetworkLogger.framework.warning('执行请求: request 为空');
      throw ArgumentError('request cannot be null');
    }
    
    _ensureInitialized();
    
    // Store original request data before execution
    // For unified queryParameters approach, store the actual data that will be sent
    final originalData = _getEffectiveRequestData(request);
    request.setOriginalRequestData(originalData);
    
    // Apply plugin request preprocessing
    for (final plugin in _plugins.values) {
      await plugin.onRequestStart(request);
    }
    
    try {
      final response = await _executor.execute(request);
      
      // Apply plugin response post-processing
      for (final plugin in _plugins.values) {
        await plugin.onRequestComplete(request, response.cast<dynamic>());
      }
      
      return response;
    } catch (error) {
      // Use unified exception handling system
      final unifiedException = await UnifiedExceptionHandler.instance.handleException(
        error,
        context: 'Unified network framework request execution',
        metadata: {
          'requestType': request.runtimeType.toString(),
          'path': request.path,
          'method': request.method.value,
        },
      );
      
      // Apply plugin error handling
      for (final plugin in _plugins.values) {
        await plugin.onRequestError(request, unifiedException);
      }
      
      rethrow;
    }
  }
  
  /// Execute batch requests
  Future<List<NetworkResponse>> executeBatch(List<BaseNetworkRequest> requests) async {
    // 空值检查
    if (requests == null) {
      NetworkLogger.framework.warning('执行批量请求: requests 为空');
      throw ArgumentError('requests cannot be null');
    }
    
    if (requests.isEmpty) {
      NetworkLogger.framework.warning('执行批量请求: requests 为空列表');
      throw ArgumentError('requests cannot be empty');
    }
    
    _ensureInitialized();
    return await _executor.executeBatch(requests);
  }
  
  /// Get effective request data based on HTTP method and queryParameters
  dynamic _getEffectiveRequestData(BaseNetworkRequest request) {
    final params = request.queryParameters;
    
    if (params != null && params.isNotEmpty) {
      switch (request.method) {
        case HttpMethod.post:
        case HttpMethod.put:
        case HttpMethod.patch:
          // For POST/PUT/PATCH, queryParameters will be converted to request body
          return params;
        case HttpMethod.get:
        case HttpMethod.delete:
        default:
          // For GET/DELETE, return null (no body data)
          return null;
      }
    }
    
    // No queryParameters, return null
    return null;
  }

  /// Execute concurrent requests
  Future<List<NetworkResponse>> executeConcurrent(
    List<BaseNetworkRequest> requests, {
    int maxConcurrency = 3,
  }) async {
    // 空值检查
    if (requests == null) {
      NetworkLogger.framework.warning('执行并发请求: requests 为空');
      throw ArgumentError('requests cannot be null');
    }
    
    if (requests.isEmpty) {
      NetworkLogger.framework.warning('执行并发请求: requests 为空列表');
      throw ArgumentError('requests cannot be empty');
    }
    
    if (maxConcurrency <= 0) {
      NetworkLogger.framework.warning('执行并发请求: maxConcurrency 必须大于0');
      throw ArgumentError('maxConcurrency must be greater than 0');
    }
    
    _ensureInitialized();
    return await _executor.executeConcurrent(requests, maxConcurrency: maxConcurrency);
  }
  
  /// Cancel request
  void cancelRequest(BaseNetworkRequest request) {
    // 空值检查
    if (request == null) {
      NetworkLogger.framework.warning('取消请求: request 为空');
      throw ArgumentError('request cannot be null');
    }
    
    _executor.cancelRequest(request);
  }
  
  /// Cancel all requests
  void cancelAllRequests() {
    _executor.cancelAllRequests();
  }
  
  /// Update configuration
  void updateConfig(Map<String, dynamic> config) {
    // 空值检查
    if (config == null) {
      NetworkLogger.framework.warning('更新配置: config 为空');
      throw ArgumentError('config cannot be null');
    }
    
    final networkConfig = NetworkConfig.instance;
    
    if (config.containsKey('baseUrl')) {
      networkConfig.updateBaseUrl(config['baseUrl']);
    }
    
    if (config.containsKey('authToken')) {
      networkConfig.setAuthToken(config['authToken']);
    }
    
    if (config.containsKey('timeouts')) {
      final timeouts = config['timeouts'] as Map<String, dynamic>;
      networkConfig.updateTimeouts(
        connectTimeout: timeouts['connectTimeout'],
        receiveTimeout: timeouts['receiveTimeout'],
        sendTimeout: timeouts['sendTimeout'],
      );
    }
    
    if (config.containsKey('retry')) {
      final retry = config['retry'] as Map<String, dynamic>;
      networkConfig.updateRetryConfig(
        maxRetries: retry['maxRetries'],
        retryDelay: retry['retryDelay'],
      );
    }
    
    if (config.containsKey('cache')) {
      final cache = config['cache'] as Map<String, dynamic>;
      networkConfig.updateCacheConfig(
        enableCache: cache['enableCache'],
        defaultCacheDuration: cache['defaultCacheDuration'],
        maxCacheSize: cache['maxCacheSize'],
      );
    }
    
    if (config.containsKey('logging')) {
      final logging = config['logging'] as Map<String, dynamic>;
      networkConfig.updateLogConfig(
        enableLogging: logging['enableLogging'],
        logLevel: logging['logLevel'],
      );
    }
    
    // 重新配置执行器
    _executor.reconfigure();
  }
  
  /// 获取插件
  T? getPlugin<T extends NetworkPlugin>(String name) {
    return _plugins[name] as T?;
  }
  
  /// 获取所有插件
  List<NetworkPlugin> get plugins => _plugins.values.toList();
  
  /// 获取框架状态
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'pluginsCount': _plugins.length,
      'globalInterceptorsCount': _globalInterceptors.length,
      'executor': _executor.getStatus(),
      'config': NetworkConfig.instance.toMap(),
    };
  }
  
  /// 清理资源
  Future<void> dispose() async {
    // 注销所有插件
    for (final pluginName in _plugins.keys.toList()) {
      await unregisterPlugin(pluginName);
    }
    
    // 清理全局拦截器
    _globalInterceptors.clear();
    
    // 清理执行器
    _executor.dispose();
    
    // 重置配置
    NetworkConfig.instance.reset();
    
    _isInitialized = false;
  }
  
  /// 确保框架已初始化
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('UnifiedNetworkFramework is not initialized. Call initialize() first.');
    }
  }
}

/// 网络插件基类
abstract class NetworkPlugin {
  /// 插件名称
  String get name;
  
  /// 插件版本
  String get version;
  
  /// 插件描述
  String get description;
  
  /// 插件拦截器
  List<Interceptor> get interceptors => [];
  
  /// 初始化插件
  Future<void> initialize();
  
  /// 请求开始时调用
  Future<void> onRequestStart(BaseNetworkRequest request) async {}
  
  /// 请求完成时调用
  Future<void> onRequestComplete(BaseNetworkRequest request, NetworkResponse<dynamic> response) async {}
  
  /// 请求错误时调用
  Future<void> onRequestError(BaseNetworkRequest request, dynamic error) async {}
  
  /// 异常处理接口（新增）
  Future<void> onException(UnifiedException exception) async {
    // 默认实现为空，子类可以重写
  }
  
  /// 清理插件资源
  Future<void> dispose();
}

/// 全局拦截器类型定义
typedef GlobalInterceptor = Interceptor;

/// 预定义的插件工厂
class NetworkPluginFactory {
  /// 创建认证插件
  static AuthPlugin createAuthPlugin({
    required String Function() getToken,
    String tokenType = 'Bearer',
    String headerName = 'Authorization',
  }) {
    return AuthPlugin(
      getToken: getToken,
      tokenType: tokenType,
      headerName: headerName,
    );
  }
  
  /// 创建缓存插件
  static CachePlugin createCachePlugin({
    int maxSize = 100,
    Duration defaultDuration = const Duration(minutes: 5),
  }) {
    return CachePlugin(
      maxSize: maxSize,
      defaultDuration: defaultDuration,
    );
  }
  
  /// 创建重试插件
  static RetryPlugin createRetryPlugin({
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
    bool Function(DioException)? shouldRetry,
  }) {
    return RetryPlugin(
      maxRetries: maxRetries,
      delay: delay,
      shouldRetry: shouldRetry,
    );
  }
  
  /// 创建日志插件
  static LoggingPlugin createLoggingPlugin({
    bool logRequest = true,
    bool logResponse = true,
    bool logError = true,
  }) {
    return LoggingPlugin(
      logRequest: logRequest,
      logResponse: logResponse,
      logError: logError,
    );
  }
}

/// 认证插件
class AuthPlugin extends NetworkPlugin {
  final String Function() getToken;
  final String tokenType;
  final String headerName;
  
  AuthPlugin({
    required this.getToken,
    this.tokenType = 'Bearer',
    this.headerName = 'Authorization',
  });
  
  @override
  String get name => 'auth';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => 'Authentication plugin for automatic token management';
  
  @override
  List<Interceptor> get interceptors => [_AuthInterceptor(this)];
  
  @override
  Future<void> initialize() async {
    // 认证插件初始化逻辑
  }
  
  @override
  Future<void> dispose() async {
    // 清理认证相关资源
  }
}

class _AuthInterceptor extends Interceptor {
  final AuthPlugin plugin;
  
  _AuthInterceptor(this.plugin);
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      final token = plugin.getToken();
      if (token.isNotEmpty) {
        options.headers[plugin.headerName] = '${plugin.tokenType} $token';
      }
    } catch (e) {
      // 忽略token获取错误
    }
    handler.next(options);
  }
}

/// 缓存插件
class CachePlugin extends NetworkPlugin {
  final int maxSize;
  final Duration defaultDuration;
  
  CachePlugin({
    required this.maxSize,
    required this.defaultDuration,
  });
  
  @override
  String get name => 'cache';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => 'Caching plugin for response caching';
  
  @override
  Future<void> initialize() async {
    // 缓存插件初始化逻辑
  }
  
  @override
  Future<void> dispose() async {
    // 清理缓存资源
  }
}

/// 重试插件
class RetryPlugin extends NetworkPlugin {
  final int maxRetries;
  final Duration delay;
  final bool Function(DioException)? shouldRetry;
  
  RetryPlugin({
    required this.maxRetries,
    required this.delay,
    this.shouldRetry,
  });
  
  @override
  String get name => 'retry';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => 'Retry plugin for automatic request retrying';
  
  @override
  Future<void> initialize() async {
    // 重试插件初始化逻辑
  }
  
  @override
  Future<void> dispose() async {
    // 清理重试相关资源
  }
}

/// 日志插件
class LoggingPlugin extends NetworkPlugin {
  final bool logRequest;
  final bool logResponse;
  final bool logError;
  
  LoggingPlugin({
    required this.logRequest,
    required this.logResponse,
    required this.logError,
  });
  
  @override
  String get name => 'logging';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => 'Logging plugin for request/response logging';
  
  @override
  List<Interceptor> get interceptors => [_LoggingInterceptor(this)];
  
  @override
  Future<void> initialize() async {
    // 日志插件初始化逻辑
  }
  
  @override
  Future<void> dispose() async {
    // 清理日志相关资源
  }
}

class _LoggingInterceptor extends Interceptor {
  final LoggingPlugin plugin;
  
  _LoggingInterceptor(this.plugin);
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (plugin.logRequest) {
      NetworkLogger.general.info('🚀 REQUEST: ${options.method} ${options.uri}');
      if (options.data != null) {
        NetworkLogger.general.info('📤 DATA: ${options.data}');
      }
    }
    handler.next(options);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (plugin.logResponse) {
      NetworkLogger.general.info('✅ RESPONSE: ${response.statusCode} ${response.requestOptions.uri}');
      NetworkLogger.general.info('📥 DATA: ${response.data}');
    }
    handler.next(response);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (plugin.logError) {
      NetworkLogger.general.warning('❌ ERROR: ${err.message}');
      NetworkLogger.general.warning('🔍 DETAILS: ${err.response?.data}');
    }
    handler.next(err);
  }
}