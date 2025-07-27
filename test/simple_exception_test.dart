import 'package:test/test.dart';
import 'package:dio/dio.dart';
import 'package:bzy_network_framework/bzy_network_framework.dart';
import 'test_config.dart';

/// 简单的异常处理测试示例
/// 展示如何测试统一异常处理机制的基本功能
void main() {
  group('简单异常处理测试', () {
    late UnifiedExceptionHandler handler;
    
    setUp(() {
      handler = UnifiedExceptionHandler.instance;
      handler.clearExceptionStats();
    });
    
    test('测试基本异常转换', () async {
      // 创建一个 DioException
      final dioError = TestExceptionGenerator.createTimeoutException();
      
      // 处理异常
      final result = await handler.handleException(dioError);
      
      // 验证结果
      TestAssertions.assertException(
        result,
        expectedType: ExceptionType.network,
        expectedCode: ErrorCode.connectionTimeout,
        expectedMessage: '连接超时，请检查网络连接',
        expectedStatusCode: -1001,
      );
    });
    
    test('测试HTTP错误处理', () async {
      // 创建401错误
      final httpError = TestExceptionGenerator.createHttpErrorException(401);
      
      // 处理异常
      final result = await handler.handleException(httpError);
      
      // 验证结果
      TestAssertions.assertException(
        result,
        expectedType: ExceptionType.auth,
        expectedCode: ErrorCode.unauthorized,
        expectedMessage: '认证失败，请重新登录',
        expectedStatusCode: 401,
      );
    });
    
    test('测试自定义异常', () async {
      // 创建自定义异常
      final customException = TestExceptionGenerator.createCustomException(
        type: ExceptionType.client,
        code: ErrorCode.validationError,
        message: '数据验证失败',
        statusCode: 400,
        metadata: {'field': 'username'},
      );
      
      // 处理异常
      final result = await handler.handleException(customException);
      
      // 验证结果
      expect(result.type, equals(ExceptionType.client));
      expect(result.code, equals(ErrorCode.validationError));
      expect(result.message, equals('数据验证失败'));
      expect(result.statusCode, equals(400));
      expect(result.metadata?['field'], equals('username'));
    });
    
    test('测试异常统计', () async {
      // 处理多个相同类型的异常
      for (int i = 0; i < 3; i++) {
        final error = TestExceptionGenerator.createTimeoutException();
        await handler.handleException(error);
      }
      
      // 处理不同类型的异常
      for (int i = 0; i < 2; i++) {
        final error = TestExceptionGenerator.createHttpErrorException(500);
        await handler.handleException(error);
      }
      
      // 验证统计
      final stats = handler.getExceptionStats();
      TestAssertions.assertExceptionStats(
        stats,
        'network_connectionTimeout',
        3,
      );
      TestAssertions.assertExceptionStats(
        stats,
        'server_internalServerError',
        2,
      );
    });
    
    test('测试异常属性判断', () {
      // 网络异常
      final networkException = TestExceptionGenerator.createCustomException(
        type: ExceptionType.network,
        code: ErrorCode.connectionTimeout,
      );
      
      expect(networkException.isNetworkError, isTrue);
      expect(networkException.isAuthError, isFalse);
      expect(networkException.isRetryable, isTrue);
      
      // 认证异常
      final authException = TestExceptionGenerator.createCustomException(
        type: ExceptionType.auth,
        code: ErrorCode.unauthorized,
      );
      
      expect(authException.isAuthError, isTrue);
      expect(authException.isNetworkError, isFalse);
      expect(authException.isRetryable, isFalse);
    });
    
    test('测试异常上下文和元数据', () async {
      final error = Exception('测试异常');
      
      // 带上下文和元数据处理异常
      final result = await handler.handleException(
        error,
        context: '用户登录流程',
        metadata: {
          'userId': 'test123',
          'action': 'login',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      // 验证上下文和元数据
      expect(result.context, equals('用户登录流程'));
      expect(result.metadata?['userId'], equals('test123'));
      expect(result.metadata?['action'], equals('login'));
      expect(result.metadata?['timestamp'], isNotNull);
    });
  });
  
  group('全局异常处理器测试', () {
    late TestGlobalExceptionHandler globalHandler;
    
    setUp(() {
      globalHandler = TestGlobalExceptionHandler();
      UnifiedExceptionHandler.instance.registerGlobalHandler(globalHandler);
    });
    
    tearDown(() {
      UnifiedExceptionHandler.instance.removeGlobalHandler(globalHandler);
    });
    
    test('测试全局处理器调用', () async {
      final error = TestExceptionGenerator.createTimeoutException();
      
      // 处理异常
      await UnifiedExceptionHandler.instance.handleException(error);
      
      // 验证全局处理器被调用
      expect(globalHandler.handledExceptions.length, equals(1));
      expect(globalHandler.handledExceptions.first.type, 
             equals(ExceptionType.network));
    });
    
    test('测试多个全局处理器', () async {
      final secondHandler = TestGlobalExceptionHandler();
      UnifiedExceptionHandler.instance.registerGlobalHandler(secondHandler);
      
      try {
        final error = TestExceptionGenerator.createHttpErrorException(404);
        
        // 处理异常
        await UnifiedExceptionHandler.instance.handleException(error);
        
        // 验证两个处理器都被调用
        expect(globalHandler.handledExceptions.length, equals(1));
        expect(secondHandler.handledExceptions.length, equals(1));
        
        // 验证异常类型
        expect(globalHandler.handledExceptions.first.type, 
               equals(ExceptionType.client));
        expect(secondHandler.handledExceptions.first.code, 
               equals(ErrorCode.notFound));
      } finally {
        UnifiedExceptionHandler.instance.removeGlobalHandler(secondHandler);
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
    
    // 模拟处理逻辑
    print('全局处理器处理异常: ${exception.type.name} - ${exception.message}');
  }
  
  /// 清理处理记录
  void clear() {
    handledExceptions.clear();
  }
}