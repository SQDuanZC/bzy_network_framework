import 'package:bzy_network_framework/src/requests/base_network_request.dart';
import 'package:bzy_network_framework/src/frameworks/unified_framework.dart';

/// 解析异常测试请求类 (GET请求)
class ParseErrorTestRequest extends BaseNetworkRequest<Map<String, dynamic>> {

  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  String get path => '/todos/1';

  @override
  Map<String, dynamic> parseResponse(dynamic responseData) {
    print('📝 parseResponse: 开始解析响应数据');
    print('📝 响应数据: $responseData');
    print('📝 原始请求数据: $originalRequestData');
    
    // 故意抛出解析异常
    throw FormatException('模拟JSON解析失败: 数据格式不正确');
  }
}

/// POST请求测试类 (带请求体数据)
class PostRequestWithDataTest extends BaseNetworkRequest<Map<String, dynamic>> {
  final Map<String, dynamic> requestData;
  
  PostRequestWithDataTest(this.requestData);

  @override
  HttpMethod get method => HttpMethod.post;
  
  @override
  String get path => '/posts';
  
  @override
  dynamic get data => requestData;

  @override
  Map<String, dynamic> parseResponse(dynamic responseData) {
    print('📝 POST parseResponse: 开始解析响应数据');
    print('📝 响应数据: $responseData');
    print('📝 原始请求数据: $originalRequestData');
    print('📝 当前请求数据: $data');
    
    // 故意抛出解析异常来测试原始数据获取
    throw FormatException('POST请求解析失败: 无法处理响应数据');
  }
}

/// 主函数
void main() async {
  final framework = UnifiedNetworkFramework.instance;
  
  await framework.initialize(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    config: {
      'connectTimeout': 15000,
      'receiveTimeout': 15000,
      'enableLogging': true,
    },
  );
  
  print('=== 测试1: GET请求原始数据获取 ===');
  final getRequest = ParseErrorTestRequest();
  try {
    final getResponse = await framework.execute(getRequest);
  } catch (e) {
    print('GET请求异常: $e');
    print('GET请求原始数据: ${getRequest.originalRequestData}');
  }
  
  print('\n=== 测试2: POST请求原始数据获取 ===');
  final postData = {
    'title': 'foo',
    'body': 'bar',
    'userId': 1,
  };
  final postRequest = PostRequestWithDataTest(postData);
  try {
    final postResponse = await framework.execute(postRequest);
  } catch (e) {
    print('POST请求异常: $e');
    print('POST请求原始数据: ${postRequest.originalRequestData}');
  }
}