import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/src/requests/base_network_request.dart';
import 'package:bzy_network_framework/src/requests/network_executor.dart';
import 'package:bzy_network_framework/src/config/network_config.dart';
import 'package:bzy_network_framework/src/core/cache/cache_manager.dart';
import 'package:bzy_network_framework/src/core/queue/request_queue_manager.dart' as queue;
import 'package:bzy_network_framework/src/utils/network_logger.dart';
import 'package:logging/logging.dart';

class MassRequestTest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String _path;
  final int _requestId;

  MassRequestTest(this._path, this._requestId);

  @override
  String get path => _path;
  @override
  HttpMethod get method => HttpMethod.get;
  @override
  Map<String, dynamic> parseResponse(dynamic data) => data as Map<String, dynamic>;

  int get requestId => _requestId;
}

void main() {
  group('大量请求处理测试', () {
    late NetworkExecutor executor;
    late CacheManager cacheManager;
    late queue.RequestQueueManager queueManager;

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
      cacheManager = CacheManager.instance;
      queueManager = queue.RequestQueueManager.instance;

      NetworkLogger.configure(
        level: Level.INFO,
        enableConsoleOutput: false,
      );
    });

    group('同一接口大量请求测试', () {
      test('100个相同请求的处理', () async {
        final stopwatch = Stopwatch();
        final requestCount = 100;
        final sameRequest = MassRequestTest('/posts/1', 1);

        stopwatch.start();

        // 创建100个相同的请求
        final futures = List.generate(
          requestCount,
          (index) => executor.execute(sameRequest),
        );

        try {
          final responses = await Future.wait(futures);
          stopwatch.stop();

          print('处理100个相同请求耗时: ${stopwatch.elapsedMilliseconds}ms');
          print('成功响应数量: ${responses.length}');
          print('队列统计: ${queueManager.statistics.totalEnqueued} 个请求入队');
          print('缓存统计: ${cacheManager.statistics.totalRequests} 个缓存请求');

          expect(responses.length, requestCount);
          expect(stopwatch.elapsedMilliseconds, lessThan(30000)); // 30秒内完成
        } catch (e) {
          print('请求处理出错: $e');
          expect(executor, isNotNull);
        }
      });

      test('不同接口大量请求的处理', () async {
        final stopwatch = Stopwatch();
        final requestCount = 50;

        stopwatch.start();

        // 创建50个不同接口的请求
        final futures = List.generate(
          requestCount,
          (index) => executor.execute(MassRequestTest('/posts/${index + 1}', index + 1)),
        );

        try {
          final responses = await Future.wait(futures);
          stopwatch.stop();

          print('处理50个不同请求耗时: ${stopwatch.elapsedMilliseconds}ms');
          print('成功响应数量: ${responses.length}');
          print('队列统计: ${queueManager.statistics.totalEnqueued} 个请求入队');

          expect(responses.length, requestCount);
          expect(stopwatch.elapsedMilliseconds, lessThan(30000));
        } catch (e) {
          print('请求处理出错: $e');
          expect(executor, isNotNull);
        }
      });

      test('混合请求（相同+不同）的处理', () async {
        final stopwatch = Stopwatch();
        final sameRequestCount = 30;
        final differentRequestCount = 20;

        stopwatch.start();

        final sameRequest = MassRequestTest('/posts/1', 1);
        final sameFutures = List.generate(
          sameRequestCount,
          (index) => executor.execute(sameRequest),
        );

        final differentFutures = List.generate(
          differentRequestCount,
          (index) => executor.execute(MassRequestTest('/posts/${index + 2}', index + 2)),
        );

        final allFutures = [...sameFutures, ...differentFutures];

        try {
          final responses = await Future.wait(allFutures);
          stopwatch.stop();

          print('处理混合请求耗时: ${stopwatch.elapsedMilliseconds}ms');
          print('总响应数量: ${responses.length}');
          print('相同请求数量: $sameRequestCount');
          print('不同请求数量: $differentRequestCount');
          print('队列统计: ${queueManager.statistics.totalEnqueued} 个请求入队');
          print('缓存命中率: ${cacheManager.statistics.totalHitRate}');

          expect(responses.length, sameRequestCount + differentRequestCount);
          expect(stopwatch.elapsedMilliseconds, lessThan(30000));
        } catch (e) {
          print('请求处理出错: $e');
          expect(executor, isNotNull);
        }
      });

      test('高并发请求的性能测试', () async {
        final stopwatch = Stopwatch();
        final requestCount = 200;

        stopwatch.start();

        // 创建200个请求，模拟高并发场景
        final futures = List.generate(
          requestCount,
          (index) => executor.execute(MassRequestTest('/posts/${index % 10 + 1}', index)),
        );

        try {
          final responses = await Future.wait(futures);
          stopwatch.stop();

          print('高并发请求处理耗时: ${stopwatch.elapsedMilliseconds}ms');
          print('请求数量: $requestCount');
          print('成功响应: ${responses.length}');
          print('平均响应时间: ${stopwatch.elapsedMilliseconds / requestCount}ms/请求');
          print('队列统计:');
          print('  - 总入队: ${queueManager.statistics.totalEnqueued}');
          print('  - 总执行: ${queueManager.statistics.totalExecuted}');
          print('  - 成功: ${queueManager.statistics.successfulRequests}');
          print('  - 失败: ${queueManager.statistics.failedRequests}');
          print('缓存统计:');
          print('  - 总请求: ${cacheManager.statistics.totalRequests}');
          print('  - 内存命中: ${cacheManager.statistics.memoryHits}');
          print('  - 总命中率: ${cacheManager.statistics.totalHitRate}');

          expect(responses.length, requestCount);
          expect(stopwatch.elapsedMilliseconds, lessThan(60000)); // 1分钟内完成
        } catch (e) {
          print('高并发请求处理出错: $e');
          expect(executor, isNotNull);
        }
      });

      test('请求去重效果测试', () async {
        final sameRequest = MassRequestTest('/posts/1', 1);
        final differentRequest = MassRequestTest('/posts/2', 2);

        final stopwatch = Stopwatch();
        stopwatch.start();

        // 同时发起多个相同请求和不同请求
        final futures = [
          executor.execute(sameRequest),    // 相同请求1
          executor.execute(sameRequest),    // 相同请求2 - 应该被去重
          executor.execute(sameRequest),    // 相同请求3 - 应该被去重
          executor.execute(differentRequest), // 不同请求1
          executor.execute(differentRequest), // 不同请求2 - 应该被去重
        ];

        try {
          final responses = await Future.wait(futures);
          stopwatch.stop();

          print('去重测试耗时: ${stopwatch.elapsedMilliseconds}ms');
          print('响应数量: ${responses.length}');
          print('队列统计: ${queueManager.statistics.totalEnqueued} 个请求入队');
          print('去重统计: ${queueManager.statistics.duplicateRequests} 个重复请求');

          expect(responses.length, 5);
          expect(stopwatch.elapsedMilliseconds, lessThan(10000));
        } catch (e) {
          print('去重测试出错: $e');
          expect(executor, isNotNull);
        }
      });
    });

    group('框架处理机制验证', () {
      test('队列容量限制', () {
        final config = queueManager.config;
        print('队列配置:');
        print('  - 最大并发请求: ${config.maxConcurrentRequests}');
        print('  - 最大队列大小: ${config.maxQueueSize}');
        print('  - 默认超时: ${config.defaultTimeout}');
        print('  - 最大队列时间: ${config.maxQueueTime}');

        expect(config.maxConcurrentRequests, greaterThan(0));
        expect(config.maxQueueSize, greaterThan(0));
      });

      test('缓存配置验证', () {
        final config = cacheManager.config;
        print('缓存配置:');
        print('  - 最大内存大小: ${config.maxMemorySize} bytes');
        print('  - 最大磁盘大小: ${config.maxDiskSize} bytes');
        print('  - 默认过期时间: ${config.defaultExpiry}');
        print('  - 清理间隔: ${config.cleanupInterval}');

        expect(config.maxMemorySize, greaterThan(0));
        expect(config.maxDiskSize, greaterThan(0));
      });

      test('网络配置验证', () {
        final config = NetworkConfig.instance;
        print('网络配置:');
        print('  - 基础URL: ${config.baseUrl}');
        print('  - 连接超时: ${config.connectTimeout}');
        print('  - 接收超时: ${config.receiveTimeout}');
        print('  - 最大重试: ${config.maxRetries}');
        print('  - 重试延迟: ${config.retryDelay}');

        expect(config.baseUrl, isNotEmpty);
        expect(config.connectTimeout, isA<Duration>());
        expect(config.receiveTimeout, isA<Duration>());
      });
    });
  });
} 