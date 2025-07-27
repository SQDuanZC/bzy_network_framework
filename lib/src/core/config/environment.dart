/// 环境枚举
enum Environment {
  /// 开发环境
  development,
  
  /// 测试环境
  testing,
  
  /// 预发布环境
  staging,
  
  /// 生产环境
  production,
}

/// 环境扩展方法
extension EnvironmentExtension on Environment {
  /// 环境名称
  String get name {
    switch (this) {
      case Environment.development:
        return 'development';
      case Environment.testing:
        return 'testing';
      case Environment.staging:
        return 'staging';
      case Environment.production:
        return 'production';
    }
  }
  
  /// 是否为开发环境
  bool get isDevelopment => this == Environment.development;
  
  /// 是否为测试环境
  bool get isTesting => this == Environment.testing;
  
  /// 是否为预发布环境
  bool get isStaging => this == Environment.staging;
  
  /// 是否为生产环境
  bool get isProduction => this == Environment.production;
  
  /// 是否为调试环境（开发或测试）
  bool get isDebug => isDevelopment || isTesting;
  
  /// 是否为发布环境（预发布或生产）
  bool get isRelease => isStaging || isProduction;
}