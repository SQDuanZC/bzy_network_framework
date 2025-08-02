import '../../lib/bzy_network_framework.dart';

/// 演示如何使用 ConfigPreset 枚举
void main() {
  print('=== 网络配置预设枚举示例 ===\n');
  
  // 1. 使用枚举获取所有可用预设
  print('1. 获取所有可用预设（枚举方式）:');
  final presetEnums = NetworkConfigPreset.values;
  for (final preset in presetEnums) {
    print('   - ${preset.name}');
  }
  print('');
  
  // 2. 使用枚举获取配置
  print('2. 使用枚举获取配置:');
  final devConfig = NetworkConfigPreset.development.getConfig();
  print('   开发环境配置: $devConfig');
  print('');
  
  // 3. 通过枚举的getConfig方法获取配置 / Get configuration through enum's getConfig method
  print('3. 通过枚举方法获取配置 / Get configuration through enum method:');
  final prodConfig = NetworkConfigPreset.production.getConfig();
  print('   生产环境配置 / Production environment config: $prodConfig');
  print('');
  
  // 4. 字符串转枚举
  print('4. 字符串转枚举:');
  final presetFromString = NetworkConfigPreset.fromString('fast_response');
  if (presetFromString != null) {
    print('   找到预设: ${presetFromString.name}');
    final config = presetFromString.getConfig();
    print('   配置: $config');
  }
  print('');
  
  // 5. 支持不同格式的字符串
  print('5. 支持不同格式的字符串:');
  final variations = ['heavy_load', 'heavyload', 'HEAVY_LOAD', 'HeavyLoad'];
  for (final variation in variations) {
    final preset = NetworkConfigPreset.fromString(variation);
    if (preset != null) {
      print('   "$variation" -> ${preset.name}');
    }
  }
  print('');
  
  // 6. 枚举值比较
  print('6. 枚举值比较:');
  final preset1 = NetworkConfigPreset.development;
  final preset2 = NetworkConfigPreset.fromString('development');
  print('   preset1 == preset2: ${preset1 == preset2}');
  print('');
  
  // 7. 错误处理
  print('7. 错误处理:');
  final invalidPreset = NetworkConfigPreset.fromString('invalid_preset');
  print('   无效预设: $invalidPreset');
   print('');
  
  print('=== 示例完成 ===');
}

/// 实际使用场景示例
class NetworkConfigurationManager {
  /// 使用枚举设置配置
  static void configureForEnvironment(NetworkConfigPreset preset) {
    final config = preset.getConfig();
    if (config != null) {
      print('正在应用 ${preset.name} 环境配置...');
      // 这里可以应用配置到实际的网络客户端
      // NetworkConfig.instance.configure(config);
    }
  }
  

  
  /// 获取所有可用环境
  static List<String> getAvailableEnvironments() {
    return NetworkConfigPreset.values
        .map((preset) => preset.name)
        .toList();
  }
}