import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/src/core/cache/cache_manager.dart';
import 'package:bzy_network_framework/src/model/response_wrapper.dart';
import 'package:bzy_network_framework/src/config/network_config.dart';
import 'package:bzy_network_framework/src/utils/network_logger.dart';
import 'package:logging/logging.dart';

void main() {
  group('存储功能测试', () {
    late CacheManager cacheManager;

    setUp(() {
      NetworkConfig.instance.initialize(
        baseUrl: 'https://api.example.com',
        enableCache: true,
        defaultCacheDuration: 300,
      );

      cacheManager = CacheManager.instance;

      NetworkLogger.configure(
        level: Level.INFO,
        enableConsoleOutput: false,
      );
    });

    group('缓存管理器基础功能', () {
      test('缓存管理器单例模式', () {
        final manager1 = CacheManager.instance;
        final manager2 = CacheManager.instance;
        expect(manager1, same(manager2));
      });

      test('缓存配置', () {
        expect(cacheManager.config, isNotNull);
        expect(cacheManager.config.maxMemorySize, isA<int>());
        expect(cacheManager.config.defaultExpiry, isA<Duration>());
      });
    });

    group('基础缓存操作', () {
      test('设置和获取缓存', () async {
        const key = 'test_key';
        final testData = {'name': 'test', 'value': 123};
        final response = BaseResponse.success(data: testData);

        await cacheManager.set(key, response);
        final cachedResponse = await cacheManager.get<Map<String, dynamic>>(key);

        expect(cachedResponse, isNotNull);
        expect(cachedResponse!.data, testData);
        expect(cachedResponse.success, true);
      });

      test('删除缓存', () async {
        const key = 'delete_key';
        final testData = {'name': 'delete_test'};
        final response = BaseResponse.success(data: testData);

        await cacheManager.set(key, response);
        
        final beforeDelete = await cacheManager.get<Map<String, dynamic>>(key);
        expect(beforeDelete, isNotNull);

        await cacheManager.remove(key);

        final afterDelete = await cacheManager.get<Map<String, dynamic>>(key);
        expect(afterDelete, isNull);
      });

      test('清空所有缓存', () async {
        const key1 = 'clear_key1';
        const key2 = 'clear_key2';
        final testData1 = {'name': 'clear_test1'};
        final testData2 = {'name': 'clear_test2'};
        final response1 = BaseResponse.success(data: testData1);
        final response2 = BaseResponse.success(data: testData2);

        await cacheManager.set(key1, response1);
        await cacheManager.set(key2, response2);

        final beforeClear1 = await cacheManager.get<Map<String, dynamic>>(key1);
        final beforeClear2 = await cacheManager.get<Map<String, dynamic>>(key2);
        expect(beforeClear1, isNotNull);
        expect(beforeClear2, isNotNull);

        await cacheManager.clear();

        final afterClear1 = await cacheManager.get<Map<String, dynamic>>(key1);
        final afterClear2 = await cacheManager.get<Map<String, dynamic>>(key2);
        expect(afterClear1, isNull);
        expect(afterClear2, isNull);
      });
    });

    group('缓存统计', () {
      test('缓存统计信息', () async {
        const key = 'stats_key';
        final testData = {'name': 'stats_test'};
        final response = BaseResponse.success(data: testData);

        await cacheManager.set(key, response);

        final stats = cacheManager.statistics;
        expect(stats, isNotNull);
        expect(stats.totalRequests, isA<int>());
        expect(stats.memoryHits, isA<int>());
        expect(stats.misses, isA<int>());
        expect(stats.totalHitRate, isA<double>());
      });
    });

    group('缓存性能测试', () {
      test('大量缓存操作性能', () async {
        final stopwatch = Stopwatch();
        final cacheCount = 50;

        stopwatch.start();

        for (int i = 0; i < cacheCount; i++) {
          final key = 'perf_key_$i';
          final testData = {'index': i, 'name': 'perf_test_$i'};
          final response = BaseResponse.success(data: testData);

          await cacheManager.set(key, response);
        }

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
    });
  });
} 