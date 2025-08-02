import 'package:bzy_network_framework/bzy_network_framework.dart';

/// 配置预设与网络请求结合使用示例
/// 演示如何在实际网络请求中应用不同的配置预设
void main() async {
  print('=== 配置预设与网络请求结合使用示例 ===\n');
  
  // 示例1: 使用开发环境配置进行网络请求
  await _demonstrateDevelopmentConfig();
  
  // 示例2: 使用生产环境配置进行网络请求
  await _demonstrateProductionConfig();
  
  // 示例3: 使用快速响应配置进行网络请求
  await _demonstrateFastResponseConfig();
  
  // 示例4: 使用重负载配置进行网络请求
  await _demonstrateHeavyLoadConfig();
  
  // 示例5: 使用离线优先配置进行网络请求
  await _demonstrateOfflineFirstConfig();
  
  // 示例6: 动态切换配置
  await _demonstrateDynamicConfigSwitching();
}

/// 演示开发环境配置的使用
Future<void> _demonstrateDevelopmentConfig() async {
  print('--- 开发环境配置示例 ---');
  
  // 使用开发环境预设初始化框架
  NetworkConfig.instance.initializeFromPreset('development');
  await UnifiedNetworkFramework.instance.initialize(
    baseUrl: 'https://jsonplaceholder.typicode.com',
  );
  
  print('当前配置:');
  print('- 连接超时: ${NetworkConfig.instance.connectTimeout}ms');
  print('- 日志启用: ${NetworkConfig.instance.enableLogging}');
  print('- 重试次数: ${NetworkConfig.instance.maxRetries}');
  
  // 执行网络请求
  final request = SimpleApiRequest(endpoint: '/posts/1');
  final executor = NetworkExecutor.instance;
  
  try {
    final response = await executor.execute(request);
    print('✅ 开发环境请求成功: ${response.data?['title']}');
  } catch (e) {
    print('❌ 开发环境请求失败: $e');
  }
  print('');
}

/// 演示生产环境配置的使用
Future<void> _demonstrateProductionConfig() async {
  print('--- 生产环境配置示例 ---');
  
  // 切换到生产环境预设
  NetworkConfig.instance.initializeFromPreset('production');
  
  print('当前配置:');
  print('- 连接超时: ${NetworkConfig.instance.connectTimeout}ms');
  print('- 日志启用: ${NetworkConfig.instance.enableLogging}');
  print('- 重试次数: ${NetworkConfig.instance.maxRetries}');
  print('- 缓存启用: ${NetworkConfig.instance.enableCache}');
  
  // 执行网络请求
  final request = SimpleApiRequest(endpoint: '/posts/2');
  final executor = NetworkExecutor.instance;
  
  try {
    final response = await executor.execute(request);
    print('✅ 生产环境请求成功: ${response.data?['title']}');
  } catch (e) {
    print('❌ 生产环境请求失败: $e');
  }
  print('');
}

/// 演示快速响应配置的使用
Future<void> _demonstrateFastResponseConfig() async {
  print('--- 快速响应配置示例 ---');
  
  // 切换到快速响应预设
  NetworkConfig.instance.initializeFromPreset('fastResponse');
  
  print('当前配置:');
  print('- 连接超时: ${NetworkConfig.instance.connectTimeout}ms');
  print('- 接收超时: ${NetworkConfig.instance.receiveTimeout}ms');
  print('- 缓存启用: ${NetworkConfig.instance.enableCache}');
  
  // 执行多个快速请求
  final requests = [
    SimpleApiRequest(endpoint: '/posts/3'),
    SimpleApiRequest(endpoint: '/posts/4'),
    SimpleApiRequest(endpoint: '/posts/5'),
  ];
  
  final executor = NetworkExecutor.instance;
  final stopwatch = Stopwatch()..start();
  
  try {
    final responses = await Future.wait(
      requests.map((request) => executor.execute(request)),
    );
    stopwatch.stop();
    print('✅ 快速响应请求完成，耗时: ${stopwatch.elapsedMilliseconds}ms');
    print('   成功请求数: ${responses.where((r) => r.success).length}/${responses.length}');
  } catch (e) {
    print('❌ 快速响应请求失败: $e');
  }
  print('');
}

/// 演示重负载配置的使用
Future<void> _demonstrateHeavyLoadConfig() async {
  print('--- 重负载配置示例 ---');
  
  // 切换到重负载预设
  NetworkConfig.instance.initializeFromPreset('heavyLoad');
  
  print('当前配置:');
  print('- 连接超时: ${NetworkConfig.instance.connectTimeout}ms');
  print('- 最大重试: ${NetworkConfig.instance.maxRetries}');
  print('- 指数退避: ${NetworkConfig.instance.enableExponentialBackoff}');
  
  // 模拟重负载请求（可能失败的请求）
  final request = RetryableApiRequest(endpoint: '/posts/999999'); // 不存在的资源
  final executor = NetworkExecutor.instance;
  
  try {
    final response = await executor.execute(request);
    print('✅ 重负载请求成功: ${response.data}');
  } catch (e) {
    print('❌ 重负载请求最终失败（经过重试）: $e');
  }
  print('');
}

/// 演示离线优先配置的使用
Future<void> _demonstrateOfflineFirstConfig() async {
  print('--- 离线优先配置示例 ---');
  
  // 切换到离线优先预设
  NetworkConfig.instance.initializeFromPreset(NetworkConfigPreset.offlineFirst.value);
  
  print('当前配置:');
  print('- 缓存启用: ${NetworkConfig.instance.enableCache}');
  print('- 缓存时长: ${NetworkConfig.instance.defaultCacheDuration}秒');
  print('- 连接超时: ${NetworkConfig.instance.connectTimeout}ms');
  
  // 执行缓存友好的请求
  final request = CacheableApiRequest(endpoint: '/posts/6');
  final executor = NetworkExecutor.instance;
  
  try {
    // 第一次请求（从网络获取）
    print('第一次请求（从网络获取）...');
    final response1 = await executor.execute(request);
    print('✅ 首次请求成功: ${response1.data?['title']}');
    
    // 第二次请求（从缓存获取）
    print('第二次请求（应该从缓存获取）...');
    final response2 = await executor.execute(request);
    print('✅ 缓存请求成功: ${response2.data?['title']}');
  } catch (e) {
    print('❌ 离线优先请求失败: $e');
  }
  print('');
}

/// 演示动态配置切换
Future<void> _demonstrateDynamicConfigSwitching() async {
  print('--- 动态配置切换示例 ---');
  
  // 获取所有可用预设
  final availablePresets = NetworkConfigPresets.getAvailablePresets();
  print('可用预设: ${availablePresets.join(", ")}');
  
  // 动态切换不同预设并执行请求
  for (final preset in ['development', 'production', 'fastResponse']) {
    print('\n切换到预设: $preset');
    NetworkConfig.instance.initializeFromPreset(preset);
    
    final request = SimpleApiRequest(endpoint: '/posts/${preset.hashCode % 10 + 1}');
    final executor = NetworkExecutor.instance;
    
    try {
      final response = await executor.execute(request);
      print('✅ $preset 配置请求成功');
    } catch (e) {
      print('❌ $preset 配置请求失败: $e');
    }
  }
  
  print('\n=== 配置预设与网络请求示例完成 ===');
}

/// 简单API请求类
class SimpleApiRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String endpoint;
  
  SimpleApiRequest({required this.endpoint});
  
  @override
  String get path => endpoint;
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// 可重试API请求类
class RetryableApiRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String endpoint;
  
  RetryableApiRequest({required this.endpoint});
  
  @override
  String get path => endpoint;
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  bool get enableRetry => true;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// 可缓存API请求类
class CacheableApiRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String endpoint;
  
  CacheableApiRequest({required this.endpoint});
  
  @override
  String get path => endpoint;
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  bool get enableCache => true;
  
  @override
  int get cacheDuration => 300; // 5分钟缓存（秒）
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}