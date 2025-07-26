import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

/// 网络框架统一日志管理器
/// 
/// 提供统一的日志接口，支持不同级别的日志输出
/// 可以配置日志输出目标（控制台、文件等）
class NetworkLogger {
  static final Map<String, Logger> _loggers = {};
  static bool _isConfigured = false;
  
  /// 获取指定名称的日志器
  static Logger getLogger(String name) {
    return _loggers.putIfAbsent(name, () => Logger(name));
  }
  
  /// 配置日志系统
  /// 
  /// [level] 日志级别
  /// [enableConsoleOutput] 是否启用控制台输出
  /// [enableFileOutput] 是否启用文件输出
  /// [logFilePath] 日志文件路径
  static void configure({
    Level level = Level.INFO,
    bool enableConsoleOutput = true,
    bool enableFileOutput = false,
    String? logFilePath,
  }) {
    if (_isConfigured) return;
    
    Logger.root.level = level;
    
    if (enableConsoleOutput) {
      Logger.root.onRecord.listen((record) {
        final time = record.time.toString().substring(11, 23);
        final level = record.level.name.padRight(7);
        final logger = record.loggerName.padRight(20);
        if (kDebugMode) {
          debugPrint('[$time] $level [$logger] ${record.message}');
          
          if (record.error != null) {
            debugPrint('Error: ${record.error}');
          }
          if (record.stackTrace != null) {
            debugPrint('StackTrace: ${record.stackTrace}');
          }
        }
      });
    }
    
    _isConfigured = true;
  }
  
  /// 获取框架日志器
  static Logger get framework => getLogger('NetworkFramework');
  
  /// 获取执行器日志器
  static Logger get executor => getLogger('NetworkExecutor');
  
  /// 获取缓存日志器
  static Logger get cache => getLogger('CacheManager');
  
  /// 获取队列日志器
  static Logger get queue => getLogger('RequestQueue');
  
  /// 获取拦截器日志器
  static Logger get interceptor => getLogger('Interceptor');
  
  /// 获取通用日志器
  static Logger get general => getLogger('General');
  
  /// 重置日志配置
  static void reset() {
    _isConfigured = false;
    _loggers.clear();
  }
}