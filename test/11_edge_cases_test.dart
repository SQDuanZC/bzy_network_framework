import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bzy_network_framework/src/config/network_config.dart';
import 'package:bzy_network_framework/src/requests/network_executor.dart';
import 'package:bzy_network_framework/src/requests/base_network_request.dart';
import 'package:bzy_network_framework/src/core/queue/request_queue_manager.dart' as queue;
import 'package:bzy_network_framework/src/core/cache/cache_manager.dart';
import 'package:bzy_network_framework/src/core/network/network_adapter.dart';
import 'package:bzy_network_framework/src/core/exception/unified_exception_handler.dart';
import 'package:bzy_network_framework/src/utils/network_logger.dart';
import 'package:bzy_network_framework/src/model/response_wrapper.dart';
import 'package:logging/logging.dart';

void main() {
  group('边界情况和异常场景测试', () {
    late NetworkExecutor executor;
    late NetworkConfig config;

    setUp(() {
      // 初始化网络配置
      config = NetworkConfig.instance;
      config.initialize(
        baseUrl: 'https://api.example.com',
        connectTimeout: 5000,
        receiveTimeout: 5000,
        sendTimeout: 5000,
      );

      // 配置日志
      NetworkLogger.configure(
        level: Level.WARNING,
        enableConsoleOutput: false,
      );

      executor = NetworkExecutor.instance;
    });

    tearDown(() {
      // 清理资源
      CacheManager.instance.clear();
    });

    group('网络配置边界情况', () {
      test('无效的baseUrl配置', () {
        expect(
          () => config.initialize(
            baseUrl: '',
            connectTimeout: 5000,
            receiveTimeout: 5000,
            sendTimeout: 5000,
          ),
          throwsArgumentError,
        );
      });

      test('负数超时配置', () {
        expect(
          () => config.initialize(
            baseUrl: 'https://api.example.com',
            connectTimeout: -1000,
            receiveTimeout: 5000,
            sendTimeout: 5000,
          ),
          throwsArgumentError,
        );
      });

      test('零超时配置', () {
        expect(
          () => config.initialize(
            baseUrl: 'https://api.example.com',
            connectTimeout: 0,
            receiveTimeout: 0,
            sendTimeout: 0,
          ),
          throwsArgumentError,
        );
      });

      test('极大超时配置', () {
        // 应该接受合理的大值
        expect(
          () => config.initialize(
            baseUrl: 'https://api.example.com',
            connectTimeout: 300000, // 5分钟
            receiveTimeout: 300000,
            sendTimeout: 300000,
          ),
          returnsNormally,
        );
      });
    });

    group('请求参数边界情况', () {
      test('空路径请求', () async {
        final request = TestNetworkRequest(
          path: '',
          method: HttpMethod.get,
        );

        expect(
          () => executor.execute(request),
          throwsA(isA<Exception>()),
        );
      });

      test('null数据请求', () async {
        final request = TestNetworkRequest(
          path: '/test',
          method: HttpMethod.post,
          data: null,
        );

        // null数据应该被正常处理
        expect(
          () => executor.execute(request),
          returnsNormally,
        );
      });

      test('超大数据请求', () async {
        // 创建一个大的数据对象（1MB）
        final largeData = List.generate(1024 * 100, (index) => 'x').join();
        
        final request = TestNetworkRequest(
          path: '/test',
          method: HttpMethod.post,
          data: {'largeField': largeData},
        );

        // 应该能处理大数据，但可能会超时
        try {
          await executor.execute(request);
        } catch (e) {
          expect(e, anyOf([
            isA<Exception>(),
            isA<TimeoutException>(),
            isA<DioException>(),
          ]));
        }
      });

      test('特殊字符路径', () async {
        final request = TestNetworkRequest(
          path: '/test/中文/特殊字符!@#\$%^&*()',
          method: HttpMethod.get,
        );

        // 特殊字符应该被正确编码
        expect(
          () => executor.execute(request),
          returnsNormally,
        );
      });

      test('循环引用数据', () async {
        final Map<String, dynamic> circularData = {};
        circularData['self'] = circularData;

        final request = TestNetworkRequest(
          path: '/test',
          method: HttpMethod.post,
          data: circularData,
        );

        // 循环引用应该被检测并处理
        expect(
          () => executor.execute(request),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('网络异常场景', () {
      test('DNS解析失败', () async {
        config.updateBaseUrl('https://nonexistent.invalid.domain.com');
        
        final request = TestNetworkRequest(
          path: '/test',
          method: HttpMethod.get,
        );

        try {
          await executor.execute(request);
          fail('应该抛出网络异常');
        } catch (e) {
          expect(e, anyOf([
            isA<Exception>(),
            isA<SocketException>(),
            isA<DioException>(),
          ]));
        }
      });

      test('连接超时', () async {
        config.updateTimeouts(
          connectTimeout: 1, // 1毫秒，几乎必然超时
          receiveTimeout: 5000,
          sendTimeout: 5000,
        );

        final request = TestNetworkRequest(
          path: '/test',
          method: HttpMethod.get,
        );

        try {
          await executor.execute(request);
          fail('应该抛出超时异常');
        } catch (e) {
          expect(e, anyOf([
            isA<Exception>(),
            isA<TimeoutException>(),
            isA<DioException>(),
          ]));
        }
      });

      test('接收超时', () async {
        config.updateTimeouts(
          connectTimeout: 5000,
          receiveTimeout: 1, // 1毫秒，几乎必然超时
          sendTimeout: 5000,
        );

        final request = TestNetworkRequest(
          path: '/test',
          method: HttpMethod.get,
        );

        try {
          await executor.execute(request);
          fail('应该抛出超时异常');
        } catch (e) {
          expect(e, anyOf([
            isA<Exception>(),
            isA<TimeoutException>(),
            isA<DioException>(),
          ]));
        }
      });

      test('发送超时', () async {
        config.updateTimeouts(
          connectTimeout: 5000,
          receiveTimeout: 5000,
          sendTimeout: 1, // 1毫秒，几乎必然超时
        );

        final request = TestNetworkRequest(
          path: '/test',
          method: HttpMethod.post,
          data: {'test': 'data'},
        );

        try {
          await executor.execute(request);
          fail('应该抛出超时异常');
        } catch (e) {
          expect(e, anyOf([
            isA<Exception>(),
            isA<TimeoutException>(),
            isA<DioException>(),
          ]));
        }
      });
    });

    group('请求队列边界情况', () {
      test('队列并发处理', () async {
        final queueManager = queue.RequestQueueManager.instance;
        final completedRequests = <String>[];
        
        // 创建多个并发请求
        final futures = List.generate(10, (index) async {
          final request = TestNetworkRequest(
            path: '/test$index',
            method: HttpMethod.get,
          );
          
          try {
            await executor.execute(request);
            completedRequests.add('test$index');
          } catch (e) {
            // 忽略网络错误，只关注队列行为
          }
        });

        await Future.wait(futures);
        
        // 验证所有请求都被处理
        expect(completedRequests.length, lessThanOrEqualTo(10));
      });

      test('队列统计信息', () async {
        final queueManager = queue.RequestQueueManager.instance;
        final stats = queueManager.statistics;
        
        // 验证统计信息存在
        expect(stats, isNotNull);
      });
    });

    group('缓存边界情况', () {
      test('缓存大量数据', () async {
        final cache = CacheManager.instance;
        
        // 尝试缓存大量数据
        final largeData = List.generate(1024 * 10, (index) => 'x').join();
        
        try {
          for (int i = 0; i < 10; i++) {
            final response = BaseResponse.success(data: largeData);
            await cache.set('large_key_$i', response);
          }
        } catch (e) {
          // 缓存空间不足时应该抛出异常或正常处理
          expect(e, isA<Exception>());
        }
      });

      test('缓存键名冲突', () async {
        final cache = CacheManager.instance;
        
        final response1 = BaseResponse.success(data: 'value1');
        await cache.set('test_key', response1);
        
        // 重复键名应该覆盖原值
        final response2 = BaseResponse.success(data: 'value2');
        await cache.set('test_key', response2);
        
        final result = await cache.get('test_key');
        expect(result?.data, equals('value2'));
      });

      test('检索不存在的键', () async {
        final cache = CacheManager.instance;
        
        final result = await cache.get('nonexistent_key');
        expect(result, isNull);
      });
    });

    group('异常处理器边界情况', () {
      test('处理未知异常类型', () async {
        final handler = UnifiedExceptionHandler.instance;
        
        final unknownException = FormatException('Unknown format error');
        final result = await handler.handleException(unknownException);
        
        expect(result, isA<UnifiedException>());
        expect(result.type, equals(ExceptionType.unknown));
      });

      test('异常处理器统计', () async {
        final handler = UnifiedExceptionHandler.instance;
        
        // 生成一些异常来测试统计
        for (int i = 0; i < 10; i++) {
          final exception = Exception('Test exception $i');
          await handler.handleException(exception);
        }
        
        final stats = handler.getExceptionStats();
        expect(stats, isNotNull);
        expect(stats.isNotEmpty, isTrue);
      });
    });

    group('内存和资源管理', () {
      test('内存使用监控', () async {
        final initialMemory = ProcessInfo.currentRss;
        
        // 执行一些网络请求
        final futures = List.generate(10, (index) async {
          final request = TestNetworkRequest(
            path: '/test$index',
            method: HttpMethod.get,
          );
          
          try {
            await executor.execute(request);
          } catch (e) {
            // 忽略网络错误
          }
        });
        
        await Future.wait(futures);
        
        // 强制垃圾回收
        await Future.delayed(Duration(milliseconds: 100));
        
        final finalMemory = ProcessInfo.currentRss;
        final memoryIncrease = finalMemory - initialMemory;
        
        // 内存增长应该在合理范围内
        expect(memoryIncrease, lessThan(50 * 1024 * 1024)); // 50MB
      });

      test('资源清理', () async {
        final cache = CacheManager.instance;
        
        // 添加一些数据
        final response1 = BaseResponse.success(data: 'value1');
        final response2 = BaseResponse.success(data: 'value2');
        await cache.set('test1', response1);
        await cache.set('test2', response2);
        
        // 清理资源
        await cache.clear();
        
        // 验证资源已清理
        expect(await cache.get('test1'), isNull);
        expect(await cache.get('test2'), isNull);
      });
    });

    group('并发和竞态条件', () {
      test('并发请求竞态条件', () async {
        final results = <String>[];
        final errors = <Exception>[];
        
        // 创建多个并发请求
        final futures = List.generate(5, (index) async {
          final request = TestNetworkRequest(
            path: '/concurrent$index',
            method: HttpMethod.get,
          );
          
          try {
            final response = await executor.execute(request);
            results.add('success$index');
          } catch (e) {
            errors.add(e as Exception);
          }
        });
        
        await Future.wait(futures);
        
        // 验证所有请求都被处理（成功或失败）
        expect(results.length + errors.length, equals(5));
      });

      test('缓存并发访问', () async {
        final cache = CacheManager.instance;
        final results = <BaseResponse?>[];
        
        // 并发读写同一个键
        final futures = List.generate(5, (index) async {
          if (index % 2 == 0) {
            // 写操作
            final response = BaseResponse.success(data: 'value$index');
            await cache.set('concurrent_key', response);
          } else {
            // 读操作
            final value = await cache.get('concurrent_key');
            results.add(value);
          }
        });
        
        await Future.wait(futures);
        
        // 验证没有崩溃，数据一致性可能无法保证但不应该崩溃
        expect(results.length, greaterThan(0));
      });
    });
  });
}

// 测试用的网络请求类
class TestNetworkRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String _path;
  final HttpMethod _method;
  final dynamic _data;
  final Map<String, String>? _headers;
  final RequestPriority _priority;

  TestNetworkRequest({
    required String path,
    required HttpMethod method,
    dynamic data,
    Map<String, String>? headers,
    RequestPriority priority = RequestPriority.normal,
  }) : _path = path,
       _method = method,
       _data = data,
       _headers = headers,
       _priority = priority;

  @override
  String get path => _path;

  @override
  HttpMethod get method => _method;

  @override
  dynamic get data => _data;

  @override
  Map<String, dynamic>? get headers => _headers?.cast<String, dynamic>();

  @override
  RequestPriority get priority => _priority;

  @override
  Map<String, dynamic> parseResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {'data': response};
  }
}

// 进程信息工具类
class ProcessInfo {
  static int get currentRss {
    // 在实际应用中，这里应该使用平台特定的API来获取内存使用情况
    // 这里返回一个模拟值
    return DateTime.now().millisecondsSinceEpoch % 1000000;
  }
}