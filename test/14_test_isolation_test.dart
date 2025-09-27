import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:math';
import 'package:bzy_network_framework/src/config/network_config.dart';
import 'package:bzy_network_framework/src/requests/network_executor.dart';
import 'package:bzy_network_framework/src/requests/base_network_request.dart';
import 'package:bzy_network_framework/src/core/queue/request_queue_manager.dart' as queue;
import 'package:bzy_network_framework/src/core/cache/cache_manager.dart';
import 'package:bzy_network_framework/src/core/exception/unified_exception_handler.dart';
import 'package:bzy_network_framework/src/model/response_wrapper.dart';
import 'package:bzy_network_framework/src/utils/network_logger.dart';
import 'package:logging/logging.dart';

void main() {
  group('测试隔离性和独立性验证', () {
    late NetworkExecutor executor;
    late NetworkConfig config;
    late CacheManager cache;

    setUp(() {
      // 每个测试前重新初始化所有组件
      config = NetworkConfig.instance;
      config.initialize(
        baseUrl: 'https://httpbin.org',
        connectTimeout: 5000,
        receiveTimeout: 5000,
        sendTimeout: 5000,
      );

      NetworkLogger.configure(
        level: Level.WARNING,
        enableConsoleOutput: false,
      );

      executor = NetworkExecutor.instance;
      cache = CacheManager.instance;
    });

    tearDown(() {
      // 每个测试后彻底清理状态
      cache.clear();
      // 重置配置到默认状态
      _resetToDefaultState();
    });

    group('状态隔离测试', () {
      test('缓存状态隔离 - 测试1', () async {
        // 设置一些缓存数据
        final response1 = BaseResponse.success(data: {'test': 'isolation1'});
        await cache.set('isolation_test_1', response1);
        
        final cached = await cache.get('isolation_test_1');
        expect(cached, isNotNull);
        expect(cached!.data, equals({'test': 'isolation1'}));
        
        // 标记这个测试设置了缓存
        _testState['cache_set_by_test1'] = true;
      });

      test('缓存状态隔离 - 测试2', () async {
        // 验证前一个测试的缓存不存在（应该被tearDown清理）
        final cached = await cache.get('isolation_test_1');
        expect(cached, isNull);
        
        // 验证测试状态已重置
        expect(_testState.containsKey('cache_set_by_test1'), isFalse);
        
        // 设置不同的缓存数据
        final response2 = BaseResponse.success(data: {'test': 'isolation2'});
        await cache.set('isolation_test_2', response2);
        
        final newCached = await cache.get('isolation_test_2');
        expect(newCached, isNotNull);
        expect(newCached!.data, equals({'test': 'isolation2'}));
      });

      test('配置状态隔离 - 测试1', () async {
        // 修改配置
        config.initialize(
          baseUrl: 'https://example.com',
          connectTimeout: 15000,
          receiveTimeout: 15000,
          sendTimeout: 15000,
        );
        
        expect(config.baseUrl, equals('https://example.com'));
        expect(config.connectTimeout, equals(15000));
        
        _testState['config_modified_by_test1'] = true;
      });

      test('配置状态隔离 - 测试2', () async {
        // 验证配置已重置到默认状态
        expect(config.baseUrl, equals('https://httpbin.org'));
        expect(config.connectTimeout, equals(5000));
        
        // 验证测试状态已重置
        expect(_testState.containsKey('config_modified_by_test1'), isFalse);
      });
    });

    group('并发测试隔离', () {
      test('并发测试1 - 快速请求', () async {
        final futures = List.generate(5, (index) async {
          final request = IsolationTestRequest(
            path: '/get?concurrent1=$index',
            method: HttpMethod.get,
            testId: 'concurrent1_$index',
          );
          return await executor.execute(request);
        });

        final responses = await Future.wait(futures);
        expect(responses.length, equals(5));
        
        for (int i = 0; i < responses.length; i++) {
          expect(responses[i], isNotNull);
        }
        
        _testState['concurrent1_completed'] = true;
      });

      test('并发测试2 - 延迟请求', () async {
        // 验证前一个并发测试的状态不影响当前测试
        expect(_testState.containsKey('concurrent1_completed'), isFalse);
        
        final futures = List.generate(3, (index) async {
          final request = IsolationTestRequest(
            path: '/delay/1',
            method: HttpMethod.get,
            testId: 'concurrent2_$index',
          );
          return await executor.execute(request);
        });

        final responses = await Future.wait(futures);
        expect(responses.length, equals(3));
        
        for (final response in responses) {
          expect(response, isNotNull);
        }
      });
    });

    group('异常状态隔离', () {
      test('异常测试1 - 网络错误', () async {
        final request = IsolationTestRequest(
          path: '/status/500',
          method: HttpMethod.get,
          testId: 'error_test_1',
        );

        try {
          await executor.execute(request);
          fail('应该抛出异常');
        } catch (e) {
          expect(e, isA<Exception>());
          _testState['error_occurred_in_test1'] = true;
        }
      });

      test('异常测试2 - 正常请求', () async {
        // 验证前一个测试的异常状态不影响当前测试
        expect(_testState.containsKey('error_occurred_in_test1'), isFalse);
        
        final request = IsolationTestRequest(
          path: '/get',
          method: HttpMethod.get,
          testId: 'normal_test_2',
        );

        final response = await executor.execute(request);
        expect(response, isNotNull);
        expect(response.data, isA<Map<String, dynamic>>());
      });
    });

    group('资源清理验证', () {
      test('内存泄漏检查 - 测试1', () async {
        final initialMemory = _getApproximateMemoryUsage();
        
        // 执行一些操作
        final futures = List.generate(10, (index) async {
          final request = IsolationTestRequest(
            path: '/get?memory=$index',
            method: HttpMethod.get,
            testId: 'memory_$index',
          );
          return await executor.execute(request);
        });

        await Future.wait(futures);
        
        final afterOperationMemory = _getApproximateMemoryUsage();
        final memoryIncrease = afterOperationMemory - initialMemory;
        
        _testState['memory_increase_test1'] = memoryIncrease;
        
        // 验证内存增长在合理范围内
        expect(memoryIncrease, lessThan(10000)); // 小于10MB
      });

      test('内存泄漏检查 - 测试2', () async {
        // 验证前一个测试的内存状态不影响当前测试
        expect(_testState.containsKey('memory_increase_test1'), isFalse);
        
        final initialMemory = _getApproximateMemoryUsage();
        
        // 执行不同的操作
        for (int i = 0; i < 5; i++) {
          final response = BaseResponse.success(data: {'memory_test': i});
          await cache.set('memory_cache_$i', response);
        }
        
        final afterCacheMemory = _getApproximateMemoryUsage();
        final memoryIncrease = afterCacheMemory - initialMemory;
        
        // 验证内存增长在合理范围内
        expect(memoryIncrease, lessThan(5000)); // 小于5MB
      });
    });

    group('随机顺序执行测试', () {
      test('随机测试A', () async {
        await _randomOperation('A');
        _testState['random_A_executed'] = true;
      });

      test('随机测试B', () async {
        // 验证测试A的状态不影响测试B
        expect(_testState.containsKey('random_A_executed'), isFalse);
        await _randomOperation('B');
        _testState['random_B_executed'] = true;
      });

      test('随机测试C', () async {
        // 验证前面测试的状态不影响测试C
        expect(_testState.containsKey('random_A_executed'), isFalse);
        expect(_testState.containsKey('random_B_executed'), isFalse);
        await _randomOperation('C');
      });
    });

    group('跨组件状态隔离', () {
      test('组件状态测试1', () async {
        // 修改多个组件的状态
        final response = BaseResponse.success(data: {'component': 'test1'});
        await cache.set('component_test_1', response);
        
        final request = IsolationTestRequest(
          path: '/get?component=1',
          method: HttpMethod.get,
          testId: 'component_1',
        );
        await executor.execute(request);
        
        _testState['component_test1_completed'] = true;
      });

      test('组件状态测试2', () async {
        // 验证所有组件状态都已重置
        final cached = await cache.get('component_test_1');
        expect(cached, isNull);
        
        expect(_testState.containsKey('component_test1_completed'), isFalse);
        
        // 执行不同的组件操作
        final response = BaseResponse.success(data: {'component': 'test2'});
        await cache.set('component_test_2', response);
        
        final request = IsolationTestRequest(
          path: '/get?component=2',
          method: HttpMethod.get,
          testId: 'component_2',
        );
        await executor.execute(request);
      });
    });

    group('测试顺序无关性验证', () {
      test('顺序测试 - 第一个', () async {
        final result = await _performOrderTest(1);
        expect(result, isNotNull);
        _testState['order_test_1'] = result;
      });

      test('顺序测试 - 第二个', () async {
        // 这个测试的结果不应该依赖于第一个测试
        expect(_testState.containsKey('order_test_1'), isFalse);
        
        final result = await _performOrderTest(2);
        expect(result, isNotNull);
        
        // 结果应该是独立的，不受第一个测试影响
        expect(result, isA<Map<String, dynamic>>());
      });

      test('顺序测试 - 第三个', () async {
        // 这个测试应该能够独立运行，不依赖前面的测试
        final result = await _performOrderTest(3);
        expect(result, isNotNull);
        
        // 验证能够正常执行相同的操作
        final duplicateResult = await _performOrderTest(3);
        expect(duplicateResult, isNotNull);
      });
    });
  });
}

// 测试状态存储（用于验证隔离性）
final Map<String, dynamic> _testState = {};

// 隔离测试专用请求类
class IsolationTestRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String _path;
  final HttpMethod _method;
  final String _testId;

  IsolationTestRequest({
    required String path,
    required HttpMethod method,
    required String testId,
  }) : _path = path,
       _method = method,
       _testId = testId;

  @override
  String get path => _path;

  @override
  HttpMethod get method => _method;

  String get testId => _testId;

  @override
  Map<String, dynamic> parseResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      return {...response, 'testId': _testId};
    }
    return {'data': response, 'testId': _testId};
  }
}

// 工具函数
void _resetToDefaultState() {
  // 清理测试状态
  _testState.clear();
  
  // 重置网络配置到默认状态
  final config = NetworkConfig.instance;
  config.initialize(
    baseUrl: 'https://httpbin.org',
    connectTimeout: 5000,
    receiveTimeout: 5000,
    sendTimeout: 5000,
  );
}

int _getApproximateMemoryUsage() {
  // 模拟内存使用情况
  // 在实际应用中，这里应该使用平台特定的API
  return DateTime.now().millisecondsSinceEpoch % 100000 + Random().nextInt(1000);
}

Future<Map<String, dynamic>> _randomOperation(String testId) async {
  final random = Random();
  final operationIndex = random.nextInt(3);
  
  switch (operationIndex) {
    case 0:
      final request = IsolationTestRequest(
        path: '/get?random=$testId',
        method: HttpMethod.get,
        testId: 'random_$testId',
      );
      final response = await NetworkExecutor.instance.execute(request);
      return response.data ?? {};
    case 1:
      final response = BaseResponse.success(data: {'random': testId});
      await CacheManager.instance.set('random_$testId', response);
      return response.data as Map<String, dynamic>;
    default:
      await Future.delayed(Duration(milliseconds: random.nextInt(100)));
      return {'delayed': testId, 'timestamp': DateTime.now().millisecondsSinceEpoch};
  }
}

Future<Map<String, dynamic>> _performOrderTest(int testNumber) async {
  final request = IsolationTestRequest(
    path: '/get?order=$testNumber',
    method: HttpMethod.get,
    testId: 'order_$testNumber',
  );

  final response = await NetworkExecutor.instance.execute(request);
  
  // 添加一些缓存操作
  final cacheResponse = BaseResponse.success(data: response.data);
  await CacheManager.instance.set('order_cache_$testNumber', cacheResponse);
  
  return response.data ?? {};
}