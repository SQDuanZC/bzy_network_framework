import 'package:dio/dio.dart';
import '../../lib/src/core/interceptor/timeout_interceptor.dart';
import '../../lib/src/core/interceptor/interceptor_manager.dart';
import '../../lib/src/core/network/network_adapter.dart';
import '../../lib/src/core/network/network_connectivity_monitor.dart';

/// 连接超时拦截器使用示例
void main() async {
  await demonstrateTimeoutInterceptor();
}

/// 演示超时拦截器的使用
Future<void> demonstrateTimeoutInterceptor() async {
  print('=== 连接超时拦截器演示 ===\n');
  
  // 1. 创建超时拦截器配置
  final timeoutConfig = TimeoutInterceptorConfig(
    enabled: true,
    enableDynamicTimeout: true,
    enableNetworkQualityCheck: true,
    baseConnectTimeout: 10000,  // 10秒基础连接超时
    baseReceiveTimeout: 20000,  // 20秒基础接收超时
    baseSendTimeout: 15000,     // 15秒基础发送超时
    timeoutRetryCount: 3,       // 超时重试3次
    timeoutRetryDelay: 1000,    // 重试延迟1秒
    enableExponentialBackoff: true,
    maxTimeout: 60000,          // 最大超时60秒
    minTimeout: 3000,           // 最小超时3秒
    errorStrategy: TimeoutErrorStrategy.retryWithBackoff,
  );
  
  // 2. 创建网络适配器和连接监控器
  final networkAdapter = NetworkAdapter();
  final connectivityMonitor = NetworkConnectivityMonitor();
  
  // 初始化组件
  await networkAdapter.initialize();
  await connectivityMonitor.initialize();
  
  // 3. 创建超时拦截器
  final timeoutInterceptor = TimeoutInterceptor(
    config: timeoutConfig,
    networkAdapter: networkAdapter,
    connectivityMonitor: connectivityMonitor,
  );
  
  // 4. 注册拦截器到拦截器管理器
  final interceptorManager = InterceptorManager.instance;
  
  interceptorManager.registerInterceptor(
    'timeout',
    timeoutInterceptor,
    config: InterceptorConfig(
      enabled: true,
      priority: 800,  // 高优先级，在请求前调整超时
      timeout: Duration(seconds: 5),
      continueOnError: true,
    ),
  );
  
  print('✅ 超时拦截器已注册');
  
  // 5. 演示不同的超时策略
  await _demonstrateTimeoutStrategies(timeoutInterceptor);
  
  // 6. 演示动态超时调整
  await _demonstrateDynamicTimeout(timeoutInterceptor);
  
  // 7. 演示超时统计
  _demonstrateTimeoutStatistics(timeoutInterceptor);
  
  // 8. 清理资源
  await networkAdapter.dispose();
  await connectivityMonitor.dispose();
  
  print('\n=== 演示完成 ===');
}

/// 演示不同的超时策略
Future<void> _demonstrateTimeoutStrategies(TimeoutInterceptor interceptor) async {
  print('\n--- 超时策略演示 ---');
  
  // 创建测试请求选项
  final requestOptions = RequestOptions(
    path: 'https://httpbin.org/delay/5',  // 延迟5秒的测试端点
    method: 'GET',
  );
  
  // 模拟不同的超时策略
  final strategies = [
    TimeoutErrorStrategy.failImmediately,
    TimeoutErrorStrategy.retry,
    TimeoutErrorStrategy.retryWithBackoff,
    TimeoutErrorStrategy.adjustTimeoutAndRetry,
  ];
  
  for (final strategy in strategies) {
    print('\n测试策略: ${strategy.toString().split('.').last}');
    
    // 创建带有特定策略的配置
    final config = TimeoutInterceptorConfig(
      errorStrategy: strategy,
      timeoutRetryCount: 2,
      timeoutRetryDelay: 500,
    );
    
    final testInterceptor = TimeoutInterceptor(config: config);
    
    // 模拟超时错误
    final timeoutError = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.connectionTimeout,
      message: '连接超时',
    );
    
    try {
      // 这里只是演示，实际使用中会在错误拦截器中处理
      print('处理超时错误...');
      // await testInterceptor.onError(timeoutError, handler);
    } catch (e) {
      print('策略处理结果: $e');
    }
  }
}

/// 演示动态超时调整
Future<void> _demonstrateDynamicTimeout(TimeoutInterceptor interceptor) async {
  print('\n--- 动态超时调整演示 ---');
  
  // 创建测试请求
  final requestOptions = RequestOptions(
    path: 'https://api.example.com/test',
    method: 'GET',
    connectTimeout: Duration(milliseconds: 5000),
    receiveTimeout: Duration(milliseconds: 10000),
    sendTimeout: Duration(milliseconds: 5000),
  );
  
  print('原始超时设置:');
  print('  连接超时: ${requestOptions.connectTimeout?.inMilliseconds}ms');
  print('  接收超时: ${requestOptions.receiveTimeout?.inMilliseconds}ms');
  print('  发送超时: ${requestOptions.sendTimeout?.inMilliseconds}ms');
  
  // 模拟请求拦截器处理
  try {
    // 这里只是演示，实际会通过拦截器链调用
    print('\n应用动态超时调整...');
    // final adjustedOptions = await interceptor.onRequest(requestOptions, handler);
    
    print('调整后的超时设置:');
    print('  连接超时: ${requestOptions.connectTimeout?.inMilliseconds}ms');
    print('  接收超时: ${requestOptions.receiveTimeout?.inMilliseconds}ms');
    print('  发送超时: ${requestOptions.sendTimeout?.inMilliseconds}ms');
  } catch (e) {
    print('动态调整失败: $e');
  }
}

/// 演示超时统计
void _demonstrateTimeoutStatistics(TimeoutInterceptor interceptor) {
  print('\n--- 超时统计演示 ---');
  
  // 模拟一些超时记录
  final testUrls = [
    'https://api.example.com/users',
    'https://api.example.com/posts',
    'https://api.example.com/comments',
  ];
  
  // 模拟超时记录（实际使用中会自动记录）
  print('模拟超时记录...');
  for (final url in testUrls) {
    // interceptor.recordTimeout(url);  // 这是内部方法
    print('记录超时: $url');
  }
  
  // 获取统计信息
  final statistics = interceptor.getTimeoutStatistics();
  print('\n超时统计信息:');
  print('  总超时次数: ${statistics['totalTimeouts']}');
  print('  各URL超时次数: ${statistics['timeoutsByUrl']}');
  print('  最后超时时间: ${statistics['lastTimeoutTimes']}');
  
  // 演示清理统计
  print('\n清理超时统计...');
  interceptor.clearTimeoutStatistics();
  
  final clearedStats = interceptor.getTimeoutStatistics();
  print('清理后统计: ${clearedStats['totalTimeouts']} 次超时');
}

/// 创建带有超时拦截器的Dio实例示例
Dio createDioWithTimeoutInterceptor() {
  final dio = Dio();
  
  // 创建超时拦截器
  final timeoutInterceptor = TimeoutInterceptor(
    config: TimeoutInterceptorConfig(
      enabled: true,
      enableDynamicTimeout: true,
      baseConnectTimeout: 15000,
      baseReceiveTimeout: 30000,
      timeoutRetryCount: 3,
      errorStrategy: TimeoutErrorStrategy.retryWithBackoff,
    ),
  );
  
  // 添加到Dio拦截器链
  dio.interceptors.add(timeoutInterceptor);
  
  return dio;
}

/// 使用示例
Future<void> exampleUsage() async {
  final dio = createDioWithTimeoutInterceptor();
  
  try {
    final response = await dio.get('https://api.example.com/data');
    print('请求成功: ${response.statusCode}');
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      print('连接超时，已自动处理和重试');
    } else {
      print('其他错误: ${e.message}');
    }
  }
}