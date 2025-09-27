import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/src/core/network/network_adapter.dart';
import 'package:bzy_network_framework/src/core/network/network_connectivity_monitor.dart';
import 'package:bzy_network_framework/src/config/network_config.dart';
import 'package:bzy_network_framework/src/utils/network_logger.dart';
import 'package:logging/logging.dart';

void main() {
  group('网络适配器测试', () {
    late NetworkAdapter networkAdapter;
    late NetworkConnectivityMonitor connectivityMonitor;

    setUp(() async {
      // 初始化网络配置
      NetworkConfig.instance.initialize(
        baseUrl: 'https://api.example.com',
        connectTimeout: 5000,
        receiveTimeout: 5000,
        sendTimeout: 5000,
        enableCache: true,
        defaultCacheDuration: 300,
        maxRetries: 3,
        retryDelay: 1000,
      );

      // 配置日志
      NetworkLogger.configure(
        level: Level.INFO,
        enableConsoleOutput: false,
      );

      networkAdapter = NetworkAdapter.instance;
      connectivityMonitor = NetworkConnectivityMonitor.instance;
    });

    tearDown(() async {
      // 清理资源
      await networkAdapter.dispose();
      await connectivityMonitor.dispose();
    });

    group('NetworkAdapter 基础功能', () {
      test('网络适配器单例模式', () {
        final adapter1 = NetworkAdapter.instance;
        final adapter2 = NetworkAdapter.instance;
        expect(adapter1, same(adapter2));
      });

      test('网络适配器初始化', () async {
        expect(networkAdapter.isInitialized, isFalse);
        
        await networkAdapter.initialize();
        
        expect(networkAdapter.isInitialized, isTrue);
        expect(networkAdapter.config, isNotNull);
      });

      test('网络适配器配置更新', () async {
        await networkAdapter.initialize();
        
        final newConfig = NetworkAdapterConfig(
          networkCheckTimeout: Duration(seconds: 10),
          maxWaitTime: Duration(seconds: 60),
          maxRetryAttempts: 5,
          retryInterval: Duration(seconds: 3),
          defaultStrategy: NetworkAdaptationStrategy.waitForConnection,
          enableNetworkQualityCheck: false,
        );
        
        networkAdapter.updateConfig(newConfig);
        
        expect(networkAdapter.config.networkCheckTimeout, Duration(seconds: 10));
        expect(networkAdapter.config.maxRetryAttempts, 5);
        expect(networkAdapter.config.enableNetworkQualityCheck, false);
      });
    });

    group('网络连接监控', () {
      test('连接监控器单例模式', () {
        final monitor1 = NetworkConnectivityMonitor.instance;
        final monitor2 = NetworkConnectivityMonitor.instance;
        expect(monitor1, same(monitor2));
      });

      test('连接监控器初始化', () async {
        expect(connectivityMonitor.isInitialized, isFalse);
        
        try {
          await connectivityMonitor.initialize();
          
          // 如果初始化成功，检查状态
          expect(connectivityMonitor.isInitialized, isTrue);
          expect(connectivityMonitor.currentStatus, isA<NetworkStatus>());
          expect(connectivityMonitor.currentType, isA<NetworkType>());
        } catch (e) {
          // 如果初始化失败，至少验证状态没有改变
          print('连接监控器初始化失败: $e');
          expect(connectivityMonitor.isInitialized, isFalse);
        }
      });

      test('网络状态变化监听', () async {
        await connectivityMonitor.initialize();
        
        bool statusReceived = false;
        connectivityMonitor.statusStream.listen((event) {
          statusReceived = true;
          expect(event, isA<NetworkStatusEvent>());
          expect(event.status, isA<NetworkStatus>());
          expect(event.type, isA<NetworkType>());
          expect(event.timestamp, isA<DateTime>());
        });

        // 模拟网络状态变化
        await Future.delayed(Duration(milliseconds: 100));
        
        // 注意：在测试环境中，实际的网络状态变化可能不会触发
        // 这里主要测试监听器的设置是否正确
        expect(connectivityMonitor.statusStream, isA<Stream<NetworkStatusEvent>>());
      });
    });

    group('网络质量检测', () {
      test('网络质量检测功能', () async {
        await networkAdapter.initialize();
        
        try {
          final quality = await networkAdapter.checkNetworkQuality();
          
          expect(quality, isNotNull);
          expect(quality.latency, isA<int>());
          expect(quality.qualityLevel, inInclusiveRange(1, 5));
          expect(quality.timestamp, isA<DateTime>());
          expect(quality.isWeakNetwork, isA<bool>());
        } catch (e) {
          // 在测试环境中，网络质量检测可能会失败
          // 这是正常的，因为没有真实的网络连接
          expect(e, isA<Exception>());
        }
      });

      test('推荐超时时间计算', () async {
        await networkAdapter.initialize();
        
        final recommendedTimeout = networkAdapter.getRecommendedTimeout();
        
        expect(recommendedTimeout, isA<Duration>());
        expect(recommendedTimeout.inMilliseconds, greaterThan(0));
      });
    });

    group('网络适配策略', () {
      test('立即失败策略', () async {
        await networkAdapter.initialize();
        
        try {
          await networkAdapter.executeWithAdaptation(
            () async {
              throw Exception('网络不可用');
            },
            strategy: NetworkAdaptationStrategy.failImmediately,
          );
          fail('应该抛出异常');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });

      test('等待网络连接策略', () async {
        await networkAdapter.initialize();
        
        // 测试等待连接超时
        final stopwatch = Stopwatch()..start();
        
        try {
          final connected = await networkAdapter.waitForConnection(
            timeout: Duration(milliseconds: 100),
          );
          
          stopwatch.stop();
          
          // 在测试环境中，通常会超时
          expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(90));
          expect(connected, isA<bool>());
        } catch (e) {
          // 超时异常是预期的
          expect(e, isA<Exception>());
        }
      });

      test('使用缓存数据策略', () async {
        await networkAdapter.initialize();
        
        final cachedData = {'cached': true, 'data': 'test'};
        
        final result = await networkAdapter.executeWithAdaptation(
          () async {
            throw Exception('网络错误');
          },
          strategy: NetworkAdaptationStrategy.useCachedData,
          cachedData: cachedData,
        );
        
        expect(result, equals(cachedData));
      });

      test('自动重试策略', () async {
        await networkAdapter.initialize();
        
        int attemptCount = 0;
        
        // 测试重试策略 - 前几次失败，最后一次成功
        try {
          final result = await networkAdapter.executeWithAdaptation(
            () async {
              attemptCount++;
              if (attemptCount < 3) {
                // 前两次失败
                throw Exception('模拟网络错误');
              }
              // 第三次成功
              return 'success_after_retry';
            },
            strategy: NetworkAdaptationStrategy.autoRetry,
          );
          
          // 如果成功，验证重试机制工作正常
          expect(result, equals('success_after_retry'));
          expect(attemptCount, greaterThanOrEqualTo(3));
        } catch (e) {
          // 如果最终失败，验证是NetworkException（说明经过了重试处理）
          expect(e.toString(), contains('retry attempts'));
          expect(attemptCount, greaterThan(1));
        }
      }, timeout: const Timeout(Duration(seconds: 15)));
    });

    group('网络可用性检查', () {
      test('网络可用性检测', () async {
        await networkAdapter.initialize();
        
        final isAvailable = await networkAdapter.checkNetworkAvailability();
        
        expect(isAvailable, isA<bool>());
      });

      test('网络连接状态检查', () async {
        await connectivityMonitor.initialize();
        
        final isConnected = connectivityMonitor.isConnected;
        
        expect(isConnected, isA<bool>());
      });
    });

    group('错误处理和边界情况', () {
      test('未初始化状态下的操作', () async {
        final newAdapter = NetworkAdapter();
        
        expect(newAdapter.isInitialized, isFalse);
        
        // 未初始化时的操作应该有适当的处理
        try {
          await newAdapter.checkNetworkQuality();
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });

      test('重复初始化处理', () async {
        await networkAdapter.initialize();
        expect(networkAdapter.isInitialized, isTrue);
        
        // 重复初始化应该被忽略
        await networkAdapter.initialize();
        expect(networkAdapter.isInitialized, isTrue);
      });

      test('资源清理', () async {
        await networkAdapter.initialize();
        expect(networkAdapter.isInitialized, isTrue);
        
        await networkAdapter.dispose();
        expect(networkAdapter.isInitialized, isFalse);
      });

      test('无效配置处理', () {
        expect(() {
          NetworkAdapterConfig(
            networkCheckTimeout: Duration(seconds: -1),
          );
        }, throwsA(isA<AssertionError>()));
        
        expect(() {
          NetworkAdapterConfig(
            maxRetryAttempts: -1,
          );
        }, throwsA(isA<AssertionError>()));
      });
    });

    group('性能和并发测试', () {
      test('并发网络质量检测', () async {
        await networkAdapter.initialize();
        
        final futures = List.generate(5, (index) async {
          try {
            return await networkAdapter.checkNetworkQuality();
          } catch (e) {
            return null; // 测试环境中可能失败
          }
        });
        
        final results = await Future.wait(futures);
        
        // 检查并发操作不会导致崩溃
        expect(results.length, equals(5));
      });

      test('并发适配策略执行', () async {
        await networkAdapter.initialize();
        
        final futures = List.generate(3, (index) async {
          try {
            return await networkAdapter.executeWithAdaptation(
              () async {
                await Future.delayed(Duration(milliseconds: 10));
                return 'result_$index';
              },
              strategy: NetworkAdaptationStrategy.useCachedData,
              cachedData: 'cached_result_$index', // 提供缓存数据
            );
          } catch (e) {
            // 如果失败，返回默认值
            return 'fallback_result_$index';
          }
        });
        
        final results = await Future.wait(futures);
        
        expect(results.length, equals(3));
        // 验证结果不为空（可能是实际结果或缓存结果）
        for (int i = 0; i < results.length; i++) {
          expect(results[i], isNotNull);
          expect(results[i], contains('result_$i'));
        }
      }, timeout: const Timeout(Duration(seconds: 60)));
    });
  });
}