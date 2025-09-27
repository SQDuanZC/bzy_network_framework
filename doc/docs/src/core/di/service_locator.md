# ServiceLocator 服务定位器文档

## 概述
`ServiceLocator` 是 BZY Network Framework 的核心依赖注入容器，实现了服务定位器模式，提供依赖注入、服务管理、生命周期控制等功能。它是框架中所有组件依赖管理的核心，确保组件间的松耦合和高可测试性。

## 文件位置
```
lib/src/core/di/service_locator.dart
```

## 核心特性

### 1. 依赖注入
- **构造函数注入**: 通过构造函数注入依赖
- **属性注入**: 通过属性设置注入依赖
- **方法注入**: 通过方法调用注入依赖
- **接口注入**: 基于接口的依赖注入

### 2. 服务管理
- **服务注册**: 注册服务实例和工厂
- **服务解析**: 解析和获取服务实例
- **服务生命周期**: 管理服务的创建和销毁
- **服务作用域**: 控制服务的作用域范围

### 3. 生命周期管理
- **单例模式**: 全局唯一实例
- **瞬态模式**: 每次请求创建新实例
- **作用域模式**: 在特定作用域内共享实例
- **懒加载**: 延迟创建服务实例

### 4. 高级功能
- **循环依赖检测**: 检测和处理循环依赖
- **条件注册**: 基于条件的服务注册
- **装饰器模式**: 服务装饰和增强
- **模块化管理**: 模块化的服务组织

## 主要组件

### 1. 服务生命周期枚举
```dart
enum ServiceLifetime {
  singleton,    // 单例：全局唯一实例
  transient,    // 瞬态：每次创建新实例
  scoped,       // 作用域：在作用域内共享
}
```

### 2. 服务描述符
```dart
class ServiceDescriptor<T> {
  final Type serviceType;
  final Type? implementationType;
  final T Function(ServiceLocator)? factory;
  final T? instance;
  final ServiceLifetime lifetime;
  final List<Type> dependencies;
  final bool isLazy;
  final String? name;
  
  ServiceDescriptor({
    required this.serviceType,
    this.implementationType,
    this.factory,
    this.instance,
    this.lifetime = ServiceLifetime.transient,
    this.dependencies = const [],
    this.isLazy = false,
    this.name,
  });
}
```

### 3. 服务作用域
```dart
class ServiceScope implements Disposable {
  final ServiceLocator _parentLocator;
  final Map<Type, dynamic> _scopedServices = {};
  bool _disposed = false;
  
  ServiceScope(this._parentLocator);
  
  T resolve<T>([String? name]);
  void dispose();
}
```

### 4. 服务模块
```dart
abstract class ServiceModule {
  void configureServices(ServiceLocator locator);
  
  List<ServiceModule> get dependencies => [];
  String get name;
  String get version;
}
```

## 核心方法

### 1. 服务注册
```dart
// 注册单例服务
void registerSingleton<T>(T instance, {String? name});

// 注册瞬态服务
void registerTransient<TInterface, TImplementation extends TInterface>({
  String? name,
});

// 注册作用域服务
void registerScoped<TInterface, TImplementation extends TInterface>({
  String? name,
});

// 注册工厂服务
void registerFactory<T>(T Function(ServiceLocator) factory, {
  ServiceLifetime lifetime = ServiceLifetime.transient,
  String? name,
});

// 注册条件服务
void registerConditional<T>(
  T Function(ServiceLocator) factory,
  bool Function() condition, {
  ServiceLifetime lifetime = ServiceLifetime.transient,
  String? name,
});
```

### 2. 服务解析
```dart
// 解析服务
T resolve<T>([String? name]);

// 尝试解析服务
T? tryResolve<T>([String? name]);

// 解析所有实现
List<T> resolveAll<T>();

// 解析命名服务
T resolveNamed<T>(String name);

// 检查服务是否已注册
bool isRegistered<T>([String? name]);
```

### 3. 作用域管理
```dart
// 创建服务作用域
ServiceScope createScope();

// 在作用域中执行
T executeInScope<T>(T Function(ServiceScope) action);

// 异步作用域执行
Future<T> executeInScopeAsync<T>(Future<T> Function(ServiceScope) action);
```

### 4. 模块管理
```dart
// 注册服务模块
void registerModule(ServiceModule module);

// 批量注册模块
void registerModules(List<ServiceModule> modules);

// 获取已注册模块
List<ServiceModule> getRegisteredModules();

// 检查模块是否已注册
bool isModuleRegistered(String moduleName);
```

### 5. 生命周期管理
```dart
// 初始化服务定位器
Future<void> initialize();

// 销毁服务定位器
Future<void> dispose();

// 重置服务定位器
void reset();

// 验证服务配置
ValidationResult validate();
```

## 使用示例

### 1. 基本服务注册和解析
```dart
import 'package:bzy_network_framework/bzy_network_framework.dart';

// 获取服务定位器实例
final serviceLocator = ServiceLocator.instance;

// 注册服务
serviceLocator.registerSingleton<NetworkConfig>(
  NetworkConfig(baseUrl: 'https://api.example.com'),
);

serviceLocator.registerTransient<HttpClient, DioHttpClient>();

serviceLocator.registerFactory<CacheManager>(
  (locator) => CacheManager(
    config: locator.resolve<NetworkConfig>(),
  ),
  lifetime: ServiceLifetime.singleton,
);

// 解析服务
final config = serviceLocator.resolve<NetworkConfig>();
final httpClient = serviceLocator.resolve<HttpClient>();
final cacheManager = serviceLocator.resolve<CacheManager>();

print('Base URL: ${config.baseUrl}');
```

### 2. 接口和实现注册
```dart
// 定义接口
abstract class INetworkLogger {
  void log(String message);
}

abstract class INetworkCache {
  Future<String?> get(String key);
  Future<void> set(String key, String value);
}

// 实现类
class ConsoleNetworkLogger implements INetworkLogger {
  @override
  void log(String message) {
    print('[Network] $message');
  }
}

class MemoryNetworkCache implements INetworkCache {
  final Map<String, String> _cache = {};
  
  @override
  Future<String?> get(String key) async => _cache[key];
  
  @override
  Future<void> set(String key, String value) async {
    _cache[key] = value;
  }
}

// 注册接口和实现
serviceLocator.registerTransient<INetworkLogger, ConsoleNetworkLogger>();
serviceLocator.registerSingleton<INetworkCache, MemoryNetworkCache>();

// 解析接口
final logger = serviceLocator.resolve<INetworkLogger>();
final cache = serviceLocator.resolve<INetworkCache>();

logger.log('服务注册成功');
```

### 3. 工厂注册和依赖注入
```dart
// 注册依赖服务
serviceLocator.registerSingleton<NetworkConfig>(
  NetworkConfig(
    baseUrl: 'https://api.example.com',
    timeout: Duration(seconds: 30),
  ),
);

serviceLocator.registerSingleton<INetworkLogger, ConsoleNetworkLogger>();

// 注册复杂服务工厂
serviceLocator.registerFactory<NetworkExecutor>(
  (locator) {
    final config = locator.resolve<NetworkConfig>();
    final logger = locator.resolve<INetworkLogger>();
    
    return NetworkExecutor(
      config: config,
      logger: logger,
      httpClient: DioHttpClient(),
    );
  },
  lifetime: ServiceLifetime.singleton,
);

// 解析服务（自动注入依赖）
final executor = serviceLocator.resolve<NetworkExecutor>();
```

### 4. 作用域服务管理
```dart
// 注册作用域服务
serviceLocator.registerScoped<RequestContext, RequestContext>();
serviceLocator.registerScoped<UserSession, UserSession>();

// 在作用域中执行操作
final result = serviceLocator.executeInScope((scope) {
  final context = scope.resolve<RequestContext>();
  final session = scope.resolve<UserSession>();
  
  // 在同一作用域中，获取的是相同实例
  final context2 = scope.resolve<RequestContext>();
  assert(identical(context, context2));
  
  return processRequest(context, session);
});

// 异步作用域执行
final asyncResult = await serviceLocator.executeInScopeAsync((scope) async {
  final context = scope.resolve<RequestContext>();
  return await processRequestAsync(context);
});
```

### 5. 服务模块化管理
```dart
// 定义网络模块
class NetworkModule extends ServiceModule {
  @override
  String get name => 'Network';
  
  @override
  String get version => '1.0.0';
  
  @override
  void configureServices(ServiceLocator locator) {
    // 注册网络相关服务
    locator.registerSingleton<NetworkConfig>(
      NetworkConfig(baseUrl: 'https://api.example.com'),
    );
    
    locator.registerTransient<HttpClient, DioHttpClient>();
    locator.registerSingleton<NetworkExecutor, NetworkExecutor>();
    locator.registerTransient<INetworkLogger, ConsoleNetworkLogger>();
  }
}

// 定义缓存模块
class CacheModule extends ServiceModule {
  @override
  String get name => 'Cache';
  
  @override
  String get version => '1.0.0';
  
  @override
  List<ServiceModule> get dependencies => [NetworkModule()];
  
  @override
  void configureServices(ServiceLocator locator) {
    // 注册缓存相关服务
    locator.registerSingleton<CacheConfig>(
      CacheConfig(maxSize: 100, ttl: Duration(hours: 1)),
    );
    
    locator.registerSingleton<ICacheStorage, MemoryCacheStorage>();
    locator.registerSingleton<CacheManager, CacheManager>();
  }
}

// 注册模块
serviceLocator.registerModules([
  NetworkModule(),
  CacheModule(),
]);

// 验证模块依赖
final validation = serviceLocator.validate();
if (!validation.isValid) {
  print('服务配置验证失败: ${validation.errors}');
}
```

### 6. 条件注册和环境配置
```dart
// 根据环境注册不同实现
serviceLocator.registerConditional<INetworkLogger>(
  (locator) => FileNetworkLogger(),
  () => kDebugMode,
  name: 'debug',
);

serviceLocator.registerConditional<INetworkLogger>(
  (locator) => RemoteNetworkLogger(),
  () => kReleaseMode,
  name: 'release',
);

// 根据配置注册服务
serviceLocator.registerConditional<ICacheStorage>(
  (locator) => RedisCacheStorage(),
  () => serviceLocator.resolve<NetworkConfig>().useRedisCache,
);

serviceLocator.registerConditional<ICacheStorage>(
  (locator) => MemoryCacheStorage(),
  () => !serviceLocator.resolve<NetworkConfig>().useRedisCache,
);
```

## 高级功能

### 1. 装饰器模式
```dart
// 定义装饰器
class LoggingNetworkExecutorDecorator implements NetworkExecutor {
  final NetworkExecutor _inner;
  final INetworkLogger _logger;
  
  LoggingNetworkExecutorDecorator(this._inner, this._logger);
  
  @override
  Future<NetworkResponse> execute(NetworkRequest request) async {
    _logger.log('执行请求: ${request.url}');
    
    final response = await _inner.execute(request);
    
    _logger.log('请求完成: ${response.statusCode}');
    return response;
  }
}

// 注册装饰器
serviceLocator.registerFactory<NetworkExecutor>(
  (locator) {
    final inner = NetworkExecutor(
      config: locator.resolve<NetworkConfig>(),
    );
    final logger = locator.resolve<INetworkLogger>();
    
    return LoggingNetworkExecutorDecorator(inner, logger);
  },
  lifetime: ServiceLifetime.singleton,
);
```

### 2. 循环依赖检测
```dart
// 服务A依赖服务B
class ServiceA {
  final ServiceB serviceB;
  ServiceA(this.serviceB);
}

// 服务B依赖服务A（循环依赖）
class ServiceB {
  final ServiceA serviceA;
  ServiceB(this.serviceA);
}

// 注册服务（会检测循环依赖）
try {
  serviceLocator.registerFactory<ServiceA>(
    (locator) => ServiceA(locator.resolve<ServiceB>()),
  );
  
  serviceLocator.registerFactory<ServiceB>(
    (locator) => ServiceB(locator.resolve<ServiceA>()),
  );
  
  // 验证配置（会发现循环依赖）
  final validation = serviceLocator.validate();
  if (!validation.isValid) {
    print('发现循环依赖: ${validation.errors}');
  }
} catch (e) {
  print('循环依赖错误: $e');
}
```

### 3. 懒加载服务
```dart
// 注册懒加载服务
serviceLocator.registerFactory<ExpensiveService>(
  (locator) {
    print('创建昂贵的服务实例');
    return ExpensiveService();
  },
  lifetime: ServiceLifetime.singleton,
  isLazy: true,
);

// 服务只有在第一次使用时才会创建
final service = serviceLocator.resolve<ExpensiveService>(); // 此时才创建
```

### 4. 命名服务
```dart
// 注册多个同类型服务
serviceLocator.registerFactory<IDataSource>(
  (locator) => DatabaseDataSource(),
  name: 'database',
);

serviceLocator.registerFactory<IDataSource>(
  (locator) => ApiDataSource(),
  name: 'api',
);

serviceLocator.registerFactory<IDataSource>(
  (locator) => CacheDataSource(),
  name: 'cache',
);

// 解析命名服务
final dbSource = serviceLocator.resolveNamed<IDataSource>('database');
final apiSource = serviceLocator.resolveNamed<IDataSource>('api');
final cacheSource = serviceLocator.resolveNamed<IDataSource>('cache');

// 解析所有实现
final allSources = serviceLocator.resolveAll<IDataSource>();
print('数据源数量: ${allSources.length}');
```

## 最佳实践

### 1. 服务注册策略
```dart
// 在应用启动时注册所有服务
class ServiceRegistration {
  static void registerServices(ServiceLocator locator) {
    // 注册配置服务
    _registerConfigurations(locator);
    
    // 注册基础服务
    _registerInfrastructure(locator);
    
    // 注册业务服务
    _registerBusinessServices(locator);
    
    // 注册UI服务
    _registerUIServices(locator);
  }
  
  static void _registerConfigurations(ServiceLocator locator) {
    locator.registerSingleton<NetworkConfig>(
      NetworkConfig.fromEnvironment(),
    );
    
    locator.registerSingleton<CacheConfig>(
      CacheConfig.defaultConfig(),
    );
  }
  
  static void _registerInfrastructure(ServiceLocator locator) {
    locator.registerTransient<HttpClient, DioHttpClient>();
    locator.registerSingleton<CacheManager, CacheManager>();
    locator.registerSingleton<NetworkExecutor, NetworkExecutor>();
  }
  
  static void _registerBusinessServices(ServiceLocator locator) {
    locator.registerTransient<UserService, UserService>();
    locator.registerTransient<ProductService, ProductService>();
    locator.registerTransient<OrderService, OrderService>();
  }
  
  static void _registerUIServices(ServiceLocator locator) {
    locator.registerTransient<NavigationService, NavigationService>();
    locator.registerTransient<DialogService, DialogService>();
  }
}
```

### 2. 接口设计
```dart
// 定义清晰的接口
abstract class IUserRepository {
  Future<User?> getUserById(String id);
  Future<List<User>> getUsers();
  Future<void> saveUser(User user);
  Future<void> deleteUser(String id);
}

// 实现接口
class ApiUserRepository implements IUserRepository {
  final NetworkExecutor _executor;
  
  ApiUserRepository(this._executor);
  
  @override
  Future<User?> getUserById(String id) async {
    final response = await _executor.get('/users/$id');
    return response.isSuccess ? User.fromJson(response.data) : null;
  }
  
  // ... 其他方法实现
}

// 注册接口和实现
serviceLocator.registerTransient<IUserRepository, ApiUserRepository>();
```

### 3. 测试友好设计
```dart
// 在测试中替换服务实现
class TestServiceRegistration {
  static void registerTestServices(ServiceLocator locator) {
    // 使用模拟实现
    locator.registerSingleton<IUserRepository, MockUserRepository>();
    locator.registerSingleton<INetworkLogger, MockNetworkLogger>();
    
    // 使用内存缓存
    locator.registerSingleton<ICacheStorage, MemoryCacheStorage>();
  }
}

// 在测试中
void main() {
  group('用户服务测试', () {
    late ServiceLocator serviceLocator;
    
    setUp(() {
      serviceLocator = ServiceLocator.instance;
      serviceLocator.reset();
      TestServiceRegistration.registerTestServices(serviceLocator);
    });
    
    test('获取用户信息', () async {
      final userService = serviceLocator.resolve<UserService>();
      final user = await userService.getUserById('123');
      
      expect(user, isNotNull);
      expect(user!.id, equals('123'));
    });
  });
}
```

## 错误处理

### 1. 服务未注册
```dart
try {
  final service = serviceLocator.resolve<UnregisteredService>();
} catch (e) {
  if (e is ServiceNotRegisteredException) {
    print('服务未注册: ${e.serviceType}');
    
    // 注册默认实现
    serviceLocator.registerTransient<UnregisteredService, DefaultService>();
    
    // 重新解析
    final service = serviceLocator.resolve<UnregisteredService>();
  }
}
```

### 2. 循环依赖处理
```dart
try {
  final validation = serviceLocator.validate();
  if (!validation.isValid) {
    for (final error in validation.errors) {
      if (error is CircularDependencyError) {
        print('循环依赖: ${error.dependencyChain.join(' -> ')}');
        
        // 使用懒加载解决循环依赖
        _resolveCyclicDependency(error);
      }
    }
  }
} catch (e) {
  print('服务验证失败: $e');
}
```

### 3. 服务创建失败
```dart
serviceLocator.registerFactory<ComplexService>(
  (locator) {
    try {
      return ComplexService(
        dependency1: locator.resolve<Dependency1>(),
        dependency2: locator.resolve<Dependency2>(),
      );
    } catch (e) {
      // 记录错误
      final logger = locator.tryResolve<INetworkLogger>();
      logger?.log('创建ComplexService失败: $e');
      
      // 返回默认实现
      return DefaultComplexService();
    }
  },
);
```

## 设计模式

### 1. 服务定位器模式
- 集中管理服务依赖
- 提供统一的服务访问接口

### 2. 工厂模式
- 延迟创建服务实例
- 支持复杂的服务构造逻辑

### 3. 单例模式
- 确保服务的唯一性
- 管理全局共享状态

### 4. 装饰器模式
- 动态增强服务功能
- 支持横切关注点

## 注意事项

### 1. 性能考虑
- 避免过度使用服务定位器
- 合理选择服务生命周期
- 注意服务创建的性能开销

### 2. 内存管理
- 及时释放不需要的服务
- 避免内存泄漏
- 合理使用作用域服务

### 3. 线程安全
- 服务定位器是线程安全的
- 注意服务实例的线程安全性
- 避免竞态条件

### 4. 测试考虑
- 设计可测试的服务接口
- 支持服务模拟和替换
- 保持测试的独立性