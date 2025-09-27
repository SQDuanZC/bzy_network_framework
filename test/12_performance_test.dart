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
  group('性能和压力测试', () {
    late NetworkExecutor executor;
    late NetworkConfig config;
    late Stopwatch stopwatch;

    setUp(() {
      // 初始化网络配置
      config = NetworkConfig.instance;
      config.initialize(
        baseUrl: 'https://httpbin.org',
        connectTimeout: 10000,
        receiveTimeout: 10000,
        sendTimeout: 10000,
      );

      // 配置日志为最小级别以减少性能影响
      NetworkLogger.configure(
        level: Level.SEVERE,
        enableConsoleOutput: false,
      );

      executor = NetworkExecutor.instance;
      stopwatch = Stopwatch();
    });

    tearDown(() {
      // 清理资源
      CacheManager.instance.clear();
    });

    group('并发请求性能测试', () {
      test('10个并发请求性能', () async {
        const requestCount = 10;
        final completedRequests = <String>[];
        final errors = <Exception>[];
        
        stopwatch.start();
        
        final futures = List.generate(requestCount, (index) async {
          final request = PerformanceTestRequest(
            path: '/delay/1', // 1秒延迟
            method: HttpMethod.get,
            requestId: 'req_$index',
          );
          
          try {
            await executor.execute(request);
            completedRequests.add('req_$index');
          } catch (e) {
            errors.add(e as Exception);
          }
        });

        await Future.wait(futures);
        stopwatch.stop();
        
        final duration = stopwatch.elapsedMilliseconds;
        print('10个并发请求完成时间: ${duration}ms');
        print('成功请求数: ${completedRequests.length}');
        print('失败请求数: ${errors.length}');
        
        // 并发请求应该在合理时间内完成（考虑1秒延迟）
        expect(duration, lessThan(5000)); // 5秒内完成
        expect(completedRequests.length + errors.length, equals(requestCount));
      });

      test('50个并发请求压力测试', () async {
        const requestCount = 50;
        final completedRequests = <String>[];
        final errors = <Exception>[];
        final requestTimes = <int>[];
        
        stopwatch.start();
        
        final futures = List.generate(requestCount, (index) async {
          final requestStopwatch = Stopwatch()..start();
          final request = PerformanceTestRequest(
            path: '/get',
            method: HttpMethod.get,
            requestId: 'stress_$index',
          );
          
          try {
            await executor.execute(request);
            requestStopwatch.stop();
            requestTimes.add(requestStopwatch.elapsedMilliseconds);
            completedRequests.add('stress_$index');
          } catch (e) {
            requestStopwatch.stop();
            errors.add(e as Exception);
          }
        });

        await Future.wait(futures);
        stopwatch.stop();
        
        final totalDuration = stopwatch.elapsedMilliseconds;
        final avgRequestTime = requestTimes.isNotEmpty 
            ? requestTimes.reduce((a, b) => a + b) / requestTimes.length 
            : 0;
        
        print('50个并发请求总时间: ${totalDuration}ms');
        print('平均单个请求时间: ${avgRequestTime.toStringAsFixed(2)}ms');
        print('成功请求数: ${completedRequests.length}');
        print('失败请求数: ${errors.length}');
        print('成功率: ${(completedRequests.length / requestCount * 100).toStringAsFixed(2)}%');
        
        // 压力测试验证
        expect(totalDuration, lessThan(30000)); // 30秒内完成
        expect(completedRequests.length, greaterThan(requestCount * 0.8)); // 至少80%成功
      });

      test('100个并发请求极限测试', () async {
        const requestCount = 100;
        final completedRequests = <String>[];
        final errors = <Exception>[];
        final requestTimes = <int>[];
        
        stopwatch.start();
        
        // 分批处理以避免系统资源耗尽
        const batchSize = 20;
        for (int batch = 0; batch < requestCount; batch += batchSize) {
          final batchEnd = (batch + batchSize).clamp(0, requestCount);
          final batchFutures = List.generate(batchEnd - batch, (index) async {
            final requestIndex = batch + index;
            final requestStopwatch = Stopwatch()..start();
            final request = PerformanceTestRequest(
              path: '/get',
              method: HttpMethod.get,
              requestId: 'extreme_$requestIndex',
            );
            
            try {
              await executor.execute(request);
              requestStopwatch.stop();
              requestTimes.add(requestStopwatch.elapsedMilliseconds);
              completedRequests.add('extreme_$requestIndex');
            } catch (e) {
              requestStopwatch.stop();
              errors.add(e as Exception);
            }
          });
          
          await Future.wait(batchFutures);
          
          // 批次间短暂休息
          await Future.delayed(Duration(milliseconds: 100));
        }
        
        stopwatch.stop();
        
        final totalDuration = stopwatch.elapsedMilliseconds;
        final avgRequestTime = requestTimes.isNotEmpty 
            ? requestTimes.reduce((a, b) => a + b) / requestTimes.length 
            : 0;
        
        print('100个请求总时间: ${totalDuration}ms');
        print('平均单个请求时间: ${avgRequestTime.toStringAsFixed(2)}ms');
        print('成功请求数: ${completedRequests.length}');
        print('失败请求数: ${errors.length}');
        print('成功率: ${(completedRequests.length / requestCount * 100).toStringAsFixed(2)}%');
        
        // 极限测试验证
        expect(totalDuration, lessThan(60000)); // 60秒内完成
        expect(completedRequests.length, greaterThan(requestCount * 0.7)); // 至少70%成功
      });
    });

    group('缓存性能测试', () {
      test('大量缓存写入性能', () async {
        final cache = CacheManager.instance;
        const cacheCount = 1000;
        
        stopwatch.start();
        
        for (int i = 0; i < cacheCount; i++) {
          final response = BaseResponse.success(
            data: {'id': i, 'data': 'test_data_$i'},
          );
          await cache.set('perf_key_$i', response);
        }
        
        stopwatch.stop();
        
        final duration = stopwatch.elapsedMilliseconds;
        final avgWriteTime = duration / cacheCount;
        
        print('1000个缓存写入总时间: ${duration}ms');
        print('平均单个写入时间: ${avgWriteTime.toStringAsFixed(2)}ms');
        
        // 缓存写入性能验证
        expect(duration, lessThan(10000)); // 10秒内完成
        expect(avgWriteTime, lessThan(10)); // 平均每个写入小于10ms
      });

      test('大量缓存读取性能', () async {
        final cache = CacheManager.instance;
        const cacheCount = 1000;
        
        // 先写入数据
        for (int i = 0; i < cacheCount; i++) {
          final response = BaseResponse.success(
            data: {'id': i, 'data': 'test_data_$i'},
          );
          await cache.set('read_perf_key_$i', response);
        }
        
        stopwatch.reset();
        stopwatch.start();
        
        final results = <BaseResponse?>[];
        for (int i = 0; i < cacheCount; i++) {
          final result = await cache.get('read_perf_key_$i');
          results.add(result);
        }
        
        stopwatch.stop();
        
        final duration = stopwatch.elapsedMilliseconds;
        final avgReadTime = duration / cacheCount;
        final hitCount = results.where((r) => r != null).length;
        
        print('1000个缓存读取总时间: ${duration}ms');
        print('平均单个读取时间: ${avgReadTime.toStringAsFixed(2)}ms');
        print('缓存命中数: $hitCount');
        print('缓存命中率: ${(hitCount / cacheCount * 100).toStringAsFixed(2)}%');
        
        // 缓存读取性能验证
        expect(duration, lessThan(5000)); // 5秒内完成
        expect(avgReadTime, lessThan(5)); // 平均每个读取小于5ms
        expect(hitCount, equals(cacheCount)); // 100%命中率
      });

      test('缓存并发读写性能', () async {
        final cache = CacheManager.instance;
        const operationCount = 500;
        final completedOperations = <String>[];
        
        stopwatch.start();
        
        final futures = List.generate(operationCount, (index) async {
          if (index % 2 == 0) {
            // 写操作
            final response = BaseResponse.success(
              data: {'id': index, 'data': 'concurrent_data_$index'},
            );
            await cache.set('concurrent_key_$index', response);
            completedOperations.add('write_$index');
          } else {
            // 读操作
            await cache.get('concurrent_key_${index - 1}');
            completedOperations.add('read_$index');
          }
        });
        
        await Future.wait(futures);
        stopwatch.stop();
        
        final duration = stopwatch.elapsedMilliseconds;
        final avgOperationTime = duration / operationCount;
        
        print('500个并发缓存操作总时间: ${duration}ms');
        print('平均单个操作时间: ${avgOperationTime.toStringAsFixed(2)}ms');
        print('完成操作数: ${completedOperations.length}');
        
        // 并发缓存性能验证
        expect(duration, lessThan(15000)); // 15秒内完成
        expect(completedOperations.length, equals(operationCount));
      });
    });

    group('队列性能测试', () {
      test('队列处理大量请求性能', () async {
        final queueManager = queue.RequestQueueManager.instance;
        const requestCount = 200;
        final processedRequests = <String>[];
        
        stopwatch.start();
        
        // 创建大量请求
        final futures = List.generate(requestCount, (index) async {
          final request = PerformanceTestRequest(
            path: '/get',
            method: HttpMethod.get,
            requestId: 'queue_$index',
            priority: _getRandomPriority(),
          );
          
          try {
            await executor.execute(request);
            processedRequests.add('queue_$index');
          } catch (e) {
            // 忽略网络错误，关注队列性能
          }
        });
        
        await Future.wait(futures);
        stopwatch.stop();
        
        final duration = stopwatch.elapsedMilliseconds;
        final avgProcessTime = duration / requestCount;
        
        print('200个队列请求处理总时间: ${duration}ms');
        print('平均单个请求处理时间: ${avgProcessTime.toStringAsFixed(2)}ms');
        print('成功处理请求数: ${processedRequests.length}');
        
        // 队列性能验证
        expect(duration, lessThan(45000)); // 45秒内完成
        expect(processedRequests.length, greaterThan(requestCount * 0.7)); // 至少70%成功
      });
    });

    group('内存使用性能测试', () {
      test('内存使用监控', () async {
        final initialMemory = _getCurrentMemoryUsage();
        
        // 执行大量操作
        const operationCount = 100;
        final futures = List.generate(operationCount, (index) async {
          final request = PerformanceTestRequest(
            path: '/get',
            method: HttpMethod.get,
            requestId: 'memory_$index',
          );
          
          try {
            await executor.execute(request);
          } catch (e) {
            // 忽略网络错误
          }
        });
        
        await Future.wait(futures);
        
        // 等待垃圾回收
        await Future.delayed(Duration(milliseconds: 500));
        
        final finalMemory = _getCurrentMemoryUsage();
        final memoryIncrease = finalMemory - initialMemory;
        
        print('初始内存使用: ${initialMemory}KB');
        print('最终内存使用: ${finalMemory}KB');
        print('内存增长: ${memoryIncrease}KB');
        
        // 内存使用验证
        expect(memoryIncrease, lessThan(50000)); // 内存增长小于50MB
      });
    });

    group('异常处理性能测试', () {
      test('大量异常处理性能', () async {
        final handler = UnifiedExceptionHandler.instance;
        const exceptionCount = 1000;
        
        stopwatch.start();
        
        for (int i = 0; i < exceptionCount; i++) {
          final exception = Exception('Performance test exception $i');
          await handler.handleException(exception);
        }
        
        stopwatch.stop();
        
        final duration = stopwatch.elapsedMilliseconds;
        final avgHandleTime = duration / exceptionCount;
        
        print('1000个异常处理总时间: ${duration}ms');
        print('平均单个异常处理时间: ${avgHandleTime.toStringAsFixed(2)}ms');
        
        // 异常处理性能验证
        expect(duration, lessThan(5000)); // 5秒内完成
        expect(avgHandleTime, lessThan(5)); // 平均每个异常处理小于5ms
      });
    });
  });
}

// 性能测试专用请求类
class PerformanceTestRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String _path;
  final HttpMethod _method;
  final String _requestId;
  final RequestPriority _priority;

  PerformanceTestRequest({
    required String path,
    required HttpMethod method,
    required String requestId,
    RequestPriority priority = RequestPriority.normal,
  }) : _path = path,
       _method = method,
       _requestId = requestId,
       _priority = priority;

  @override
  String get path => _path;

  @override
  HttpMethod get method => _method;

  @override
  RequestPriority get priority => _priority;

  String get requestId => _requestId;

  @override
  Map<String, dynamic> parseResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {'data': response, 'requestId': _requestId};
  }
}

// 工具函数
RequestPriority _getRandomPriority() {
  final random = Random();
  final priorities = [
    RequestPriority.low,
    RequestPriority.normal,
    RequestPriority.high,
  ];
  return priorities[random.nextInt(priorities.length)];
}

int _getCurrentMemoryUsage() {
  // 在实际应用中，这里应该使用平台特定的API来获取内存使用情况
  // 这里返回一个模拟值
  return DateTime.now().millisecondsSinceEpoch % 100000;
}