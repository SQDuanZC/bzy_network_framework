import 'package:bzy_network_framework/src/requests/base_network_request.dart';
import 'package:bzy_network_framework/src/frameworks/unified_framework.dart';

/// 示例：如何在请求中获取和使用原始请求数据
/// 
/// 原始请求数据功能允许您在请求的任何阶段访问最初传递给请求的数据，
/// 这在调试、日志记录和错误处理时特别有用。

/// 用户登录请求示例
class UserLoginRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String username;
  final String password;
  
  UserLoginRequest({
    required this.username,
    required this.password,
  });

  @override
  HttpMethod get method => HttpMethod.post;
  
  @override
  String get path => '/auth/login';
  
  @override
  dynamic get data => {
    'username': username,
    'password': password,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };

  @override
  Map<String, dynamic> parseResponse(dynamic responseData) {
    print('🔐 登录请求解析开始');
    print('📤 原始请求数据: $originalRequestData');
    print('📥 服务器响应: $responseData');
    
    if (responseData is Map<String, dynamic>) {
      // 检查登录是否成功
      if (responseData['success'] == true) {
        print('✅ 登录成功');
        return responseData;
      } else {
        // 登录失败时，记录原始请求数据用于调试
        print('❌ 登录失败');
        print('🔍 调试信息 - 原始用户名: ${(originalRequestData as Map?)?['username']}');
        throw Exception('登录失败: ${responseData['message']}');
      }
    }
    
    throw FormatException('无效的响应格式');
  }
  
  @override
  void onRequestError(NetworkException error) {
    super.onRequestError(error);
    // 在错误处理中使用原始请求数据
    print('🚨 请求错误发生');
    print('📋 错误详情: $error');
    print('🔍 原始请求数据: $originalRequestData');
    
    // 可以根据原始数据进行特定的错误处理
    final originalData = originalRequestData as Map<String, dynamic>?;
    if (originalData != null) {
      print('👤 失败的用户名: ${originalData['username']}');
      // 注意：出于安全考虑，不要在生产环境中记录密码
    }
  }
}

/// 文件上传请求示例
class FileUploadRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String filePath;
  final Map<String, String> metadata;
  
  FileUploadRequest({
    required this.filePath,
    required this.metadata,
  });

  @override
  HttpMethod get method => HttpMethod.post;
  
  @override
  String get path => '/upload';
  
  @override
  dynamic get data => {
    'file_path': filePath,
    'metadata': metadata,
    'upload_time': DateTime.now().toIso8601String(),
  };

  @override
  Map<String, dynamic> parseResponse(dynamic responseData) {
    print('📁 文件上传响应解析');
    
    // 获取原始请求数据用于验证
    final originalData = originalRequestData as Map<String, dynamic>?;
    if (originalData != null) {
      print('📂 上传的文件: ${originalData['file_path']}');
      print('📋 文件元数据: ${originalData['metadata']}');
      print('⏰ 上传时间: ${originalData['upload_time']}');
    }
    
    if (responseData is Map<String, dynamic>) {
      if (responseData['success'] == true) {
        print('✅ 文件上传成功');
        print('🔗 文件URL: ${responseData['file_url']}');
        return responseData;
      } else {
        throw Exception('文件上传失败: ${responseData['error']}');
      }
    }
    
    throw FormatException('无效的上传响应格式');
  }
}

/// 数据查询请求示例（GET请求）
class DataQueryRequest extends BaseNetworkRequest<List<Map<String, dynamic>>> {
  final Map<String, String> filters;
  
  DataQueryRequest(this.filters);

  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  String get path => '/data/query';
  
  @override
  Map<String, String> get queryParameters => filters;
  
  // GET请求通常没有请求体，但我们可以设置一些元数据
  @override
  dynamic get data => {
    'query_filters': filters,
    'request_id': DateTime.now().millisecondsSinceEpoch.toString(),
  };

  @override
  List<Map<String, dynamic>> parseResponse(dynamic responseData) {
    print('🔍 数据查询响应解析');
    
    // 即使是GET请求，也可以访问原始请求数据
    final originalData = originalRequestData as Map<String, dynamic>?;
    if (originalData != null) {
      print('🔎 查询过滤器: ${originalData['query_filters']}');
      print('🆔 请求ID: ${originalData['request_id']}');
    }
    
    if (responseData is Map<String, dynamic> && responseData['data'] is List) {
      final dataList = (responseData['data'] as List)
          .cast<Map<String, dynamic>>();
      
      print('📊 查询结果数量: ${dataList.length}');
      return dataList;
    }
    
    throw FormatException('无效的查询响应格式');
  }
}

/// 主函数 - 演示原始请求数据功能
void main() async {
  // 初始化网络框架
  final framework = UnifiedNetworkFramework.instance;
  
  await framework.initialize(
    baseUrl: 'https://api.example.com',
    config: {
      'connectTimeout': 15000,
      'receiveTimeout': 15000,
      'enableLogging': true,
    },
  );
  
  print('🚀 原始请求数据功能演示开始\n');
  
  // 示例1: 用户登录请求
  print('=== 示例1: 用户登录请求 ===');
  final loginRequest = UserLoginRequest(
    username: 'john_doe',
    password: 'secure_password_123',
  );
  
  try {
    final loginResponse = await framework.execute(loginRequest);
    print('登录响应: $loginResponse');
  } catch (e) {
    print('登录请求失败: $e');
    print('可以通过 loginRequest.originalRequestData 获取原始数据');
  }
  
  print('\n=== 示例2: 文件上传请求 ===');
  final uploadRequest = FileUploadRequest(
    filePath: '/path/to/document.pdf',
    metadata: {
      'title': '重要文档',
      'category': 'business',
      'tags': 'urgent,confidential',
    },
  );
  
  try {
    final uploadResponse = await framework.execute(uploadRequest);
    print('上传响应: $uploadResponse');
  } catch (e) {
    print('文件上传失败: $e');
    print('原始上传数据: ${uploadRequest.originalRequestData}');
  }
  
  print('\n=== 示例3: 数据查询请求 ===');
  final queryRequest = DataQueryRequest({
    'status': 'active',
    'category': 'premium',
    'limit': '50',
  });
  
  try {
    final queryResponse = await framework.execute(queryRequest);
    print('查询响应: $queryResponse');
  } catch (e) {
    print('数据查询失败: $e');
    print('原始查询参数: ${queryRequest.originalRequestData}');
  }
  
  print('\n🎉 原始请求数据功能演示完成!');
  print('\n💡 使用提示:');
  print('1. 原始请求数据在请求执行前自动设置');
  print('2. 可以在 parseResponse、onRequestError 等方法中访问');
  print('3. 对于调试、日志记录和错误分析非常有用');
  print('4. 数据类型与请求的 queryParameters 返回的类型一致');
}