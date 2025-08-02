import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/bzy_network_framework.dart';
import 'dart:async';

void main() {
  group('Minimal Batch Request Tests', () {
    setUpAll(() async {
      // Initialize with minimal configuration
      NetworkConfig.instance.initialize(
        baseUrl: 'https://jsonplaceholder.typicode.com',
        connectTimeout: 5000,
        receiveTimeout: 10000,
        enableLogging: false,
      );
    });

    test('Simple Batch Request', () async {
      final executor = NetworkExecutor.instance;
      
      // Create a simple batch request with just one sub-request
      final batchRequest = BatchRequest([
        SimpleApiRequest(id: 1),
      ]);
      
      print('Starting batch request test...');
      
      try {
        final response = await executor.execute(batchRequest).timeout(
          Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException('Batch request timed out', Duration(seconds: 15));
          },
        );
        
        print('Batch request completed successfully');
        print('Response data: ${response.data}');
        
        expect(response.success, true);
        expect(response.data, isNotNull);
      } catch (e) {
        print('Batch request failed: $e');
        rethrow;
      }
    });
  });
}