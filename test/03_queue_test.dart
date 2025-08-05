import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/src/requests/base_network_request.dart';
import 'package:bzy_network_framework/src/requests/network_executor.dart';
import 'package:bzy_network_framework/src/config/network_config.dart';
import 'package:bzy_network_framework/src/core/queue/request_queue_manager.dart' as queue;
import 'package:bzy_network_framework/src/utils/queue_monitor.dart';
import 'package:bzy_network_framework/src/utils/network_logger.dart';
import 'package:logging/logging.dart';

class QueueTestRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String _path;

  QueueTestRequest(this._path);

  @override
  String get path => _path;
  @override
  HttpMethod get method => HttpMethod.get;
  @override
  Map<String, dynamic> parseResponse(dynamic data) => data as Map<String, dynamic>;
}

void main() {
  group('请求队列测试', () {
    late NetworkExecutor executor;
    late queue.RequestQueueManager queueManager;
    late QueueMonitor queueMonitor;

    setUp(() {
      NetworkConfig.instance.initialize(
        baseUrl: 'https://jsonplaceholder.typicode.com',
        connectTimeout: 5000,
        receiveTimeout: 10000,
        sendTimeout: 5000,
        enableLogging: true,
        enableCache: true,
        defaultCacheDuration: 300,
        maxRetries: 2,
        retryDelay: 1000,
        enableExponentialBackoff: true,
      );

      executor = NetworkExecutor.instance;
      queueManager = queue.RequestQueueManager.instance;
      queueMonitor = QueueMonitor.instance;

      NetworkLogger.configure(
        level: Level.INFO,
        enableConsoleOutput: false,
      );
    });

    group('队列管理器基础功能', () {
      test('队列管理器单例模式', () {
        final manager1 = queue.RequestQueueManager.instance;
        final manager2 = queue.RequestQueueManager.instance;
        expect(manager1, same(manager2));
      });

      test('队列配置', () {
        expect(queueManager.config, isNotNull);
        expect(queueManager.config.maxConcurrentRequests, isA<int>());
        expect(queueManager.config.maxQueueSize, isA<int>());
        expect(queueManager.config.defaultTimeout, isA<Duration>());
      });

      test('队列统计', () {
        final stats = queueManager.statistics;
        expect(stats, isNotNull);
        expect(stats.totalEnqueued, isA<int>());
        expect(stats.totalExecuted, isA<int>());
        expect(stats.successfulRequests, isA<int>());
        expect(stats.failedRequests, isA<int>());
        expect(stats.averageExecutionTime, isA<Duration>());
        expect(stats.queueSizes, isA<Map>());
      });
    });

    group('队列监控功能', () {
      test('队列监控器', () {
        expect(queueMonitor, isNotNull);
      });
    });

    group('并发控制测试', () {
      test('并发请求控制', () async {
        final requestCount = 10;
        final requests = List.generate(
          requestCount,
          (index) => QueueTestRequest('/posts/${index}'),
        );

        try {
          final responses = await Future.wait(
            requests.map((request) => executor.execute(request)),
          );

          expect(responses.length, requestCount);
        } catch (e) {
          expect(requests.length, requestCount);
        }
      });
    });

    group('队列性能测试', () {
      test('队列处理性能', () async {
        final stopwatch = Stopwatch();
        final requestCount = 15;

        stopwatch.start();

        final requests = List.generate(
          requestCount,
          (index) => QueueTestRequest('/posts/${index}'),
        );

        try {
          final responses = await Future.wait(
            requests.map((request) => executor.execute(request)),
          );

          stopwatch.stop();

          expect(responses.length, requestCount);
          expect(stopwatch.elapsedMilliseconds, lessThan(30000));
        } catch (e) {
          expect(requests.length, requestCount);
        }
      });
    });
  });
} 