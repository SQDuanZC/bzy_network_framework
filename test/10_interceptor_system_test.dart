import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:bzy_network_framework/src/core/interceptor/interceptor_manager.dart';
import 'package:bzy_network_framework/src/core/interceptor/header_interceptor.dart';
import 'package:bzy_network_framework/src/core/interceptor/network_status_interceptor.dart';
import 'package:bzy_network_framework/src/core/interceptor/http_status_interceptor.dart';
import 'package:bzy_network_framework/src/core/interceptor/logging_interceptor.dart';
import 'package:bzy_network_framework/src/core/interceptor/retry_interceptor.dart';
import 'package:bzy_network_framework/src/core/interceptor/performance_interceptor.dart';
import 'package:bzy_network_framework/src/config/network_config.dart';
import 'package:bzy_network_framework/src/utils/network_logger.dart';
import 'package:logging/logging.dart';

void main() {
  group('拦截器系统测试', () {
    late InterceptorManager interceptorManager;

    setUp(() {
      // 初始化网络配置
      NetworkConfig.instance.initialize(
        baseUrl: 'https://api.example.com',
        connectTimeout: 5000,
        receiveTimeout: 5000,
        sendTimeout: 5000,
      );

      // 配置日志
      NetworkLogger.configure(
        level: Level.INFO,
        enableConsoleOutput: false,
      );

      interceptorManager = InterceptorManager.instance;
      // 清理之前的拦截器
      interceptorManager.clear();
    });

    tearDown(() {
      // 清理拦截器
      interceptorManager.clear();
    });

    group('拦截器管理器基础功能', () {
      test('拦截器管理器单例模式', () {
        final manager1 = InterceptorManager.instance;
        final manager2 = InterceptorManager.instance;
        expect(manager1, same(manager2));
      });

      test('注册拦截器', () {
        final testInterceptor = TestPluginInterceptor('test');
        
        interceptorManager.registerInterceptor(
          'test',
          testInterceptor,
          config: InterceptorConfig(enabled: true, priority: 1),
        );

        final names = interceptorManager.getInterceptorNames();
        expect(names.contains('test'), isTrue);
      });

      test('注册重复名称拦截器应抛出异常', () {
        final testInterceptor1 = TestPluginInterceptor('test1');
        final testInterceptor2 = TestPluginInterceptor('test2');
        
        interceptorManager.registerInterceptor('test', testInterceptor1);
        
        expect(
          () => interceptorManager.registerInterceptor('test', testInterceptor2),
          throwsArgumentError,
        );
      });

      test('注销拦截器', () {
        final testInterceptor = TestPluginInterceptor('test');
        
        interceptorManager.registerInterceptor('test', testInterceptor);
        expect(interceptorManager.getInterceptorNames().contains('test'), isTrue);
        
        final result = interceptorManager.unregisterInterceptor('test');
        expect(result, isTrue);
        expect(interceptorManager.getInterceptorNames().contains('test'), isFalse);
      });

      test('注销不存在的拦截器', () {
        final result = interceptorManager.unregisterInterceptor('nonexistent');
        expect(result, isFalse);
      });
    });

    group('拦截器启用/禁用控制', () {
      test('启用拦截器', () {
        final testInterceptor = TestPluginInterceptor('test');
        
        interceptorManager.registerInterceptor(
          'test',
          testInterceptor,
          config: InterceptorConfig(enabled: false),
        );

        final result = interceptorManager.enableInterceptor('test');
        expect(result, isTrue);
        
        final enabledInterceptors = interceptorManager.getEnabledInterceptors();
        expect(enabledInterceptors.contains('test'), isTrue);
      });

      test('禁用拦截器', () {
        final testInterceptor = TestPluginInterceptor('test');
        
        interceptorManager.registerInterceptor(
          'test',
          testInterceptor,
          config: InterceptorConfig(enabled: true),
        );

        final result = interceptorManager.disableInterceptor('test');
        expect(result, isTrue);
        
        final enabledInterceptors = interceptorManager.getEnabledInterceptors();
        expect(enabledInterceptors.contains('test'), isFalse);
      });

      test('启用/禁用不存在的拦截器', () {
        expect(interceptorManager.enableInterceptor('nonexistent'), isFalse);
        expect(interceptorManager.disableInterceptor('nonexistent'), isFalse);
      });
    });

    group('拦截器配置管理', () {
      test('更新拦截器配置', () {
        final testInterceptor = TestPluginInterceptor('test');
        
        interceptorManager.registerInterceptor('test', testInterceptor);
        
        final newConfig = InterceptorConfig(
          enabled: false,
          priority: 10,
          timeout: Duration(seconds: 30),
        );
        
        final result = interceptorManager.updateInterceptorConfig('test', newConfig);
        expect(result, isTrue);
      });

      test('更新不存在拦截器的配置', () {
        final newConfig = InterceptorConfig(enabled: false);
        
        final result = interceptorManager.updateInterceptorConfig('nonexistent', newConfig);
        expect(result, isFalse);
      });
    });

    group('拦截器执行顺序', () {
      test('设置执行顺序', () {
        final interceptor1 = TestPluginInterceptor('test1');
        final interceptor2 = TestPluginInterceptor('test2');
        final interceptor3 = TestPluginInterceptor('test3');
        
        interceptorManager.registerInterceptor('test1', interceptor1);
        interceptorManager.registerInterceptor('test2', interceptor2);
        interceptorManager.registerInterceptor('test3', interceptor3);
        
        interceptorManager.setExecutionOrder(['test3', 'test1', 'test2']);
        
        final order = interceptorManager.getInterceptorNames();
        expect(order, equals(['test3', 'test1', 'test2']));
      });

      test('设置包含未注册拦截器的执行顺序应抛出异常', () {
        final interceptor1 = TestPluginInterceptor('test1');
        interceptorManager.registerInterceptor('test1', interceptor1);
        
        expect(
          () => interceptorManager.setExecutionOrder(['test1', 'nonexistent']),
          throwsArgumentError,
        );
      });

      test('基于优先级的拦截器排序', () {
        final interceptor1 = TestPluginInterceptor('low');
        final interceptor2 = TestPluginInterceptor('high');
        final interceptor3 = TestPluginInterceptor('medium');
        
        // 注册时指定优先级（数值越小优先级越高）
        interceptorManager.registerInterceptor('low', interceptor1, priority: 10);
        interceptorManager.registerInterceptor('high', interceptor2, priority: 1);
        interceptorManager.registerInterceptor('medium', interceptor3, priority: 5);
        
        final order = interceptorManager.getInterceptorNames();
        // 应该按优先级排序：high(1) -> medium(5) -> low(10)
        expect(order.indexOf('high'), lessThan(order.indexOf('medium')));
        expect(order.indexOf('medium'), lessThan(order.indexOf('low')));
      });
    });

    group('拦截器统计', () {
      test('获取拦截器统计', () {
        final statistics = interceptorManager.statistics;
        expect(statistics, isA<InterceptorStatistics>());
      });

      test('记录拦截器执行统计', () {
        final testInterceptor = TestPluginInterceptor('test');
        interceptorManager.registerInterceptor('test', testInterceptor);
        
        final statistics = interceptorManager.statistics;
        
        // 记录执行
        statistics.recordExecution(
          'test',
          InterceptorType.request,
          Duration(milliseconds: 100),
          true,
        );
        
        final metrics = statistics.getMetrics('test', InterceptorType.request);
        expect(metrics, isNotNull);
        expect(metrics!.totalExecutions, equals(1));
        expect(metrics.successfulExecutions, equals(1));
      });

      test('记录拦截器执行失败统计', () {
        final testInterceptor = TestPluginInterceptor('test');
        interceptorManager.registerInterceptor('test', testInterceptor);
        
        final statistics = interceptorManager.statistics;
        
        // 记录失败执行
        statistics.recordExecution(
          'test',
          InterceptorType.error,
          Duration(milliseconds: 50),
          false,
        );
        
        final metrics = statistics.getMetrics('test', InterceptorType.error);
        expect(metrics!.totalExecutions, equals(1));
        expect(metrics.failedExecutions, equals(1));
      });
    });

    group('内置拦截器工厂', () {
      test('创建日志拦截器', () {
        final loggingInterceptor = BuiltInInterceptors.createLoggingInterceptor();
        expect(loggingInterceptor, isA<LoggingInterceptor>());
        expect(loggingInterceptor.name, equals('logging'));
      });

      test('创建重试拦截器', () {
        final retryInterceptor = BuiltInInterceptors.createRetryInterceptor();
        expect(retryInterceptor, isA<RetryInterceptor>());
        expect(retryInterceptor.name, equals('retry'));
      });

      test('创建性能监控拦截器', () {
        final performanceInterceptor = PerformanceInterceptor();
        expect(performanceInterceptor, isA<PerformanceInterceptor>());
        expect(performanceInterceptor.name, equals('performance'));
      });
    });

    group('内置拦截器功能测试', () {
      test('日志拦截器基础功能', () async {
        final loggingInterceptor = LoggingInterceptor();
        
        expect(loggingInterceptor.name, equals('logging'));
        expect(loggingInterceptor.version, isNotEmpty);
        expect(loggingInterceptor.description, isNotEmpty);
        
        await loggingInterceptor.initialize();
        await loggingInterceptor.dispose();
      });

      test('性能监控拦截器基础功能', () async {
        final performanceInterceptor = PerformanceInterceptor();
        
        expect(performanceInterceptor.name, equals('performance'));
        expect(performanceInterceptor.version, isNotEmpty);
        expect(performanceInterceptor.description, isNotEmpty);
        
        await performanceInterceptor.initialize();
        await performanceInterceptor.dispose();
      });

      test('重试拦截器基础功能', () async {
        final retryInterceptor = RetryInterceptor();
        
        expect(retryInterceptor.name, equals('retry'));
        expect(retryInterceptor.version, isNotEmpty);
        expect(retryInterceptor.description, isNotEmpty);
        
        await retryInterceptor.initialize();
        await retryInterceptor.dispose();
      });
    });

    group('请求头拦截器测试', () {
      test('请求头拦截器创建', () {
        final headerInterceptor = HeaderInterceptor();
        expect(headerInterceptor, isA<Interceptor>());
      });

      test('设置和获取Token', () {
        final headerInterceptor = HeaderInterceptor();
        
        headerInterceptor.setToken('test_token');
        expect(headerInterceptor.token, equals('test_token'));
        
        headerInterceptor.clearTokens();
        expect(headerInterceptor.token, isNull);
      });

      test('设置和获取刷新Token', () {
        final headerInterceptor = HeaderInterceptor();
        
        headerInterceptor.setRefreshToken('refresh_token');
        expect(headerInterceptor.refreshToken, equals('refresh_token'));
        
        headerInterceptor.clearTokens();
        expect(headerInterceptor.refreshToken, isNull);
      });

      test('添加和移除静态请求头', () {
        final headerInterceptor = HeaderInterceptor();
        
        headerInterceptor.addStaticHeader('X-Custom-Header', 'custom_value');
        final headers = headerInterceptor.staticHeaders;
        expect(headers['X-Custom-Header'], equals('custom_value'));
        
        headerInterceptor.removeStaticHeader('X-Custom-Header');
        final updatedHeaders = headerInterceptor.staticHeaders;
        expect(updatedHeaders.containsKey('X-Custom-Header'), isFalse);
      });

      test('设置静态请求头', () {
        final headerInterceptor = HeaderInterceptor();
        
        headerInterceptor.setStaticHeaders({'Header1': 'value1', 'Header2': 'value2'});
        final headers = headerInterceptor.staticHeaders;
        expect(headers['Header1'], equals('value1'));
        expect(headers['Header2'], equals('value2'));
      });
    });

    group('拦截器配置测试', () {
      test('拦截器配置默认值', () {
        final config = InterceptorConfig();
        
        expect(config.enabled, isTrue);
        expect(config.priority, equals(0));
        expect(config.timeout, equals(Duration(seconds: 10)));
        expect(config.continueOnError, isTrue);
        expect(config.customConfig.isEmpty, isTrue);
      });

      test('拦截器配置自定义值', () {
        final config = InterceptorConfig(
          enabled: false,
          priority: 5,
          timeout: Duration(seconds: 30),
          continueOnError: false,
          customConfig: {'key': 'value'},
        );
        
        expect(config.enabled, isFalse);
        expect(config.priority, equals(5));
        expect(config.timeout, equals(Duration(seconds: 30)));
        expect(config.continueOnError, isFalse);
        expect(config.customConfig['key'], equals('value'));
      });
    });

    group('拦截器执行流程测试', () {
      test('拦截器优先级排序', () {
        final interceptor1 = TestPluginInterceptor('test1');
        final interceptor2 = TestPluginInterceptor('test2');
        
        interceptorManager.registerInterceptor('test1', interceptor1, priority: 2);
        interceptorManager.registerInterceptor('test2', interceptor2, priority: 1);
        
        final order = interceptorManager.getInterceptorNames();
        // 优先级低的数字应该排在前面
        expect(order.indexOf('test2'), lessThan(order.indexOf('test1')));
      });

      test('禁用的拦截器不在启用列表中', () {
        final interceptor = TestPluginInterceptor('test');
        
        interceptorManager.registerInterceptor(
          'test',
          interceptor,
          config: InterceptorConfig(enabled: false),
        );
        
        final enabledInterceptors = interceptorManager.getEnabledInterceptors();
        expect(enabledInterceptors.contains('test'), isFalse);
      });
    });

    group('错误处理和边界情况', () {
      test('拦截器注册异常处理', () {
        final faultyInterceptor = FaultyPluginInterceptor('faulty');
        
        interceptorManager.registerInterceptor(
          'faulty',
          faultyInterceptor,
          config: InterceptorConfig(continueOnError: true),
        );
        
        // 验证拦截器已注册
        final names = interceptorManager.getInterceptorNames();
        expect(names.contains('faulty'), isTrue);
      });

      test('拦截器配置验证', () {
        final slowInterceptor = SlowPluginInterceptor('slow');
        
        interceptorManager.registerInterceptor(
          'slow',
          slowInterceptor,
          config: InterceptorConfig(timeout: Duration(milliseconds: 100)),
        );
        
        // 验证拦截器已注册
        final names = interceptorManager.getInterceptorNames();
        expect(names.contains('slow'), isTrue);
      });

      test('空拦截器列表处理', () {
        // 清空所有拦截器
        interceptorManager.clear();
        
        // 没有注册任何拦截器时列表应该为空
        final names = interceptorManager.getInterceptorNames();
        expect(names.isEmpty, isTrue);
      });
    });

    group('拦截器重置和清理', () {
      test('清理拦截器管理器', () {
        final testInterceptor = TestPluginInterceptor('test');
        
        interceptorManager.registerInterceptor('test', testInterceptor);
        expect(interceptorManager.getInterceptorNames().isNotEmpty, isTrue);
        
        interceptorManager.clear();
        expect(interceptorManager.getInterceptorNames().isEmpty, isTrue);
      });

      test('重置拦截器统计', () {
        final statistics = interceptorManager.statistics;
        
        // 添加一些统计数据
        statistics.recordExecution(
          'test',
          InterceptorType.request,
          Duration(milliseconds: 100),
          true,
        );
        
        statistics.reset();
        
        final metrics = statistics.getMetrics('test', InterceptorType.request);
        expect(metrics, isNull);
      });
    });
  });
}

// 测试用的插件拦截器
class TestPluginInterceptor extends PluginInterceptor {
  final String _name;
  bool wasExecuted = false;
  int executionOrder = 0;
  static int _globalExecutionCounter = 0;

  TestPluginInterceptor(this._name);

  @override
  String get name => _name;

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Test interceptor';

  @override
  bool get supportsRequestInterception => true;

  @override
  bool get supportsResponseInterception => true;

  @override
  bool get supportsErrorInterception => true;

  @override
  Future<RequestOptions> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    wasExecuted = true;
    executionOrder = ++_globalExecutionCounter;
    return options;
  }

  @override
  Future<Response> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    wasExecuted = true;
    executionOrder = ++_globalExecutionCounter;
    return response;
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    wasExecuted = true;
    executionOrder = ++_globalExecutionCounter;
  }
}

// 故障拦截器（用于测试异常处理）
class FaultyPluginInterceptor extends PluginInterceptor {
  final String _name;

  FaultyPluginInterceptor(this._name);

  @override
  String get name => _name;

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Faulty test interceptor';

  @override
  bool get supportsRequestInterception => true;

  @override
  Future<RequestOptions> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    throw Exception('Interceptor execution failed');
  }
}

// 慢拦截器（用于测试超时）
class SlowPluginInterceptor extends PluginInterceptor {
  final String _name;

  SlowPluginInterceptor(this._name);

  @override
  String get name => _name;

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Slow test interceptor';

  @override
  bool get supportsRequestInterception => true;

  @override
  Future<RequestOptions> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 模拟慢操作
    await Future.delayed(Duration(seconds: 1));
    return options;
  }
}

// 模拟请求拦截器处理器
class MockRequestInterceptorHandler extends RequestInterceptorHandler {
  @override
  void next(RequestOptions requestOptions) {
    // 模拟继续执行
  }

  @override
  void resolve(Response response, [bool callFollowingResponseInterceptor = false]) {
    // 模拟解析响应
  }

  @override
  void reject(DioException err, [bool callFollowingErrorInterceptor = false]) {
    // 模拟拒绝请求
  }
}

