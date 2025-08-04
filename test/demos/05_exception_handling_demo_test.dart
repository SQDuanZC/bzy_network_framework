import 'package:test/test.dart';
import 'dart:async';
import '../../lib/bzy_network_framework.dart';

int retryableRequestCounter = 0;

/// 异常处理示例
/// 演示网络超时、HTTP状态码、JSON解析、自定义异常、可重试异常和异常恢复的处理方式
/// 这个示例展示了BZY网络框架1.0.3版本中增强的异常处理能力

void main() {
  group('异常处理功能测试', () {
    setUpAll(() async {
      // 初始化框架，禁用缓存以便测试
      await UnifiedNetworkFramework.instance.initialize(
        baseUrl: 'https://httpbin.org',
        config: {'enableCache': false},
      );
      
      // 注册全局异常处理器
      UnifiedExceptionHandler.instance.registerGlobalHandler(
        CustomGlobalExceptionHandler(),
      );
    });

    setUp(() {
      retryableRequestCounter = 0;
    });
    
    test('网络超时异常测试', () async {
      await _demonstrateTimeoutException();
    });
    
    test('HTTP状态码异常测试', () async {
      await _demonstrateHttpException();
    });
    
    test('JSON解析异常测试', () async {
      await _demonstrateJsonParseException();
    });
    
    test('自定义业务异常测试', () async {
      await _demonstrateCustomException();
    });
    
    test('可重试异常测试', () async {
      await _demonstrateRetryableException();
    });
    
    test('异常恢复测试', () async {
      await _demonstrateRecoverableException();
    }, timeout: const Timeout(Duration(seconds: 30)));

    tearDown(() async {
      // 确保每个测试后取消所有请求
      await NetworkExecutor.instance.cancelAllRequests();
      await Future.delayed(Duration(milliseconds: 200));
    });

    tearDownAll(() async {
      // 确保所有测试完成后释放资源
      await NetworkExecutor.instance.dispose();
      await Future.delayed(Duration(milliseconds: 200));
    });
  });
}

/// 演示网络超时异常
Future<void> _demonstrateTimeoutException() async {
  print('--- 网络超时异常 ---');
  
  final request = TimeoutRequest();
  
  try {
    final response = await NetworkExecutor.instance.execute(request);
    print('超时请求成功: ${response.data}');
  } catch (e) {
    print('捕获到超时异常: $e');
    if (e is NetworkException) {
      print('错误代码: ${e.errorCode}');
      print('错误消息: ${e.message}');
      
      // 1.0.3版本新增：检查重试次数
      print('重试次数: ${e.retryCount}');
    }
  }
  
  print('');
}

/// 演示HTTP状态码异常
Future<void> _demonstrateHttpException() async {
  print('--- HTTP状态码异常 ---');
  
  final request = HttpErrorRequest();
  
  try {
    final response = await NetworkExecutor.instance.execute(request);
    print('HTTP请求成功: ${response.data}');
  } catch (e) {
    print('捕获到HTTP异常: $e');
    if (e is NetworkException) {
      print('错误代码: ${e.errorCode}');
      print('HTTP状态码: ${e.statusCode}');
      
      // 1.0.3版本新增：检查是否是服务器错误
      if (e.statusCode != null && e.statusCode! >= 500) {
        print('服务器错误，可以考虑重试');
      } else if (e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
        print('客户端错误，需要修改请求参数');
      }
    }
  }
  
  print('');
}

/// 演示JSON解析异常
Future<void> _demonstrateJsonParseException() async {
  print('--- JSON解析异常 ---');
  
  final request = JsonParseErrorRequest();
  
  try {
    final response = await NetworkExecutor.instance.execute(request);
    print('JSON解析成功: ${response.data}');
  } catch (e) {
    print('捕获到JSON解析异常: $e');
    if (e is NetworkException) {
      print('错误代码: ${e.errorCode}');
      print('原始数据: ${e.originalData}');
      
      // 1.0.3版本新增：尝试恢复解析
      try {
        if (e.originalData is String) {
          print('尝试作为纯文本处理: ${(e.originalData as String).substring(0, 50)}...');
        }
      } catch (_) {
        print('恢复解析失败');
      }
    }
  }
  
  print('');
}

/// 演示自定义业务异常
Future<void> _demonstrateCustomException() async {
  print('--- 自定义业务异常 ---');
  
  final request = CustomExceptionRequest();
  
  try {
    final response = await NetworkExecutor.instance.execute(request);
    print('自定义请求成功: ${response.data}');
  } catch (e) {
    print('捕获到自定义业务异常: $e');
    if (e is CustomBusinessException) {
      print('业务错误代码: ${e.businessCode}');
      print('业务错误消息: ${e.businessMessage}');
      
      // 1.0.3版本新增：业务异常分类处理
      switch (e.businessCode) {
        case 'BUSINESS_ERROR_001':
          print('处理策略: 业务规则验证失败，需要用户修正输入');
          break;
        case 'BUSINESS_ERROR_002':
          print('处理策略: 权限不足，需要提示用户升级权限');
          break;
        default:
          print('处理策略: 通用业务错误处理');
      }
    }
  }
  
  print('');
}

/// 演示可重试异常处理
Future<void> _demonstrateRetryableException() async {
  print('--- 可重试异常处理 ---');
  
  final request = RetryableErrorRequest();
  
  try {
    final response = await NetworkExecutor.instance.execute(request);
    print('重试请求成功: ${response.data}');
  } catch (e) {
    print('重试后仍然失败: $e');
    if (e is NetworkException) {
      print('重试次数: ${e.retryCount}');
    }
  }
  
  print('');
}

/// 演示异常恢复
Future<void> _demonstrateRecoverableException() async {
  print('--- 异常恢复 ---');
  
  final request = RecoverableErrorRequest();
  
  try {
    final response = await NetworkExecutor.instance.execute(request);
    print('恢复请求成功: ${response.data}');
  } catch (e) {
    print('异常恢复失败: $e');
  }
  
  print('');
}

/// 超时请求
class TimeoutRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/delay/5'; // httpbin.org延迟端点
  
  @override
  int? get timeout => 2000; // 2秒超时
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
  
  // 1.0.3版本新增：自定义超时处理
  @override
  void onRequestError(NetworkException error) {
    if (error.errorCode == 'TIMEOUT') {
      print('自定义超时处理: 可以在这里执行特定于此请求的超时逻辑');
    }
  }
}

/// HTTP错误请求
class HttpErrorRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/status/404'; // httpbin.org状态码端点
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
  
  // 1.0.3版本新增：指定哪些状态码需要重试
  @override
  bool shouldRetryForStatusCode(int statusCode) {
    // 只对服务器错误(5xx)进行重试
    return statusCode >= 500 && statusCode < 600;
  }
}

/// JSON解析错误请求
class JsonParseErrorRequest extends BaseNetworkRequest<String> {
  @override
  String get path => '/html'; // httpbin.org返回HTML的端点

  @override
  String parseResponse(dynamic data) {
    // 这里会失败，因为我们期望JSON但得到的是HTML
    return data['headers']['Host'];
  }
  
  // 1.0.3版本新增：解析错误恢复
  @override
  String? handleParseError(dynamic data, Exception error) {
    print('尝试从解析错误中恢复');
    if (data is String && data.contains('<html>')) {
      return '成功从HTML中恢复: 这是一个HTML页面';
    }
    return null; // 返回null表示无法恢复，将抛出原始异常
  }
}

/// 自定义异常请求
class CustomExceptionRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/get';
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    // 模拟业务逻辑异常
    final response = data as Map<String, dynamic>;
    
    // 1.0.3版本新增：更复杂的业务规则验证
    if (response['url'] != null && response['url'].toString().contains('httpbin.org')) {
      throw CustomBusinessException(
        businessCode: 'BUSINESS_ERROR_001',
        businessMessage: '业务规则验证失败',
        originalData: response,
      );
    }
    return response;
  }
  
  // 1.0.3版本新增：业务异常转换
  @override
  NetworkException? handleError(DioException error) {
    if (error.response?.statusCode == 200) {
      // 即使是200状态码，也可能需要根据业务逻辑抛出异常
      return NetworkException(
        errorCode: 'BUSINESS_ERROR_002',
        message: '业务逻辑错误',
        statusCode: 200,
        originalData: error.response?.data,
      );
    }
    return null; // 返回null表示使用默认异常处理
  }
}

/// 可重试错误请求
class RetryableErrorRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/get';

  @override
  int get maxRetries => 3;

  @override
  int get retryDelay => 1000;
  
  // 1.0.3版本新增：指数退避重试延迟
  @override
  int calculateRetryDelay(int retryCount) {
    // 使用指数退避算法：2^retryCount * 基础延迟
    return (1 << retryCount) * retryDelay;
  }

  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    retryableRequestCounter++;
    print('RetryableErrorRequest尝试次数: $retryableRequestCounter');
    if (retryableRequestCounter <= 2) {
      throw NetworkException(
        errorCode: 'RETRYABLE_ERROR',
        message: '模拟间歇性解析错误',
      );
    }
    print('RetryableErrorRequest在第$retryableRequestCounter次尝试成功');
    return data as Map<String, dynamic>;
  }
  
  // 1.0.3版本新增：自定义重试条件
  @override
  bool shouldRetry(Exception exception) {
    if (exception is NetworkException) {
      // 只对特定错误代码进行重试
      return exception.errorCode == 'RETRYABLE_ERROR' || 
             exception.errorCode == 'CONNECTION_ERROR' ||
             exception.errorCode == 'TIMEOUT';
    }
    return false;
  }
}

/// 可恢复错误请求
class RecoverableErrorRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/get';

  @override
  int? get sendTimeout => 5000;

  @override
  int? get receiveTimeout => 5000;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
      return Map<String, dynamic>.from(data);
    } else {
      return {'message': data?.toString() ?? '未知响应'};
    }
  }
  
  // 1.0.3版本新增：增强的错误恢复逻辑
  @override
  void onRequestError(NetworkException error) {
    print('尝试错误恢复: $error');
    
    // 根据错误类型执行不同的恢复策略
    switch (error.errorCode) {
      case 'TIMEOUT':
        print('超时恢复策略: 可以尝试使用备用API或本地缓存数据');
        break;
      case 'CONNECTION_ERROR':
        print('连接错误恢复策略: 检查网络连接，可以提供离线模式');
        break;
      case 'HTTP_ERROR':
        print('HTTP错误恢复策略: 根据状态码执行特定操作');
        if (error.statusCode == 404) {
          print('资源不存在，可以创建默认资源');
        } else if (error.statusCode == 403) {
          print('权限不足，可以请求用户重新授权');
        }
        break;
      default:
        print('通用恢复策略: 记录错误并通知用户');
    }
  }
  
  // 1.0.3版本新增：提供备用数据源
  @override
  Future<NetworkResponse<Map<String, dynamic>>?> provideFallbackResponse(NetworkException error) async {
    print('提供备用响应数据');
    // 模拟从本地缓存或默认配置获取备用数据
    await Future.delayed(Duration(milliseconds: 500)); // 模拟异步操作
    return NetworkResponse.success(
      data: {'fallback': true, 'message': '这是备用数据', 'originalError': error.message},
      statusCode: 200,
      message: '使用备用数据源成功',
    );
  }
}

/// 自定义业务异常
class CustomBusinessException implements Exception {
  final String businessCode;
  final String businessMessage;
  final dynamic originalData;
  
  CustomBusinessException({
    required this.businessCode,
    required this.businessMessage,
    this.originalData,
  });
  
  @override
  String toString() {
    return '自定义业务异常: $businessCode - $businessMessage';
  }
}

/// 自定义全局异常处理器
class CustomGlobalExceptionHandler implements GlobalExceptionHandler {
  @override
  bool canHandle(UnifiedException exception) {
    return exception.type == ExceptionType.network;
  }

  @override
  UnifiedException handle(UnifiedException exception) {
    print('全局异常处理器处理异常: ${exception.message}');
    return exception;
  }

  @override
  Future<void> onException(UnifiedException exception) async {
    print('全局异常回调: ${exception.message}');
  }

  @override
  Future<void> handleException(Exception exception) async {
    print('=== 全局异常处理器 ===');
    print('异常类型: ${exception.runtimeType}');
    print('异常信息: $exception');
    
    if (exception is NetworkException) {
      print('网络异常详情:');
      print('  错误代码: ${exception.errorCode}');
      print('  错误消息: ${exception.message}');
      print('  状态码: ${exception.statusCode}');
      print('  重试次数: ${exception.retryCount}');
      
      // 处理不同类型的错误
      switch (exception.errorCode) {
        case 'TIMEOUT':
          print('  处理策略: 网络超时，建议检查网络连接');
          break;
        case 'HTTP_ERROR':
          print('  处理策略: HTTP错误，检查请求参数和服务器状态');
          break;
        case 'PARSE_ERROR':
          print('  处理策略: 解析错误，检查数据格式');
          break;
        default:
          print('  处理策略: 通用错误处理');
      }
    } else if (exception is CustomBusinessException) {
      print('业务异常详情:');
      print('  业务错误代码: ${exception.businessCode}');
      print('  业务错误消息: ${exception.businessMessage}');
      print('  原始数据: ${exception.originalData}');
      print('  处理策略: 业务逻辑错误，需要用户处理');
    } else {
      print('未知异常，使用默认处理策略');
    }
    
    // 异常日志记录、错误报告等可以在这里添加
    await _logException(exception);
    await _reportException(exception);
  }
  
  Future<void> _logException(Exception exception) async {
    // 模拟日志记录
    print('异常已记录到本地日志');
  }
  
  Future<void> _reportException(Exception exception) async {
    // 模拟错误报告
    print('异常已报告给错误监控系统');
  }
}