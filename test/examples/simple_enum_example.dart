/// Demonstrates how to use NetworkConfigPreset enum with simplified examples
/// This is a pure Dart example that does not depend on Flutter

// 直接导入网络配置文件
import '../../lib/src/config/network_config.dart';

void main() {
  print('=== NetworkConfigPreset Enum Usage Examples ===');
  print('');
  
  // 1. Get all available preset enums
  print('1. All available presets:');
  final allPresets = NetworkConfigPreset.values;
  for (final preset in allPresets) {
    print('   - ${preset.name}: ${preset.value}');
  }
  print('');
  
  // 2. Get configuration through enum
  print('2. Get configuration through enum:');
  final devConfig = NetworkConfigPreset.development.getConfig();
  print('   开发环境配置: $devConfig');
  print('');
  
  // 3. String to enum conversion
  print('3. String to enum conversion:');
  final preset1 = NetworkConfigPreset.fromString('production');
  print('   production 预设: $preset1');
  
  final preset2 = NetworkConfigPreset.fromString('invalid');
  print('   无效预设: $preset2');
  print('');
  
  // 4. Enum comparison
  print('4. Enum comparison:');
  final dev1 = NetworkConfigPreset.development;
  final dev2 = NetworkConfigPreset.fromString('development');
  print('   development == development: ${dev1 == dev2}');
  print('');
  
  // 5. Get configuration for specific preset
  print('5. Get configuration for specific preset:');
  final prodConfig = NetworkConfigPreset.production.getConfig();
  print('   生产环境 baseUrl: ${prodConfig?['baseUrl']}');
  print('   生产环境 timeout: ${prodConfig?['connectTimeout']}');
  print('');
  
  print('=== Examples Complete ===');
}

/// Configuration manager example
class SimpleConfigManager {
  /// Configure using enum
  static void configureForEnvironment(NetworkConfigPreset preset) {
    final config = preset.getConfig();
    if (config != null) {
      print('Configuring environment: ${preset.name}');
      print('Base URL: ${config['baseUrl']}');
      print('Timeout: ${config['connectTimeout']}ms');
    }
  }
  
  /// Get all environment names
  static List<String> getAllEnvironmentNames() {
    return NetworkConfigPreset.values.map((preset) => preset.name).toList();
  }
}