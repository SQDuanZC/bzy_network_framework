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

    group('简化接口测试', () {
      test('字符串缓存操作', () async {
        const key = 'string_key';
        const testValue = 'Hello, World!';

        await cacheManager.putString(key, testValue);
        final cachedValue = await cacheManager.getString(key);

        expect(cachedValue, equals(testValue));
      });

      test('整数缓存操作', () async {
        const key = 'int_key';
        const testValue = 42;

        await cacheManager.putInt(key, testValue);
        final cachedValue = await cacheManager.getInt(key);

        expect(cachedValue, equals(testValue));
      });

      test('浮点数缓存操作', () async {
        const key = 'double_key';
        const testValue = 3.14159;

        await cacheManager.putDouble(key, testValue);
        final cachedValue = await cacheManager.getDouble(key);

        expect(cachedValue, equals(testValue));
      });

      test('布尔值缓存操作', () async {
        const key = 'bool_key';
        const testValue = true;

        await cacheManager.putBool(key, testValue);
        final cachedValue = await cacheManager.getBool(key);

        expect(cachedValue, equals(testValue));
      });

      test('Map缓存操作', () async {
        const key = 'map_key';
        final testValue = {'name': 'John', 'age': 30, 'city': 'New York'};

        await cacheManager.putMap(key, testValue);
        final cachedValue = await cacheManager.getMap(key);

        expect(cachedValue, equals(testValue));
      });

      test('List缓存操作', () async {
        const key = 'list_key';
        final testValue = ['apple', 'banana', 'orange'];

        await cacheManager.putList<String>(key, testValue);
        final cachedValue = await cacheManager.getList<String>(key);

        expect(cachedValue, equals(testValue));
      });

      test('对象缓存操作', () async {
        const key = 'object_key';
        final testValue = TestUser(id: 1, name: 'Alice', email: 'alice@example.com');

        await cacheManager.putObject(key, testValue);
        final cachedValue = await cacheManager.getObject<TestUser>(key);

        expect(cachedValue, isNotNull);
        expect(cachedValue!.id, equals(testValue.id));
        expect(cachedValue.name, equals(testValue.name));
        expect(cachedValue.email, equals(testValue.email));
      });

      test('JSON对象缓存操作', () async {
        const key = 'json_object_key';
        final testValue = TestUser(id: 2, name: 'Bob', email: 'bob@example.com');

        await cacheManager.putJsonObject(key, testValue, TestUser.fromJson);
        final cachedValue = await cacheManager.getJsonObject(key, TestUser.fromJson);

        expect(cachedValue, isNotNull);
        expect(cachedValue!.id, equals(testValue.id));
        expect(cachedValue.name, equals(testValue.name));
        expect(cachedValue.email, equals(testValue.email));
      });

      test('缓存存在性检查', () async {
        const key = 'exists_key';
        const testValue = 'test_value';

        expect(await cacheManager.exists(key), false);

        await cacheManager.putString(key, testValue);
        expect(await cacheManager.exists(key), true);

        await cacheManager.remove(key);
        expect(await cacheManager.exists(key), false);
      });

      test('缓存过期时间操作', () async {
        const key = 'expiry_key';
        const testValue = 'expiry_test';
        final expiry = Duration(seconds: 10);

        await cacheManager.putString(key, testValue, expiry: expiry);
        
        final expiryTime = await cacheManager.getExpiryTime(key);
        expect(expiryTime, isNotNull);
        expect(expiryTime!.isAfter(DateTime.now()), true);

        // 延长过期时间
        final newExpiry = Duration(seconds: 20);
        await cacheManager.extendExpiry(key, newExpiry);
        
        final newExpiryTime = await cacheManager.getExpiryTime(key);
        expect(newExpiryTime, isNotNull);
        expect(newExpiryTime!.isAfter(expiryTime), true);
      });

      test('带标签的简化接口操作', () async {
        const key1 = 'tagged_key1';
        const key2 = 'tagged_key2';
        const value1 = 'tagged_value1';
        const value2 = 'tagged_value2';
        final tags = {'category', 'test'};

        await cacheManager.putString(key1, value1, tags: tags);
        await cacheManager.putString(key2, value2, tags: tags);

        expect(await cacheManager.getString(key1), equals(value1));
        expect(await cacheManager.getString(key2), equals(value2));

        // 通过标签清理缓存
        await cacheManager.clearByTag('category');

        expect(await cacheManager.getString(key1), isNull);
        expect(await cacheManager.getString(key2), isNull);
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

      test('简化接口性能测试', () async {
        final stopwatch = Stopwatch();
        final cacheCount = 100;

        stopwatch.start();

        // 测试不同类型的缓存操作性能
        for (int i = 0; i < cacheCount; i++) {
          await Future.wait([
            cacheManager.putString('string_$i', 'value_$i'),
            cacheManager.putInt('int_$i', i),
            cacheManager.putBool('bool_$i', i % 2 == 0),
            cacheManager.putMap('map_$i', {'index': i, 'name': 'item_$i'}),
          ]);
        }

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(10000));

        // 验证数据正确性
        expect(await cacheManager.getString('string_50'), equals('value_50'));
        expect(await cacheManager.getInt('int_50'), equals(50));
        expect(await cacheManager.getBool('bool_50'), equals(true));
        final map = await cacheManager.getMap('map_50');
        expect(map?['index'], equals(50));
        expect(map?['name'], equals('item_50'));
      });
    });
  });
}

/// 测试用户类
class TestUser {
  final int id;
  final String name;
  final String email;

  TestUser({required this.id, required this.name, required this.email});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
  };

  static TestUser fromJson(Map<String, dynamic> json) => TestUser(
    id: json['id'],
    name: json['name'],
    email: json['email'],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ email.hashCode;
}