import 'package:flutter_test/flutter_test.dart';
import '../bzy_network_framework.dart';

void main() {
  group('BZY Network Framework Tests', () {
    test('framework constants should be defined', () {
      expect(bzyNetworkFrameworkName, equals('BZY Network Framework'));
      expect(bzyNetworkFrameworkVersion, equals('1.0.0'));
    });

    test('framework should export core components', () {
      // Basic smoke test to ensure the framework can be imported
      expect(bzyNetworkFrameworkName, isNotNull);
      expect(bzyNetworkFrameworkVersion, isNotNull);
    });
  });
}