import '../cache/cache_manager.dart';
import '../config/network_config.dart';
import '../interceptor/interceptor_manager.dart';
import '../interceptor/logging_interceptor.dart' as logging;
import '../queue/request_queue_manager.dart';
import '../config/config_validator.dart';
import '../../utils/network_logger.dart';


// =============================================================================
// 服务定位器 - 依赖注入容器
// =============================================================================

/// 服务生命周期
enum ServiceLifecycle {
  /// 单例 - 整个应用生命周期内只有一个实例
  singleton,
  /// 瞬态 - 每次获取都创建新实例
  transient,
  /// 作用域 - 在特定作用域内是单例
  scoped,
}

/// 服务工厂函数
typedef ServiceFactory<T> = T Function(ServiceLocator locator);

/// 服务销毁函数
typedef ServiceDisposer<T> = void Function(T service);

/// 服务注册信息
class ServiceRegistration<T> {
  final ServiceFactory<T> factory;
  final ServiceLifecycle lifecycle;
  final ServiceDisposer<T>? disposer;
  final List<Type> dependencies;
  T? _instance;
  
  ServiceRegistration({
    required this.factory,
    required this.lifecycle,
    this.disposer,
    this.dependencies = const [],
  });
  
  /// 获取或创建实例
  T getInstance(ServiceLocator locator) {
    switch (lifecycle) {
      case ServiceLifecycle.singleton:
        return _instance ??= factory(locator);
      case ServiceLifecycle.transient:
        return factory(locator);
      case ServiceLifecycle.scoped:
        // 作用域实例由作用域管理器处理
        return _instance ??= factory(locator);
    }
  }
  
  /// 清理实例
  void dispose() {
    if (_instance != null && disposer != null) {
      disposer!(_instance as T);
      _instance = null;
    }
  }
  
  /// 重置实例（用于作用域）
  void reset() {
    dispose();
  }
}

/// 服务作用域
class ServiceScope {
  final String name;
  final Map<Type, dynamic> _scopedInstances = {};
  final ServiceLocator _parent;
  
  ServiceScope(this.name, this._parent);
  
  /// 获取作用域内的服务实例
  T get<T>() {
    final type = T;
    
    // 先检查作用域内是否已有实例
    if (_scopedInstances.containsKey(type)) {
      return _scopedInstances[type] as T;
    }
    
    // 从父容器获取注册信息
    final registration = _parent._getRegistration<T>();
    if (registration == null) {
      throw ServiceNotRegisteredException('Service $type is not registered');
    }
    
    // 如果是作用域服务，在当前作用域创建实例
    if (registration.lifecycle == ServiceLifecycle.scoped) {
      final instance = registration.factory(_parent);
      _scopedInstances[type] = instance;
      return instance;
    }
    
    // 其他生命周期直接从父容器获取
    return _parent.get<T>();
  }
  
  /// 销毁作用域
  void dispose() {
    for (final entry in _scopedInstances.entries) {
      final registration = _parent._getRegistration(entry.key);
      if (registration?.disposer != null) {
        registration!.disposer!(entry.value);
      }
    }
    _scopedInstances.clear();
  }
}

/// 服务定位器主类
class ServiceLocator {
  static ServiceLocator? _instance;
  static ServiceLocator get instance => _instance ??= ServiceLocator._();
  
  final Map<Type, ServiceRegistration> _services = {};
  final Map<String, ServiceScope> _scopes = {};
  bool _isInitialized = false;
  
  ServiceLocator._();
  
  /// 注册单例服务
  void registerSingleton<T>(
    ServiceFactory<T> factory, {
    ServiceDisposer<T>? disposer,
    List<Type> dependencies = const [],
  }) {
    _register<T>(
      factory: factory,
      lifecycle: ServiceLifecycle.singleton,
      disposer: disposer,
      dependencies: dependencies,
    );
  }
  
  /// 注册瞬态服务
  void registerTransient<T>(
    ServiceFactory<T> factory, {
    List<Type> dependencies = const [],
  }) {
    _register<T>(
      factory: factory,
      lifecycle: ServiceLifecycle.transient,
      dependencies: dependencies,
    );
  }
  
  /// 注册作用域服务
  void registerScoped<T>(
    ServiceFactory<T> factory, {
    ServiceDisposer<T>? disposer,
    List<Type> dependencies = const [],
  }) {
    _register<T>(
      factory: factory,
      lifecycle: ServiceLifecycle.scoped,
      disposer: disposer,
      dependencies: dependencies,
    );
  }
  
  /// 注册实例
  void registerInstance<T>(T instance) {
    _services[T] = ServiceRegistration<T>(
      factory: (_) => instance,
      lifecycle: ServiceLifecycle.singleton,
    );
    (_services[T] as ServiceRegistration<T>)._instance = instance;
  }
  
  /// 内部注册方法
  void _register<T>({
    required ServiceFactory<T> factory,
    required ServiceLifecycle lifecycle,
    ServiceDisposer<T>? disposer,
    List<Type> dependencies = const [],
  }) {
    if (_services.containsKey(T)) {
      throw ServiceAlreadyRegisteredException('Service $T is already registered');
    }
    
    _services[T] = ServiceRegistration<T>(
      factory: factory,
      lifecycle: lifecycle,
      disposer: disposer,
      dependencies: dependencies,
    );
  }
  
  /// 获取服务实例
  T get<T>() {
    final registration = _getRegistration<T>();
    if (registration == null) {
      throw ServiceNotRegisteredException('Service $T is not registered');
    }
    
    // 检查循环依赖
    _checkCircularDependency<T>();
    
    return registration.getInstance(this);
  }
  
  /// 尝试获取服务实例
  T? tryGet<T>() {
    try {
      return get<T>();
    } catch (e) {
      return null;
    }
  }
  
  /// 检查服务是否已注册
  bool isRegistered<T>() {
    return _services.containsKey(T);
  }
  
  /// 获取注册信息
  ServiceRegistration<T>? _getRegistration<T>([Type? type]) {
    final targetType = type ?? T;
    return _services[targetType] as ServiceRegistration<T>?;
  }
  
  /// 检查循环依赖
  void _checkCircularDependency<T>([Set<Type>? visited]) {
    visited ??= <Type>{};
    
    if (visited.contains(T)) {
      throw CircularDependencyException('Circular dependency detected for $T');
    }
    
    visited.add(T);
    
    final registration = _getRegistration<T>();
    if (registration != null) {
      for (final _ in registration.dependencies) {
        _checkCircularDependency<dynamic>(visited);
      }
    }
    
    visited.remove(T);
  }
  
  /// 创建作用域
  ServiceScope createScope(String name) {
    if (_scopes.containsKey(name)) {
      throw ScopeAlreadyExistsException('Scope $name already exists');
    }
    
    final scope = ServiceScope(name, this);
    _scopes[name] = scope;
    return scope;
  }
  
  /// 获取作用域
  ServiceScope? getScope(String name) {
    return _scopes[name];
  }
  
  /// 销毁作用域
  void disposeScope(String name) {
    final scope = _scopes.remove(name);
    scope?.dispose();
  }
  
  /// 重置服务（主要用于测试）
  void reset() {
    // 销毁所有作用域
    for (final scope in _scopes.values) {
      scope.dispose();
    }
    _scopes.clear();
    
    // 销毁所有单例服务
    for (final registration in _services.values) {
      registration.dispose();
    }
    
    _services.clear();
    _isInitialized = false;
  }
  
  /// 初始化所有服务
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // 按依赖顺序初始化服务
    final initOrder = _calculateInitializationOrder();
    
    for (final serviceType in initOrder) {
      final registration = _services[serviceType];
      if (registration?.lifecycle == ServiceLifecycle.singleton) {
        // 预初始化单例服务
        registration!.getInstance(this);
      }
    }
    
    _isInitialized = true;
  }
  
  /// 计算初始化顺序
  List<Type> _calculateInitializationOrder() {
    final order = <Type>[];
    final visited = <Type>{};
    final visiting = <Type>{};
    
    void visit(Type type) {
      if (visited.contains(type)) return;
      if (visiting.contains(type)) {
        throw CircularDependencyException('Circular dependency detected for $type');
      }
      
      visiting.add(type);
      
      final registration = _services[type];
      if (registration != null) {
        for (final dependency in registration.dependencies) {
          visit(dependency);
        }
      }
      
      visiting.remove(type);
      visited.add(type);
      order.add(type);
    }
    
    for (final serviceType in _services.keys) {
      visit(serviceType);
    }
    
    return order;
  }
  
  /// 获取服务统计信息
  Map<String, dynamic> getStatistics() {
    final singletonCount = _services.values
        .where((r) => r.lifecycle == ServiceLifecycle.singleton)
        .length;
    final transientCount = _services.values
        .where((r) => r.lifecycle == ServiceLifecycle.transient)
        .length;
    final scopedCount = _services.values
        .where((r) => r.lifecycle == ServiceLifecycle.scoped)
        .length;
    
    final initializedSingletons = _services.values
        .where((r) => r.lifecycle == ServiceLifecycle.singleton && r._instance != null)
        .length;
    
    return {
      'totalServices': _services.length,
      'singletonServices': singletonCount,
      'transientServices': transientCount,
      'scopedServices': scopedCount,
      'initializedSingletons': initializedSingletons,
      'activeScopes': _scopes.length,
      'isInitialized': _isInitialized,
    };
  }
}

// =============================================================================
// 网络框架服务注册
// =============================================================================

/// 网络框架服务注册器
class NetworkServiceRegistrar {
  /// 注册所有网络框架服务
  static void registerServices(ServiceLocator locator) {
    // 注册配置服务
    locator.registerSingleton<NetworkConfig>(
      (_) => NetworkConfig.instance,
    );
    
    // 注册缓存管理器
    locator.registerSingleton<CacheManager>(
      (_) => CacheManager.instance,
      disposer: (cache) => cache.dispose(),
    );
    
    // 注册配置验证器
    locator.registerSingleton<CompositeConfigValidator>(
      (_) => CompositeConfigValidator(),
    );
    
    // 注册拦截器管理器
    locator.registerSingleton<InterceptorManager>(
      (_) => InterceptorManager.instance,
    );
    
    // 注册请求队列管理器
    locator.registerSingleton<RequestQueueManager>(
      (_) => RequestQueueManager.instance,
      disposer: (queue) => queue.dispose(),
    );
    
    // 注册日志拦截器
    locator.registerTransient<logging.LoggingInterceptor>(
      (_) => logging.LoggingInterceptor(),
    );
    
    // 注册服务完成
  }
  
  /// 初始化网络框架
  static Future<void> initializeNetworkFramework({
    NetworkConfig? networkConfig,
    CacheConfig? cacheConfig,
    bool validateConfig = true,
  }) async {
    final locator = ServiceLocator.instance;
    
    // 注册服务
    registerServices(locator);
    
    // 验证配置
    if (validateConfig) {
      await ConfigValidationUtils.validateAndInitialize(
        networkConfig: networkConfig,
        cacheConfig: cacheConfig,
      );
    }
    
    // 初始化服务
    await locator.initialize();
    
    // Network framework initialized successfully
  }
}

// =============================================================================
// 服务定位器扩展
// =============================================================================

/// 服务定位器扩展 - 提供便捷方法
extension ServiceLocatorExtensions on ServiceLocator {
  /// 获取缓存管理器
  CacheManager get cacheManager => get<CacheManager>();
  
  /// 获取请求队列管理器
  RequestQueueManager get requestQueueManager => get<RequestQueueManager>();
  
  /// 获取配置
  NetworkConfig get networkConfig => get<NetworkConfig>();
}

// =============================================================================
// 异常类
// =============================================================================

/// 服务未注册异常
class ServiceNotRegisteredException implements Exception {
  final String message;
  ServiceNotRegisteredException(this.message);
  
  @override
  String toString() => 'ServiceNotRegisteredException: $message';
}

/// 服务已注册异常
class ServiceAlreadyRegisteredException implements Exception {
  final String message;
  ServiceAlreadyRegisteredException(this.message);
  
  @override
  String toString() => 'ServiceAlreadyRegisteredException: $message';
}

/// 循环依赖异常
class CircularDependencyException implements Exception {
  final String message;
  CircularDependencyException(this.message);
  
  @override
  String toString() => 'CircularDependencyException: $message';
}

/// 作用域已存在异常
class ScopeAlreadyExistsException implements Exception {
  final String message;
  ScopeAlreadyExistsException(this.message);
  
  @override
  String toString() => 'ScopeAlreadyExistsException: $message';
}

// =============================================================================
// 使用示例
// =============================================================================

/// 服务定位器使用示例
class ServiceLocatorUsageExamples {
  /// 基本使用示例
  static Future<void> basicUsage() async {
    final locator = ServiceLocator.instance;
    
    // 初始化网络框架
    await NetworkServiceRegistrar.initializeNetworkFramework();
    
    // 获取服务
    final cacheManager = locator.cacheManager;
    final requestQueueManager = locator.requestQueueManager;
    
    NetworkLogger.general.info('Cache manager: $cacheManager');
    NetworkLogger.general.info('Request queue manager: $requestQueueManager');
  }
  
  /// 作用域使用示例
  static Future<void> scopeUsage() async {
    final locator = ServiceLocator.instance;
    
    // 创建请求作用域
    final requestScope = locator.createScope('request');
    
    try {
      // 在作用域内获取服务
      final scopedService = requestScope.get<CacheManager>();
      NetworkLogger.general.info('Scoped service: $scopedService');
    } finally {
      // 销毁作用域
      locator.disposeScope('request');
    }
  }
  
  /// 自定义服务注册示例
  static void customServiceRegistration() {
    final locator = ServiceLocator.instance;
    
    // 注册自定义服务
    locator.registerSingleton<MyCustomService>(
      (locator) => MyCustomService(
        cacheManager: locator.get<CacheManager>(),
      ),
      dependencies: [CacheManager],
    );
    
    // 使用自定义服务
    final customService = locator.get<MyCustomService>();
    customService.doSomething();
  }
}

/// 自定义服务示例
class MyCustomService {
  final CacheManager cacheManager;
  
  MyCustomService({required this.cacheManager});
  
  void doSomething() {
    NetworkLogger.general.info('Doing something with cache manager: $cacheManager');
  }
}