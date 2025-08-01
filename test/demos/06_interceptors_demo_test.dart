import 'package:bzy_network_framework/bzy_network_framework.dart';

import 'package:test/test.dart';

/// Interceptor Functionality Examples
/// Demonstrates the usage of authentication, logging, response transformation and custom interceptors

void main() {
  group('Interceptor Functionality Tests', () {
    setUpAll(() async {
      print('=== Interceptor Functionality Demo ===\n');
      
      // Initialize framework
      await UnifiedNetworkFramework.instance.initialize(
        baseUrl: 'https://jsonplaceholder.typicode.com',
      );
    });
    
    test('Authentication Interceptor Test', () async {
      await _demonstrateAuthenticationInterceptor();
    });
    
    test('Logging Interceptor Test', () async {
      await _demonstrateLoggingInterceptor();
    });
    
    test('Response Transform Interceptor Test', () async {
      await _demonstrateResponseTransformInterceptor();
    });
    
    test('Custom Interceptor Test', () async {
      await _demonstrateCustomInterceptor();
    });
  });
}

/// Demonstrate authentication interceptor
Future<void> _demonstrateAuthenticationInterceptor() async {
  print('--- Authentication Interceptor ---');
  
  final request = AuthenticatedRequest();
  
  try {
    final response = await NetworkExecutor.instance.execute(request);
    print('Authentication request successful: ${response.data}');
  } catch (e) {
    print('Authentication request failed: $e');
  }
  
  print('');
}

/// Demonstrate logging interceptor
Future<void> _demonstrateLoggingInterceptor() async {
  print('--- Logging Interceptor ---');
  
  final request = LoggedRequest();
  
  try {
    final response = await NetworkExecutor.instance.execute(request);
    print('Logging request completed');
  } catch (e) {
    print('Logging request failed: $e');
  }
  
  print('');
}

/// Demonstrate response transform interceptor
Future<void> _demonstrateResponseTransformInterceptor() async {
  print('--- Response Transform Interceptor ---');
  
  final request = TransformableRequest();
  
  try {
    final response = await NetworkExecutor.instance.execute(request);
    print('Transformed response: ${response.data}');
  } catch (e) {
    print('Response transformation failed: $e');
  }
  
  print('');
}

/// Demonstrate custom interceptor
Future<void> _demonstrateCustomInterceptor() async {
  print('--- Custom Interceptor ---');
  
  final request = CustomInterceptorRequest();
  
  try {
    final response = await NetworkExecutor.instance.execute(request);
    print('Custom interceptor request successful: ${response.data}');
  } catch (e) {
    print('Custom interceptor request failed: $e');
  }
  
  print('');
}



/// Authentication interceptor (simplified version)
class AuthenticationInterceptor {
  void addAuthHeader(Map<String, dynamic> headers) {
    headers['Authorization'] = 'Bearer fake-token-12345';
    print('Authentication interceptor: Adding auth header');
  }
}

/// Logging interceptor (simplified version)
class LoggingInterceptor {
  void logRequest(String method, String path, dynamic data) {
    print('Logging interceptor: $method $path');
    if (data != null) {
      print('Logging interceptor: Request data $data');
    }
  }
  
  void logResponse(int statusCode, dynamic data) {
    print('Logging interceptor: Response status code $statusCode');
    print('Logging interceptor: Response data $data');
  }
  
  void logError(String error) {
    print('Logging interceptor: Request error $error');
  }
}

/// Response transform interceptor (simplified version)
class ResponseTransformInterceptor {
  Map<String, dynamic> transformResponse(Map<String, dynamic> data) {
    data['transformed'] = true;
    data['transformTime'] = DateTime.now().toIso8601String();
    print('Response transform interceptor: Data transformed');
    return data;
  }
}

/// Custom request interceptor (simplified version)
class CustomRequestInterceptor {
  void addCustomHeaders(Map<String, dynamic> headers) {
    headers['X-Custom-Header'] = 'CustomValue';
    headers['X-Request-Time'] = DateTime.now().millisecondsSinceEpoch.toString();
    print('Custom interceptor: Adding custom headers');
  }
}

/// Request requiring authentication
class AuthenticatedRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  bool get requiresAuth => true;
  
  @override
  Map<String, dynamic>? get headers {
    final authInterceptor = AuthenticationInterceptor();
    final headers = <String, dynamic>{};
    authInterceptor.addAuthHeader(headers);
    return headers;
  }
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// Request requiring logging
class LoggedRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/2';
  
  @override
  void onRequestStart() {
    final logger = LoggingInterceptor();
    logger.logRequest(method.value, path, data);
  }
  
  @override
  void onRequestComplete(NetworkResponse<Map<String, dynamic>> response) {
    final logger = LoggingInterceptor();
    logger.logResponse(response.statusCode ?? 200, response.data);
  }
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// Request requiring response transformation
class TransformableRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/3';
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    final transformer = ResponseTransformInterceptor();
    return transformer.transformResponse(data as Map<String, dynamic>);
  }
}

/// Request using custom interceptor
class CustomInterceptorRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/4';
  
  @override
  Map<String, dynamic>? get headers {
    final customInterceptor = CustomRequestInterceptor();
    final headers = <String, dynamic>{};
    customInterceptor.addCustomHeaders(headers);
    return headers;
  }
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}