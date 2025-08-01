import '../cache/cache_manager.dart';
import '../config/network_config.dart';
import '../interceptor/interceptor_manager.dart';
import '../interceptor/logging_interceptor.dart' as logging;
import '../queue/request_queue_manager.dart';
import '../config/config_validator.dart';
import '../cache/cache_manager.dart';
import '../../utils/network_logger.dart';


// =============================================================================
// Service Locator - Dependency Injection Container
// =============================================================================

/// Service lifecycle
enum ServiceLifecycle {
  /// Singleton - Only one instance throughout the application lifecycle
  singleton,
  /// Transient - Create new instance every time it's requested
  transient,
  /// Scoped - Singleton within a specific scope
  scoped,
}

/// Service factory function
typedef ServiceFactory<T> = T Function(ServiceLocator locator);

/// Service disposer function
typedef ServiceDisposer<T> = void Function(T service);

/// Service registration information
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
  
  /// Get or create instance
  T getInstance(ServiceLocator locator) {
    switch (lifecycle) {
      case ServiceLifecycle.singleton:
        return _instance ??= factory(locator);
      case ServiceLifecycle.transient:
        return factory(locator);
      case ServiceLifecycle.scoped:
        // Scoped instances are handled by scope manager
        return _instance ??= factory(locator);
    }
  }
  
  /// Dispose instance
  void dispose() {
    if (_instance != null && disposer != null) {
      disposer!(_instance as T);
      _instance = null;
    }
  }
  
  /// Reset instance (for scope)
  void reset() {
    dispose();
  }
}

/// Service scope
class ServiceScope {
  final String name;
  final Map<Type, dynamic> _scopedInstances = {};
  final ServiceLocator _parent;
  
  ServiceScope(this.name, this._parent);
  
  /// Get service instance within scope
  T get<T>() {
    final type = T;
    
    // First check if instance already exists in scope
    if (_scopedInstances.containsKey(type)) {
      return _scopedInstances[type] as T;
    }
    
    // Get registration information from parent container
    final registration = _parent._getRegistration<T>();
    if (registration == null) {
      throw ServiceNotRegisteredException('Service $type is not registered');
    }
    
    // If it's a scoped service, create instance in current scope
    if (registration.lifecycle == ServiceLifecycle.scoped) {
      final instance = registration.factory(_parent);
      _scopedInstances[type] = instance;
      return instance;
    }
    
    // Other lifecycles get directly from parent container
    return _parent.get<T>();
  }
  
  /// Dispose scope
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

/// Main service locator class
class ServiceLocator {
  static ServiceLocator? _instance;
  static ServiceLocator get instance => _instance ??= ServiceLocator._();
  
  final Map<Type, ServiceRegistration> _services = {};
  final Map<String, ServiceScope> _scopes = {};
  bool _isInitialized = false;
  
  ServiceLocator._();
  
  /// Register singleton service
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
  
  /// Register transient service
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
  
  /// Register scoped service
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
  
  /// Register instance
  void registerInstance<T>(T instance) {
    _services[T] = ServiceRegistration<T>(
      factory: (_) => instance,
      lifecycle: ServiceLifecycle.singleton,
    );
    (_services[T] as ServiceRegistration<T>)._instance = instance;
  }
  
  /// Internal registration method
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
  
  /// Get service instance
  T get<T>() {
    final registration = _getRegistration<T>();
    if (registration == null) {
      throw ServiceNotRegisteredException('Service $T is not registered');
    }
    
    // Check circular dependency
    _checkCircularDependency<T>();
    
    return registration.getInstance(this);
  }
  
  /// Try to get service instance
  T? tryGet<T>() {
    try {
      return get<T>();
    } catch (e) {
      return null;
    }
  }
  
  /// Check if service is registered
  bool isRegistered<T>() {
    return _services.containsKey(T);
  }
  
  /// Get registration information
  ServiceRegistration<T>? _getRegistration<T>([Type? type]) {
    final targetType = type ?? T;
    return _services[targetType] as ServiceRegistration<T>?;
  }
  
  /// Check circular dependency
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
  
  /// Create scope
  ServiceScope createScope(String name) {
    if (_scopes.containsKey(name)) {
      throw ScopeAlreadyExistsException('Scope $name already exists');
    }
    
    final scope = ServiceScope(name, this);
    _scopes[name] = scope;
    return scope;
  }
  
  /// Get scope
  ServiceScope? getScope(String name) {
    return _scopes[name];
  }
  
  /// Dispose scope
  void disposeScope(String name) {
    final scope = _scopes.remove(name);
    scope?.dispose();
  }
  
  /// Reset services (mainly for testing)
  void reset() {
    // Dispose all scopes
    for (final scope in _scopes.values) {
      scope.dispose();
    }
    _scopes.clear();
    
    // Dispose all singleton services
    for (final registration in _services.values) {
      registration.dispose();
    }
    
    _services.clear();
    _isInitialized = false;
  }
  
  /// Initialize all services
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize services in dependency order
    final initOrder = _calculateInitializationOrder();
    
    for (final serviceType in initOrder) {
      final registration = _services[serviceType];
      if (registration?.lifecycle == ServiceLifecycle.singleton) {
        // Pre-initialize singleton services
        registration!.getInstance(this);
      }
    }
    
    _isInitialized = true;
  }
  
  /// Calculate initialization order
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
  
  /// Get service statistics
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
// Network Framework Service Registration
// =============================================================================

/// Network framework service registrar
class NetworkServiceRegistrar {
  /// Register all network framework services
  static void registerServices(ServiceLocator locator) {
    // Register configuration service
    locator.registerSingleton<NetworkConfig>(
      (_) => NetworkConfig.instance,
    );
    
    // Register cache manager
    locator.registerSingleton<CacheManager>(
      (_) => CacheManager.instance,
      disposer: (cache) => cache.dispose(),
    );
    
    // Register configuration validator
    locator.registerSingleton<CompositeConfigValidator>(
      (_) => CompositeConfigValidator(),
    );
    
    // Register interceptor manager
    locator.registerSingleton<InterceptorManager>(
      (_) => InterceptorManager.instance,
    );
    
    // Register request queue manager
    locator.registerSingleton<RequestQueueManager>(
      (_) => RequestQueueManager.instance,
      disposer: (queue) => queue.dispose(),
    );
    
    // Register logging interceptor
    locator.registerTransient<logging.LoggingInterceptor>(
      (_) => logging.LoggingInterceptor(),
    );
    
    // Service registration completed
  }
  
  /// Initialize network framework
  static Future<void> initializeNetworkFramework({
    NetworkConfig? networkConfig,
    CacheConfig? cacheConfig,
    bool validateConfig = true,
  }) async {
    final locator = ServiceLocator.instance;
    
    // Register services
    registerServices(locator);
    
    // Validate configuration
    if (validateConfig) {
      await ConfigValidationUtils.validateAndInitialize(
        networkConfig: networkConfig,
        cacheConfig: cacheConfig,
      );
    }
    
    // Initialize services
    await locator.initialize();
    
    // Network framework initialized successfully
  }
}

// =============================================================================
// Service Locator Extensions
// =============================================================================

/// Service locator extensions - Provides convenient methods
extension ServiceLocatorExtensions on ServiceLocator {
  /// Get cache manager
  CacheManager get cacheManager => get<CacheManager>();
  
  /// Get request queue manager
  RequestQueueManager get requestQueueManager => get<RequestQueueManager>();
  
  /// Get configuration
  NetworkConfig get networkConfig => get<NetworkConfig>();
}

// =============================================================================
// Exception Classes
// =============================================================================

/// Service not registered exception
class ServiceNotRegisteredException implements Exception {
  final String message;
  ServiceNotRegisteredException(this.message);
  
  @override
  String toString() => 'ServiceNotRegisteredException: $message';
}

/// Service already registered exception
class ServiceAlreadyRegisteredException implements Exception {
  final String message;
  ServiceAlreadyRegisteredException(this.message);
  
  @override
  String toString() => 'ServiceAlreadyRegisteredException: $message';
}

/// Circular dependency exception
class CircularDependencyException implements Exception {
  final String message;
  CircularDependencyException(this.message);
  
  @override
  String toString() => 'CircularDependencyException: $message';
}

/// Scope already exists exception
class ScopeAlreadyExistsException implements Exception {
  final String message;
  ScopeAlreadyExistsException(this.message);
  
  @override
  String toString() => 'ScopeAlreadyExistsException: $message';
}

// =============================================================================
// Usage Examples
// =============================================================================

/// Service locator usage examples
class ServiceLocatorUsageExamples {
  /// Basic usage example
  static Future<void> basicUsage() async {
    final locator = ServiceLocator.instance;
    
    // Initialize network framework
    await NetworkServiceRegistrar.initializeNetworkFramework();
    
    // Get services
    final cacheManager = locator.cacheManager;
    final requestQueueManager = locator.requestQueueManager;
    
    NetworkLogger.general.info('Cache manager: $cacheManager');
    NetworkLogger.general.info('Request queue manager: $requestQueueManager');
  }
  
  /// Scope usage example
  static Future<void> scopeUsage() async {
    final locator = ServiceLocator.instance;
    
    // Create request scope
    final requestScope = locator.createScope('request');
    
    try {
      // Get service within scope
      final scopedService = requestScope.get<CacheManager>();
      NetworkLogger.general.info('Scoped service: $scopedService');
    } finally {
      // Dispose scope
      locator.disposeScope('request');
    }
  }
  
  /// Custom service registration example
  static void customServiceRegistration() {
    final locator = ServiceLocator.instance;
    
    // Register custom service
    locator.registerSingleton<MyCustomService>(
      (locator) => MyCustomService(
        cacheManager: locator.get<CacheManager>(),
      ),
      dependencies: [CacheManager],
    );
    
    // Use custom service
    final customService = locator.get<MyCustomService>();
    customService.doSomething();
  }
}

/// Custom service example
class MyCustomService {
  final CacheManager cacheManager;
  
  MyCustomService({required this.cacheManager});
  
  void doSomething() {
    NetworkLogger.general.info('Doing something with cache manager: $cacheManager');
  }
}