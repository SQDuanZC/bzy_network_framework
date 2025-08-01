import '../../lib/bzy_network_framework.dart';

/// 演示如何使用 ConfigPreset 枚举 / Demonstrates how to use ConfigPreset enum
void main() {
  print('=== 网络配置预设枚举示例 / Network Configuration Preset Enum Example ===\n');
  
  // 1. 使用枚举获取所有可用预设 / Use enum to get all available presets
  print('1. 获取所有可用预设（枚举方式） / Get all available presets (enum way):');
  final presetEnums = NetworkConfigPreset.values;
  for (final preset in presetEnums) {
    print('   - ${preset.name}');
  }
  print('');
  
  // 2. 使用枚举获取配置 / Use enum to get configuration
  print('2. 使用枚举获取配置 / Use enum to get configuration:');
  final devConfig = NetworkConfigPreset.development.getConfig();
  print('   开发环境配置 / Development environment config: $devConfig');
  print('');
  
  // 3. 通过枚举的getConfig方法获取配置 / Get configuration through enum's getConfig method
  print('3. 通过枚举方法获取配置 / Get configuration through enum method:');
  final prodConfig = NetworkConfigPreset.production.getConfig();
  print('   生产环境配置 / Production environment config: $prodConfig');
  print('');
  
  // 4. 字符串转枚举 / String to enum
  print('4. 字符串转枚举 / String to enum:');
  final presetFromString = NetworkConfigPreset.fromString('fast_response');
  if (presetFromString != null) {
    print('   找到预设 / Found preset: ${presetFromString.name}');
    final config = presetFromString.getConfig();
    print('   配置 / Configuration: $config');
  }
  print('');
  
  // 5. 支持不同格式的字符串 / Support different string formats
  print('5. 支持不同格式的字符串 / Support different string formats:');
  final variations = ['heavy_load', 'heavyload', 'HEAVY_LOAD', 'HeavyLoad'];
  for (final variation in variations) {
    final preset = NetworkConfigPreset.fromString(variation);
    if (preset != null) {
      print('   "$variation" -> ${preset.name}');
    }
  }
  print('');
  
  // 6. 枚举值比较 / Enum value comparison
  print('6. 枚举值比较 / Enum value comparison:');
  final preset1 = NetworkConfigPreset.development;
  final preset2 = NetworkConfigPreset.fromString('development');
  print('   preset1 == preset2: ${preset1 == preset2}');
  print('');
  
  // 7. 错误处理 / Error handling
  print('7. 错误处理 / Error handling:');
  final invalidPreset = NetworkConfigPreset.fromString('invalid_preset');
  print('   无效预设 / Invalid preset: $invalidPreset');
   print('');
  
  print('=== 示例完成 / Example completed ===');
}

/// 实际使用场景示例 / Practical usage scenario example
class NetworkConfigurationManager {
  /// 使用枚举设置配置 / Configure using enum
  static void configureForEnvironment(NetworkConfigPreset preset) {
    final config = preset.getConfig();
    if (config != null) {
      print('正在应用 ${preset.name} 环境配置... / Applying ${preset.name} environment configuration...');
      // 这里可以应用配置到实际的网络客户端 / Here you can apply configuration to actual network client
      // NetworkConfig.instance.configure(config);
    }
  }
  

  
  /// 获取所有可用环境 / Get all available environments
  static List<String> getAvailableEnvironments() {
    return NetworkConfigPreset.values
        .map((preset) => preset.name)
        .toList();
  }
}