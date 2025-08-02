import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/bzy_network_framework.dart';

void main() {
  group('Simple Batch Request Tests', () {
    test('BatchRequest type check', () {
      final batchRequest = BatchRequest([
        SimpleApiRequest(id: 1),
        SimpleApiRequest(id: 2),
      ]);
      
      expect(batchRequest is BatchRequest, true);
      expect(batchRequest is BaseNetworkRequest, true);
      expect(batchRequest.requests.length, 2);
      
      print('BatchRequest type: ${batchRequest.runtimeType}');
      print('Is BatchRequest: ${batchRequest is BatchRequest}');
      print('Requests count: ${batchRequest.requests.length}');
    });
  });
}