import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/src/config/network_config.dart';
import 'package:bzy_network_framework/src/core/config/config_manager.dart';
import 'package:bzy_network_framework/src/core/config/config_validator.dart';
import 'package:bzy_network_framework/src/core/config/environment_config.dart';
import 'package:bzy_network_framework/src/core/config/hot_config_manager.dart';
import 'package:bzy_network_framework/src/utils/network_logger.dart';
import 'package:logging/logging.dart';

void main() {
  group('网络框架初始化测试', () {
    setUp(() {
      // 清理之前的配置
      NetworkConfig.instance.reset();
    });

    group('基础初始化测试', () {
      test('NetworkConfig 单例模式', () {
        final config1 = NetworkConfig.instance;
        final config2 = NetworkConfig.instance;
        expect(config1, same(config2));
      });

      test('基础配置初始化', () {
        NetworkConfig.instance.initialize(
          baseUrl: 'https://api.example.com',
          connectTimeout: 5000,
          receiveTimeout: 10000,
          sendTimeout: 5000,
          enableLogging: true,
          enableCache: true,
          defaultCacheDuration: 300,
          maxRetries: 3,
          retryDelay: 1000,
          enableExponentialBackoff: true,
        );

        expect(NetworkConfig.instance.baseUrl, 'https://api.example.com');
        expect(NetworkConfig.instance.connectTimeout, Duration(milliseconds: 5000));
        expect(NetworkConfig.instance.receiveTimeout, Duration(milliseconds: 10000));
        expect(NetworkConfig.instance.sendTimeout, Duration(milliseconds: 5000));
        expect(NetworkConfig.instance.enableLogging, true);
        expect(NetworkConfig.instance.enableCache, true);
        expect(NetworkConfig.instance.defaultCacheDuration, 300);
        expect(NetworkConfig.instance.maxRetries, 3);
        expect(NetworkConfig.instance.retryDelay, Duration(milliseconds: 1000));
        expect(NetworkConfig.instance.enableExponentialBackoff, true);
      });

      test('默认配置值', () {
        NetworkConfig.instance.initialize(
          baseUrl: 'https://api.example.com',
        );
        
        expect(NetworkConfig.instance.baseUrl, 'https://api.example.com');
        expect(NetworkConfig.instance.connectTimeout, isA<Duration>());
        expect(NetworkConfig.instance.receiveTimeout, isA<Duration>());
        expect(NetworkConfig.instance.sendTimeout, isA<Duration>());
        expect(NetworkConfig.instance.enableLogging, isA<bool>());
        expect(NetworkConfig.instance.enableCache, isA<bool>());
        expect(NetworkConfig.instance.defaultCacheDuration, isA<int>());
        expect(NetworkConfig.instance.maxRetries, isA<int>());
        expect(NetworkConfig.instance.retryDelay, isA<Duration>());
        expect(NetworkConfig.instance.enableExponentialBackoff, isA<bool>());
      });
    });

    group('配置管理器测试', () {
      test('ConfigManager 基础功能', () {
        final configManager = ConfigManager.instance;
        expect(configManager, isNotNull);
      });

      test('配置验证器测试', () {
        final validator = NetworkConfigValidator();
        expect(validator, isNotNull);
      });

      test('环境配置测试', () {
        final envConfig = EnvironmentConfig(
          baseUrl: 'https://api.example.com',
          connectTimeout: 5000,
          receiveTimeout: 10000,
          sendTimeout: 5000,
          maxRetryCount: 3,
          enableLogging: true,
          enableCache: true,
          cacheMaxAge: 300,
          enableExponentialBackoff: true,
        );
        expect(envConfig, isNotNull);
        expect(envConfig.baseUrl, 'https://api.example.com');
      });

      test('热配置管理器测试', () {
        final hotConfig = HotConfigManager.instance;
        expect(hotConfig, isNotNull);
      });
    });

    group('日志配置测试', () {
      test('NetworkLogger 配置', () {
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
    });

    group('配置验证测试', () {
      test('无效URL配置', () {
        expect(() {
          NetworkConfig.instance.initialize(baseUrl: '');
        }, throwsA(isA<Exception>()));
      });

      test('无效超时配置', () {
        expect(() {
          NetworkConfig.instance.initialize(
            baseUrl: 'https://api.example.com',
            connectTimeout: -1000,
          );
        }, throwsA(isA<Exception>()));
      });

      test('无效重试配置', () {
        expect(() {
          NetworkConfig.instance.initialize(
            baseUrl: 'https://api.example.com',
            maxRetries: -1,
          );
        }, throwsA(isA<Exception>()));
      });
    });

    group('配置重置测试', () {
      test('配置重置功能', () {
        NetworkConfig.instance.initialize(
          baseUrl: 'https://api.example.com',
          connectTimeout: 5000,
        );

        expect(NetworkConfig.instance.baseUrl, 'https://api.example.com');

        NetworkConfig.instance.reset();

        // 重置后应该使用默认值
        expect(NetworkConfig.instance.baseUrl, isNot('https://api.example.com'));
      });
    });

    group('初始化性能测试', () {
      test('快速初始化', () {
        final stopwatch = Stopwatch();
        stopwatch.start();

        for (int i = 0; i < 100; i++) {
          NetworkConfig.instance.initialize(
            baseUrl: 'https://api$i.example.com',
            connectTimeout: 5000,
          );
        }

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // 1秒内完成100次初始化
      });
    });

    group('环境配置功能测试', () {
      test('环境配置复制功能', () {
        final originalConfig = EnvironmentConfig(
          baseUrl: 'https://api.example.com',
          connectTimeout: 5000,
          receiveTimeout: 10000,
          sendTimeout: 5000,
          maxRetryCount: 3,
          enableLogging: true,
          enableCache: true,
          cacheMaxAge: 300,
          enableExponentialBackoff: true,
        );

        final copiedConfig = originalConfig.copyWith(
          baseUrl: 'https://new-api.example.com',
          connectTimeout: 8000,
        );

        expect(copiedConfig.baseUrl, 'https://new-api.example.com');
        expect(copiedConfig.connectTimeout, 8000);
        expect(copiedConfig.receiveTimeout, 10000); // 保持不变
        expect(copiedConfig.enableLogging, true); // 保持不变
      });

      test('环境配置Map转换', () {
        final config = EnvironmentConfig(
          baseUrl: 'https://api.example.com',
          connectTimeout: 5000,
          receiveTimeout: 10000,
          sendTimeout: 5000,
          maxRetryCount: 3,
          enableLogging: true,
          enableCache: true,
          cacheMaxAge: 300,
          enableExponentialBackoff: true,
        );

        final map = config.toMap();
        expect(map['baseUrl'], 'https://api.example.com');
        expect(map['connectTimeout'], 5000);
        expect(map['enableLogging'], true);

        final fromMapConfig = EnvironmentConfig.fromMap(map);
        expect(fromMapConfig.baseUrl, 'https://api.example.com');
        expect(fromMapConfig.connectTimeout, 5000);
        expect(fromMapConfig.enableLogging, true);
      });
    });
  });
} 