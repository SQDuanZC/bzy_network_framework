/// 演示如何使用 NetworkConfigPreset 枚举的简化示例
/// 这是一个纯 Dart 示例，不依赖 Flutter

// 直接导入网络配置文件
import '../../lib/src/config/network_config.dart';

void main() {
  print('=== NetworkConfigPreset 枚举使用示例 ===');
  print('');
  
  // 1. 获取所有可用的预设枚举
  print('1. 所有可用预设:');
  final allPresets = NetworkConfigPreset.values;
  for (final preset in allPresets) {
    print('   - ${preset.name}: ${preset.value}');
  }
  print('');
  
  // 2. 通过枚举获取配置
  print('2. 通过枚举获取配置:');
  final devConfig = NetworkConfigPreset.development.getConfig();
  print('   开发环境配置: $devConfig');
  print('');
  
  // 3. 字符串转枚举
  print('3. 字符串转枚举:');
  final preset1 = NetworkConfigPreset.fromString('production');
  print('   production 预设: $preset1');
  
  final preset2 = NetworkConfigPreset.fromString('invalid');
  print('   无效预设: $preset2');
  print('');
  
  // 4. 枚举比较
  print('4. 枚举比较:');
  final dev1 = NetworkConfigPreset.development;
  final dev2 = NetworkConfigPreset.fromString('development');
  print('   development == development: ${dev1 == dev2}');
  print('');
  
  // 5. 获取特定预设的配置
  print('5. 获取特定预设配置:');
  final prodConfig = NetworkConfigPreset.production.getConfig();
  print('   生产环境 baseUrl: ${prodConfig?['baseUrl']}');
  print('   生产环境 timeout: ${prodConfig?['connectTimeout']}');
  print('');
  
  print('=== 示例完成 ===');
}

/// 配置管理器示例
class SimpleConfigManager {
  /// 使用枚举设置配置
  static void configureForEnvironment(NetworkConfigPreset preset) {
    final config = preset.getConfig();
    if (config != null) {
      print('配置环境: ${preset.name}');
      print('Base URL: ${config['baseUrl']}');
      print('超时时间: ${config['connectTimeout']}ms');
    }
  }
  
  /// 获取所有环境名称
  static List<String> getAllEnvironmentNames() {
    return NetworkConfigPreset.values.map((preset) => preset.name).toList();
  }
}