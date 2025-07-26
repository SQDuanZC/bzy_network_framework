import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 插件化拦截器管理器
/// 支持拦截器的动态注册、管理、执行顺序控制
class InterceptorManager {
  static InterceptorManager? _instance;
  
  // 拦截器注册表
  final Map<String, PluginInterceptor> _interceptors = {};
  
  // 拦截器执行顺序
  final List<String> _executionOrder = [];
  
  // 拦截器配置
  final Map<String, InterceptorConfig> _configs = {};
  
  // 拦截器统计
  final InterceptorStatistics _statistics = InterceptorStatistics();
  
  // 私有构造函数
  InterceptorManager._();
  
  /// 获取单例实例
  static InterceptorManager get instance {
    _instance ??= InterceptorManager._();
    return _instance!;
  }
  
  /// 拦截器统计
  InterceptorStatistics get statistics => _statistics;
  
  /// 注册拦截器
  void registerInterceptor(
    String name,
    PluginInterceptor interceptor, {
    InterceptorConfig? config,
    int? priority,
  }) {
    if (_interceptors.containsKey(name)) {
      throw ArgumentError('拦截器 "$name" 已存在');
    }
    
    _interceptors[name] = interceptor;
    _configs[name] = config ?? InterceptorConfig();
    
    // 根据优先级插入执行顺序
    if (priority != null) {
      _insertByPriority(name, priority);
    } else {
      _executionOrder.add(name);
    }
    
    if (kDebugMode) {
      debugPrint('拦截器已注册: $name');
    }
  }
  
  /// 注销拦截器
  bool unregisterInterceptor(String name) {
    if (!_interceptors.containsKey(name)) {
      return false;
    }
    
    _interceptors.remove(name);
    _configs.remove(name);
    _executionOrder.remove(name);
    
    if (kDebugMode) {
      debugPrint('拦截器已注销: $name');
    }
    return true;
  }
  
  /// 启用拦截器
  bool enableInterceptor(String name) {
    final config = _configs[name];
    if (config != null) {
      config.enabled = true;
      if (kDebugMode) {
        debugPrint('拦截器已启用: $name');
      }
      return true;
    }
    return false;
  }
  
  /// 禁用拦截器
  bool disableInterceptor(String name) {
    final config = _configs[name];
    if (config != null) {
      config.enabled = false;
      if (kDebugMode) {
        debugPrint('拦截器已禁用: $name');
      }
      return true;
    }
    return false;
  }
  
  /// 更新拦截器配置
  bool updateInterceptorConfig(String name, InterceptorConfig config) {
    if (_configs.containsKey(name)) {
      _configs[name] = config;
      return true;
    }
    return false;
  }
  
  /// 设置拦截器执行顺序
  void setExecutionOrder(List<String> order) {
    // 验证所有拦截器都已注册
    for (final name in order) {
      if (!_interceptors.containsKey(name)) {
        throw ArgumentError('拦截器 "$name" 未注册');
      }
    }
    
    _executionOrder.clear();
    _executionOrder.addAll(order);
  }
  
  /// 获取拦截器列表
  List<String> getInterceptorNames() {
    return List.from(_executionOrder);
  }
  
  /// 获取已启用的拦截器列表
  List<String> getEnabledInterceptors() {
    return _executionOrder.where((name) {
      final config = _configs[name];
      return config?.enabled ?? false;
    }).toList();
  }
  
  /// 执行请求拦截
  Future<RequestOptions> interceptRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    var currentOptions = options;
    
    for (final name in _executionOrder) {
      final interceptor = _interceptors[name];
      final config = _configs[name];
      
      if (interceptor == null || config == null || !config.enabled) {
        continue;
      }
      
      final startTime = DateTime.now();
      try {
        // 检查拦截器是否支持请求拦截
        if (interceptor.supportsRequestInterception) {
          currentOptions = await _executeWithTimeout(
            () => interceptor.onRequest(currentOptions, handler),
            config.timeout,
            '请求拦截器 "$name" 超时',
          );
        }
        
        final duration = DateTime.now().difference(startTime);
        _statistics.recordExecution(name, InterceptorType.request, duration, true);
        
      } catch (e) {
        final duration = DateTime.now().difference(startTime);
        _statistics.recordExecution(name, InterceptorType.request, duration, false);
        
        if (config.continueOnError) {
          if (kDebugMode) {
            debugPrint('请求拦截器 "$name" 执行失败，继续执行: $e');
          }
          continue;
        } else {
          if (kDebugMode) {
            debugPrint('请求拦截器 "$name" 执行失败，中断执行: $e');
          }
          rethrow;
        }
      }
    }
    
    return currentOptions;
  }
  
  /// 执行响应拦截
  Future<Response> interceptResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    var currentResponse = response;
    
    // 响应拦截器按相反顺序执行
    for (final name in _executionOrder.reversed) {
      final interceptor = _interceptors[name];
      final config = _configs[name];
      
      if (interceptor == null || config == null || !config.enabled) {
        continue;
      }
      
      final startTime = DateTime.now();
      try {
        // 检查拦截器是否支持响应拦截
        if (interceptor.supportsResponseInterception) {
          currentResponse = await _executeWithTimeout(
            () => interceptor.onResponse(currentResponse, handler),
            config.timeout,
            '响应拦截器 "$name" 超时',
          );
        }
        
        final duration = DateTime.now().difference(startTime);
        _statistics.recordExecution(name, InterceptorType.response, duration, true);
        
      } catch (e) {
        final duration = DateTime.now().difference(startTime);
        _statistics.recordExecution(name, InterceptorType.response, duration, false);
        
        if (config.continueOnError) {
          if (kDebugMode) {
            debugPrint('响应拦截器 "$name" 执行失败，继续执行: $e');
          }
          continue;
        } else {
          if (kDebugMode) {
            debugPrint('响应拦截器 "$name" 执行失败，中断执行: $e');
          }
          rethrow;
        }
      }
    }
    
    return currentResponse;
  }
  
  /// 执行错误拦截
  Future<void> interceptError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    var currentError = err;
    
    for (final name in _executionOrder) {
      final interceptor = _interceptors[name];
      final config = _configs[name];
      
      if (interceptor == null || config == null || !config.enabled) {
        continue;
      }
      
      final startTime = DateTime.now();
      try {
        // 检查拦截器是否支持错误拦截
        if (interceptor.supportsErrorInterception) {
          await _executeWithTimeout(
            () => interceptor.onError(currentError, handler),
            config.timeout,
            '错误拦截器 "$name" 超时',
          );
        }
        
        final duration = DateTime.now().difference(startTime);
        _statistics.recordExecution(name, InterceptorType.error, duration, true);
        
      } catch (e) {
        final duration = DateTime.now().difference(startTime);
        _statistics.recordExecution(name, InterceptorType.error, duration, false);
        
        if (config.continueOnError) {
          if (kDebugMode) {
            debugPrint('错误拦截器 "$name" 执行失败，继续执行: $e');
          }
          continue;
        } else {
          if (kDebugMode) {
            debugPrint('错误拦截器 "$name" 执行失败，中断执行: $e');
          }
          // 对于错误拦截器，即使失败也不重新抛出异常
          continue;
        }
      }
    }
  }
  
  /// 根据优先级插入拦截器
  void _insertByPriority(String name, int priority) {
    // 找到合适的插入位置
    int insertIndex = _executionOrder.length;
    
    for (int i = 0; i < _executionOrder.length; i++) {
      final existingName = _executionOrder[i];
      final existingConfig = _configs[existingName];
      
      if (existingConfig != null && priority > existingConfig.priority) {
        insertIndex = i;
        break;
      }
    }
    
    _executionOrder.insert(insertIndex, name);
    _configs[name]!.priority = priority;
  }
  
  /// 带超时的执行
  Future<T> _executeWithTimeout<T>(
    Future<T> Function() function,
    Duration timeout,
    String timeoutMessage,
  ) async {
    return await function().timeout(
      timeout,
      onTimeout: () => throw TimeoutException(timeoutMessage, timeout),
    );
  }
  
  /// 获取拦截器状态
  Map<String, dynamic> getInterceptorStatus() {
    final status = <String, dynamic>{};
    
    for (final name in _executionOrder) {
      final config = _configs[name];
      final interceptor = _interceptors[name];
      
      status[name] = {
        'enabled': config?.enabled ?? false,
        'priority': config?.priority ?? 0,
        'timeout': config?.timeout.inMilliseconds ?? 0,
        'continueOnError': config?.continueOnError ?? false,
        'supportsRequest': interceptor?.supportsRequestInterception ?? false,
        'supportsResponse': interceptor?.supportsResponseInterception ?? false,
        'supportsError': interceptor?.supportsErrorInterception ?? false,
      };
    }
    
    return {
      'interceptors': status,
      'executionOrder': _executionOrder,
      'statistics': _statistics.toMap(),
    };
  }
  
  /// 清空所有拦截器
  void clear() {
    _interceptors.clear();
    _configs.clear();
    _executionOrder.clear();
    _statistics.reset();
  }
}

/// 插件拦截器基类
abstract class PluginInterceptor {
  /// 拦截器名称
  String get name;
  
  /// 拦截器版本
  String get version;
  
  /// 拦截器描述
  String get description;
  
  /// 是否支持请求拦截
  bool get supportsRequestInterception => false;
  
  /// 是否支持响应拦截
  bool get supportsResponseInterception => false;
  
  /// 是否支持错误拦截
  bool get supportsErrorInterception => false;
  
  /// 请求拦截
  Future<RequestOptions> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    return options;
  }
  
  /// 响应拦截
  Future<Response> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    return response;
  }
  
  /// 错误拦截
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // 默认不处理错误
  }
  
  /// 初始化拦截器
  Future<void> initialize() async {
    // 默认不需要初始化
  }
  
  /// 销毁拦截器
  Future<void> dispose() async {
    // 默认不需要清理
  }
}

/// 拦截器配置
class InterceptorConfig {
  /// 是否启用
  bool enabled;
  
  /// 优先级（数值越大优先级越高）
  int priority;
  
  /// 超时时间
  Duration timeout;
  
  /// 出错时是否继续执行后续拦截器
  bool continueOnError;
  
  /// 自定义配置
  Map<String, dynamic> customConfig;
  
  InterceptorConfig({
    this.enabled = true,
    this.priority = 0,
    this.timeout = const Duration(seconds: 10),
    this.continueOnError = true,
    this.customConfig = const {},
  });
}

/// 拦截器类型
enum InterceptorType {
  request,
  response,
  error,
}

/// 拦截器统计
class InterceptorStatistics {
  final Map<String, Map<InterceptorType, InterceptorMetrics>> _metrics = {};
  
  /// 记录执行
  void recordExecution(
    String interceptorName,
    InterceptorType type,
    Duration duration,
    bool success,
  ) {
    _metrics.putIfAbsent(interceptorName, () => {
      InterceptorType.request: InterceptorMetrics(),
      InterceptorType.response: InterceptorMetrics(),
      InterceptorType.error: InterceptorMetrics(),
    });
    
    final metrics = _metrics[interceptorName]![type]!;
    metrics.totalExecutions++;
    metrics.totalDuration += duration;
    
    if (success) {
      metrics.successfulExecutions++;
    } else {
      metrics.failedExecutions++;
    }
  }
  
  /// 获取拦截器指标
  InterceptorMetrics? getMetrics(String interceptorName, InterceptorType type) {
    return _metrics[interceptorName]?[type];
  }
  
  /// 获取所有指标
  Map<String, Map<String, Map<String, dynamic>>> getAllMetrics() {
    final result = <String, Map<String, Map<String, dynamic>>>{};
    
    for (final entry in _metrics.entries) {
      final interceptorName = entry.key;
      final typeMetrics = entry.value;
      
      result[interceptorName] = {};
      
      for (final typeEntry in typeMetrics.entries) {
        final type = typeEntry.key;
        final metrics = typeEntry.value;
        
        result[interceptorName]![type.name] = metrics.toMap();
      }
    }
    
    return result;
  }
  
  /// 重置统计
  void reset() {
    _metrics.clear();
  }
  
  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'metrics': getAllMetrics(),
      'totalInterceptors': _metrics.length,
    };
  }
}

/// 拦截器指标
class InterceptorMetrics {
  int totalExecutions = 0;
  int successfulExecutions = 0;
  int failedExecutions = 0;
  Duration totalDuration = Duration.zero;
  
  /// 平均执行时间
  Duration get averageDuration {
    return totalExecutions > 0
        ? Duration(milliseconds: totalDuration.inMilliseconds ~/ totalExecutions)
        : Duration.zero;
  }
  
  /// 成功率
  double get successRate {
    return totalExecutions > 0 ? successfulExecutions / totalExecutions : 0.0;
  }
  
  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'totalExecutions': totalExecutions,
      'successfulExecutions': successfulExecutions,
      'failedExecutions': failedExecutions,
      'averageDuration': averageDuration.inMilliseconds,
      'successRate': successRate,
    };
  }
}

/// 内置拦截器工厂
class BuiltInInterceptors {
  /// 创建缓存拦截器
  static CacheInterceptor createCacheInterceptor() {
    return CacheInterceptor();
  }
  
  /// 创建认证拦截器
  static AuthInterceptor createAuthInterceptor() {
    return AuthInterceptor();
  }
  
  /// 创建日志拦截器
  static LoggingInterceptor createLoggingInterceptor() {
    return LoggingInterceptor();
  }
  
  /// 创建重试拦截器
  static RetryInterceptor createRetryInterceptor() {
    return RetryInterceptor();
  }
  
  /// 创建性能监控拦截器
  static PerformanceInterceptor createPerformanceInterceptor() {
    return PerformanceInterceptor();
  }
}

/// 缓存拦截器
class CacheInterceptor extends PluginInterceptor {
  @override
  String get name => 'cache';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => '缓存拦截器';
  
  @override
  bool get supportsRequestInterception => true;
  
  @override
  bool get supportsResponseInterception => true;
  
  @override
  Future<RequestOptions> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 检查缓存逻辑
    if (kDebugMode) {
      debugPrint('缓存拦截器: 检查请求缓存');
    }
    return options;
  }
  
  @override
  Future<Response> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    // 保存缓存逻辑
    if (kDebugMode) {
      debugPrint('缓存拦截器: 保存响应缓存');
    }
    return response;
  }
}

/// 认证拦截器
class AuthInterceptor extends PluginInterceptor {
  @override
  String get name => 'auth';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => '认证拦截器';
  
  @override
  bool get supportsRequestInterception => true;
  
  @override
  bool get supportsErrorInterception => true;
  
  @override
  Future<RequestOptions> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 添加认证头
    if (kDebugMode) {
      debugPrint('认证拦截器: 添加认证信息');
    }
    return options;
  }
  
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // 处理认证错误
    if (kDebugMode) {
      debugPrint('认证拦截器: 处理认证错误');
    }
  }
}

/// 日志拦截器
class LoggingInterceptor extends PluginInterceptor {
  @override
  String get name => 'logging';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => '日志拦截器';
  
  @override
  bool get supportsRequestInterception => true;
  
  @override
  bool get supportsResponseInterception => true;
  
  @override
  bool get supportsErrorInterception => true;
  
  @override
  Future<RequestOptions> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (kDebugMode) {
      debugPrint('日志拦截器: 记录请求 ${options.method} ${options.uri}');
    }
    return options;
  }
  
  @override
  Future<Response> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    if (kDebugMode) {
      debugPrint('日志拦截器: 记录响应 ${response.statusCode}');
    }
    return response;
  }
  
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (kDebugMode) {
      debugPrint('日志拦截器: 记录错误 ${err.message}');
    }
  }
}

/// 重试拦截器
class RetryInterceptor extends PluginInterceptor {
  @override
  String get name => 'retry';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => '重试拦截器';
  
  @override
  bool get supportsErrorInterception => true;
  
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // 重试逻辑
    if (kDebugMode) {
      debugPrint('重试拦截器: 处理重试');
    }
  }
}

/// 性能监控拦截器
class PerformanceInterceptor extends PluginInterceptor {
  @override
  String get name => 'performance';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => '性能监控拦截器';
  
  @override
  bool get supportsRequestInterception => true;
  
  @override
  bool get supportsResponseInterception => true;
  
  @override
  Future<RequestOptions> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 记录请求开始时间
    options.extra['startTime'] = DateTime.now();
    return options;
  }
  
  @override
  Future<Response> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    // 计算请求耗时
    final startTime = response.requestOptions.extra['startTime'] as DateTime?;
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      // 可以在这里记录性能数据或发送到监控系统
      // 性能监控: 请求耗时 ${duration.inMilliseconds}ms
      // 使用duration变量避免警告
      response.extra['duration'] = duration.inMilliseconds;
    }
    return response;
  }
}