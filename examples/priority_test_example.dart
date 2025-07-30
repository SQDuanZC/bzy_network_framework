import '../lib/src/requests/base_network_request.dart';
// HttpMethod 已在 base_network_request.dart 中定义
import 'package:dio/dio.dart';

/// 测试 data 优先级的示例
void main() {
  print('=== 测试 data 和 queryParameters 优先级 ===\n');
  
  // 1. 测试 GET 请求 - 应该使用 queryParameters 作为 URL 参数
  final getRequest = TestGetRequest();
  final getOptions = getRequest.buildRequestOptions();
  print('GET 请求:');
  print('  queryParameters: ${getOptions.queryParameters}');
  print('  data: ${getOptions.data}');
  print('');
  
  // 2. 测试 POST 请求（只有 queryParameters）- 应该使用 queryParameters 作为请求体
  final postRequest = TestPostRequest();
  final postOptions = postRequest.buildRequestOptions();
  print('POST 请求（只有 queryParameters）:');
  print('  queryParameters: ${postOptions.queryParameters}');
  print('  data: ${postOptions.data}');
  print('');
  
  // 3. 测试文件上传请求 - 应该优先使用 data（FormData）
  final uploadRequest = TestUploadRequest();
  final uploadOptions = uploadRequest.buildRequestOptions();
  print('文件上传请求（data 优先）:');
  print('  queryParameters: ${uploadOptions.queryParameters}');
  print('  data 类型: ${uploadOptions.data.runtimeType}');
  print('  data 是否为 FormData: ${uploadOptions.data is FormData}');
  print('');
  
  // 4. 测试同时有 data 和 queryParameters 的 POST 请求 - 应该优先使用 data
  final mixedRequest = TestMixedRequest();
  final mixedOptions = mixedRequest.buildRequestOptions();
  print('混合请求（data 优先于 queryParameters）:');
  print('  queryParameters: ${mixedOptions.queryParameters}');
  print('  data: ${mixedOptions.data}');
  print('');
}

/// GET 请求测试类
class TestGetRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/api/users';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'page': 1,
    'limit': 10,
  };

  @override
  Map<String, dynamic> parseResponse(dynamic response) {
    return response as Map<String, dynamic>;
  }
}

/// POST 请求测试类（只有 queryParameters）
class TestPostRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/api/users';
  
  @override
  HttpMethod get method => HttpMethod.post;
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'name': 'John Doe',
    'email': 'john@example.com',
  };

  @override
  Map<String, dynamic> parseResponse(dynamic response) {
    return response as Map<String, dynamic>;
  }
}

/// 文件上传请求测试类
class TestUploadRequest extends UploadRequest<Map<String, dynamic>> {
  @override
  String get path => '/api/upload';
  
  @override
  String get filePath => '/path/to/test/file.jpg';
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'category': 'avatar',
    'userId': '123',
  };
  
  @override
  Map<String, dynamic>? getFormData() => {
    'description': 'User avatar upload',
  };

  @override
  Map<String, dynamic> parseResponse(dynamic response) {
    return response as Map<String, dynamic>;
  }
}

/// 混合请求测试类（同时有 data 和 queryParameters）
class TestMixedRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/api/mixed';
  
  @override
  HttpMethod get method => HttpMethod.post;
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'from_query': 'query_value',
  };
  
  @override
  dynamic get data => {
    'from_data': 'data_value',
    'priority': 'data_should_win',
  };

  @override
  Map<String, dynamic> parseResponse(dynamic response) {
    return response as Map<String, dynamic>;
  }
}