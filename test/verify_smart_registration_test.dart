import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/bzy_network_framework.dart';
import 'package:dio/dio.dart';

class TestInterceptor extends PluginInterceptor {
  @override
  String get name => 'TestInterceptor';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => '测试拦截器';
  
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    handler.next(options);
  }
  
  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    handler.next(response);
  }
  
  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    handler.next(err);
  }
}

void main() {
  group('智能注册策略和便捷方法验证', () {
    late InterceptorManager manager;
    
    setUp(() {
      manager = InterceptorManager.instance;
      manager.safeReset();
    });
    
    test('智能注册策略 - 首次注册应该成功', () {
      final success = manager.registerInterceptorSmart(
        'test1',
        TestInterceptor(),
        strategy: InterceptorRegistrationStrategy.strict,
      );
      
      expect(success, isTrue);
      expect(manager.hasInterceptor('test1'), isTrue);
    });
    
    test('智能注册策略 - 重复注册应该跳过', () {
      // 首次注册
      manager.registerInterceptorSmart(
        'test2',
        TestInterceptor(),
        strategy: InterceptorRegistrationStrategy.strict,
      );
      
      // 重复注册 - 应该跳过
      final success = manager.registerInterceptorSmart(
        'test2',
        TestInterceptor(),
        strategy: InterceptorRegistrationStrategy.skip,
      );
      
      expect(success, isFalse);
    });
    
    test('智能注册策略 - 强制替换', () {
      // 首次注册
      manager.registerInterceptorSmart(
        'test3',
        TestInterceptor(),
        strategy: InterceptorRegistrationStrategy.strict,
      );
      
      // 强制替换
      final success = manager.registerInterceptorSmart(
        'test3',
        TestInterceptor(),
        strategy: InterceptorRegistrationStrategy.replace,
      );
      
      expect(success, isTrue);
    });
    
    test('安全注册功能', () {
      final success = manager.safeRegister('safe_test', TestInterceptor());
      expect(success, isTrue);
      expect(manager.hasInterceptor('safe_test'), isTrue);
    });
    
    test('条件注册功能', () {
      final success = manager.registerIf(
        'conditional_test',
        TestInterceptor(),
        true,
      );
      
      expect(success, isTrue);
      expect(manager.hasInterceptor('conditional_test'), isTrue);
    });
    
    test('批量注册功能', () {
      final interceptors = {
        'batch1': TestInterceptor(),
        'batch2': TestInterceptor(),
        'batch3': TestInterceptor(),
      };
      
      final results = manager.registerInterceptorsBatch(interceptors);
      
      expect(results.length, equals(3));
      expect(results.contains('batch1'), isTrue);
      expect(results.contains('batch2'), isTrue);
      expect(results.contains('batch3'), isTrue);
      
      expect(manager.hasInterceptor('batch1'), isTrue);
      expect(manager.hasInterceptor('batch2'), isTrue);
      expect(manager.hasInterceptor('batch3'), isTrue);
    });
    
    test('常用拦截器注册', () {
      manager.registerCommonInterceptors();
      
      // 检查是否注册了常用拦截器
      expect(manager.hasInterceptor('header'), isTrue);
      expect(manager.hasInterceptor('logging'), isTrue);
      expect(manager.hasInterceptor('retry'), isTrue);
    });
    
    test('统计信息获取', () {
      manager.registerInterceptorSmart('stats_test', TestInterceptor());
      
      final stats = manager.statistics;
      final metrics = stats.getAllMetrics();
      
      expect(metrics, isNotNull);
    });
    
    test('安全重置功能', () {
      // 注册一些拦截器
      manager.registerInterceptorSmart('reset_test1', TestInterceptor());
      manager.registerInterceptorSmart('reset_test2', TestInterceptor());
      
      expect(manager.hasInterceptor('reset_test1'), isTrue);
      expect(manager.hasInterceptor('reset_test2'), isTrue);
      
      // 安全重置
      manager.safeReset();
      
      expect(manager.hasInterceptor('reset_test1'), isFalse);
      expect(manager.hasInterceptor('reset_test2'), isFalse);
    });
  });
}