import 'package:test/test.dart';
import 'package:dio/dio.dart';
import 'package:bzy_network_framework/bzy_network_framework.dart';
import 'dart:io';

/// 统一异常处理测试示例
void main() {
  group('统一异常处理测试', () {
    late UnifiedExceptionHandler handler;
    late TestGlobalExceptionHandler globalHandler;
    
    setUp(() {
      handler = UnifiedExceptionHandler.instance;
      globalHandler = TestGlobalExceptionHandler();
      handler.registerGlobalHandler(globalHandler);
      handler.clearExceptionStats();
    });
    
    tearDown(() {
      handler.removeGlobalHandler(globalHandler);
      handler.clearExceptionStats();
    });
    
    test('测试 DioException 转换', () async {
      // 模拟连接超时异常
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
        message: '连接超时',
      );
      
      final unifiedException = await handler.handleException(dioError);
      
      expect(unifiedException.type, equals(ExceptionType.network));
      expect(unifiedException.code, equals(ErrorCode.connectionTimeout));
      expect(unifiedException.message, equals('连接超时，请检查网络连接'));
      expect(unifiedException.statusCode, equals(-1001));
    });
    
    test('测试 HTTP 状态码处理', () async {
      // 模拟 401 未授权错误
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
        ),
      );
      
      final unifiedException = await handler.handleException(dioError);
      
      expect(unifiedException.type, equals(ExceptionType.auth));
      expect(unifiedException.code, equals(ErrorCode.unauthorized));
      expect(unifiedException.message, equals('认证失败，请重新登录'));
      expect(unifiedException.statusCode, equals(401));
    });
    
    test('测试 SocketException 处理', () async {
      final socketError = const SocketException('网络不可达');
      
      final unifiedException = await handler.handleException(socketError);
      
      expect(unifiedException.type, equals(ExceptionType.network));
      expect(unifiedException.code, equals(ErrorCode.networkUnavailable));
      expect(unifiedException.message, equals('网络不可用，请检查网络连接'));
      expect(unifiedException.statusCode, equals(-2001));
    });
    
    test('测试 FormatException 处理', () async {
      final formatError = const FormatException('JSON解析失败');
      
      final unifiedException = await handler.handleException(formatError);
      
      expect(unifiedException.type, equals(ExceptionType.data));
      expect(unifiedException.code, equals(ErrorCode.parseError));
      expect(unifiedException.message, equals('数据解析失败'));
      expect(unifiedException.statusCode, equals(-3001));
    });
    
    test('测试自定义异常处理', () async {
      final customException = UnifiedException(
        type: ExceptionType.client,
        code: ErrorCode.validationError,
        message: '用户输入验证失败',
        statusCode: 400,
        metadata: {'field': 'email'},
      );
      
      final handledException = await handler.handleException(customException);
      
      expect(handledException.type, equals(ExceptionType.client));
      expect(handledException.code, equals(ErrorCode.validationError));
      expect(handledException.message, equals('用户输入验证失败'));
      expect(handledException.metadata?['field'], equals('email'));
    });
    
    test('测试异常统计功能', () async {
      // 处理多个异常
      await handler.handleException(DioException(
        requestOptions: RequestOptions(path: '/test1'),
        type: DioExceptionType.connectionTimeout,
      ));
      
      await handler.handleException(DioException(
        requestOptions: RequestOptions(path: '/test2'),
        type: DioExceptionType.connectionTimeout,
      ));
      
      await handler.handleException(DioException(
        requestOptions: RequestOptions(path: '/test3'),
        type: DioExceptionType.sendTimeout,
      ));
      
      final stats = handler.getExceptionStats();
      
      expect(stats['network_connectionTimeout'], equals(2));
      expect(stats['network_sendTimeout'], equals(1));
    });
    
    test('测试全局异常处理器调用', () async {
      final testException = UnifiedException(
        type: ExceptionType.server,
        code: ErrorCode.internalServerError,
        message: '服务器内部错误',
        statusCode: 500,
      );
      
      await handler.handleException(testException);
      
      expect(globalHandler.handledExceptions.length, equals(1));
      expect(globalHandler.handledExceptions.first.type, equals(ExceptionType.server));
    });
    
    test('测试异常上下文和元数据', () async {
      final error = Exception('测试异常');
      
      final unifiedException = await handler.handleException(
        error,
        context: '用户登录操作',
        metadata: {
          'userId': '123',
          'timestamp': '2024-01-01T00:00:00Z',
        },
      );
      
      expect(unifiedException.context, equals('用户登录操作'));
      expect(unifiedException.metadata?['userId'], equals('123'));
      expect(unifiedException.metadata?['timestamp'], equals('2024-01-01T00:00:00Z'));
    });
    
    test('测试异常重试判断', () {
      final networkException = UnifiedException(
        type: ExceptionType.network,
        code: ErrorCode.connectionTimeout,
        message: '连接超时',
        statusCode: -1001,
      );
      
      final authException = UnifiedException(
        type: ExceptionType.auth,
        code: ErrorCode.unauthorized,
        message: '未授权',
        statusCode: 401,
      );
      
      expect(networkException.isRetryable, isTrue);
      expect(authException.isRetryable, isFalse);
    });
    
    test('测试异常类型判断', () {
      final networkException = UnifiedException(
        type: ExceptionType.network,
        code: ErrorCode.connectionTimeout,
        message: '网络异常',
        statusCode: -1001,
      );
      
      expect(networkException.isNetworkError, isTrue);
      expect(networkException.isAuthError, isFalse);
      expect(networkException.isServerError, isFalse);
      expect(networkException.isClientError, isFalse);
    });
    
    test('测试异常拦截器', () async {
      final interceptor = ExceptionInterceptor();
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );
      
      bool errorHandled = false;
      final errorHandler = ErrorInterceptorHandler();
      
      // 模拟错误处理
      try {
        interceptor.onError(dioError, errorHandler);
      } catch (e) {
        errorHandled = true;
        expect(e, isA<DioException>());
        final wrappedError = e as DioException;
        expect(wrappedError.error, isA<UnifiedException>());
      }
      
      expect(errorHandled, isTrue);
    });
  });
  
  group('异常处理集成测试', () {
    late UnifiedNetworkFramework framework;
    
    setUp(() async {
      framework = UnifiedNetworkFramework.instance;
      // 重置框架状态 - 直接调用 dispose，如果未初始化会被忽略
      try {
        await framework.dispose();
      } catch (e) {
        // 忽略未初始化状态的错误
      }
    });
    
    test('测试网络框架异常处理集成', () async {
      await framework.initialize(
        baseUrl: 'https://httpbin.org',
        config: {
          'connectTimeout': 5000,
          'receiveTimeout': 5000,
        },
      );
      
      final request = TestNetworkRequest();
      
      try {
        await framework.execute(request);
        fail('应该抛出异常');
      } catch (e) {
        expect(e, isA<DioException>());
        final dioError = e as DioException;
        expect(dioError.error, isA<UnifiedException>());
      }
    });
  });
}

/// 测试用的全局异常处理器
class TestGlobalExceptionHandler implements GlobalExceptionHandler {
  final List<UnifiedException> handledExceptions = [];
  
  @override
  Future<void> onException(UnifiedException exception) async {
    handledExceptions.add(exception);
  }
}

/// 测试用的网络请求类
class TestNetworkRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/status/500'; // 模拟服务器错误
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
  
  @override
  NetworkException? handleError(DioException error) {
    // 测试自定义错误处理
    if (error.response?.statusCode == 500) {
      return NetworkException(
        message: '自定义服务器错误处理',
        statusCode: 500,
        errorCode: 'CUSTOM_SERVER_ERROR',
      );
    }
    return null;
  }
}

/// 异常处理性能测试
void performanceTest() {
  group('异常处理性能测试', () {
    test('大量异常处理性能测试', () async {
      final handler = UnifiedExceptionHandler.instance;
      final stopwatch = Stopwatch()..start();
      
      // 处理1000个异常
      for (int i = 0; i < 1000; i++) {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test$i'),
          type: DioExceptionType.connectionTimeout,
        );
        await handler.handleException(error);
      }
      
      stopwatch.stop();
      print('处理1000个异常耗时: ${stopwatch.elapsedMilliseconds}ms');
      
      // 验证性能要求（每个异常处理时间应小于10ms）
      expect(stopwatch.elapsedMilliseconds / 1000, lessThan(10));
    });
    
    test('异常统计内存使用测试', () async {
      final handler = UnifiedExceptionHandler.instance;
      handler.clearExceptionStats();
      
      // 生成大量不同类型的异常
      for (int i = 0; i < 10000; i++) {
        final errorTypes = [
          DioExceptionType.connectionTimeout,
          DioExceptionType.sendTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.cancel,
        ];
        
        final error = DioException(
          requestOptions: RequestOptions(path: '/test$i'),
          type: errorTypes[i % errorTypes.length],
        );
        
        await handler.handleException(error);
      }
      
      final stats = handler.getExceptionStats();
      
      // 验证统计数据正确性
      expect(stats.values.reduce((a, b) => a + b), equals(10000));
      
      // 清理统计数据
      handler.clearExceptionStats();
      expect(handler.getExceptionStats().isEmpty, isTrue);
    });
  });
}

/// 异常处理边界测试
void boundaryTest() {
  group('异常处理边界测试', () {
    test('空异常处理', () async {
      final handler = UnifiedExceptionHandler.instance;
      
      try {
        await handler.handleException(null);
        fail('应该抛出异常');
      } catch (e) {
        expect(e, isA<UnifiedException>());
        final unifiedException = e as UnifiedException;
        expect(unifiedException.type, equals(ExceptionType.unknown));
      }
    });
    
    test('循环异常处理', () async {
      final handler = UnifiedExceptionHandler.instance;
      final circularHandler = CircularExceptionHandler();
      
      handler.registerGlobalHandler(circularHandler);
      
      try {
        final error = Exception('测试循环异常');
        await handler.handleException(error);
        
        // 验证没有发生无限循环
        expect(circularHandler.callCount, lessThan(10));
      } finally {
        handler.removeGlobalHandler(circularHandler);
      }
    });
    
    test('异常处理器异常', () async {
      final handler = UnifiedExceptionHandler.instance;
      final faultyHandler = FaultyExceptionHandler();
      
      handler.registerGlobalHandler(faultyHandler);
      
      try {
        final error = Exception('测试异常');
        final result = await handler.handleException(error);
        
        // 即使全局处理器出错，主要异常处理仍应正常工作
        expect(result, isA<UnifiedException>());
      } finally {
        handler.removeGlobalHandler(faultyHandler);
      }
    });
  });
}

/// 循环异常处理器（用于测试）
class CircularExceptionHandler implements GlobalExceptionHandler {
  int callCount = 0;
  
  @override
  Future<void> onException(UnifiedException exception) async {
    callCount++;
    if (callCount < 5) {
      // 模拟可能导致循环的情况
      throw Exception('处理器内部异常');
    }
  }
}

/// 有问题的异常处理器（用于测试）
class FaultyExceptionHandler implements GlobalExceptionHandler {
  @override
  Future<void> onException(UnifiedException exception) async {
    throw Exception('全局处理器故障');
  }
}