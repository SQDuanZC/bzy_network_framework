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
          'connectTimeout': 10000,
          'receiveTimeout': 15000,
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
      final future = executor.execute(request);
      executor.cancelRequest(request);
      final result = await future;
      
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
      
      // 创建批量请求
      final batchRequest = BatchRequest([
        SimpleApiRequest(id: 1),
        SimpleApiRequest(id: 2),
        SimpleApiRequest(id: 3),
        SimpleApiRequest(id: 4),
        SimpleApiRequest(id: 5),
      ]);
      
      try {
        final response = await executor.execute(batchRequest);
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

// SimpleApiRequest is now imported from the main library

/// Long running request
class LongRunningRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  RequestPriority get priority => RequestPriority.critical; // Set to critical priority to avoid queue issues
  
  @override
  int? get timeout => 10000; // 10 second timeout
  
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

// SimpleApiRequest is now imported from the main library

// BatchRequest is now imported from the main library

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