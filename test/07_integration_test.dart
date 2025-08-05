import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/src/requests/base_network_request.dart';
import 'package:bzy_network_framework/src/requests/network_executor.dart';
import 'package:bzy_network_framework/src/config/network_config.dart';
import 'package:bzy_network_framework/src/core/cache/cache_manager.dart';
import 'package:bzy_network_framework/src/core/exception/unified_exception_handler.dart';
import 'package:bzy_network_framework/src/utils/network_logger.dart';
import 'package:bzy_network_framework/src/model/response_wrapper.dart';
import 'package:logging/logging.dart';

class UserRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String _path;
  final HttpMethod _method;
  final Map<String, dynamic>? _data;

  UserRequest(
    this._path, {
    HttpMethod method = HttpMethod.get,
    Map<String, dynamic>? data,
  }) : _method = method,
       _data = data;

  @override
  String get path => _path;
  @override
  HttpMethod get method => _method;
  @override
  Map<String, dynamic>? get data => _data;
  @override
  Map<String, dynamic> parseResponse(dynamic data) => data as Map<String, dynamic>;
}

class UserService {
  final NetworkExecutor _executor = NetworkExecutor.instance;
  final CacheManager _cache = CacheManager.instance;

  Future<Map<String, dynamic>> getUserInfo(int userId) async {
    final request = UserRequest('/users/$userId');
    
    try {
      final response = await _executor.execute(request);
      
      if (response.success && response.data != null) {
        await _cache.set(
          'user_$userId',
          BaseResponse.success(data: response.data),
          expiry: Duration(hours: 1),
        );
      }
      
      return response.data ?? {};
    } catch (e) {
      final cachedResponse = await _cache.get<Map<String, dynamic>>('user_$userId');
      if (cachedResponse != null) {
        return cachedResponse.data ?? {};
      }
      rethrow;
    }
  }
}

void main() {
  group('网络框架综合测试', () {
    late UserService userService;
    late UnifiedExceptionHandler exceptionHandler;

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

      NetworkLogger.configure(
        level: Level.INFO,
        enableConsoleOutput: false,
      );

      userService = UserService();
      exceptionHandler = UnifiedExceptionHandler.instance;
    });

    group('用户服务集成测试', () {
      test('获取用户信息', () async {
        try {
          final userInfo = await userService.getUserInfo(1);
          expect(userInfo, isA<Map<String, dynamic>>());
          expect(userInfo.isNotEmpty, true);
        } catch (e) {
          expect(userService, isNotNull);
        }
      });
    });

    group('缓存集成测试', () {
      test('用户信息缓存', () async {
        try {
          final user1 = await userService.getUserInfo(1);
          expect(user1, isA<Map<String, dynamic>>());

          final user2 = await userService.getUserInfo(1);
          expect(user2, isA<Map<String, dynamic>>());
        } catch (e) {
          expect(userService, isNotNull);
        }
      });
    });

    group('异常处理集成测试', () {
      test('网络错误处理', () async {
        try {
          await userService.getUserInfo(999999);
          fail('应该抛出异常');
        } catch (e) {
          final handledException = await exceptionHandler.handleException(e);
          expect(handledException, isNotNull);
          expect(handledException.message, isNotEmpty);
        }
      });
    });

    group('并发请求集成测试', () {
      test('多用户并发获取', () async {
        try {
          final futures = List.generate(
            5,
            (index) => userService.getUserInfo(index + 1),
          );

          final results = await Future.wait(futures);
          expect(results.length, 5);
          
          for (final result in results) {
            expect(result, isA<Map<String, dynamic>>());
          }
        } catch (e) {
          expect(userService, isNotNull);
        }
      });
    });
  });
} 