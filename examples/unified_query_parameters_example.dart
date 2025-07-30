import 'package:bzy_network_framework/src/requests/base_network_request.dart';
import 'package:bzy_network_framework/src/frameworks/unified_framework.dart';
import 'package:bzy_network_framework/src/model/network_response.dart';

/// GET请求示例 - 使用统一的queryParameters
class GetUserRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String userId;
  final bool includeProfile;
  
  GetUserRequest({
    required this.userId,
    this.includeProfile = false,
  });
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  String get path => '/users';
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'id': userId,
    'include_profile': includeProfile.toString(),
  };
  // 框架自动处理为: GET /users?id=123&include_profile=true
  
  @override
  Map<String, dynamic> parseResponse(dynamic response) {
    print('GET请求 - 原始数据: $originalRequestData');
    print('GET请求 - 响应数据: $response');
    return response as Map<String, dynamic>;
  }
  
  @override
  void onRequestError(NetworkException error) {
    print('GET请求错误 - 原始数据: $originalRequestData');
    print('GET请求错误: ${error.message}');
  }
}

/// POST请求示例 - 使用统一的queryParameters
class CreateUserRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String name;
  final String email;
  final int age;
  
  CreateUserRequest({
    required this.name,
    required this.email,
    required this.age,
  });
  
  @override
  HttpMethod get method => HttpMethod.post;
  
  @override
  String get path => '/users';
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'name': name,
    'email': email,
    'age': age,
    'created_at': DateTime.now().toIso8601String(),
  };
  // 框架自动转换为请求体: POST /users + JSON body
  
  @override
  Map<String, dynamic> parseResponse(dynamic response) {
    print('POST请求 - 原始数据: $originalRequestData');
    print('POST请求 - 响应数据: $response');
    return response as Map<String, dynamic>;
  }
  
  @override
  void onRequestError(NetworkException error) {
    print('POST请求错误 - 原始数据: $originalRequestData');
    print('POST请求错误: ${error.message}');
  }
}

/// PUT请求示例 - 使用统一的queryParameters
class UpdateUserRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String userId;
  final String? name;
  final String? email;
  
  UpdateUserRequest({
    required this.userId,
    this.name,
    this.email,
  });
  
  @override
  HttpMethod get method => HttpMethod.put;
  
  @override
  String get path => '/users/$userId';
  
  @override
  Map<String, dynamic>? get queryParameters {
    final data = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    if (name != null) data['name'] = name;
    if (email != null) data['email'] = email;
    
    return data;
  }
  // 框架自动转换为请求体: PUT /users/123 + JSON body
  
  @override
  Map<String, dynamic> parseResponse(dynamic response) {
    print('PUT请求 - 原始数据: $originalRequestData');
    print('PUT请求 - 响应数据: $response');
    return response as Map<String, dynamic>;
  }
  
  @override
  void onRequestError(NetworkException error) {
    print('PUT请求错误 - 原始数据: $originalRequestData');
    print('PUT请求错误: ${error.message}');
  }
}

/// DELETE请求示例 - 使用统一的queryParameters
class DeleteUserRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String userId;
  final bool force;
  
  DeleteUserRequest({
    required this.userId,
    this.force = false,
  });
  
  @override
  HttpMethod get method => HttpMethod.delete;
  
  @override
  String get path => '/users/$userId';
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'force': force.toString(),
    'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
  };
  // 框架自动处理为: DELETE /users/123?force=true&timestamp=1234567890
  
  @override
  Map<String, dynamic> parseResponse(dynamic response) {
    print('DELETE请求 - 原始数据: $originalRequestData');
    print('DELETE请求 - 响应数据: $response');
    return response as Map<String, dynamic>;
  }
  
  @override
  void onRequestError(NetworkException error) {
    print('DELETE请求错误 - 原始数据: $originalRequestData');
    print('DELETE请求错误: ${error.message}');
  }
}

void main() async {
  // 初始化网络框架
  await UnifiedNetworkFramework.instance.initialize(
    baseUrl: 'https://jsonplaceholder.typicode.com',
  );
  
  print('=== 统一queryParameters方案演示 ===\n');
  
  // 1. GET请求测试
  print('1. GET请求测试:');
  try {
    final getUserRequest = GetUserRequest(
      userId: '1',
      includeProfile: true,
    );
    final getUserResponse = await UnifiedNetworkFramework.instance.execute(getUserRequest);
    print('GET请求成功: ${getUserResponse.success}\n');
  } catch (e) {
    print('GET请求失败: $e\n');
  }
  
  // 2. POST请求测试
  print('2. POST请求测试:');
  try {
    final createUserRequest = CreateUserRequest(
      name: '张三',
      email: 'zhangsan@example.com',
      age: 25,
    );
    final createUserResponse = await UnifiedNetworkFramework.instance.execute(createUserRequest);
    print('POST请求成功: ${createUserResponse.success}\n');
  } catch (e) {
    print('POST请求失败: $e\n');
  }
  
  // 3. PUT请求测试
  print('3. PUT请求测试:');
  try {
    final updateUserRequest = UpdateUserRequest(
      userId: '1',
      name: '李四',
      email: 'lisi@example.com',
    );
    final updateUserResponse = await UnifiedNetworkFramework.instance.execute(updateUserRequest);
    print('PUT请求成功: ${updateUserResponse.success}\n');
  } catch (e) {
    print('PUT请求失败: $e\n');
  }
  
  // 4. DELETE请求测试
  print('4. DELETE请求测试:');
  try {
    final deleteUserRequest = DeleteUserRequest(
      userId: '1',
      force: true,
    );
    final deleteUserResponse = await UnifiedNetworkFramework.instance.execute(deleteUserRequest);
    print('DELETE请求成功: ${deleteUserResponse.success}\n');
  } catch (e) {
    print('DELETE请求失败: $e\n');
  }
  
  print('=== 演示完成 ===');
}