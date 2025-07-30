import 'package:test/test.dart';
import 'package:bzy_network_framework/bzy_network_framework.dart';
import 'dart:io';

/// 测试配置和工具类
class TestConfig {
  static const String testBaseUrl = 'https://httpbin.org';
  static const String mockBaseUrl = 'https://mock.api.test';
  
  /// 测试用的网络配置
  static Map<String, dynamic> get testNetworkConfig => {
    'connectTimeout': 5000,
    'receiveTimeout': 5000,
    'sendTimeout': 5000,
    'enableLogging': true,
    'logLevel': LogLevel.debug,
    'enableCache': false, // 测试时禁用缓存
    'maxRetries': 1,
    'retryDelay': 100,
  };
  
  /// 初始化测试环境
  static Future<void> setupTestEnvironment() async {
    // 清理之前的状态
    await cleanupTestEnvironment();
    
    // 初始化网络框架
    final framework = UnifiedNetworkFramework.instance;
    await framework.initialize(
      baseUrl: testBaseUrl,
      config: testNetworkConfig,
    );
  }
  
  /// 清理测试环境
  static Future<void> cleanupTestEnvironment() async {
    try {
      final framework = UnifiedNetworkFramework.instance;
      await framework.dispose();
    } catch (e) {
      // 忽略清理错误
    }
    
    // 清理异常处理器状态
    UnifiedExceptionHandler.instance.clearExceptionStats();
  }
}

/// 测试用的网络请求类
class TestApiRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String endpoint;
  final HttpMethod requestMethod;
  final Map<String, dynamic>? requestData;
  final int? expectedStatusCode;
  
  TestApiRequest({
    required this.endpoint,
    this.requestMethod = HttpMethod.get,
    this.requestData,
    this.expectedStatusCode,
  });
  
  @override
  String get path => endpoint;
  
  @override
  HttpMethod get method => requestMethod;
  

  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    return {'data': data};
  }
  
  @override
  NetworkException? handleError(DioException error) {
    if (expectedStatusCode != null && 
        error.response?.statusCode == expectedStatusCode) {
      // 期望的错误状态码，返回自定义异常
      return NetworkException(
        message: '测试期望的错误: ${error.response?.statusCode}',
        statusCode: error.response?.statusCode ?? -1,
        errorCode: 'TEST_EXPECTED_ERROR',
      );
    }
    return null;
  }
}

/// 测试用的异常生成器
class TestExceptionGenerator {
  /// 生成网络超时异常
  static DioException createTimeoutException() {
    return DioException(
      requestOptions: RequestOptions(path: '/timeout'),
      type: DioExceptionType.connectionTimeout,
      message: '连接超时',
    );
  }
  
  /// 生成HTTP错误响应
  static DioException createHttpErrorException(int statusCode) {
    return DioException(
      requestOptions: RequestOptions(path: '/error'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/error'),
        statusCode: statusCode,
        data: {'error': 'HTTP $statusCode Error'},
      ),
    );
  }
  
  /// 生成网络不可达异常
  static SocketException createNetworkException() {
    return const SocketException('网络不可达');
  }
  
  /// 生成数据解析异常
  static FormatException createParseException() {
    return const FormatException('JSON解析失败');
  }
  
  /// 生成自定义异常
  static UnifiedException createCustomException({
    ExceptionType type = ExceptionType.unknown,
    ErrorCode code = ErrorCode.unknownError,
    String message = '自定义测试异常',
    int statusCode = -1,
    Map<String, dynamic>? metadata,
  }) {
    return UnifiedException(
      type: type,
      code: code,
      message: message,
      statusCode: statusCode,
      metadata: metadata,
    );
  }
}

/// 测试断言工具
class TestAssertions {
  /// 断言异常类型和属性
  static void assertException(
    UnifiedException exception, {
    required ExceptionType expectedType,
    required ErrorCode expectedCode,
    String? expectedMessage,
    int? expectedStatusCode,
  }) {
    expect(exception.type, equals(expectedType));
    expect(exception.code, equals(expectedCode));
    
    if (expectedMessage != null) {
      expect(exception.message, equals(expectedMessage));
    }
    
    if (expectedStatusCode != null) {
      expect(exception.statusCode, equals(expectedStatusCode));
    }
  }
  
  /// 断言异常统计
  static void assertExceptionStats(
    Map<String, int> stats,
    String expectedKey,
    int expectedCount,
  ) {
    expect(stats.containsKey(expectedKey), isTrue);
    expect(stats[expectedKey], equals(expectedCount));
  }
}

/// 测试数据生成器
class TestDataGenerator {
  /// 生成测试用户数据
  static Map<String, dynamic> generateUserData({
    String? id,
    String? name,
    String? email,
  }) {
    return {
      'id': id ?? 'test_user_${DateTime.now().millisecondsSinceEpoch}',
      'name': name ?? 'Test User',
      'email': email ?? 'test@example.com',
      'created_at': DateTime.now().toIso8601String(),
    };
  }
  
  /// 生成测试API响应数据
  static Map<String, dynamic> generateApiResponse({
    bool success = true,
    dynamic data,
    String? message,
  }) {
    return {
      'success': success,
      'data': data,
      'message': message ?? (success ? 'Success' : 'Error'),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

/// 测试性能监控
class TestPerformanceMonitor {
  final Stopwatch _stopwatch = Stopwatch();
  final List<Duration> _measurements = [];
  
  /// 开始测量
  void start() {
    _stopwatch.reset();
    _stopwatch.start();
  }
  
  /// 停止测量并记录
  Duration stop() {
    _stopwatch.stop();
    final duration = _stopwatch.elapsed;
    _measurements.add(duration);
    return duration;
  }
  
  /// 获取平均耗时
  Duration get averageDuration {
    if (_measurements.isEmpty) return Duration.zero;
    
    final totalMs = _measurements
        .map((d) => d.inMilliseconds)
        .reduce((a, b) => a + b);
    
    return Duration(milliseconds: totalMs ~/ _measurements.length);
  }
  
  /// 获取最大耗时
  Duration get maxDuration {
    if (_measurements.isEmpty) return Duration.zero;
    
    return _measurements.reduce((a, b) => 
        a.inMilliseconds > b.inMilliseconds ? a : b);
  }
  
  /// 清理测量数据
  void clear() {
    _measurements.clear();
    _stopwatch.reset();
  }
}