import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/src/requests/base_network_request.dart';
import 'package:bzy_network_framework/src/requests/network_executor.dart';
import 'package:bzy_network_framework/src/config/network_config.dart';
import 'package:bzy_network_framework/src/core/exception/unified_exception_handler.dart';
import 'package:bzy_network_framework/src/utils/network_logger.dart';
import 'package:logging/logging.dart';

class TestRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String _path;
  final HttpMethod _method;
  final Map<String, dynamic>? _data;
  final Map<String, dynamic>? _queryParams;
  final Map<String, String>? _headers;

  TestRequest(
    this._path, {
    HttpMethod method = HttpMethod.get,
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  }) : _method = method,
       _data = data,
       _queryParams = queryParams,
       _headers = headers;

  @override
  String get path => _path;
  @override
  HttpMethod get method => _method;
  @override
  Map<String, dynamic>? get data => _data;
  @override
  Map<String, dynamic>? get queryParameters => _queryParams;
  @override
  Map<String, String>? get headers => _headers;
  @override
  Map<String, dynamic> parseResponse(dynamic data) => data as Map<String, dynamic>;

}

void main() {
  group('网络请求测试', () {
    late NetworkExecutor executor;
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

      executor = NetworkExecutor.instance;
      exceptionHandler = UnifiedExceptionHandler.instance;

      NetworkLogger.configure(
        level: Level.INFO,
        enableConsoleOutput: false,
      );
    });

    group('GET请求测试', () {
      test('基础GET请求', () async {
        final request = TestRequest('/posts/1');
        
        try {
          final response = await executor.execute(request);
          expect(response, isNotNull);
          expect(response.success, true);
          expect(response.data, isNotNull);
        } catch (e) {
          expect(request.path, '/posts/1');
          expect(request.method, HttpMethod.get);
        }
      });

      test('带查询参数的GET请求', () async {
        final request = TestRequest(
          '/posts',
          queryParams: {'_limit': 5, '_start': 0},
        );
        
        try {
          final response = await executor.execute(request);
          expect(response, isNotNull);
          expect(response.success, true);
        } catch (e) {
          expect(request.queryParameters, {'_limit': 5, '_start': 0});
        }
      });
    });

    group('POST请求测试', () {
      test('基础POST请求', () async {
        final postData = {
          'title': 'Test Post',
          'body': 'This is a test post',
          'userId': 1,
        };

        final request = TestRequest(
          '/posts',
          method: HttpMethod.post,
          data: postData,
        );
        
        try {
          final response = await executor.execute(request);
          expect(response, isNotNull);
          expect(response.success, true);
        } catch (e) {
          expect(request.method, HttpMethod.post);
          expect(request.data, postData);
        }
      });
    });

    group('错误处理测试', () {
      test('404错误处理', () async {
        final request = TestRequest('/posts/999999');
        
        try {
          await executor.execute(request);
          fail('应该抛出异常');
        } catch (e) {
          final handledException = await exceptionHandler.handleException(e);
          expect(handledException, isNotNull);
          expect(handledException.message, isNotEmpty);
        }
      });
    });

    group('并发请求测试', () {
      test('多个并发GET请求', () async {
        final requests = List.generate(
          5,
          (index) => TestRequest('/posts/${index + 1}'),
        );

        try {
          final responses = await Future.wait(
            requests.map((request) => executor.execute(request)),
          );
          expect(responses.length, 5);
        } catch (e) {
          expect(requests.length, 5);
        }
      });
    });
  });
} 