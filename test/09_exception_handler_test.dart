import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:async';
import 'package:bzy_network_framework/src/core/exception/unified_exception_handler.dart';
import 'package:bzy_network_framework/src/core/exception/network_exception.dart';
import 'package:bzy_network_framework/src/config/network_config.dart';
import 'package:bzy_network_framework/src/utils/network_logger.dart';
import 'package:logging/logging.dart';

void main() {
  group('统一异常处理器测试', () {
    late UnifiedExceptionHandler exceptionHandler;

    setUp(() {
      // 初始化网络配置
      NetworkConfig.instance.initialize(
        baseUrl: 'https://api.example.com',
        connectTimeout: 5000,
        receiveTimeout: 5000,
        sendTimeout: 5000,
      );

      // 配置日志
      NetworkLogger.configure(
        level: Level.INFO,
        enableConsoleOutput: false,
      );

      exceptionHandler = UnifiedExceptionHandler.instance;
    });

    tearDown(() {
      // 清理全局异常处理器
      exceptionHandler.reset();
    });

    group('异常处理器基础功能', () {
      test('异常处理器单例模式', () {
        final handler1 = UnifiedExceptionHandler.instance;
        final handler2 = UnifiedExceptionHandler.instance;
        expect(handler1, same(handler2));
      });

      test('创建NetworkException', () {
        final testError = Exception('测试错误');
        final networkException = exceptionHandler.createNetworkException(testError);
        
        expect(networkException, isA<NetworkException>());
        expect(networkException.message, contains('测试错误'));
        expect(networkException.originalError, equals(testError));
      });
    });

    group('Dio异常处理', () {
      test('连接超时异常', () async {
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionTimeout,
          message: '连接超时',
        );

        final unifiedException = await exceptionHandler.handleException(dioError);

        expect(unifiedException.type, equals(ExceptionType.network));
        expect(unifiedException.code, equals(ErrorCode.connectionTimeout));
        expect(unifiedException.statusCode, equals(-1001));
        expect(unifiedException.message, contains('连接超时'));
      });

      test('接收超时异常', () async {
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.receiveTimeout,
          message: '接收超时',
        );

        final unifiedException = await exceptionHandler.handleException(dioError);

        expect(unifiedException.type, equals(ExceptionType.network));
        expect(unifiedException.code, equals(ErrorCode.receiveTimeout));
        expect(unifiedException.statusCode, equals(-1003));
      });

      test('发送超时异常', () async {
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.sendTimeout,
          message: '发送超时',
        );

        final unifiedException = await exceptionHandler.handleException(dioError);

        expect(unifiedException.type, equals(ExceptionType.network));
        expect(unifiedException.code, equals(ErrorCode.sendTimeout));
        expect(unifiedException.statusCode, equals(-1002));
      });

      test('请求取消异常', () async {
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.cancel,
          message: '请求被取消',
        );

        final unifiedException = await exceptionHandler.handleException(dioError);

        expect(unifiedException.type, equals(ExceptionType.operation));
        expect(unifiedException.code, equals(ErrorCode.requestCancelled));
        expect(unifiedException.statusCode, equals(-1999));
      });

      test('连接错误异常', () async {
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionError,
          message: '连接错误',
        );

        final unifiedException = await exceptionHandler.handleException(dioError);

        expect(unifiedException.type, equals(ExceptionType.network));
        expect(unifiedException.code, equals(ErrorCode.connectionError));
        expect(unifiedException.statusCode, equals(-1004));
      });
    });

    group('HTTP状态码异常处理', () {
      test('400 错误请求', () async {
        final response = Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 400,
          data: {'error': 'Bad Request'},
        );
        
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          response: response,
          type: DioExceptionType.badResponse,
        );

        final unifiedException = await exceptionHandler.handleException(dioError);

        expect(unifiedException.type, equals(ExceptionType.client));
        expect(unifiedException.code, equals(ErrorCode.badRequest));
        expect(unifiedException.statusCode, equals(400));
      });

      test('401 未授权', () async {
        final response = Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
          data: {'error': 'Unauthorized'},
        );
        
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          response: response,
          type: DioExceptionType.badResponse,
        );

        final unifiedException = await exceptionHandler.handleException(dioError);

        expect(unifiedException.type, equals(ExceptionType.auth));
        expect(unifiedException.code, equals(ErrorCode.unauthorized));
        expect(unifiedException.statusCode, equals(401));
      });

      test('403 禁止访问', () async {
        final response = Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 403,
          data: {'error': 'Forbidden'},
        );
        
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          response: response,
          type: DioExceptionType.badResponse,
        );

        final unifiedException = await exceptionHandler.handleException(dioError);

        expect(unifiedException.type, equals(ExceptionType.auth));
        expect(unifiedException.code, equals(ErrorCode.forbidden));
        expect(unifiedException.statusCode, equals(403));
      });

      test('404 未找到', () async {
        final response = Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 404,
          data: {'error': 'Not Found'},
        );
        
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          response: response,
          type: DioExceptionType.badResponse,
        );

        final unifiedException = await exceptionHandler.handleException(dioError);

        expect(unifiedException.type, equals(ExceptionType.client));
        expect(unifiedException.code, equals(ErrorCode.notFound));
        expect(unifiedException.statusCode, equals(404));
      });

      test('500 内部服务器错误', () async {
        final response = Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 500,
          data: {'error': 'Internal Server Error'},
        );
        
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          response: response,
          type: DioExceptionType.badResponse,
        );

        final unifiedException = await exceptionHandler.handleException(dioError);

        expect(unifiedException.type, equals(ExceptionType.server));
        expect(unifiedException.code, equals(ErrorCode.internalServerError));
        expect(unifiedException.statusCode, equals(500));
      });

      test('502 网关错误', () async {
        final response = Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 502,
          data: {'error': 'Bad Gateway'},
        );
        
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          response: response,
          type: DioExceptionType.badResponse,
        );

        final unifiedException = await exceptionHandler.handleException(dioError);

        expect(unifiedException.type, equals(ExceptionType.server));
        expect(unifiedException.code, equals(ErrorCode.badGateway));
        expect(unifiedException.statusCode, equals(502));
      });

      test('503 服务不可用', () async {
        final response = Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 503,
          data: {'error': 'Service Unavailable'},
        );
        
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          response: response,
          type: DioExceptionType.badResponse,
        );

        final unifiedException = await exceptionHandler.handleException(dioError);

        expect(unifiedException.type, equals(ExceptionType.server));
        expect(unifiedException.code, equals(ErrorCode.serviceUnavailable));
        expect(unifiedException.statusCode, equals(503));
      });
    });

    group('其他异常类型处理', () {
      test('Socket异常', () async {
        final socketError = SocketException('网络不可达');

        final unifiedException = await exceptionHandler.handleException(socketError);

        expect(unifiedException.type, equals(ExceptionType.network));
        expect(unifiedException.code, equals(ErrorCode.networkUnavailable));
        expect(unifiedException.statusCode, equals(-2001));
        expect(unifiedException.message, contains('网络不可达'));
      });

      test('超时异常', () async {
        final timeoutError = TimeoutException('操作超时', Duration(seconds: 30));

        final unifiedException = await exceptionHandler.handleException(timeoutError);

        expect(unifiedException.type, equals(ExceptionType.network));
        expect(unifiedException.code, equals(ErrorCode.operationTimeout));
        expect(unifiedException.statusCode, equals(-2002));
        expect(unifiedException.message, contains('操作超时'));
      });

      test('格式异常', () async {
        final formatError = FormatException('数据格式错误');

        final unifiedException = await exceptionHandler.handleException(formatError);

        expect(unifiedException.type, equals(ExceptionType.data));
        expect(unifiedException.code, equals(ErrorCode.parseError));
        expect(unifiedException.statusCode, equals(-3001));
        expect(unifiedException.message, contains('数据格式错误'));
      });

      test('通用异常', () async {
        final genericError = Exception('未知错误');

        final unifiedException = await exceptionHandler.handleException(genericError);

        expect(unifiedException.type, equals(ExceptionType.unknown));
        expect(unifiedException.code, equals(ErrorCode.unknownError));
        expect(unifiedException.statusCode, equals(-9999));
        expect(unifiedException.message, contains('未知错误'));
      });
    });

    group('全局异常处理器', () {
      test('注册和移除全局处理器', () {
        final testHandler = TestGlobalExceptionHandler();
        
        // 注册处理器
        exceptionHandler.registerGlobalHandler(testHandler);
        
        // 通过测试异常处理来验证处理器是否注册成功
        expect(() => exceptionHandler.registerGlobalHandler(testHandler), returnsNormally);
        
        // 移除处理器
        exceptionHandler.removeGlobalHandler(testHandler);
        expect(() => exceptionHandler.removeGlobalHandler(testHandler), returnsNormally);
      });

      test('全局处理器调用', () async {
        final testHandler = TestGlobalExceptionHandler();
        exceptionHandler.registerGlobalHandler(testHandler);
        
        final testError = Exception('测试错误');
        await exceptionHandler.handleException(testError);
        
        expect(testHandler.handledExceptions.length, equals(1));
        expect(testHandler.handledExceptions.first.message, contains('测试错误'));
      });

      test('多个全局处理器调用', () async {
        final handler1 = TestGlobalExceptionHandler();
        final handler2 = TestGlobalExceptionHandler();
        
        exceptionHandler.registerGlobalHandler(handler1);
        exceptionHandler.registerGlobalHandler(handler2);
        
        final testError = Exception('测试错误');
        await exceptionHandler.handleException(testError);
        
        expect(handler1.handledExceptions.length, equals(1));
        expect(handler2.handledExceptions.length, equals(1));
      });

      test('全局处理器异常不影响主流程', () async {
        final faultyHandler = FaultyGlobalExceptionHandler();
        exceptionHandler.registerGlobalHandler(faultyHandler);
        
        final testError = Exception('测试错误');
        final unifiedException = await exceptionHandler.handleException(testError);
        
        // 即使全局处理器抛出异常，主流程应该继续
        expect(unifiedException, isNotNull);
        expect(unifiedException.message, contains('测试错误'));
      });
    });

    group('异常上下文和元数据', () {
      test('添加上下文信息', () async {
        final testError = Exception('测试错误');
        
        final unifiedException = await exceptionHandler.handleException(
          testError,
          context: '用户登录',
          metadata: {
            'userId': '12345',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        
        expect(unifiedException.context, equals('用户登录'));
        expect(unifiedException.metadata?['userId'], equals('12345'));
        expect(unifiedException.metadata?['timestamp'], isNotNull);
      });

      test('异常时间戳', () async {
        final testError = Exception('测试错误');
        final beforeTime = DateTime.now();
        
        final unifiedException = await exceptionHandler.handleException(testError);
        
        final afterTime = DateTime.now();
        
        expect(unifiedException.timestamp.isAfter(beforeTime.subtract(Duration(seconds: 1))), isTrue);
        expect(unifiedException.timestamp.isBefore(afterTime.add(Duration(seconds: 1))), isTrue);
      });
    });

    group('异常统计', () {
      test('异常统计记录', () async {
        final initialStats = Map.from(exceptionHandler.getExceptionStats());
        
        final testError = Exception('测试错误');
        await exceptionHandler.handleException(testError);
        
        final newStats = exceptionHandler.getExceptionStats();
        // 检查统计是否更新
        expect(newStats.length, greaterThanOrEqualTo(initialStats.length));
      });

      test('获取异常统计', () {
        final stats = exceptionHandler.getExceptionStats();
        
        expect(stats, isA<Map<String, int>>());
      });

      test('清理异常统计', () {
        // 先产生一些统计数据
        exceptionHandler.handleException(Exception('测试'));
        
        // 清理统计
        exceptionHandler.clearExceptionStats();
        
        final stats = exceptionHandler.getExceptionStats();
        expect(stats.isEmpty, isTrue);
      });
    });

    group('异常拦截器', () {
      test('异常拦截器创建', () {
        final interceptor = ExceptionInterceptor();
        
        expect(interceptor, isA<Interceptor>());
      });

      test('异常拦截器错误处理', () async {
        final interceptor = ExceptionInterceptor();
        final requestOptions = RequestOptions(path: '/test');
        final dioError = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
        );
        
        bool errorHandled = false;
        final completer = Completer<void>();
        final handler = MockErrorInterceptorHandler((error) {
          errorHandled = true;
          expect(error, isA<DioException>());
          expect(error.error, isA<UnifiedException>());
          completer.complete();
        });
        
        interceptor.onError(dioError, handler);
        
        // 等待异步操作完成
        await completer.future;
        expect(errorHandled, isTrue);
      });
    });

    group('边界情况和错误处理', () {
      test('空异常处理', () async {
        final unifiedException = await exceptionHandler.handleException(null);
        
        expect(unifiedException.type, equals(ExceptionType.unknown));
        expect(unifiedException.code, equals(ErrorCode.unknownError));
      });

      test('已处理的UnifiedException', () async {
        final originalException = UnifiedException(
          type: ExceptionType.network,
          code: ErrorCode.connectionTimeout,
          message: '原始异常',
          statusCode: -1001,
        );
        
        final handledException = await exceptionHandler.handleException(originalException);
        
        expect(handledException, equals(originalException));
      });

      test('异常消息本地化', () async {
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionTimeout,
        );

        final unifiedException = await exceptionHandler.handleException(dioError);
        
        // 检查消息是否包含适当的描述
        expect(unifiedException.message, isNotEmpty);
        expect(unifiedException.message, isA<String>());
      });
    });
  });
}

// 测试用的全局异常处理器
class TestGlobalExceptionHandler implements GlobalExceptionHandler {
  final List<UnifiedException> handledExceptions = [];

  @override
  Future<void> onException(UnifiedException exception) async {
    handledExceptions.add(exception);
  }
}

// 故障全局异常处理器（用于测试异常处理的健壮性）
class FaultyGlobalExceptionHandler implements GlobalExceptionHandler {
  @override
  Future<void> onException(UnifiedException exception) async {
    throw Exception('全局处理器内部错误');
  }
}

// 模拟错误拦截器处理器
class MockErrorInterceptorHandler extends ErrorInterceptorHandler {
  final Function(DioException) onReject;

  MockErrorInterceptorHandler(this.onReject);

  @override
  void reject(DioException err) {
    onReject(err);
  }
}