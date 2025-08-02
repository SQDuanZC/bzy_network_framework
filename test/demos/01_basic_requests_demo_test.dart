import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/bzy_network_framework.dart';
import 'dart:async';

/// Basic Network Request Examples / 基础网络请求示例 (Basic Network Request Examples)
/// Demonstrates the basic usage of the network framework / 演示网络框架的基本使用方法 (demonstrates the basic usage of the network framework)
void main() {
  group('Basic Network Request Examples / 基础网络请求示例 (Basic Network Request Examples)', () {
    setUpAll(() async {
      // Initialize network framework / 初始化网络框架 (initialize network framework)
      await UnifiedNetworkFramework.instance.initialize(
        baseUrl: 'https://jsonplaceholder.typicode.com',
        config: {
          'enableLogging': true,
          'connectTimeout': 10000,
          'receiveTimeout': 10000,
        },
      );
    });

    test('Simple GET Request Example / 简单GET请求示例 (Simple GET Request Example)', () async {
      final request = SimpleGetRequest();
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await executor.execute(request);
        print('GET request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('GET request failed: $e');
      }
    });

    test('GET Request with Query Parameters Example / 带查询参数的GET请求示例 (GET Request with Query Parameters Example)', () async {
      final request = GetWithParamsRequest(userId: 1);
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await executor.execute(request);
        print('GET request with parameters successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('GET request with parameters failed: $e');
      }
    });

    test('POST Request with JSON Data Example / 带JSON数据的POST请求示例 (POST Request with JSON Data Example)', () async {
      final request = SimplePostRequest(
        title: 'Test Post',
        body: 'This is a test post',
        userId: 1,
      );
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await executor.execute(request);
        print('POST request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('POST request failed: $e');
      }
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}

/// Simple GET request class / 简单GET请求类 (Simple GET request class)
class SimpleGetRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// GET request with parameters class / 带参数的GET请求类 (GET request with parameters class)
class GetWithParamsRequest extends BaseNetworkRequest<List<dynamic>> {
  final int userId;
  
  GetWithParamsRequest({required this.userId});
  
  @override
  String get path => '/posts';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'userId': userId,
  };
  
  @override
  List<dynamic> parseResponse(dynamic data) {
    return data as List<dynamic>;
  }
}

/// Simple POST request class / 简单POST请求类 (Simple POST request class)
class SimplePostRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String title;
  final String body;
  final int userId;
  
  SimplePostRequest({
    required this.title,
    required this.body,
    required this.userId,
  });
  
  @override
  String get path => '/posts';
  
  @override
  HttpMethod get method => HttpMethod.post;
  
  @override
  dynamic get data => {
    'title': title,
    'body': body,
    'userId': userId,
  };
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// PUT request class / PUT请求类 (PUT request class)
class SimplePutRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final int id;
  final String title;
  final String body;
  final int userId;
  
  SimplePutRequest({
    required this.id,
    required this.title,
    required this.body,
    required this.userId,
  });
  
  @override
  String get path => '/posts/$id';
  
  @override
  HttpMethod get method => HttpMethod.put;
  
  @override
  dynamic get data => {
    'id': id,
    'title': title,
    'body': body,
    'userId': userId,
  };
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// DELETE request class / DELETE请求类 (DELETE request class)
class SimpleDeleteRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final int id;
  
  SimpleDeleteRequest({required this.id});
  
  @override
  String get path => '/posts/$id';
  
  @override
  HttpMethod get method => HttpMethod.delete;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// Request class with custom headers / 带自定义请求头的请求类 (Request class with custom headers)
class RequestWithHeaders extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  Map<String, String>? get headers => {
    'Authorization': 'Bearer token123',
    'Custom-Header': 'custom-value',
  };
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// Request class with timeout setting / 带超时设置的请求类 (Request class with timeout setting)
class RequestWithTimeout extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  int? get timeout => 5;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}