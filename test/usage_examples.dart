import 'package:dio/dio.dart';
import 'package:bzy_network_framework/src/frameworks/unified_framework.dart';
import 'package:bzy_network_framework/src/config/network_config.dart';
import 'package:bzy_network_framework/src/requests/base_network_request.dart';
import 'package:bzy_network_framework/src/model/network_response.dart';
import 'package:bzy_network_framework/src/utils/network_logger.dart';
import 'example_requests.dart';

/// 统一网络框架使用示例
class NetworkFrameworkUsageExamples {
  late UnifiedNetworkFramework _framework;
  
  /// 初始化示例
  Future<void> initializeFramework() async {
    _framework = UnifiedNetworkFramework.instance;
    
    // 基础配置
    await _framework.initialize(
      baseUrl: 'https://api.example.com',
      config: {
        'connectTimeout': 30000,
        'receiveTimeout': 30000,
        'sendTimeout': 30000,
        'enableLogging': true,
        'logLevel': LogLevel.debug,
        'enableCache': true,
        'defaultCacheDuration': 300,
        'maxRetries': 3,
        'retryDelay': 1000,
        'environment': Environment.development,
        'defaultHeaders': {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-App-Version': '1.0.0',
        },
      },
      plugins: [
        // 认证插件
        NetworkPluginFactory.createAuthPlugin(
          getToken: () => _getStoredToken(),
          tokenType: 'Bearer',
        ),
        
        // 缓存插件
        NetworkPluginFactory.createCachePlugin(
          maxSize: 100,
          defaultDuration: const Duration(minutes: 5),
        ),
        
        // 重试插件
        NetworkPluginFactory.createRetryPlugin(
          maxRetries: 3,
          delay: const Duration(seconds: 1),
          shouldRetry: (error) => error.type != DioExceptionType.cancel,
        ),
        
        // 日志插件
        NetworkPluginFactory.createLoggingPlugin(
          logRequest: true,
          logResponse: true,
          logError: true,
        ),
      ],
    );
    
    NetworkLogger.framework.info('✅ 网络框架初始化完成');
  }
  
  /// 基础请求示例
  Future<void> basicRequestExamples() async {
    NetworkLogger.general.info('\n=== 基础请求示例 ===');
    
    // 1. 获取用户信息
    final getUserRequest = GetUserProfileRequest(userId: '123');
    final userResponse = await _framework.execute(getUserRequest);
    
    if (userResponse.success) {
      NetworkLogger.general.info('✅ 获取用户信息成功: ${userResponse.data?.name}');
    } else {
      NetworkLogger.general.warning('❌ 获取用户信息失败: ${userResponse.message}');
    }
    
    // 2. 更新用户信息
    final updateRequest = UpdateUserProfileRequest(
      userId: '123',
      userData: {
        'name': '新用户名',
        'phone': '+86 138 0013 8000',
        'department': '技术部',
      },
    );
    
    final updateResponse = await _framework.execute(updateRequest);
    if (updateResponse.success) {
      NetworkLogger.general.info('✅ 更新用户信息成功');
    }
    
    // 3. 分页获取用户列表
    final getUsersRequest = GetUsersListRequest(
      page: 1,
      pageSize: 20,
    );
    
    final usersResponse = await _framework.execute(getUsersRequest);
    if (usersResponse.success) {
      NetworkLogger.general.info('✅ 获取用户列表成功，共 ${usersResponse.data?.length} 个用户');
    }
  }
  
  /// 批量请求示例
  Future<void> batchRequestExamples() async {
    NetworkLogger.general.info('\n=== 批量请求示例 ===');
    
    // 创建多个请求
    final requests = <BaseNetworkRequest>[
      GetUserProfileRequest(userId: '1'),
      GetUserProfileRequest(userId: '2'),
      GetUserProfileRequest(userId: '3'),
      GetUsersListRequest(page: 1, pageSize: 10),
    ];
    
    // 批量执行（顺序执行）
    final batchResponses = await _framework.executeBatch(requests);
    NetworkLogger.general.info('✅ 批量请求完成，共 ${batchResponses.length} 个响应');
    
    // 并发执行（限制并发数）
    final concurrentResponses = await _framework.executeConcurrent(
      requests,
      maxConcurrency: 2,
    );
    NetworkLogger.general.info('✅ 并发请求完成，共 ${concurrentResponses.length} 个响应');
  }
  
  /// 自定义请求示例
  Future<void> customRequestExamples() async {
    NetworkLogger.general.info('\n=== 自定义请求示例 ===');
    
    // 创建自定义请求
    final customRequest = CustomApiRequest(
      endpoint: '/api/custom/data',
      params: {'type': 'special', 'limit': 50},
    );
    
    final response = await _framework.execute(customRequest);
    if (response.success) {
      NetworkLogger.general.info('✅ 自定义请求成功: ${response.data}');
    }
  }
  
  /// 文件上传示例
  Future<void> fileUploadExample() async {
    NetworkLogger.general.info('\n=== 文件上传示例 ===');
    
    final uploadRequest = UploadUserAvatarRequest(
      userId: '123',
      filePath: '/path/to/avatar.jpg',
    );
    
    final uploadResponse = await _framework.execute(uploadRequest);
    if (uploadResponse.success) {
      NetworkLogger.general.info('✅ 文件上传成功: ${uploadResponse.data?['url']}');
    }
  }
  
  /// 错误处理示例
  Future<void> errorHandlingExamples() async {
    NetworkLogger.general.info('\n=== 错误处理示例 ===');
    
    try {
      // 创建一个会失败的请求
      final failRequest = GetUserProfileRequest(userId: 'invalid-id');
      final response = await _framework.execute(failRequest);
      
      if (!response.success) {
        NetworkLogger.general.warning('❌ 请求失败: ${response.message}');
        NetworkLogger.general.warning('   状态码: ${response.statusCode}');
        NetworkLogger.general.warning('   错误代码: ${response.errorCode}');
      }
    } catch (e) {
      NetworkLogger.general.severe('❌ 捕获异常: $e');
    }
  }
  
  /// 配置更新示例
  Future<void> configUpdateExamples() async {
    NetworkLogger.general.info('\n=== 配置更新示例 ===');
    
    // 更新认证token
    _framework.updateConfig({
      'authToken': 'new-auth-token-12345',
    });
    
    // 更新超时配置
    _framework.updateConfig({
      'timeouts': {
        'connectTimeout': 15000,
        'receiveTimeout': 15000,
      },
    });
    
    // 更新缓存配置
    _framework.updateConfig({
      'cache': {
        'enableCache': false,
      },
    });
    
    // 更新日志配置
    _framework.updateConfig({
      'logging': {
        'enableLogging': false,
      },
    });
    
    NetworkLogger.general.info('✅ 配置更新完成');
  }
  
  /// 插件管理示例
  Future<void> pluginManagementExamples() async {
    NetworkLogger.general.info('\n=== 插件管理示例 ===');
    
    // 动态注册插件
    final customPlugin = CustomAnalyticsPlugin();
    await _framework.registerPlugin(customPlugin);
    NetworkLogger.general.info('✅ 注册自定义插件: ${customPlugin.name}');
    
    // 获取插件
    final authPlugin = _framework.getPlugin<AuthPlugin>('auth');
    if (authPlugin != null) {
      NetworkLogger.general.info('✅ 获取认证插件成功');
    }
    
    // 查看所有插件
    final allPlugins = _framework.plugins;
    NetworkLogger.general.info('📋 当前插件列表:');
    for (final plugin in allPlugins) {
      NetworkLogger.general.info('   - ${plugin.name} (${plugin.version}): ${plugin.description}');
    }
    
    // 注销插件
    await _framework.unregisterPlugin('custom-analytics');
    NetworkLogger.general.info('✅ 注销自定义插件');
  }
  
  /// 状态监控示例
  Future<void> statusMonitoringExamples() async {
    NetworkLogger.general.info('\n=== 状态监控示例 ===');
    
    final status = _framework.getStatus();
    NetworkLogger.general.info('📊 框架状态:');
    NetworkLogger.general.info('   - 是否已初始化: ${status['isInitialized']}');
    NetworkLogger.general.info('   - 插件数量: ${status['pluginsCount']}');
    NetworkLogger.general.info('   - 全局拦截器数量: ${status['globalInterceptorsCount']}');
    
    final executorStatus = status['executor'] as Map<String, dynamic>;
    NetworkLogger.general.info('   - 待处理请求: ${executorStatus['pendingRequests']}');
    NetworkLogger.general.info('   - 队列中请求: ${executorStatus['queuedRequests']}');
    NetworkLogger.general.info('   - 缓存大小: ${executorStatus['cacheSize']}');
  }
  
  /// 清理资源示例
  Future<void> cleanupExample() async {
    NetworkLogger.general.info('\n=== 清理资源示例 ===');
    
    // 取消所有请求
    _framework.cancelAllRequests();
    NetworkLogger.general.info('✅ 取消所有请求');
    
    // 清理框架资源
    await _framework.dispose();
    NetworkLogger.general.info('✅ 清理框架资源完成');
  }
  
  /// 获取存储的token
  String _getStoredToken() {
    // 这里应该从安全存储中获取token
    return 'stored-auth-token-12345';
  }
  
  /// 运行所有示例
  Future<void> runAllExamples() async {
    try {
      await initializeFramework();
      await basicRequestExamples();
      await batchRequestExamples();
      await customRequestExamples();
      await fileUploadExample();
      await errorHandlingExamples();
      await configUpdateExamples();
      await pluginManagementExamples();
      await statusMonitoringExamples();
      await cleanupExample();
      
      NetworkLogger.general.info('\n🎉 所有示例运行完成！');
    } catch (e) {
      NetworkLogger.general.severe('❌ 示例运行出错: $e');
    }
  }
}

/// 自定义API请求示例
class CustomApiRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  HttpMethod get method => HttpMethod.get;
  final String endpoint;
  final Map<String, dynamic> params;
  
  CustomApiRequest({
    required this.endpoint,
    required this.params,
  });
  
  @override
  String get path => endpoint;
  
  @override
  Map<String, dynamic> get queryParameters => params;
  
  @override
  bool get enableCache => true;
  
  @override
  int get cacheDuration => 180; // 3分钟缓存
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// 自定义分析插件示例
class CustomAnalyticsPlugin extends NetworkPlugin {
  @override
  String get name => 'custom-analytics';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => 'Custom analytics plugin for tracking API usage';
  
  @override
  Future<void> initialize() async {
    NetworkLogger.general.info('🔧 初始化分析插件');
  }
  
  @override
  Future<void> onRequestStart(BaseNetworkRequest request) async {
    NetworkLogger.general.info('📊 [Analytics] 请求开始: ${request.method} ${request.path}');
  }
  
  @override
  Future<void> onRequestComplete(BaseNetworkRequest request, NetworkResponse response) async {
    NetworkLogger.general.info('📊 [Analytics] 请求完成: ${request.path} - ${response.statusCode} (${response.duration}ms)');
  }
  
  @override
  Future<void> onRequestError(BaseNetworkRequest request, dynamic error) async {
    NetworkLogger.general.warning('📊 [Analytics] 请求错误: ${request.path} - $error');
  }
  
  @override
  Future<void> dispose() async {
    NetworkLogger.general.info('🔧 清理分析插件');
  }
}

/// 使用示例的入口函数
Future<void> runNetworkFrameworkExamples() async {
  final examples = NetworkFrameworkUsageExamples();
  await examples.runAllExamples();
}