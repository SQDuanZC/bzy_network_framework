import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/bzy_network_framework.dart';

/// Advanced Network Request Examples
/// Demonstrates custom headers, timeout, retry, priority and other advanced features
void main() {
  group('Advanced Network Request Examples', () {
    setUpAll(() async {
      // Initialize network framework
      await UnifiedNetworkFramework.instance.initialize(
        baseUrl: 'https://jsonplaceholder.typicode.com',
        config: {
          'enableLogging': true,
          'connectTimeout': 10000,
          'receiveTimeout': 10000,
          'maxRetries': 3,
          'retryDelay': 1000,
        },
      );
    });

    test('Request with Custom Headers', () async {
      final request = RequestWithCustomHeaders();
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await executor.execute(request);
        print('Custom headers request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('Custom headers request failed: $e');
      }
    });

    test('Request with Timeout Configuration', () async {
      final request = RequestWithTimeout();
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await executor.execute(request);
        print('Timeout configuration request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('Timeout configuration request failed: $e');
      }
    });

    test('High Priority Request', () async {
      final request = HighPriorityRequest();
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await executor.execute(request);
        print('High priority request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('High priority request failed: $e');
      }
    });

    test('Request with Retry Mechanism', () async {
      final request = RequestWithRetry();
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await executor.execute(request);
        print('Retry mechanism request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('Retry mechanism request failed: $e');
      }
    });

    test('Authenticated Request', () async {
      final request = AuthenticatedRequest();
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await executor.execute(request);
        print('Authentication request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('Authentication request failed: $e');
      }
    });
  });
}

/// Request with custom headers
class RequestWithCustomHeaders extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  Map<String, dynamic>? get headers => {
    'X-Custom-Header': 'CustomValue',
    'User-Agent': 'MyApp/1.0',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
  };
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// Request with timeout configuration
class RequestWithTimeout extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  int? get timeout => 5000; // 5 seconds timeout
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// High priority request
class HighPriorityRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  RequestPriority get priority => RequestPriority.high;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// Request with retry mechanism
class RequestWithRetry extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  int get retryCount => 3;
  
  @override
  int get retryDelay => 2000; // 2 seconds retry interval
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// Authenticated request
class AuthenticatedRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  bool get requiresAuth => true;
  
  @override
  Map<String, dynamic>? get headers => {
    'Authorization': 'Bearer your-token-here',
  };
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}