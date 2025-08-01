import 'network_config.dart';
import '../cache/cache_manager.dart';
import '../../utils/network_logger.dart';

// =============================================================================
// 配置验证器
// =============================================================================

/// 配置验证结果
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  
  ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });
  
  /// 创建成功的验证结果
  factory ValidationResult.success({List<String> warnings = const []}) {
    return ValidationResult(
      isValid: true,
      warnings: warnings,
    );
  }
  
  /// 创建失败的验证结果
  factory ValidationResult.failure(List<String> errors, {List<String> warnings = const []}) {
    return ValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings,
    );
  }
  
  /// 是否有警告
  bool get hasWarnings => warnings.isNotEmpty;
  
  /// 获取所有问题（错误+警告）
  List<String> get allIssues => [...errors, ...warnings];
  
  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('ValidationResult(isValid: $isValid)');
    
    if (errors.isNotEmpty) {
      buffer.writeln('Errors:');
      for (final error in errors) {
        buffer.writeln('  - $error');
      }
    }
    
    if (warnings.isNotEmpty) {
      buffer.writeln('Warnings:');
      for (final warning in warnings) {
        buffer.writeln('  - $warning');
      }
    }
    
    return buffer.toString();
  }
}

/// 配置验证器基类
abstract class ConfigValidator<T> {
  /// 验证配置
  ValidationResult validate(T config);
  
  /// 验证并抛出异常（如果验证失败）
  void validateAndThrow(T config) {
    final result = validate(config);
    if (!result.isValid) {
      throw ConfigValidationException(
        'Configuration validation failed',
        errors: result.errors,
        warnings: result.warnings,
      );
    }
  }
}

/// 网络配置验证器
class NetworkConfigValidator extends ConfigValidator<NetworkConfig> {
  @override
  ValidationResult validate(NetworkConfig config) {
    final errors = <String>[];
    final warnings = <String>[];
    
    // 验证基础URL
    if (config.baseUrl.isEmpty) {
      errors.add('Base URL cannot be empty');
    } else {
      try {
        final uri = Uri.parse(config.baseUrl);
        if (!uri.hasScheme) {
          errors.add('Base URL must include scheme (http/https)');
        } else if (!['http', 'https'].contains(uri.scheme.toLowerCase())) {
          errors.add('Base URL scheme must be http or https');
        }
        
        if (!uri.hasAuthority) {
          errors.add('Base URL must include host');
        }
      } catch (e) {
        errors.add('Invalid base URL format: ${config.baseUrl}');
      }
    }
    
    // 验证超时设置
    if (config.connectTimeout <= 0) {
      errors.add('Connect timeout must be positive');
    } else if (config.connectTimeout < 1000) {
      warnings.add('Connect timeout is very short (${config.connectTimeout}ms), consider increasing it');
    } else if (config.connectTimeout > 60000) {
      warnings.add('Connect timeout is very long (${config.connectTimeout}ms), consider reducing it');
    }
    
    if (config.receiveTimeout <= 0) {
      errors.add('Receive timeout must be positive');
    } else if (config.receiveTimeout < 1000) {
      warnings.add('Receive timeout is very short (${config.receiveTimeout}ms), consider increasing it');
    } else if (config.receiveTimeout > 300000) {
      warnings.add('Receive timeout is very long (${config.receiveTimeout}ms), consider reducing it');
    }
    
    if (config.sendTimeout <= 0) {
      errors.add('Send timeout must be positive');
    } else if (config.sendTimeout < 1000) {
      warnings.add('Send timeout is very short (${config.sendTimeout}ms), consider increasing it');
    } else if (config.sendTimeout > 300000) {
      warnings.add('Send timeout is very long (${config.sendTimeout}ms), consider reducing it');
    }
    
    // 验证超时关系
    if (config.connectTimeout > config.receiveTimeout) {
      warnings.add('Connect timeout should not be longer than receive timeout');
    }
    
    // 验证缓存设置
    if (config.enableCache) {
      if (config.cacheMaxAge <= 0) {
        errors.add('Cache max age must be positive when cache is enabled');
      } else if (config.cacheMaxAge < 60) {
        warnings.add('Cache max age is very short (${config.cacheMaxAge}s), consider increasing it');
      } else if (config.cacheMaxAge > 86400) {
        warnings.add('Cache max age is very long (${config.cacheMaxAge}s), consider reducing it');
      }
    }
    
    // 验证重试设置
    if (config.maxRetryCount < 0) {
      errors.add('Max retries cannot be negative');
    } else if (config.maxRetryCount > 5) {
      warnings.add('Max retries is high (${config.maxRetryCount}), consider reducing it');
    }
    
    if (config.retryDelay <= 0) {
      errors.add('Retry delay must be positive');
    } else if (config.retryDelay < 100) {
      warnings.add('Retry delay is very short (${config.retryDelay}ms)');
    } else if (config.retryDelay > 10000) {
      warnings.add('Retry delay is very long (${config.retryDelay}ms)');
    }
    
    // 验证指数退避设置
    if (config.enableExponentialBackoff && config.maxRetryCount > 0) {
      if (config.retryDelay < 500) {
        warnings.add('Initial retry delay is short for exponential backoff (${config.retryDelay}ms), consider increasing it');
      }
      
      // 计算最大延迟时间（假设指数因子为2）
      final maxDelay = config.calculateRetryDelay(config.maxRetryCount - 1);
      if (maxDelay > 30000) {
        warnings.add('Maximum retry delay with exponential backoff is very long (${maxDelay}ms)');
      }
    }
    
    return errors.isEmpty 
        ? ValidationResult.success(warnings: warnings)
        : ValidationResult.failure(errors, warnings: warnings);
  }
}

/// 缓存配置验证器
class CacheConfigValidator extends ConfigValidator<CacheConfig> {
  @override
  ValidationResult validate(CacheConfig config) {
    final errors = <String>[];
    final warnings = <String>[];
    
    // 验证内存缓存设置
    if (config.enableMemoryCache) {
      if (config.maxMemorySize <= 0) {
        errors.add('Memory cache size must be positive when enabled');
      } else if (config.maxMemorySize < 1024 * 1024) { // 1MB
        warnings.add('Memory cache size is very small (${_formatBytes(config.maxMemorySize)})');
      } else if (config.maxMemorySize > 100 * 1024 * 1024) { // 100MB
        warnings.add('Memory cache size is very large (${_formatBytes(config.maxMemorySize)})');
      }
    }
    
    // 验证磁盘缓存设置
    if (config.enableDiskCache) {
      if (config.maxDiskSize <= 0) {
        errors.add('Disk cache size must be positive when enabled');
      } else if (config.maxDiskSize < 10 * 1024 * 1024) { // 10MB
        warnings.add('Disk cache size is very small (${_formatBytes(config.maxDiskSize)})');
      } else if (config.maxDiskSize > 1024 * 1024 * 1024) { // 1GB
        warnings.add('Disk cache size is very large (${_formatBytes(config.maxDiskSize)})');
      }
    }
    
    // 验证缓存大小关系
    if (config.enableMemoryCache && config.enableDiskCache) {
      if (config.maxMemorySize >= config.maxDiskSize) {
        warnings.add('Memory cache size should be smaller than disk cache size');
      }
      
      final ratio = config.maxMemorySize / config.maxDiskSize;
      if (ratio > 0.5) {
        warnings.add('Memory cache is more than 50% of disk cache size, consider reducing it');
      }
    }
    
    // 验证默认过期时间
    if (config.defaultExpiry.inSeconds <= 0) {
      errors.add('Default expiry must be positive');
    } else if (config.defaultExpiry.inSeconds < 60) {
      warnings.add('Default expiry is very short (${config.defaultExpiry.inSeconds}s)');
    } else if (config.defaultExpiry.inDays > 30) {
      warnings.add('Default expiry is very long (${config.defaultExpiry.inDays} days)');
    }
    
    // 验证清理间隔
    if (config.cleanupInterval.inSeconds <= 0) {
      errors.add('Cleanup interval must be positive');
    } else if (config.cleanupInterval.inMinutes < 1) {
      warnings.add('Cleanup interval is very frequent (${config.cleanupInterval.inSeconds}s)');
    } else if (config.cleanupInterval.inHours > 24) {
      warnings.add('Cleanup interval is very infrequent (${config.cleanupInterval.inHours} hours)');
    }
    
    // 验证清理间隔与过期时间的关系
    if (config.cleanupInterval > config.defaultExpiry) {
      warnings.add('Cleanup interval is longer than default expiry, expired items may not be cleaned promptly');
    }
    
    // 验证缓存启用状态
    if (!config.enableMemoryCache && !config.enableDiskCache) {
      warnings.add('Both memory and disk cache are disabled, caching will not work');
    }
    
    return errors.isEmpty 
        ? ValidationResult.success(warnings: warnings)
        : ValidationResult.failure(errors, warnings: warnings);
  }
  
  /// 格式化字节大小
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

/// 组合配置验证器
class CompositeConfigValidator {
  final NetworkConfigValidator _networkValidator = NetworkConfigValidator();
  final CacheConfigValidator _cacheValidator = CacheConfigValidator();
  
  /// 验证网络配置和缓存配置的兼容性
  ValidationResult validateCompatibility(NetworkConfig networkConfig, CacheConfig cacheConfig) {
    final errors = <String>[];
    final warnings = <String>[];
    
    // 首先验证各自的配置
    final networkResult = _networkValidator.validate(networkConfig);
    final cacheResult = _cacheValidator.validate(cacheConfig);
    
    errors.addAll(networkResult.errors);
    errors.addAll(cacheResult.errors);
    warnings.addAll(networkResult.warnings);
    warnings.addAll(cacheResult.warnings);
    
    // 验证兼容性
    if (networkConfig.enableCache && !cacheConfig.enableMemoryCache && !cacheConfig.enableDiskCache) {
      errors.add('Network cache is enabled but both memory and disk cache are disabled');
    }
    
    if (!networkConfig.enableCache && (cacheConfig.enableMemoryCache || cacheConfig.enableDiskCache)) {
      warnings.add('Cache is configured but network cache is disabled');
    }
    
    // 验证缓存过期时间兼容性
    if (networkConfig.enableCache && cacheConfig.defaultExpiry.inSeconds < networkConfig.cacheMaxAge) {
      warnings.add('Cache default expiry (${cacheConfig.defaultExpiry.inSeconds}s) is shorter than network cache max age (${networkConfig.cacheMaxAge}s)');
    }
    
    return errors.isEmpty 
        ? ValidationResult.success(warnings: warnings)
        : ValidationResult.failure(errors, warnings: warnings);
  }
  
  /// 验证所有配置
  ValidationResult validateAll(NetworkConfig networkConfig, CacheConfig cacheConfig) {
    return validateCompatibility(networkConfig, cacheConfig);
  }
}

/// 配置验证异常
class ConfigValidationException implements Exception {
  final String message;
  final List<String> errors;
  final List<String> warnings;
  
  ConfigValidationException(
    this.message, {
    this.errors = const [],
    this.warnings = const [],
  });
  
  @override
  String toString() {
    final buffer = StringBuffer(message);
    
    if (errors.isNotEmpty) {
      buffer.writeln('\nErrors:');
      for (final error in errors) {
        buffer.writeln('  - $error');
      }
    }
    
    if (warnings.isNotEmpty) {
      buffer.writeln('\nWarnings:');
      for (final warning in warnings) {
        buffer.writeln('  - $warning');
      }
    }
    
    return buffer.toString();
  }
}

// =============================================================================
// 配置验证工具类
// =============================================================================

/// 配置验证工具
class ConfigValidationUtils {
  static final CompositeConfigValidator _validator = CompositeConfigValidator();
  
  /// 验证网络配置
  static ValidationResult validateNetworkConfig(NetworkConfig config) {
    return NetworkConfigValidator().validate(config);
  }
  
  /// 验证缓存配置
  static ValidationResult validateCacheConfig(CacheConfig config) {
    return CacheConfigValidator().validate(config);
  }
  
  /// 验证配置兼容性
  static ValidationResult validateCompatibility(NetworkConfig networkConfig, CacheConfig cacheConfig) {
    return _validator.validateCompatibility(networkConfig, cacheConfig);
  }
  
  /// 验证并初始化配置
  static Future<void> validateAndInitialize({
    NetworkConfig? networkConfig,
    CacheConfig? cacheConfig,
    bool throwOnError = true,
    bool logWarnings = true,
  }) async {
    networkConfig ??= NetworkConfig.instance;
    cacheConfig ??= CacheManager.instance.config;
    
    final result = _validator.validateAll(networkConfig, cacheConfig);
    
    // 记录警告
    if (logWarnings && result.hasWarnings) {
      for (final warning in result.warnings) {
        NetworkLogger.general.warning('Config Warning: $warning');
      }
    }
    
    // 处理错误
    if (!result.isValid) {
      for (final error in result.errors) {
        NetworkLogger.general.severe('Config Error: $error');
      }
      
      if (throwOnError) {
        throw ConfigValidationException(
          'Configuration validation failed',
          errors: result.errors,
          warnings: result.warnings,
        );
      }
    } else {
      // Configuration validation passed
    }
  }
  
  /// 生成配置报告
  static String generateConfigReport(NetworkConfig networkConfig, CacheConfig cacheConfig) {
    final buffer = StringBuffer();
    buffer.writeln('=== Configuration Report ===');
    buffer.writeln();
    
    // 网络配置
    buffer.writeln('Network Configuration:');
    buffer.writeln('  Base URL: ${networkConfig.baseUrl}');
    buffer.writeln('  Connect Timeout: ${networkConfig.connectTimeout}ms');
    buffer.writeln('  Receive Timeout: ${networkConfig.receiveTimeout}ms');
    buffer.writeln('  Send Timeout: ${networkConfig.sendTimeout}ms');
    buffer.writeln('  Enable Cache: ${networkConfig.enableCache}');
    buffer.writeln('  Cache Max Age: ${networkConfig.cacheMaxAge}s');
    buffer.writeln('  Max Retries: ${networkConfig.maxRetryCount}');
    buffer.writeln('  Retry Delay: ${networkConfig.retryDelay}ms');
    buffer.writeln('  Enable Logging: ${networkConfig.enableLogging}');
    buffer.writeln();
    
    // 缓存配置
    buffer.writeln('Cache Configuration:');
    buffer.writeln('  Memory Cache: ${cacheConfig.enableMemoryCache}');
    if (cacheConfig.enableMemoryCache) {
      buffer.writeln('    Max Size: ${_formatBytes(cacheConfig.maxMemorySize)}');
    }
    buffer.writeln('  Disk Cache: ${cacheConfig.enableDiskCache}');
    if (cacheConfig.enableDiskCache) {
      buffer.writeln('    Max Size: ${_formatBytes(cacheConfig.maxDiskSize)}');
    }
    buffer.writeln('  Default Expiry: ${cacheConfig.defaultExpiry.inSeconds}s');
    buffer.writeln('  Cleanup Interval: ${cacheConfig.cleanupInterval.inMinutes}min');
    buffer.writeln();
    
    // 验证结果
    final result = _validator.validateAll(networkConfig, cacheConfig);
    buffer.writeln('Validation Result:');
    buffer.writeln('  Status: ${result.isValid ? "✅ Valid" : "❌ Invalid"}');
    
    if (result.errors.isNotEmpty) {
      buffer.writeln('  Errors:');
      for (final error in result.errors) {
        buffer.writeln('    - $error');
      }
    }
    
    if (result.warnings.isNotEmpty) {
      buffer.writeln('  Warnings:');
      for (final warning in result.warnings) {
        buffer.writeln('    - $warning');
      }
    }
    
    return buffer.toString();
  }
  
  /// 格式化字节大小
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

// =============================================================================
// 配置建议器
// =============================================================================

/// 配置建议
class ConfigSuggestion {
  final String category;
  final String description;
  final String recommendation;
  final ConfigSuggestionPriority priority;
  
  ConfigSuggestion({
    required this.category,
    required this.description,
    required this.recommendation,
    required this.priority,
  });
  
  @override
  String toString() {
    final priorityIcon = priority == ConfigSuggestionPriority.high ? '🔴' 
                      : priority == ConfigSuggestionPriority.medium ? '🟡' 
                      : '🟢';
    return '$priorityIcon [$category] $description\n  💡 $recommendation';
  }
}

/// 配置建议优先级
enum ConfigSuggestionPriority {
  low,
  medium,
  high,
}

/// 配置建议器
class ConfigSuggestionEngine {
  /// 生成配置建议
  static List<ConfigSuggestion> generateSuggestions(NetworkConfig networkConfig, CacheConfig cacheConfig) {
    final suggestions = <ConfigSuggestion>[];
    
    // 性能优化建议
    _addPerformanceSuggestions(suggestions, networkConfig, cacheConfig);
    
    // 可靠性建议
    _addReliabilitySuggestions(suggestions, networkConfig, cacheConfig);
    
    // 资源使用建议
    _addResourceSuggestions(suggestions, networkConfig, cacheConfig);
    
    // 安全性建议
    _addSecuritySuggestions(suggestions, networkConfig, cacheConfig);
    
    return suggestions;
  }
  
  static void _addPerformanceSuggestions(List<ConfigSuggestion> suggestions, NetworkConfig networkConfig, CacheConfig cacheConfig) {
    // 缓存建议
    if (!networkConfig.enableCache) {
      suggestions.add(ConfigSuggestion(
        category: 'Performance',
        description: 'Network cache is disabled',
        recommendation: 'Enable cache to improve response times and reduce network usage',
        priority: ConfigSuggestionPriority.medium,
      ));
    }
    
    if (!cacheConfig.enableMemoryCache && cacheConfig.enableDiskCache) {
      suggestions.add(ConfigSuggestion(
        category: 'Performance',
        description: 'Only disk cache is enabled',
        recommendation: 'Enable memory cache for faster access to frequently used data',
        priority: ConfigSuggestionPriority.medium,
      ));
    }
    
    // 超时建议
    if (networkConfig.connectTimeout > 30000) {
      suggestions.add(ConfigSuggestion(
        category: 'Performance',
        description: 'Connect timeout is very long (${networkConfig.connectTimeout}ms)',
        recommendation: 'Consider reducing connect timeout to 10-15 seconds for better user experience',
        priority: ConfigSuggestionPriority.low,
      ));
    }
  }
  
  static void _addReliabilitySuggestions(List<ConfigSuggestion> suggestions, NetworkConfig networkConfig, CacheConfig cacheConfig) {
    // 重试建议
    if (networkConfig.maxRetryCount == 0) {
      suggestions.add(ConfigSuggestion(
        category: 'Reliability',
        description: 'No retry mechanism configured',
        recommendation: 'Enable retries (2-3 times) to handle temporary network issues',
        priority: ConfigSuggestionPriority.high,
      ));
    }
    
    if (networkConfig.maxRetryCount > 3) {
      suggestions.add(ConfigSuggestion(
        category: 'Reliability',
        description: 'Too many retries configured (${networkConfig.maxRetryCount})',
        recommendation: 'Reduce retries to 2-3 to avoid excessive delays',
        priority: ConfigSuggestionPriority.medium,
      ));
    }
  }
  
  static void _addResourceSuggestions(List<ConfigSuggestion> suggestions, NetworkConfig networkConfig, CacheConfig cacheConfig) {
    // 内存使用建议
    if (cacheConfig.enableMemoryCache && cacheConfig.maxMemorySize > 50 * 1024 * 1024) {
      suggestions.add(ConfigSuggestion(
        category: 'Resource',
        description: 'Memory cache size is large (${ConfigValidationUtils._formatBytes(cacheConfig.maxMemorySize)})',
        recommendation: 'Consider reducing memory cache size to 20-50MB to avoid memory pressure',
        priority: ConfigSuggestionPriority.medium,
      ));
    }
    
    // 磁盘使用建议
    if (cacheConfig.enableDiskCache && cacheConfig.maxDiskSize > 500 * 1024 * 1024) {
      suggestions.add(ConfigSuggestion(
        category: 'Resource',
        description: 'Disk cache size is very large (${ConfigValidationUtils._formatBytes(cacheConfig.maxDiskSize)})',
        recommendation: 'Consider reducing disk cache size to 100-500MB unless you have specific requirements',
        priority: ConfigSuggestionPriority.low,
      ));
    }
  }
  
  static void _addSecuritySuggestions(List<ConfigSuggestion> suggestions, NetworkConfig networkConfig, CacheConfig cacheConfig) {
    // HTTPS建议
    if (networkConfig.baseUrl.startsWith('http://')) {
      suggestions.add(ConfigSuggestion(
        category: 'Security',
        description: 'Using HTTP instead of HTTPS',
        recommendation: 'Use HTTPS for secure communication',
        priority: ConfigSuggestionPriority.high,
      ));
    }
    
    // 缓存安全建议
    if (cacheConfig.enableDiskCache) {
      suggestions.add(ConfigSuggestion(
        category: 'Security',
        description: 'Disk cache is enabled without encryption',
        recommendation: 'Consider enabling cache encryption for sensitive data',
        priority: ConfigSuggestionPriority.medium,
      ));
    }
  }
}