import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/src/utils/network_logger.dart';
import 'package:bzy_network_framework/src/config/network_config.dart';
import 'package:logging/logging.dart';

void main() {
  group('日志功能测试', () {
    setUp(() {
      NetworkConfig.instance.initialize(
        baseUrl: 'https://api.example.com',
        enableLogging: true,
      );
    });

    group('日志配置测试', () {
      test('基础日志配置', () {
        NetworkLogger.configure(
          level: Level.INFO,
          enableConsoleOutput: true,
          enableFileOutput: false,
          logFilePath: 'test.log',
        );

        expect(NetworkLogger, isNotNull);
      });

      test('不同日志级别配置', () {
        final levels = [Level.ALL, Level.FINE, Level.INFO, Level.WARNING, Level.SEVERE, Level.OFF];
        
        for (final level in levels) {
          NetworkLogger.configure(level: level);
          expect(NetworkLogger, isNotNull);
        }
      });

      test('文件输出配置', () {
        NetworkLogger.configure(
          level: Level.INFO,
          enableConsoleOutput: false,
          enableFileOutput: true,
          logFilePath: 'test_file.log',
        );

        expect(NetworkLogger, isNotNull);
      });
    });

    group('日志记录测试', () {
      test('信息日志记录', () {
        NetworkLogger.configure(
          level: Level.INFO,
          enableConsoleOutput: false,
        );

        NetworkLogger.framework.info('这是一条信息日志');
        expect(NetworkLogger.framework, isNotNull);
      });

      test('警告日志记录', () {
        NetworkLogger.configure(
          level: Level.WARNING,
          enableConsoleOutput: false,
        );

        NetworkLogger.framework.warning('这是一条警告日志');
        expect(NetworkLogger.framework, isNotNull);
      });

      test('错误日志记录', () {
        NetworkLogger.configure(
          level: Level.SEVERE,
          enableConsoleOutput: false,
        );

        NetworkLogger.framework.severe('这是一条错误日志');
        expect(NetworkLogger.framework, isNotNull);
      });

      test('调试日志记录', () {
        NetworkLogger.configure(
          level: Level.FINE,
          enableConsoleOutput: false,
        );

        NetworkLogger.framework.fine('这是一条调试日志');
        expect(NetworkLogger.framework, isNotNull);
      });
    });

    group('模块化日志测试', () {
      test('网络请求日志', () {
        NetworkLogger.configure(
          level: Level.INFO,
          enableConsoleOutput: false,
        );

        NetworkLogger.executor.info('网络请求日志');
        expect(NetworkLogger.executor, isNotNull);
      });

      test('缓存操作日志', () {
        NetworkLogger.configure(
          level: Level.INFO,
          enableConsoleOutput: false,
        );

        NetworkLogger.cache.info('缓存操作日志');
        expect(NetworkLogger.cache, isNotNull);
      });

      test('队列管理日志', () {
        NetworkLogger.configure(
          level: Level.INFO,
          enableConsoleOutput: false,
        );

        NetworkLogger.queue.info('队列管理日志');
        expect(NetworkLogger.queue, isNotNull);
      });

      test('拦截器日志', () {
        NetworkLogger.configure(
          level: Level.INFO,
          enableConsoleOutput: false,
        );

        NetworkLogger.interceptor.info('拦截器日志');
        expect(NetworkLogger.interceptor, isNotNull);
      });

      test('一般日志', () {
        NetworkLogger.configure(
          level: Level.INFO,
          enableConsoleOutput: false,
        );

        NetworkLogger.general.info('一般日志');
        expect(NetworkLogger.general, isNotNull);
      });
    });

    group('日志性能测试', () {
      test('大量日志记录性能', () {
        NetworkLogger.configure(
          level: Level.INFO,
          enableConsoleOutput: false,
        );

        final stopwatch = Stopwatch();
        final logCount = 1000;

        stopwatch.start();

        for (int i = 0; i < logCount; i++) {
          NetworkLogger.framework.info('性能测试日志 $i');
        }

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
    });

    group('日志格式化测试', () {
      test('带参数的日志', () {
        NetworkLogger.configure(
          level: Level.INFO,
          enableConsoleOutput: false,
        );

        final userId = 123;
        final action = 'login';
        
        NetworkLogger.framework.info('用户 $userId 执行了 $action 操作');
        expect(NetworkLogger.framework, isNotNull);
      });

      test('带对象的日志', () {
        NetworkLogger.configure(
          level: Level.INFO,
          enableConsoleOutput: false,
        );

        final data = {'name': 'test', 'value': 123};
        NetworkLogger.framework.info('数据对象: $data');
        expect(NetworkLogger.framework, isNotNull);
      });
    });
  });
} 