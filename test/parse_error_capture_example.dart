import 'package:bzy_network_framework/src/frameworks/unified_framework.dart';
import 'package:bzy_network_framework/src/requests/base_network_request.dart';
import 'package:bzy_network_framework/src/model/network_response.dart';
import 'package:bzy_network_framework/src/core/exception/unified_exception_handler.dart';

/// 解析异常捕获示例
class ParseErrorCaptureExample {
  static final _framework = UnifiedNetworkFramework.instance;

  /// 初始化框架
  static Future<void> initialize() async {
    await _framework.initialize(
      baseUrl: 'https://api.example.com',
      config: {
        'connectTimeout': 15000,
        'receiveTimeout': 15000,
        'enableLogging': true,
      },
    );
  }

  /// 运行示例
  static Future<void> runExample() async {
    await initialize();
    print('=== 解析异常捕获示例 ===\n');
    
    await example1_CatchErrorMethod();
    // await example2_TryCatchMethod();
    // await example3_ResponseStatusCheck();
    // await example4_CustomErrorHandling();
    
    print('\n=== 示例结束 ===');
  }

  /// 示例1: 使用 .catchError() 捕获解析异常
  static Future<void> example1_CatchErrorMethod() async {
    print('\n--- 示例1: 使用 .catchError() 捕获解析异常 ---');
    
    final request = ParseErrorRequest();
    
    await _framework.execute(request)
        .then((response) {
          // 这里不会执行，因为解析异常会被转换为失败响应
          if (response.success) {
            print('✅ 请求成功: ${response.data}');
          } else {
            print('❌ 请求失败: ${response.message}');
            print('📋 状态码: ${response.statusCode}');
            print('📋 错误码: ${response.errorCode}');
            print('📋 错误消息: ${response.message}');
          }
        })
        .catchError((error) {
          // 注意: 在这个框架中，解析异常通常不会到达这里
          // 因为框架会将异常转换为失败的响应
          print('❌ catchError 捕获到异常: $error');
          
          if (error is NetworkException) {
            print('🔍 NetworkException 详情:');
            print('   错误码: ${error.errorCode}');
            print('   消息: ${error.message}');
            print('   状态码: ${error.statusCode}');
            print('   原始异常: ${error.originalError}');
          }
        });
  }

  /// 示例2: 使用 try-catch 捕获解析异常
  static Future<void> example2_TryCatchMethod() async {
    print('\n--- 示例2: 使用 try-catch 捕获解析异常 ---');
    
    final request = ParseErrorRequest();
    
    try {
      final response = await _framework.execute(request);
      
      if (response.success) {
        print('✅ 请求成功: ${response.data}');
      } else {
        print('❌ 请求失败: ${response.message}');
        
        // 从响应中获取错误信息
        print('📋 状态码: ${response.statusCode}');
        print('📋 错误码: ${response.errorCode}');
        print('📋 错误消息: ${response.message}');
      }
    } catch (e) {
      // 在这个框架中，通常不会到达这里
      print('❌ try-catch 捕获到异常: $e');
    }
  }

  /// 示例3: 通过响应状态检查获取错误
  static Future<void> example3_ResponseStatusCheck() async {
    print('\n--- 示例3: 通过响应状态检查获取错误 ---');
    
    final request = ParseErrorRequest();
    final response = await _framework.execute(request);
    
    print('🔍 响应状态检查:');
    print('   成功状态: ${response.success}');
    print('   响应消息: ${response.message}');
    print('   状态码: ${response.statusCode}');
    
    if (!response.success) {
      print('❌ 请求失败，获取错误信息:');
      
      // 方式1: 从 response 状态获取错误信息
      print('📋 状态码: ${response.statusCode}');
      print('📋 错误码: ${response.errorCode}');
      print('📋 错误消息: ${response.message}');
      
      // 方式2: 从 response.message 获取错误描述
      print('💬 错误描述: ${response.message}');
    }
  }

  /// 示例4: 自定义错误处理
  static Future<void> example4_CustomErrorHandling() async {
    print('\n--- 示例4: 自定义错误处理 ---');
    
    final request = CustomParseErrorRequest();
    await _framework.execute(request);
  }

  /// 打印 NetworkException 详细信息
  static void _printNetworkExceptionDetails(NetworkException error) {
    print('🔍 NetworkException 详细信息:');
    print('   错误码: ${error.errorCode}');
    print('   错误消息: ${error.message}');
    print('   HTTP状态码: ${error.statusCode}');
    print('   原始异常: ${error.originalError}');
    print('   原始异常类型: ${error.originalError?.runtimeType}');
  }
}

/// 解析异常请求类
class ParseErrorRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/api/parse-error';

  @override
  Map<String, dynamic> parseResponse(dynamic responseData) {
    print('📝 parseResponse: 开始解析响应数据');
    print('📝 响应数据: $responseData');
    
    // 故意抛出解析异常
    throw FormatException('模拟JSON解析失败: 数据格式不正确');
  }
}

/// 自定义解析异常处理请求类
class CustomParseErrorRequest extends BaseNetworkRequest<String> {
  @override
  String get path => '/api/custom-parse-error';

  @override
  String parseResponse(dynamic responseData) {
    print('📝 parseResponse: 开始自定义解析');
    
    try {
      // 模拟解析过程
      if (responseData == null) {
        throw FormatException('响应数据为空');
      }
      
      // 故意抛出不同类型的解析异常
      throw FormatException('自定义解析异常: 无法解析数据格式');
      
    } catch (e) {
      print('❌ parseResponse 内部捕获异常: $e');
      // 重新抛出，让框架处理
      rethrow;
    }
  }

  @override
  Future<void> onRequestError(dynamic error) async {
    print('❌ CustomParseErrorRequest.onRequestError: 捕获异常');
    
    if (error is NetworkException) {
      print('🔍 NetworkException 信息:');
      print('   错误码: ${error.errorCode}');
      print('   消息: ${error.message}');
      print('   状态码: ${error.statusCode}');
      
      // 根据错误码进行不同处理
      if (error.errorCode == 'dataParseError') {
        print('📊 数据异常处理: 建议检查数据格式');
      } else if (error.errorCode == 'networkError') {
        print('🌐 网络异常处理: 建议检查网络连接');
      } else if (error.errorCode == 'serverError') {
        print('🖥️ 服务器异常处理: 建议稍后重试');
      } else {
        print('❓ 其他异常处理');
      }
      
      // 获取原始异常信息
      if (error.originalError != null) {
           print('📝 原始异常: ${error.originalError}');
           print('📝 原始异常类型: ${error.originalError.runtimeType}');
      }
    }
  }
}

/// 主函数
void main() async {
  await ParseErrorCaptureExample.runExample();
}