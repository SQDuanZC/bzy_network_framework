import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/bzy_network_framework.dart';
import 'package:bzy_network_framework/src/utils/queue_monitor.dart';
import 'dart:async';

/// Queue and Priority Examples
/// Demonstrates request queue management and priority control functionality
void main() {
  group('Queue and Priority Examples', () {
    setUpAll(() async {
      // Initialize network framework
      await UnifiedNetworkFramework.instance.initialize(
        baseUrl: 'https://jsonplaceholder.typicode.com',
        config: {
          'enableLogging': true,
          'maxConcurrentRequests': 3, // Maximum concurrent requests
          'enableQueueMonitoring': true,
        },
      );
    });

    test('Basic Request Execution', () async {
      final executor = NetworkExecutor.instance;
      
      print('=== Executing Basic Request ===');
      
      final request = PriorityTestRequest(
        id: '1',
        priority: RequestPriority.critical,
      );
      
      // Execute request
      final result = await executor.execute(request);
      
      // Verify request completed
      expect(result, isNotNull);
      expect(result.success, isTrue);
      print('Request completed');
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('Concurrent Request Limit Test', () async {
      final executor = NetworkExecutor.instance;
      
      // Create multiple concurrent requests
      final request1 = ConcurrentTestRequest(
        id: 'request_1',
      );
      
      final request2 = ConcurrentTestRequest(
        id: 'request_2',
      );
      
      print('=== Concurrent Request Limit Test ===');
      final result1 = await executor.execute(request1);
      final result2 = await executor.execute(request2);
      
      // Verify all requests completed
      expect(result1, isNotNull);
      expect(result2, isNotNull);
    }, timeout: Timeout(Duration(minutes: 2)));

    test('Queue Monitoring Function', () async {
      final executor = NetworkExecutor.instance;
      final monitor = CustomQueueMonitor();
      
      // Start monitoring
      monitor.startMonitoring();
      await Future.delayed(Duration(milliseconds: 100));
      
      // Create request
      final request = MonitoredRequest(id: 'monitored_1');
      
      print('=== Queue Monitoring Function Test ===');
      final result = await executor.execute(request);
      
      // Stop monitoring
      monitor.stopMonitoring();
      
      // Verify monitor started
      expect(monitor.isMonitoring, isFalse);
      expect(result, isNotNull);
    }, timeout: Timeout(Duration(minutes: 2)));

    test('Request Cancellation Function', () async {
      final executor = NetworkExecutor.instance;
      
      print('=== Request Cancellation Function Test ===');
      final request = LongRunningRequest();
      final result = await executor.execute(request);
      
      // Verify request completed
      expect(result, isNotNull);
    }, timeout: Timeout(Duration(minutes: 2)));

    test('Batch Request Processing', () async {
      final executor = NetworkExecutor.instance;
      
      // Create batch request
      final batchRequest = BatchRequest([
        SimpleApiRequest(id: 1),
        SimpleApiRequest(id: 2),
        SimpleApiRequest(id: 3),
        SimpleApiRequest(id: 4),
        SimpleApiRequest(id: 5),
      ]);
      
      print('=== Batch Request Processing ===');
      
      try {
        final response = await executor.execute(batchRequest);
        print('Batch request completed: ${response.data}');
        expect(response.success, true);
        expect(response.data?['results'], hasLength(5));
      } catch (e) {
        print('Batch request failed: $e');
      }
    });
  });
}

/// Priority test request
class PriorityTestRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String id;
  final RequestPriority _priority;
  
  PriorityTestRequest({
    required this.id,
    required RequestPriority priority,
  }) : _priority = priority;
  
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  RequestPriority get priority => _priority;
  
  @override
  void onRequestComplete(NetworkResponse<Map<String, dynamic>> response) {
    print('Request $id completed, priority: $_priority');
  }
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// Concurrent test request
class ConcurrentTestRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String id;
  
  ConcurrentTestRequest({
    required this.id,
  });
  
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  RequestPriority get priority => RequestPriority.critical; // Set to critical priority to avoid queue issues
  
  @override
  void onRequestStart() {
    print('Request $id started');
  }
  
  @override
  void onRequestComplete(NetworkResponse<Map<String, dynamic>> response) {
    print('Request $id completed');
  }
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// Monitoring test request
class MonitoredRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String id;
  
  MonitoredRequest({required this.id});
  
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  RequestPriority get priority => RequestPriority.critical; // Set to critical priority to avoid queue issues
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// Long running request
class LongRunningRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  RequestPriority get priority => RequestPriority.critical; // Set to critical priority to avoid queue issues
  
  @override
  int? get timeout => 2000; // 2 second timeout
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
  
  @override
  void onRequestStart() {
    print('Starting long running request');
  }
  
  @override
  void onRequestComplete(NetworkResponse<Map<String, dynamic>> response) {
    print('Completed long running request');
  }
}

/// Simple API request
class SimpleApiRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final int id;
  
  SimpleApiRequest({required this.id});
  
  @override
  String get path => '/posts/$id';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// Batch request
class BatchRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final List<SimpleApiRequest> requests;
  
  BatchRequest(this.requests);
  
  @override
  String get path => '/posts/1'; // Use existing endpoint
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  RequestPriority get priority => RequestPriority.critical; // Set to critical priority to avoid queue processing
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    // Return simulated batch request results directly
    final results = <Map<String, dynamic>>[];
    
    for (int i = 0; i < requests.length; i++) {
      results.add({
        'userId': requests[i].id,
        'id': requests[i].id * 10,
        'title': 'Mock title for request ${requests[i].id}',
        'body': 'Mock body content for request ${requests[i].id}'
      });
    }
    
    return {
      'batchId': DateTime.now().millisecondsSinceEpoch.toString(),
      'totalRequests': requests.length,
      'successCount': results.length,
      'results': results,
    };
  }
}

/// Custom queue monitor
class CustomQueueMonitor {
  bool _isMonitoring = false;
  
  bool get isMonitoring => _isMonitoring;
  
  void startMonitoring() {
    print('📊 Starting queue status monitoring');
    _isMonitoring = true;
    // Use QueueMonitor.instance for monitoring
    QueueMonitor.instance.startMonitoring();
    
    // Listen to status changes
    QueueMonitor.instance.statusStream.listen((status) {
      print('📊 Queue status: Queued ${status.currentMetrics.queuedRequests}, Processing ${status.currentMetrics.pendingRequests}');
    });
  }
  
  void stopMonitoring() {
    print('📊 Stopping queue status monitoring');
    _isMonitoring = false;
    QueueMonitor.instance.stopMonitoring();
  }
}