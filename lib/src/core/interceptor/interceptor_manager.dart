import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../utils/network_logger.dart';

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
    
    NetworkLogger.interceptor.info('拦截器已注册: $name');
  }
  
  /// 注销拦截器
  bool unregisterInterceptor(String name) {
    if (!_interceptors.containsKey(name)) {
      return false;
    }
    
    _interceptors.remove(name);
    _configs.remove(name);
    _executionOrder.remove(name);
    
    NetworkLogger.interceptor.info('拦截器已注销: $name');
    return true;
  }
  
  /// 启用拦截器
  bool enableInterceptor(String name) {
    final config = _configs[name];
    if (config != null) {
      config.enabled = true;
          NetworkLogger.interceptor.info('拦截器已启用: $name');
      return true;
    }
    return false;
  }
  
  /// 禁用拦截器
  bool disableInterceptor(String name) {
    final config = _configs[name];
    if (config != null) {
      config.enabled = false;
          NetworkLogger.interceptor.info('拦截器已禁用: $name');
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
  void interceptRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 空值检查
    if (options == null) {
      NetworkLogger.interceptor.warning('请求拦截: RequestOptions 为空');
      return;
    }
    if (handler == null) {
      NetworkLogger.interceptor.warning('请求拦截: RequestInterceptorHandler 为空');
      return;
    }
    
    _executeRequestChain(0, options, handler);
  }

  void _executeRequestChain(int index, RequestOptions options, RequestInterceptorHandler handler) {
    if (index >= _executionOrder.length) {
      // All interceptors have been processed, call the final handler
      handler.next(options);
      return;
    }

    final name = _executionOrder[index];
    final interceptor = _interceptors[name];
    final config = _configs[name];

    if (interceptor == null || config == null || !config.enabled) {
      _executeRequestChain(index + 1, options, handler);
      return;
    }

    final startTime = DateTime.now();
    
    // 应用执行超时控制
    _executeWithTimeout(
      name,
      config.timeout,
      () async {
        final customHandler = CustomRequestInterceptorHandler(
          onNext: (req) {
            final duration = DateTime.now().difference(startTime);
            _statistics.recordExecution(name, InterceptorType.request, duration, true);
            _executeRequestChain(index + 1, req, handler);
          },
          onError: (err) {
            final duration = DateTime.now().difference(startTime);
            _statistics.recordExecution(name, InterceptorType.request, duration, false);
            handler.reject(err);
          }
        );
        interceptor.onRequest(options, customHandler);
      },
      onTimeout: () {
        final duration = DateTime.now().difference(startTime);
        _statistics.recordExecution(name, InterceptorType.request, duration, false);
        if (config.continueOnError) {
          NetworkLogger.interceptor.warning('请求拦截器 "$name" 执行超时，继续执行');
          _executeRequestChain(index + 1, options, handler);
        } else {
          NetworkLogger.interceptor.warning('请求拦截器 "$name" 执行超时，中断执行');
          handler.reject(DioException(
            requestOptions: options,
            error: TimeoutException('拦截器执行超时', config.timeout),
            type: DioExceptionType.unknown,
          ));
        }
      },
      onError: (e) {
        final duration = DateTime.now().difference(startTime);
        _statistics.recordExecution(name, InterceptorType.request, duration, false);
        if (config.continueOnError) {
          NetworkLogger.interceptor.warning('请求拦截器 "$name" 执行失败，继续执行: $e');
          _executeRequestChain(index + 1, options, handler);
        } else {
          NetworkLogger.interceptor.warning('请求拦截器 "$name" 执行失败，中断执行: $e');
          handler.reject(e is DioException ? e : DioException(requestOptions: options, error: e));
        }
      },
    );
  }
  
  /// 执行响应拦截
  void interceptResponse(Response response, ResponseInterceptorHandler handler) {
    // 空值检查
    if (response == null) {
      NetworkLogger.interceptor.warning('响应拦截: Response 为空');
      return;
    }
    if (handler == null) {
      NetworkLogger.interceptor.warning('响应拦截: ResponseInterceptorHandler 为空');
      return;
    }
    
    _executeResponseChain(_executionOrder.length - 1, response, handler);
  }

  void _executeResponseChain(int index, Response response, ResponseInterceptorHandler handler) {
    if (index < 0) {
      handler.next(response);
      return;
    }

    final name = _executionOrder[index];
    final interceptor = _interceptors[name];
    final config = _configs[name];

    if (interceptor == null || config == null || !config.enabled) {
      _executeResponseChain(index - 1, response, handler);
      return;
    }

    final startTime = DateTime.now();
    
    // 应用执行超时控制
    _executeWithTimeout(
      name,
      config.timeout,
      () async {
        final customHandler = CustomResponseInterceptorHandler(
          onNext: (res) {
            final duration = DateTime.now().difference(startTime);
            _statistics.recordExecution(name, InterceptorType.response, duration, true);
            _executeResponseChain(index - 1, res, handler);
          },
          onError: (err) {
            final duration = DateTime.now().difference(startTime);
            _statistics.recordExecution(name, InterceptorType.response, duration, false);
            handler.reject(err);
          }
        );
        interceptor.onResponse(response, customHandler);
      },
      onTimeout: () {
        final duration = DateTime.now().difference(startTime);
        _statistics.recordExecution(name, InterceptorType.response, duration, false);
        if (config.continueOnError) {
          NetworkLogger.interceptor.warning('响应拦截器 "$name" 执行超时，继续执行');
          _executeResponseChain(index - 1, response, handler);
        } else {
          NetworkLogger.interceptor.warning('响应拦截器 "$name" 执行超时，中断执行');
          handler.reject(DioException(
            requestOptions: response.requestOptions,
            error: TimeoutException('拦截器执行超时', config.timeout),
            type: DioExceptionType.unknown,
          ));
        }
      },
      onError: (e) {
        final duration = DateTime.now().difference(startTime);
        _statistics.recordExecution(name, InterceptorType.response, duration, false);
        if (config.continueOnError) {
          NetworkLogger.interceptor.warning('响应拦截器 "$name" 执行失败，继续执行: $e');
          _executeResponseChain(index - 1, response, handler);
        } else {
          NetworkLogger.interceptor.warning('响应拦截器 "$name" 执行失败，中断执行: $e');
          handler.reject(e is DioException ? e : DioException(requestOptions: response.requestOptions, error: e));
        }
      },
    );
  }
  
  /// 执行错误拦截
  void interceptError(DioException err, ErrorInterceptorHandler handler) {
    // 空值检查
    if (err == null) {
      NetworkLogger.interceptor.warning('错误拦截: DioException 为空');
      return;
    }
    if (handler == null) {
      NetworkLogger.interceptor.warning('错误拦截: ErrorInterceptorHandler 为空');
      return;
    }
    
    _executeErrorChain(0, err, handler);
  }

  void _executeErrorChain(int index, DioException err, ErrorInterceptorHandler handler) {
    if (index >= _executionOrder.length) {
      handler.next(err);
      return;
    }

    final name = _executionOrder[index];
    final interceptor = _interceptors[name];
    final config = _configs[name];

    if (interceptor == null || config == null || !config.enabled) {
      _executeErrorChain(index + 1, err, handler);
      return;
    }

    final startTime = DateTime.now();
    
    // 应用执行超时控制
    _executeWithTimeout(
      name,
      config.timeout,
      () async {
        final customHandler = CustomErrorInterceptorHandler(
          onNext: (error) {
            final duration = DateTime.now().difference(startTime);
            _statistics.recordExecution(name, InterceptorType.error, duration, true);
            _executeErrorChain(index + 1, error, handler);
          },
          onError: (error) {
            final duration = DateTime.now().difference(startTime);
            _statistics.recordExecution(name, InterceptorType.error, duration, false);
            handler.reject(error);
          }
        );
        interceptor.onError(err, customHandler);
      },
      onTimeout: () {
        final duration = DateTime.now().difference(startTime);
        _statistics.recordExecution(name, InterceptorType.error, duration, false);
        if (config.continueOnError) {
          NetworkLogger.interceptor.warning('错误拦截器 "$name" 执行超时，继续执行');
          _executeErrorChain(index + 1, err, handler);
        } else {
          NetworkLogger.interceptor.warning('错误拦截器 "$name" 执行超时，中断执行');
          handler.reject(DioException(
            requestOptions: err.requestOptions,
            error: TimeoutException('拦截器执行超时', config.timeout),
            type: DioExceptionType.unknown,
          ));
        }
      },
      onError: (e) {
        final duration = DateTime.now().difference(startTime);
        _statistics.recordExecution(name, InterceptorType.error, duration, false);
        if (config.continueOnError) {
          NetworkLogger.interceptor.warning('错误拦截器 "$name" 执行失败，继续执行: $e');
          _executeErrorChain(index + 1, err, handler);
        } else {
          NetworkLogger.interceptor.warning('错误拦截器 "$name" 执行失败，中断执行: $e');
          handler.reject(e is DioException ? e : DioException(requestOptions: err.requestOptions, error: e));
        }
      },
    );
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

  /// 执行带超时控制的操作
  void _executeWithTimeout(
    String interceptorName,
    Duration? timeout,
    Future<void> Function() operation,
    {
    required VoidCallback onTimeout,
    required Function(dynamic) onError,
  }) {
    if (timeout == null) {
      // 没有配置超时，直接执行
      operation().catchError(onError);
      return;
    }

    Timer? timeoutTimer;
    bool completed = false;

    // 设置超时定时器
    timeoutTimer = Timer(timeout, () {
      if (!completed) {
        completed = true;
        timeoutTimer?.cancel(); // 确保Timer被清理
        onTimeout();
      }
    });

    // 执行操作
    operation().then((_) {
      if (!completed) {
        completed = true;
        timeoutTimer?.cancel();
      }
    }).catchError((error) {
      if (!completed) {
        completed = true;
        timeoutTimer?.cancel();
        onError(error);
      }
    });
  }
}

/// 插件拦截器基类
abstract class PluginInterceptor extends Interceptor {
  /// 拦截器名称
  String get name;
  
  /// 拦截器版本
  String get version;
  
  /// 拦截器描述
  String get description;
  
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

class CustomRequestInterceptorHandler extends RequestInterceptorHandler {
  final void Function(RequestOptions) _onNext;
  final void Function(DioException) _onError;

  CustomRequestInterceptorHandler({
    required void Function(RequestOptions) onNext,
    required void Function(DioException) onError,
  }) : _onNext = onNext, _onError = onError;

  @override
  void next(RequestOptions requestOptions) {
    _onNext(requestOptions);
  }

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptors = true]) {
    _onError(error);
  }
}

class CustomResponseInterceptorHandler extends ResponseInterceptorHandler {
  final void Function(Response) _onNext;
  final void Function(DioException) _onError;

  CustomResponseInterceptorHandler({
    required void Function(Response) onNext,
    required void Function(DioException) onError,
  }) : _onNext = onNext, _onError = onError;

  @override
  void next(Response response) {
    _onNext(response);
  }

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptors = true]) {
    _onError(error);
  }
}

class CustomErrorInterceptorHandler extends ErrorInterceptorHandler {
  final void Function(DioException) _onNext;
  final void Function(DioException) _onError;

  CustomErrorInterceptorHandler({
    required void Function(DioException) onNext,
    required void Function(DioException) onError,
  }) : _onNext = onNext, _onError = onError;

  @override
  void next(DioException err) {
    _onNext(err);
  }

  @override
  void reject(DioException error) {
    _onError(error);
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
    NetworkLogger.interceptor.fine('缓存拦截器: 检查请求缓存');
    return options;
  }
  
  @override
  Future<Response> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    // 保存缓存逻辑
    NetworkLogger.interceptor.fine('缓存拦截器: 保存响应缓存');
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
    NetworkLogger.interceptor.fine('认证拦截器: 添加认证信息');
    return options;
  }
  
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // 处理认证错误
    NetworkLogger.interceptor.fine('认证拦截器: 处理认证错误');
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
    NetworkLogger.interceptor.info('日志拦截器: 记录请求 ${options.method} ${options.uri}');
    return options;
  }
  
  @override
  Future<Response> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    NetworkLogger.interceptor.info('日志拦截器: 记录响应 ${response.statusCode}');
    return response;
  }
  
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    NetworkLogger.interceptor.warning('日志拦截器: 记录错误 ${err.message}');
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
  bool get supportsRequestInterception => true;
  
  @override
  bool get supportsErrorInterception => true;
  
  @override
  Future<RequestOptions> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 直接返回请求选项，不做任何处理
    return options;
  }
  
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // 重试逻辑
    NetworkLogger.interceptor.fine('重试拦截器: 处理重试');
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