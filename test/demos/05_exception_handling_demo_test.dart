import 'package:bzy_network_framework/bzy_network_framework.dart';

import 'package:test/test.dart';

/// Exception Handling Examples
/// Demonstrates handling of network timeout, HTTP status codes, JSON parsing, custom exceptions, retryable exceptions, and exception recovery

void main() {
  group('Exception Handling Function Tests', () {
    setUpAll(() async {
      // Initialize framework
      await UnifiedNetworkFramework.instance.initialize(
        baseUrl: 'https://jsonplaceholder.typicode.com',
      );
      
      // Register global exception handler
      UnifiedExceptionHandler.instance.registerGlobalHandler(
        CustomGlobalExceptionHandler(),
      );
    });
    
    test('Network Timeout Exception Test', () async {
      await _demonstrateTimeoutException();
    });
    
    test('HTTP Status Code Exception Test', () async {
      await _demonstrateHttpException();
    });
    
    test('JSON Parse Exception Test', () async {
      await _demonstrateJsonParseException();
    });
    
    test('Custom Exception Test', () async {
      await _demonstrateCustomException();
    });
    
    test('Retry Exception Test', () async {
      await _demonstrateRetryableException();
    });
    
    test('Exception Recovery Test', () async {
      await _demonstrateRecoverableException();
    });
  });
}

/// Demonstrate network timeout exception
Future<void> _demonstrateTimeoutException() async {
  print('--- Network Timeout Exception ---');
  
  final request = TimeoutRequest();
  
  try {
    final response = await NetworkExecutor.instance.execute(request);
    print('Timeout request successful: ${response.data}');
  } catch (e) {
    print('Timeout exception caught: $e');
    if (e is NetworkException) {
      print('Error code: ${e.errorCode}');
      print('Error message: ${e.message}');
    }
  }
  
  print('');
}

/// Demonstrate HTTP status code exception
Future<void> _demonstrateHttpException() async {
  print('--- HTTP Status Code Exception ---');
  
  final request = HttpErrorRequest();
  
  try {
    final response = await NetworkExecutor.instance.execute(request);
    print('HTTP request successful: ${response.data}');
  } catch (e) {
    print('HTTP exception caught: $e');
    if (e is NetworkException) {
      print('Error code: ${e.errorCode}');
      print('HTTP status code: ${e.statusCode}');
    }
  }
  
  print('');
}

/// Demonstrate JSON parse exception
Future<void> _demonstrateJsonParseException() async {
  print('--- JSON Parse Exception ---');
  
  final request = JsonParseErrorRequest();
  
  try {
    final response = await NetworkExecutor.instance.execute(request);
    print('JSON parse successful: ${response.data}');
  } catch (e) {
    print('JSON parse exception caught: $e');
    if (e is NetworkException) {
      print('Error code: ${e.errorCode}');
      print('Original data: ${e.originalData}');
    }
  }
  
  print('');
}

/// Demonstrate custom exception
Future<void> _demonstrateCustomException() async {
  print('--- Custom Exception ---');
  
  final request = CustomExceptionRequest();
  
  try {
    final response = await NetworkExecutor.instance.execute(request);
    print('Custom request successful: ${response.data}');
  } catch (e) {
    print('Custom exception caught: $e');
    if (e is CustomBusinessException) {
      print('Business error code: ${e.businessCode}');
      print('Business error message: ${e.businessMessage}');
    }
  }
  
  print('');
}

/// Demonstrate retryable exception handling
Future<void> _demonstrateRetryableException() async {
  print('--- Retryable Exception Handling ---');
  
  final request = RetryableErrorRequest();
  
  try {
    final response = await NetworkExecutor.instance.execute(request);
    print('Retry request successful: ${response.data}');
  } catch (e) {
    print('Still failed after retry: $e');
    if (e is NetworkException) {
      print('Retry count: ${e.retryCount}');
    }
  }
  
  print('');
}

/// Demonstrate exception recovery
Future<void> _demonstrateRecoverableException() async {
  print('--- Exception Recovery ---');
  
  final request = RecoverableErrorRequest();
  
  try {
    final response = await NetworkExecutor.instance.execute(request);
    print('Recovery request successful: ${response.data}');
  } catch (e) {
    print('Exception recovery failed: $e');
  }
  
  print('');
}



/// Timeout request
class TimeoutRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  int? get timeout => 1; // Very short timeout, guaranteed to timeout
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// HTTP error request
class HttpErrorRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/999999'; // Non-existent resource, returns 404
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// JSON parse error request
class JsonParseErrorRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    // Intentionally throw parse exception
    if (data is Map<String, dynamic>) {
      throw FormatException('Simulate JSON parse error');
    }
    return data as Map<String, dynamic>;
  }
}

/// Custom exception request
class CustomExceptionRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    // Simulate business logic exception
    final response = data as Map<String, dynamic>;
    if (response['id'] == 1) {
      throw CustomBusinessException(
        businessCode: 'BUSINESS_ERROR_001',
        businessMessage: 'Business rule validation failed',
        originalData: response,
      );
    }
    return response;
  }
}

/// Retryable error request
class RetryableErrorRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  int get maxRetries => 3;
  
  @override
  int get retryDelay => 1000;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    // Simulate intermittent error
    if (DateTime.now().millisecond % 2 == 0) {
      throw Exception('Simulate intermittent network error');
    }
    return data as Map<String, dynamic>;
  }
}

/// Recoverable error request
class RecoverableErrorRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
  
  @override
  void onRequestError(Exception error) {
    print('Attempting error recovery: $error');
    // Error recovery logic can be implemented here
  }
}

/// Custom business exception
class CustomBusinessException implements Exception {
  final String businessCode;
  final String businessMessage;
  final dynamic originalData;
  
  CustomBusinessException({
    required this.businessCode,
    required this.businessMessage,
    this.originalData,
  });
  
  @override
  String toString() {
    return 'CustomBusinessException: $businessCode - $businessMessage';
  }
}

/// Custom global exception handler
class CustomGlobalExceptionHandler implements GlobalExceptionHandler {
  @override
  bool canHandle(UnifiedException exception) {
    return exception.type == ExceptionType.network;
  }

  @override
  UnifiedException handle(UnifiedException exception) {
    print('Global exception handler processing exception: ${exception.message}');
    return exception;
  }

  @override
  Future<void> onException(UnifiedException exception) async {
    print('Global exception callback: ${exception.message}');
  }

  @override
  Future<void> handleException(Exception exception) async {
    print('=== Global Exception Handler ===');
    print('Exception type: ${exception.runtimeType}');
    print('Exception info: $exception');
    
    if (exception is NetworkException) {
      print('Network exception details:');
      print('  Error code: ${exception.errorCode}');
      print('  Error message: ${exception.message}');
      print('  Status code: ${exception.statusCode}');
      print('  Retry count: ${exception.retryCount}');
      
      // Handle different error types
      switch (exception.errorCode) {
        case 'TIMEOUT':
          print('  Handling strategy: Network timeout, suggest checking network connection');
          break;
        case 'HTTP_ERROR':
          print('  Handling strategy: HTTP error, check request parameters and server status');
          break;
        case 'PARSE_ERROR':
          print('  Handling strategy: Parse error, check data format');
          break;
        default:
          print('  Handling strategy: Generic error handling');
      }
    } else if (exception is CustomBusinessException) {
      print('Business exception details:');
      print('  Business error code: ${exception.businessCode}');
      print('  Business error message: ${exception.businessMessage}');
      print('  Original data: ${exception.originalData}');
      print('  Handling strategy: Business logic error, requires user handling');
    } else {
      print('Unknown exception, using default handling strategy');
    }
    
    // Exception logging, error reporting, etc. can be added here
    await _logException(exception);
    await _reportException(exception);
  }
  
  Future<void> _logException(Exception exception) async {
    // Simulate logging
    print('Exception logged to local log');
  }
  
  Future<void> _reportException(Exception exception) async {
    // Simulate error reporting
    print('Exception reported to error monitoring system');
  }
}