import 'package:test/test.dart';
import 'unified_exception_test.dart' as unified_exception_test;
import 'test_config.dart';

/// 统一异常处理测试套件
/// 运行所有相关的测试用例
void main() {
  group('BZY Network Framework 测试套件', () {
    setUpAll(() async {
      print('🚀 开始运行 BZY Network Framework 测试套件');
      await TestConfig.setupTestEnvironment();
    });
    
    tearDownAll(() async {
      print('🏁 测试套件运行完成，清理环境');
      await TestConfig.cleanupTestEnvironment();
    });
    
    group('统一异常处理测试', () {
      unified_exception_test.main();
    });
    
    group('性能测试', () {
      unified_exception_test.performanceTest();
    });
    
    group('边界测试', () {
      unified_exception_test.boundaryTest();
    });
  });
}