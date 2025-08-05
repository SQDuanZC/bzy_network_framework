import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/src/core/interceptor/interceptor_manager.dart';
import 'package:bzy_network_framework/src/core/interceptor/header_interceptor.dart';
import 'package:bzy_network_framework/src/config/network_config.dart';
import 'package:bzy_network_framework/src/utils/network_logger.dart';
import 'package:logging/logging.dart';

void main() {
  group('插件功能测试', () {
    late InterceptorManager interceptorManager;

    setUp(() {
      NetworkConfig.instance.initialize(
        baseUrl: 'https://api.example.com',
        enableLogging: true,
      );

      interceptorManager = InterceptorManager.instance;

      NetworkLogger.configure(
        level: Level.INFO,
        enableConsoleOutput: false,
      );
    });

    group('拦截器管理器测试', () {
      test('拦截器管理器单例模式', () {
        final manager1 = InterceptorManager.instance;
        final manager2 = InterceptorManager.instance;
        expect(manager1, same(manager2));
      });

      test('拦截器统计信息', () {
        final stats = interceptorManager.statistics;
        expect(stats, isNotNull);
      });
    });

    group('头部拦截器测试', () {
      test('头部拦截器创建', () {
        final interceptor = HeaderInterceptor();
        expect(interceptor, isNotNull);
      });

      test('添加和删除静态头部', () {
        final interceptor = HeaderInterceptor();

        interceptor.addStaticHeader('Authorization', 'Bearer token');
        interceptor.addStaticHeader('Content-Type', 'application/json');

        interceptor.removeStaticHeader('Content-Type');
      });
    });

    group('拦截器错误处理测试', () {
      test('注销不存在的拦截器', () {
        final removed = interceptorManager.unregisterInterceptor('nonexistent');
        expect(removed, false);
      });
    });
  });
} 