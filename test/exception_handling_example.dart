import 'dart:convert';
import 'package:bzy_network_framework/src/frameworks/unified_framework.dart';
import 'package:bzy_network_framework/src/requests/base_network_request.dart';
import 'package:bzy_network_framework/src/model/network_response.dart';
/// 演示异常处理和请求结束通知的示例
class ExceptionHandlingExample {
  static Future<void> runExample() async {
    print('=== 异常处理和请求结束通知示例 ===\n');
    
    // 示例1: 正常请求
    print('1. 正常请求示例:');
    final normalRequest = ExampleRequest();
    final framework = UnifiedNetworkFramework.instance;
    await framework.execute(normalRequest);
    
    print('\n2. 解析异常示例:');
    // 示例2: 解析异常
    final parseErrorRequest = ParseErrorRequest();
    await framework.execute(parseErrorRequest);
    print('\n3. 网络异常示例:');
    // 示例3: 网络异常
    final networkErrorRequest = NetworkErrorRequest();
    await framework.execute(networkErrorRequest);
    
    print('\n=== 示例结束 ===');
  }
}

/// 正常请求示例
class ExampleRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/api/user/123';
  
  @override
  Map<String, dynamic> parseResponse(dynamic responseData) {
    print('   📝 parseResponse: 开始解析响应数据');
    
    // 模拟正常解析
    if (responseData is String) {
      try {
        final data = jsonDecode(responseData);
        print('   ✅ parseResponse: 解析成功');
        return data as Map<String, dynamic>;
      } catch (e) {
        print('   ❌ parseResponse: JSON解析失败 - $e');
        throw FormatException('JSON解析失败: $e');
      }
    }
    
    // 模拟成功响应
    final result = {
      'id': 123,
      'name': '用户示例',
      'timestamp': DateTime.now().toIso8601String(),
    };
    print('   ✅ parseResponse: 解析成功');
    return result;
  }
  
  @override
  Future<void> onRequestComplete(NetworkResponse<Map<String, dynamic>> response) async {
    print('   🎉 onRequestComplete: 请求完成');
    if (response.success) {
      print('   ✅ 请求成功: ${response.data}');
    } else {
      print('   ❌ 请求失败: ${response.message}');
    }
  }
  
  @override
  Future<void> onRequestError(dynamic error) async {
    print('   ❌ onRequestError: 捕获到异常');
    print('   📋 异常详情: $error');
    
    if (error is NetworkException) {
      print('   💬 错误消息: ${error.message}');
      print('   🌐 状态码: ${error.statusCode}');
    }
    
    // 这里可以执行自定义的错误处理逻辑
    // 比如: 更新UI状态、记录日志、通知用户等
    await _handleCustomErrorLogic(error);
  }
  
  Future<void> _handleCustomErrorLogic(dynamic error) async {
    print('   🔧 执行自定义错误处理逻辑');
    // 模拟一些异步操作，如保存错误日志
    await Future.delayed(Duration(milliseconds: 100));
    print('   📝 错误已记录到日志系统');
  }
}

/// 解析异常示例
class ParseErrorRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/api/invalid-data';
  
  @override
  Map<String, dynamic> parseResponse(dynamic responseData) {
    print('   📝 parseResponse: 开始解析响应数据');
    
    // 故意抛出解析异常
    throw FormatException('模拟解析失败: 无效的数据格式');
  }
  
  @override
  Future<void> onRequestComplete(NetworkResponse<Map<String, dynamic>> response) async {
    print('   🎉 onRequestComplete: 请求完成');
    if (response.success) {
      print('   ✅ 请求成功: ${response.data}');
    } else {
      print('   ❌ 请求失败: ${response.message}');
    }
  }
  
  @override
  Future<void> onRequestError(dynamic error) async {
    print('   ❌ onRequestError: 捕获到解析异常');
    print('   📋 异常详情: $error');
    
    // 解析异常的特殊处理
    if (error is NetworkException) {
      print('   🔍 这是一个数据解析异常');
      print('   💡 建议: 检查服务器返回的数据格式');
    }
    
    // 通知外部系统请求已结束（失败）
    await _notifyRequestFinished(false, error);
  }
  
  Future<void> _notifyRequestFinished(bool success, dynamic error) async {
    print('   📢 通知外部系统: 请求已结束');
    print('   📊 结果: ${success ? "成功" : "失败"}');
    if (!success) {
      print('   🚨 错误信息: $error');
    }
  }
}

/// 网络异常示例
class NetworkErrorRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/api/timeout';
  
  @override
  Map<String, dynamic> parseResponse(dynamic responseData) {
    print('   📝 parseResponse: 开始解析响应数据');
    // 这个方法在网络异常时不会被调用
    return {'data': 'success'};
  }
  
  @override
  Future<void> onRequestComplete(NetworkResponse<Map<String, dynamic>> response) async {
    print('   🎉 onRequestComplete: 请求完成');
    if (response.success) {
      print('   ✅ 请求成功: ${response.data}');
    } else {
      print('   ❌ 请求失败: ${response.message}');
    }
  }
  
  @override
  Future<void> onRequestError(dynamic error) async {
    print('   ❌ onRequestError: 捕获到网络异常');
    print('   📋 异常详情: $error');
    
    // 网络异常的特殊处理
    if (error is NetworkException) {
      if (error.message.contains('timeout')) {
        print('   ⏰ 请求超时');
        await _handleTimeoutError();
      } else if (error.statusCode != null && error.statusCode! >= 500) {
        print('   🖥️  服务器错误');
        await _handleServerError();
      } else {
        print('   🌐 网络连接异常');
        await _handleNetworkError();
      }
    }
    
    // 通知外部系统请求已结束（失败）
    await _notifyExternalSystem(error);
  }
  
  Future<void> _handleNetworkError() async {
    print('   🔧 处理网络连接异常');
    print('   💡 建议: 检查网络连接状态');
  }
  
  Future<void> _handleTimeoutError() async {
    print('   🔧 处理请求超时');
    print('   💡 建议: 可以尝试重新请求');
  }
  
  Future<void> _handleServerError() async {
    print('   🔧 处理服务器错误');
    print('   💡 建议: 稍后重试或联系技术支持');
  }
  
  Future<void> _notifyExternalSystem(dynamic error) async {
    print('   📡 通知外部系统请求失败');
    // 这里可以:
    // 1. 更新UI状态
    // 2. 发送错误统计
    // 3. 触发重试机制
    // 4. 显示用户友好的错误提示
    await Future.delayed(Duration(milliseconds: 50));
    print('   ✅ 外部系统已收到通知');
  }
}

/// 使用示例的主函数
void main() async {
  await ExceptionHandlingExample.runExample();
}