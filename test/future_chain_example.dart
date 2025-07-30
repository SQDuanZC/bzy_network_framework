import 'package:bzy_network_framework/src/frameworks/unified_framework.dart';
import 'package:bzy_network_framework/src/model/network_response.dart';
import 'example_requests.dart';

/// Future链式调用错误处理示例
class FutureChainExample {
  late UnifiedNetworkFramework _framework;
  
  FutureChainExample() {
    _framework = UnifiedNetworkFramework.instance;
  }
  
  /// 示例1: 使用 .then() 和 .catchError() 处理错误
  Future<void> example1_ThenCatchError() async {
    print('\n=== 示例1: .then() 和 .catchError() ===');
    
    final request = GetUserProfileRequest(userId: '123');
    
    await _framework.execute(request)
        .then((response) {
          if (response.success) {
            print('✅ 请求成功: ${response.data?.name}');
            // 处理成功响应
            _handleSuccessResponse(response);
          } else {
            print('❌ 请求失败: ${response.message}');
            // 处理失败响应
            _handleErrorResponse(response);
          }
        })
        .catchError((error) {
          print('❌ 捕获异常: $error');
          // 处理异常
          _handleException(error);
        });
  }
  
  /// 示例2: 使用 .whenComplete() 进行清理
  Future<void> example2_WhenComplete() async {
    print('\n=== 示例2: .whenComplete() 清理 ===');
    
    print('🔄 开始加载...');
    
    final request = GetUserProfileRequest(userId: '456');
    
    await _framework.execute(request)
        .then((response) {
          if (response.success) {
            print('✅ 数据加载成功');
          } else {
            print('❌ 数据加载失败: ${response.message}');
          }
        })
        .catchError((error) {
          print('❌ 网络异常: $error');
        })
        .whenComplete(() {
          print('🏁 请求完成（无论成功失败）');
        });
  }
  
  /// 示例3: 链式处理多个操作
  Future<void> example3_ChainedOperations() async {
    print('\n=== 示例3: 链式处理多个操作 ===');
    
    final getUserRequest = GetUserProfileRequest(userId: '789');
    
    await _framework.execute(getUserRequest)
        .then((userResponse) async {
          if (userResponse.success) {
            print('✅ 获取用户信息成功');
            // 基于用户信息创建下一个请求
            final updateRequest = UpdateUserProfileRequest(
              userId: '789',
              userData: {'lastLogin': DateTime.now().toIso8601String()},
            );
            return await _framework.execute(updateRequest);
          } else {
            throw Exception('获取用户信息失败: ${userResponse.message}');
          }
        })
        .then((updateResponse) {
          if (updateResponse.success) {
            print('✅ 更新用户信息成功');
          } else {
            print('❌ 更新用户信息失败');
          }
        })
        .catchError((error) {
          print('❌ 操作链中发生错误: $error');
        });
  }
  
  /// 示例4: 使用 Future.wait 处理多个请求
  Future<void> example4_FutureWait() async {
    print('\n=== 示例4: Future.wait 并发处理 ===');
    
    final requests = [
      _framework.execute(GetUserProfileRequest(userId: '1')),
      _framework.execute(GetUserProfileRequest(userId: '2')),
      _framework.execute(GetUserProfileRequest(userId: '3')),
    ];
    
    await Future.wait(requests)
        .then((responses) {
          print('✅ 所有请求完成');
          for (int i = 0; i < responses.length; i++) {
            final response = responses[i];
            if (response.success) {
              print('  用户${i + 1}: ${response.data?.name}');
            } else {
              print('  用户${i + 1}: 获取失败');
            }
          }
        })
        .catchError((error) {
          print('❌ 批量请求中有失败: $error');
        });
  }
  
  /// 示例5: 错误恢复和重试
  Future<void> example5_ErrorRecovery() async {
    print('\n=== 示例5: 错误恢复和重试 ===');
    
    final request = GetUserProfileRequest(userId: 'invalid-id');
    
    await _framework.execute(request)
        .then((response) async {
          if (response.success) {
            print('✅ 请求成功');
            return response;
          } else {
            print('❌ 首次请求失败，尝试备用方案');
            // 返回备用请求
            return await _framework.execute(GetUserProfileRequest(userId: 'default-user'));
          }
        })
        .then((NetworkResponse<UserModel> fallbackResponse) {
          if (fallbackResponse.success) {
            print('✅ 备用方案成功');
          } else {
            print('❌ 备用方案也失败了');
          }
          return fallbackResponse;
        })
        .catchError((error) {
          print('❌ 备用方案请求失败: $error');
          // 返回一个默认的失败响应
          return NetworkResponse<UserModel>(
            success: false,
            statusCode: 500,
            message: '备用方案失败: $error',
            timestamp: DateTime.now(),
            data: null,
          );
        });
  }
  
  /// 示例6: 条件链式调用
  Future<void> example6_ConditionalChaining() async {
    print('\n=== 示例6: 条件链式调用 ===');
    
    final request = GetUserProfileRequest(userId: '999');
    
    await _framework.execute(request)
        .then((response) async {
          if (response.success) {
            print('✅ 获取用户成功');
            
            // 根据用户ID决定下一步操作（模拟用户类型判断）
            final userType = response.data?.id == 'admin' ? 'admin' : 'normal';
            if (userType == 'admin') {
              print('🔑 管理员用户，获取管理权限');
              return await _getAdminPermissions();
            } else {
              print('👤 普通用户，获取基础信息');
              return await _getBasicInfo();
            }
          } else {
            throw Exception('用户信息获取失败');
          }
        })
        .then((additionalInfo) {
          print('✅ 附加信息获取成功: $additionalInfo');
        })
        .catchError((error) {
          print('❌ 条件链式调用失败: $error');
        });
  }
  
  // 辅助方法
  void _handleSuccessResponse(NetworkResponse response) {
    print('  处理成功响应: 状态码 ${response.statusCode}');
  }
  
  void _handleErrorResponse(NetworkResponse response) {
    print('  处理错误响应: ${response.errorCode}');
  }
  
  void _handleException(dynamic error) {
    print('  处理异常: ${error.runtimeType}');
  }
  
  Future<String> _getAdminPermissions() async {
    await Future.delayed(Duration(milliseconds: 100));
    return '管理员权限列表';
  }
  
  Future<String> _getBasicInfo() async {
    await Future.delayed(Duration(milliseconds: 100));
    return '基础用户信息';
  }
  
  /// 运行所有示例
  Future<void> runAllExamples() async {
    print('🚀 开始运行 Future 链式调用示例');
    
    await example1_ThenCatchError();
    await example2_WhenComplete();
    await example3_ChainedOperations();
    await example4_FutureWait();
    await example5_ErrorRecovery();
    await example6_ConditionalChaining();
    
    print('\n🎉 所有示例运行完成');
  }
}

/// 运行示例
Future<void> main() async {
  final example = FutureChainExample();
  await example.runAllExamples();
}