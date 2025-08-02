import 'package:bzy_network_framework/bzy_network_framework.dart';

/// 配置预设使用示例
void main() async {
  // 示例1: 使用预设配置初始化
  print('=== 配置预设使用示例 ===\n');
  
  // 获取所有可用的预设
  final availablePresets = NetworkConfigPresets.getAvailablePresets();
  print('可用的配置预设: ${availablePresets.join(", ")}\n');
  
  // 示例2: 使用开发环境预设
  print('--- 开发环境配置 ---');
  final devConfig = NetworkConfigPresets.getPreset('development');
  if (devConfig != null) {
    NetworkConfig.instance.initializeFromPreset('development');
    print('连接超时: ${NetworkConfig.instance.connectTimeout}ms');
    print('接收超时: ${NetworkConfig.instance.receiveTimeout}ms');
    print('发送超时: ${NetworkConfig.instance.sendTimeout}ms');
    print('缓存时长: ${NetworkConfig.instance.defaultCacheDuration}秒');
    print('指数退避: ${NetworkConfig.instance.enableExponentialBackoff}');
    print('最大重试: ${NetworkConfig.instance.maxRetries}次\n');
  }
  
  // 示例3: 使用生产环境预设
  print('--- 生产环境配置 ---');
  NetworkConfig.instance.initializeFromPreset('production');
  print('连接超时: ${NetworkConfig.instance.connectTimeout}ms');
    print('接收超时: ${NetworkConfig.instance.receiveTimeout}ms');
    print('发送超时: ${NetworkConfig.instance.sendTimeout}ms');
    print('缓存时长: ${NetworkConfig.instance.defaultCacheDuration}秒');
    print('指数退避: ${NetworkConfig.instance.enableExponentialBackoff}');
    print('最大重试: ${NetworkConfig.instance.maxRetries}次\n');
  
  // 示例4: 使用快速响应预设
  print('--- 快速响应配置 ---');
  NetworkConfig.instance.initializeFromPreset('fastResponse');
  print('连接超时: ${NetworkConfig.instance.connectTimeout}ms');
  print('接收超时: ${NetworkConfig.instance.receiveTimeout}ms');
  print('发送超时: ${NetworkConfig.instance.sendTimeout}ms');
  print('缓存启用: ${NetworkConfig.instance.enableCache}');
  print('指数退避: ${NetworkConfig.instance.enableExponentialBackoff}\n');
  
  // 示例5: 使用重负载预设
  print('--- 重负载配置 ---');
  NetworkConfig.instance.initializeFromPreset('heavyLoad');
  print('连接超时: ${NetworkConfig.instance.connectTimeout}ms');
  print('接收超时: ${NetworkConfig.instance.receiveTimeout}ms');
  print('发送超时: ${NetworkConfig.instance.sendTimeout}ms');
  print('最大重试: ${NetworkConfig.instance.maxRetries}次');
  print('指数退避: ${NetworkConfig.instance.enableExponentialBackoff}\n');
  
  // 示例6: 使用离线优先预设
  print('--- 离线优先配置 ---');
  NetworkConfig.instance.initializeFromPreset('offlineFirst');
  print('连接超时: ${NetworkConfig.instance.connectTimeout}ms');
  print('缓存启用: ${NetworkConfig.instance.enableCache}');
  print('缓存时长: ${NetworkConfig.instance.defaultCacheDuration}秒');
  print('最大重试: ${NetworkConfig.instance.maxRetries}次\n');
  
  // 示例7: 使用低带宽预设
  print('--- 低带宽配置 ---');
  NetworkConfig.instance.initializeFromPreset('lowBandwidth');
  print('连接超时: ${NetworkConfig.instance.connectTimeout}ms');
  print('接收超时: ${NetworkConfig.instance.receiveTimeout}ms');
  print('发送超时: ${NetworkConfig.instance.sendTimeout}ms');
  print('缓存启用: ${NetworkConfig.instance.enableCache}');
  print('缓存时长: ${NetworkConfig.instance.defaultCacheDuration}秒\n');
  
  // 示例8: 自定义配置基于预设
  print('--- 自定义配置（基于生产环境预设）---');
  final customConfig = NetworkConfigPresets.getPreset('production')!;
  customConfig['baseUrl'] = 'https://my-custom-api.com';
  customConfig['connectTimeout'] = 20000; // 20秒
  customConfig['enableLogging'] = true; // 启用日志 / Enable logging
  
  NetworkConfig.instance.initialize(
    baseUrl: customConfig['baseUrl'],
    connectTimeout: customConfig['connectTimeout'],
    receiveTimeout: customConfig['receiveTimeout'],
    sendTimeout: customConfig['sendTimeout'],
    maxRetries: customConfig['maxRetries'],
    retryDelay: customConfig['retryDelay'],
    enableLogging: customConfig['enableLogging'],
    logLevel: LogLevel.values.firstWhere(
      (level) => level.toString().split('.').last == customConfig['logLevel'],
      orElse: () => LogLevel.info,
    ),
    enableCache: customConfig['enableCache'],
    defaultCacheDuration: customConfig['defaultCacheDuration'],
    environment: Environment.values.firstWhere(
      (env) => env.toString().split('.').last == customConfig['environment'],
      orElse: () => Environment.production,
    ),
    enableExponentialBackoff: customConfig['enableExponentialBackoff'],
  );
  
  print('自定义Base URL: ${NetworkConfig.instance.baseUrl}');
  print('自定义连接超时: ${NetworkConfig.instance.connectTimeout}ms');
  print('自定义日志启用: ${NetworkConfig.instance.enableLogging}\n');
  
  // 示例9: 指数退避重试延迟计算
  print('--- 指数退避重试延迟计算 ---');
  NetworkConfig.instance.updateExponentialBackoff(true);
  for (int attempt = 0; attempt < 4; attempt++) {
    final delay = NetworkConfig.instance.calculateRetryDelay(attempt);
    print('第${attempt + 1}次重试延迟: ${delay}ms');
  }
  
  print('\n=== 配置预设示例完成 ===');
}