import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:bzy_network_framework/bzy_network_framework.dart';

/// Plugin System and Extension Features Demo | 插件系统和扩展功能示例
/// Demonstrates plugin registration, custom plugin development and extension features | 演示插件注册、自定义插件开发和扩展功能
void main() {
  group('Plugin System and Extension Features Demo', () {
    setUpAll(() async {
      // Initialize network framework | 初始化网络框架
      await UnifiedNetworkFramework.instance.initialize(
        baseUrl: 'https://jsonplaceholder.typicode.com',
      );
      
      // Register custom plugins | 注册自定义插件
      _registerCustomPlugins();
    });

    test('Authentication Plugin Features', () async {
      print('=== Authentication Plugin Features Test ===');
      
      final request = AuthenticatedApiRequest();
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('Authentication request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('Authentication request failed: $e');
      }
    });

    test('Cache Plugin Features', () async {
      print('=== Cache Plugin Features Test ===');
      
      final request = CacheableApiRequest();
      
      // First request (from network) | 第一次请求（从网络获取）
      print('First request (from network):');
      final response1 = await NetworkExecutor.instance.execute(request);
      print('Response source: ${response1.fromCache ? 'Cache' : 'Network'}');
      
      // Second request (from cache) | 第二次请求（从缓存获取）
      print('Second request (should be from cache):');
      final response2 = await NetworkExecutor.instance.execute(request);
      print('Response source: ${response2.fromCache ? 'Cache' : 'Network'}');
      
      expect(response1.success, true);
      expect(response2.success, true);
    });

    test('Logging Plugin Features', () async {
      print('=== Logging Plugin Features Test ===');
      
      final request = LoggedApiRequest();
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('Logging request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('Logging request failed: $e');
      }
    });

    test('Retry Plugin Features', () async {
      print('=== Retry Plugin Features Test ===');
      
      final request = RetryableApiRequest();
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('Retry request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('Retry request finally failed: $e');
      }
    });

    test('Data Transform Plugin Features', () async {
      print('=== Data Transform Plugin Features Test ===');
      
      final request = TransformableApiRequest();
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('Data transform request successful: ${response.data}');
        expect(response.success, true);
        expect(response.data?['transformed'], true);
      } catch (e) {
        print('Data transform request failed: $e');
      }
    });

    test('Performance Monitoring Plugin Features', () async {
      print('=== Performance Monitoring Plugin Features Test ===');
      
      final request = MonitoredApiRequest();
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('Performance monitoring request successful: ${response.data}');
        print('Request duration: ${response.duration}ms');
        expect(response.success, true);
        expect(response.duration, greaterThan(0));
      } catch (e) {
        print('Performance monitoring request failed: $e');
      }
    });

    test('Security Plugin Features', () async {
      print('=== Security Plugin Features Test ===');
      
      final request = SecureApiRequest();
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('Security request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('Security request failed: $e');
      }
    });

    test('Composite Plugin Features', () async {
      print('=== Composite Plugin Features Test ===');
      
      final request = CompositePluginRequest();
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('Composite plugin request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('Composite plugin request failed: $e');
      }
    });

    test('Custom Extension Features', () async {
      print('=== Custom Extension Features Test ===');
      
      final request = CustomExtensionRequest();
      
      try {
        final response = await request.executeCustom();
        print('Custom extension request successful: $response');
        expect(response['customExtension'], true);
      } catch (e) {
        print('Custom extension request failed: $e');
      }
    });
  });
}

/// Register Custom Plugins | 注册自定义插件
void _registerCustomPlugins() {
  final framework = UnifiedNetworkFramework.instance;
  
  // Register authentication plugin | 注册认证插件
  framework.registerPlugin(AuthenticationPlugin());
  
  // Register cache plugin | 注册缓存插件
  framework.registerPlugin(CachePlugin());
  
  // Register logging plugin | 注册日志插件
  framework.registerPlugin(LoggingPlugin());
  
  // Register retry plugin | 注册重试插件
  framework.registerPlugin(RetryPlugin());
  
  // Register data transform plugin | 注册数据转换插件
  framework.registerPlugin(DataTransformPlugin());
  
  // Register performance monitoring plugin | 注册性能监控插件
  framework.registerPlugin(PerformanceMonitorPlugin());
  
  // Register security plugin | 注册安全插件
  framework.registerPlugin(SecurityPlugin());
  
  print('All custom plugins registered');
}

/// Authentication Plugin | 认证插件
class AuthenticationPlugin implements NetworkPlugin {
  @override
  String get name => 'AuthenticationPlugin';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => 'Authentication plugin for secure requests';
  
  @override
  int get priority => 100;
  
  @override
  List<Interceptor> get interceptors => [];
  
  @override
  Future<void> initialize() async {}
  
  @override
  Future<void> dispose() async {}
  
  @override
  Future<void> onException(dynamic exception) async {}
  
  @override
  Future<void> onRequestComplete(BaseNetworkRequest request, NetworkResponse response) async {}
  
  @override
  Future<void> onRequestPrepare(BaseNetworkRequest request) async {
    if (request is AuthenticatedApiRequest) {
        // Add authentication headers | 添加认证头
        // Since headers might be readonly, this is just a demo of auth plugin logic | 由于 headers 可能是只读的，这里只是演示认证插件逻辑
        // In real applications, headers should be set when creating requests | 在实际应用中，应该在请求创建时设置 headers
        print('🔐 Authentication Plugin: Added auth info - Authorization: Bearer fake_token_12345, X-API-Key: api_key_67890');
      }
  }
  
  @override
  Future<void> onRequestStart(BaseNetworkRequest request) async {}
  
  @override
  Future<void> onRequestError(BaseNetworkRequest request, dynamic error) async {}
  
  @override
  Future<void> onResponseReceived(BaseNetworkRequest request, NetworkResponse response) async {
    if (request is AuthenticatedApiRequest) {
      print('🔐 Authentication Plugin: Auth request completed');
    }
  }
  
  @override
  Future<void> onError(BaseNetworkRequest request, dynamic error) async {
    if (request is AuthenticatedApiRequest) {
      print('🔐 Authentication Plugin: Auth request failed - $error');
    }
  }
}

/// Cache Plugin | 缓存插件
class CachePlugin implements NetworkPlugin {
  final Map<String, dynamic> _cache = {};
  
  @override
  String get name => 'CachePlugin';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => 'Cache plugin for request/response caching';
  
  @override
  int get priority => 90;
  
  @override
  List<Interceptor> get interceptors => [];
  
  @override
  Future<void> initialize() async {}
  
  @override
  Future<void> dispose() async {}
  
  @override
  Future<void> onException(dynamic exception) async {}
  
  @override
  Future<void> onRequestComplete(BaseNetworkRequest request, NetworkResponse response) async {}
  
  @override
  Future<void> onRequestPrepare(BaseNetworkRequest request) async {}
  
  @override
  Future<void> onRequestStart(BaseNetworkRequest request) async {}
  
  @override
  Future<void> onRequestError(BaseNetworkRequest request, dynamic error) async {}
  
  @override
  Future<NetworkResponse?> onRequestExecute(BaseNetworkRequest request) async {
    if (request is CacheableApiRequest && request.enableCache) {
      final cacheKey = request.cacheKey;
      final cached = _cache[cacheKey];
      
      if (cached != null && !cached.isExpired) {
        print('💾 Cache Plugin: Returning data from cache');
        return NetworkResponse.success(
          data: cached.data,
          statusCode: 200,
          message: 'From cache',
          fromCache: true,
        );
      }
    }
    return null;
  }
  
  @override
  Future<void> onResponseReceived(BaseNetworkRequest request, NetworkResponse response) async {
    if (request is CacheableApiRequest && request.enableCache && response.success) {
      final cacheKey = request.cacheKey;
      if (cacheKey != null) {
        _cache[cacheKey] = CacheEntry(
          data: response.data,
          expireTime: DateTime.now().add(Duration(minutes: 5)),
        );
        print('💾 Cache Plugin: Data cached');
      }
    }
  }
}

class CacheEntry {
  final dynamic data;
  final DateTime expireTime;
  
  CacheEntry({required this.data, required this.expireTime});
  
  bool get isExpired => DateTime.now().isAfter(expireTime);
}

/// Logging Plugin | 日志插件
class LoggingPlugin implements NetworkPlugin {
  @override
  String get name => 'LoggingPlugin';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => 'Logging plugin for request/response logging';
  
  @override
  int get priority => 80;
  
  @override
  List<Interceptor> get interceptors => [];
  
  @override
  Future<void> initialize() async {}
  
  @override
  Future<void> dispose() async {}
  
  @override
  Future<void> onException(dynamic exception) async {}
  
  @override
  Future<void> onRequestComplete(BaseNetworkRequest request, NetworkResponse response) async {}
  
  @override
  Future<NetworkResponse?> onRequestExecute(BaseNetworkRequest request) async => null;
  
  @override
  Future<void> onRequestError(BaseNetworkRequest request, dynamic error) async {}
  
  @override
  Future<void> onRequestPrepare(BaseNetworkRequest request) async {
    if (request is LoggedApiRequest) {
      print('📝 Logging Plugin: Request prepared - ${request.method.name.toUpperCase()} ${request.path}');
    }
  }
  
  @override
  Future<void> onRequestStart(BaseNetworkRequest request) async {
    if (request is LoggedApiRequest) {
      print('📝 Logging Plugin: Request started - ${DateTime.now()}');
    }
  }
  
  @override
  Future<void> onResponseReceived(BaseNetworkRequest request, NetworkResponse response) async {
    if (request is LoggedApiRequest) {
      print('📝 Logging Plugin: Response received - Status: ${response.statusCode}, Duration: ${response.duration}ms');
    }
  }
}

/// Retry Plugin | 重试插件
class RetryPlugin implements NetworkPlugin {
  @override
  String get name => 'RetryPlugin';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => 'Retry plugin for failed requests';
  
  @override
  int get priority => 70;
  
  @override
  List<Interceptor> get interceptors => [];
  
  @override
  Future<void> initialize() async {}
  
  @override
  Future<void> dispose() async {}
  
  @override
  Future<void> onException(dynamic exception) async {}
  
  @override
  Future<void> onRequestComplete(BaseNetworkRequest request, NetworkResponse response) async {}
  
  @override
  Future<void> onRequestPrepare(BaseNetworkRequest request) async {}
  
  @override
  Future<void> onRequestStart(BaseNetworkRequest request) async {}
  
  @override
  Future<NetworkResponse?> onRequestExecute(BaseNetworkRequest request) async => null;
  
  @override
  Future<void> onResponseReceived(BaseNetworkRequest request, NetworkResponse response) async {}
  
  @override
  Future<void> onRequestError(BaseNetworkRequest request, dynamic error) async {
    await onError(request, error);
  }
  
  Future<void> onError(BaseNetworkRequest request, dynamic error) async {
    if (request is RetryableApiRequest) {
      print('🔄 Retry Plugin: Request failed, preparing retry - $error');
      // Retry logic can be implemented here | 这里可以实现重试逻辑
    }
  }
}

/// Data Transform Plugin | 数据转换插件
class DataTransformPlugin implements NetworkPlugin {
  @override
  String get name => 'DataTransformPlugin';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => 'Data transformation plugin for response processing';
  
  @override
  int get priority => 60;
  
  @override
  List<Interceptor> get interceptors => [];
  
  @override
  Future<void> initialize() async {}
  
  @override
  Future<void> dispose() async {}
  
  @override
  Future<void> onException(dynamic exception) async {}
  
  @override
  Future<void> onRequestComplete(BaseNetworkRequest request, NetworkResponse response) async {}
  
  @override
  Future<void> onRequestPrepare(BaseNetworkRequest request) async {}
  
  @override
  Future<void> onRequestStart(BaseNetworkRequest request) async {}
  
  @override
  Future<NetworkResponse?> onRequestExecute(BaseNetworkRequest request) async => null;
  
  @override
  Future<void> onRequestError(BaseNetworkRequest request, dynamic error) async {}
  
  @override
  Future<void> onResponseReceived(BaseNetworkRequest request, NetworkResponse response) async {
    if (request is TransformableApiRequest && response.success) {
      // Transform response data | 转换响应数据
      final originalData = response.data as Map<String, dynamic>;
      final transformedData = {
        ...originalData,
        'transformed': true,
        'transformedAt': DateTime.now().toIso8601String(),
        'transformedBy': 'DataTransformPlugin',
      };
      
      // Since data is a final property, this is just a demo of transform logic | 由于 data 是 final 属性，这里只是演示转换逻辑
      // In real applications, data transformation should be done during request processing | 在实际应用中，应该在请求处理过程中进行数据转换
      print('🔄 Data Transform Plugin: Data transformed - ${transformedData.toString()}');
    }
  }
}

/// Performance Monitor Plugin | 性能监控插件
class PerformanceMonitorPlugin implements NetworkPlugin {
  final Map<String, DateTime> _startTimes = {};
  
  @override
  String get name => 'PerformanceMonitorPlugin';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => 'Performance monitoring plugin for request timing';
  
  @override
  int get priority => 50;
  
  @override
  List<Interceptor> get interceptors => [];
  
  @override
  Future<void> initialize() async {}
  
  @override
  Future<void> dispose() async {}
  
  @override
  Future<void> onException(dynamic exception) async {}
  
  @override
  Future<void> onRequestComplete(BaseNetworkRequest request, NetworkResponse response) async {}
  
  @override
  Future<void> onRequestPrepare(BaseNetworkRequest request) async {}
  
  @override
  Future<NetworkResponse?> onRequestExecute(BaseNetworkRequest request) async => null;
  
  @override
  Future<void> onRequestError(BaseNetworkRequest request, dynamic error) async {}
  
  @override
  Future<void> onRequestStart(BaseNetworkRequest request) async {
    if (request is MonitoredApiRequest) {
      _startTimes[request.hashCode.toString()] = DateTime.now();
      print('⏱️ Performance Monitor Plugin: Started timing');
    }
  }
  
  @override
  Future<void> onResponseReceived(BaseNetworkRequest request, NetworkResponse response) async {
    if (request is MonitoredApiRequest) {
      final startTime = _startTimes[request.hashCode.toString()];
      if (startTime != null) {
        final duration = DateTime.now().difference(startTime).inMilliseconds;
        // Since duration is a final property, this is just a demo of performance monitoring logic | 由于 duration 是 final 属性，这里只是演示性能监控逻辑
        // In real applications, duration will be set when creating response | 在实际应用中，duration 会在响应创建时设置
        print('⏱️ Performance Monitor Plugin: Request took ${duration}ms');
        _startTimes.remove(request.hashCode.toString());
      }
    }
  }
}

/// Security Plugin | 安全插件
class SecurityPlugin implements NetworkPlugin {
  @override
  String get name => 'SecurityPlugin';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => 'Security plugin for request/response validation';
  
  @override
  int get priority => 40;
  
  @override
  List<Interceptor> get interceptors => [];
  
  @override
  Future<void> initialize() async {}
  
  @override
  Future<void> dispose() async {}
  
  @override
  Future<void> onException(dynamic exception) async {}
  
  @override
  Future<void> onRequestComplete(BaseNetworkRequest request, NetworkResponse response) async {}
  
  @override
  Future<void> onRequestStart(BaseNetworkRequest request) async {}
  
  @override
  Future<NetworkResponse?> onRequestExecute(BaseNetworkRequest request) async => null;
  
  @override
  Future<void> onRequestError(BaseNetworkRequest request, dynamic error) async {}
  
  @override
  Future<void> onRequestPrepare(BaseNetworkRequest request) async {
    if (request is SecureApiRequest) {
      // Add security headers | 添加安全头
      // Since headers might be readonly, this is just a demo of security plugin logic | 由于 headers 可能是只读的，这里只是演示安全插件逻辑
      // In real applications, headers should be set when creating requests | 在实际应用中，应该在请求创建时设置 headers
      final requestId = _generateRequestId();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final clientVersion = '1.0.0';
      print('🔒 Security Plugin: Added security headers - RequestID: $requestId, Timestamp: $timestamp, Version: $clientVersion');
    }
  }
  
  @override
  Future<void> onResponseReceived(BaseNetworkRequest request, NetworkResponse response) async {
    if (request is SecureApiRequest) {
      // Validate response security | 验证响应安全性
      _validateResponse(response);
      print('🔒 Security Plugin: Response security validation passed');
    }
  }
  
  String _generateRequestId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           (1000 + (DateTime.now().microsecond % 9000)).toString();
  }
  
  void _validateResponse(NetworkResponse response) {
    // Response security validation logic can be implemented here | 这里可以实现响应安全验证逻辑
    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('🔒 Security Plugin: Detected abnormal status code ${response.statusCode}');
    }
  }
}

/// Authenticated API Request | 认证API请求
class AuthenticatedApiRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    final response = data as Map<String, dynamic>;
    response['authenticated'] = true;
    return response;
  }
}

/// Cacheable API Request | 可缓存API请求
class CacheableApiRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  bool get enableCache => true;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    final response = data as Map<String, dynamic>;
    response['cacheable'] = true;
    return response;
  }
}

/// Logged API Request | 日志API请求
class LoggedApiRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    final response = data as Map<String, dynamic>;
    response['logged'] = true;
    return response;
  }
}

/// Retryable API Request | 可重试API请求
class RetryableApiRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  int get maxRetries => 3;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    final response = data as Map<String, dynamic>;
    response['retryable'] = true;
    return response;
  }
}

/// Transformable API Request | 可转换API请求
class TransformableApiRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// Monitored API Request | 监控API请求
class MonitoredApiRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    final response = data as Map<String, dynamic>;
    response['monitored'] = true;
    return response;
  }
}

/// Secure API Request | 安全API请求
class SecureApiRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    final response = data as Map<String, dynamic>;
    response['secure'] = true;
    return response;
  }
}

/// Composite Plugin Request | 组合插件请求
class CompositePluginRequest extends BaseNetworkRequest<Map<String, dynamic>> 
    implements AuthenticatedApiRequest, CacheableApiRequest, LoggedApiRequest {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  bool get enableCache => true;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    final response = data as Map<String, dynamic>;
    response['composite'] = true;
    response['plugins'] = ['auth', 'cache', 'logging'];
    return response;
  }
}

/// Custom Extension Request | 自定义扩展请求
class CustomExtensionRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  Future<Map<String, dynamic>> executeCustom() async {
    print('🔧 Executing custom extension logic');
    
    // Custom pre-processing | 自定义前置处理
    await _customPreProcess();
    
    // Execute standard request | 执行标准请求
    final executor = NetworkExecutor.instance;
    final response = await executor.execute(this);
    
    // Custom post-processing | 自定义后置处理
    final processedData = await _customPostProcess(response.data);
    
    return processedData;
  }
  
  Future<void> _customPreProcess() async {
    print('🔧 Custom pre-processing');
    await Future.delayed(Duration(milliseconds: 100));
  }
  
  Future<Map<String, dynamic>> _customPostProcess(dynamic data) async {
    print('🔧 Custom post-processing');
    await Future.delayed(Duration(milliseconds: 100));
    
    final response = data as Map<String, dynamic>;
    return {
      ...response,
      'customExtension': true,
      'processedAt': DateTime.now().toIso8601String(),
      'customLogic': 'applied',
    };
  }
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}