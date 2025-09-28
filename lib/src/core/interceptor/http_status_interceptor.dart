import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../bzy_network_framework.dart';
import 'interceptor_manager.dart';

/// HTTP状态码错误处理拦截器配置
class HttpStatusConfig {
  /// 是否启用状态码检查
  final bool enabled;
  
  /// 是否启用智能重试
  final bool enableSmartRetry;
  
  /// 是否启用API端点验证
  final bool enableEndpointValidation;
  
  /// 是否启用状态码统计
  final bool enableStatistics;
  
  /// 自定义状态码处理器
  final Map<int, HttpStatusHandler>? customHandlers;
  
  /// 重试配置
  final HttpRetryConfig retryConfig;
  
  /// 端点验证配置
  final EndpointValidationConfig validationConfig;
  
  /// 错误恢复策略
  final HttpErrorRecoveryStrategy recoveryStrategy;
  
  const HttpStatusConfig({
    this.enabled = true,
    this.enableSmartRetry = true,
    this.enableEndpointValidation = true,
    this.enableStatistics = true,
    this.customHandlers,
    this.retryConfig = const HttpRetryConfig(),
    this.validationConfig = const EndpointValidationConfig(),
    this.recoveryStrategy = HttpErrorRecoveryStrategy.intelligent,
  });
}

/// HTTP重试配置
class HttpRetryConfig {
  /// 最大重试次数
  final int maxRetries;
  
  /// 基础重试延迟
  final Duration baseDelay;
  
  /// 是否使用指数退避
  final bool useExponentialBackoff;
  
  /// 最大退避延迟
  final Duration maxBackoffDelay;
  
  /// 可重试的状态码
  final Set<int> retryableStatusCodes;
  
  /// 不可重试的状态码
  final Set<int> nonRetryableStatusCodes;
  
  const HttpRetryConfig({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.useExponentialBackoff = true,
    this.maxBackoffDelay = const Duration(seconds: 30),
    this.retryableStatusCodes = const {408, 429, 500, 502, 503, 504},
    this.nonRetryableStatusCodes = const {400, 401, 403, 404, 405, 406, 409, 410, 422},
  });
}

/// 端点验证配置
class EndpointValidationConfig {
  /// 是否启用端点存在性检查
  final bool enableExistenceCheck;
  
  /// 是否启用端点健康检查
  final bool enableHealthCheck;
  
  /// 健康检查间隔
  final Duration healthCheckInterval;
  
  /// 端点缓存时间
  final Duration endpointCacheTime;
  
  /// 验证超时时间
  final Duration validationTimeout;
  
  const EndpointValidationConfig({
    this.enableExistenceCheck = true,
    this.enableHealthCheck = false,
    this.healthCheckInterval = const Duration(minutes: 5),
    this.endpointCacheTime = const Duration(minutes: 10),
    this.validationTimeout = const Duration(seconds: 5),
  });
}

/// HTTP错误恢复策略
enum HttpErrorRecoveryStrategy {
  /// 立即失败
  failImmediately,
  
  /// 智能恢复（根据状态码自动选择策略）
  intelligent,
  
  /// 总是重试
  alwaysRetry,
  
  /// 降级处理
  gracefulDegradation,
}

/// HTTP状态码处理器
abstract class HttpStatusHandler {
  /// 处理状态码
  Future<HttpStatusResult> handle(
    int statusCode,
    DioException error,
    RequestOptions options,
  );
}

/// HTTP状态码处理结果
class HttpStatusResult {
  /// 是否应该重试
  final bool shouldRetry;
  
  /// 重试延迟
  final Duration? retryDelay;
  
  /// 自定义错误
  final DioException? customError;
  
  /// 是否继续处理
  final bool continueProcessing;
  
  /// 附加数据
  final Map<String, dynamic>? metadata;
  
  const HttpStatusResult({
    this.shouldRetry = false,
    this.retryDelay,
    this.customError,
    this.continueProcessing = true,
    this.metadata,
  });
  
  /// 创建重试结果
  factory HttpStatusResult.retry({Duration? delay, Map<String, dynamic>? metadata}) {
    return HttpStatusResult(
      shouldRetry: true,
      retryDelay: delay,
      metadata: metadata,
    );
  }
  
  /// 创建失败结果
  factory HttpStatusResult.fail({DioException? error, Map<String, dynamic>? metadata}) {
    return HttpStatusResult(
      shouldRetry: false,
      customError: error,
      continueProcessing: false,
      metadata: metadata,
    );
  }
  
  /// 创建继续处理结果
  factory HttpStatusResult.continue_({Map<String, dynamic>? metadata}) {
    return HttpStatusResult(
      shouldRetry: false,
      continueProcessing: true,
      metadata: metadata,
    );
  }
}

/// HTTP状态码统计
class HttpStatusStatistics {
  final Map<int, int> _statusCodeCounts = {};
  final Map<int, List<DateTime>> _statusCodeTimestamps = {};
  final Map<String, int> _endpointErrorCounts = {};
  int _totalRequests = 0;
  int _totalErrors = 0;
  DateTime? _lastResetTime;
  
  /// 记录状态码
  void recordStatusCode(int statusCode, String endpoint) {
    _totalRequests++;
    _statusCodeCounts[statusCode] = (_statusCodeCounts[statusCode] ?? 0) + 1;
    
    final now = DateTime.now();
    _statusCodeTimestamps.putIfAbsent(statusCode, () => []).add(now);
    
    if (statusCode >= 400) {
      _totalErrors++;
      _endpointErrorCounts[endpoint] = (_endpointErrorCounts[endpoint] ?? 0) + 1;
    }
  }
  
  /// 获取状态码统计
  Map<int, int> get statusCodeCounts => Map.unmodifiable(_statusCodeCounts);
  
  /// 获取错误率
  double get errorRate => _totalRequests > 0 ? _totalErrors / _totalRequests : 0.0;
  
  /// 获取最常见的错误状态码
  int? get mostCommonErrorCode {
    int? mostCommon;
    int maxCount = 0;
    
    for (final entry in _statusCodeCounts.entries) {
      if (entry.key >= 400 && entry.value > maxCount) {
        maxCount = entry.value;
        mostCommon = entry.key;
      }
    }
    
    return mostCommon;
  }
  
  /// 获取端点错误统计
  Map<String, int> get endpointErrorCounts => Map.unmodifiable(_endpointErrorCounts);
  
  /// 获取最近时间段内的状态码频率
  Map<int, int> getRecentStatusCodes(Duration timeWindow) {
    final now = DateTime.now();
    final cutoff = now.subtract(timeWindow);
    final recentCounts = <int, int>{};
    
    for (final entry in _statusCodeTimestamps.entries) {
      final recentTimestamps = entry.value.where((timestamp) => timestamp.isAfter(cutoff));
      if (recentTimestamps.isNotEmpty) {
        recentCounts[entry.key] = recentTimestamps.length;
      }
    }
    
    return recentCounts;
  }
  
  /// 清除统计数据
  void clear() {
    _statusCodeCounts.clear();
    _statusCodeTimestamps.clear();
    _endpointErrorCounts.clear();
    _totalRequests = 0;
    _totalErrors = 0;
    _lastResetTime = DateTime.now();
  }
  
  /// 获取统计摘要
  Map<String, dynamic> getSummary() {
    return {
      'totalRequests': _totalRequests,
      'totalErrors': _totalErrors,
      'errorRate': errorRate,
      'mostCommonErrorCode': mostCommonErrorCode,
      'statusCodeCounts': statusCodeCounts,
      'endpointErrorCounts': endpointErrorCounts,
      'lastResetTime': _lastResetTime?.toIso8601String(),
    };
  }
}

/// 端点验证器
class EndpointValidator {
  final EndpointValidationConfig _config;
  final Map<String, DateTime> _validatedEndpoints = {};
  final Map<String, bool> _endpointStatus = {};
  final Dio _dio;
  
  EndpointValidator(this._config) : _dio = Dio();
  
  /// 验证端点
  Future<bool> validateEndpoint(String endpoint) async {
    if (!_config.enableExistenceCheck) {
      return true;
    }
    
    // 检查缓存
    final lastValidated = _validatedEndpoints[endpoint];
    if (lastValidated != null) {
      final cacheExpiry = lastValidated.add(_config.endpointCacheTime);
      if (DateTime.now().isBefore(cacheExpiry)) {
        return _endpointStatus[endpoint] ?? false;
      }
    }
    
    try {
      // 执行HEAD请求检查端点存在性
      final response = await _dio.head(
        endpoint,
        options: Options(
          sendTimeout: _config.validationTimeout,
          receiveTimeout: _config.validationTimeout,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      
      final isValid = response.statusCode != null && response.statusCode! < 400;
      
      // 更新缓存
      _validatedEndpoints[endpoint] = DateTime.now();
      _endpointStatus[endpoint] = isValid;
      
      return isValid;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('端点验证失败: $endpoint, 错误: $e');
      }
      
      // 验证失败，标记为无效
      _validatedEndpoints[endpoint] = DateTime.now();
      _endpointStatus[endpoint] = false;
      
      return false;
    }
  }
  
  /// 清除验证缓存
  void clearCache() {
    _validatedEndpoints.clear();
    _endpointStatus.clear();
  }
  
  /// 获取端点状态
  bool? getEndpointStatus(String endpoint) {
    return _endpointStatus[endpoint];
  }
}

/// HTTP状态码错误处理拦截器
class HttpStatusInterceptor extends PluginInterceptor {
  @override
  String get name => 'http_status';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => 'HTTP状态码错误处理拦截器';
  
  final HttpStatusConfig _config;
  final HttpStatusStatistics _statistics = HttpStatusStatistics();
  final EndpointValidator _validator;
  final Map<String, int> _retryAttempts = {};
  
  HttpStatusInterceptor(this._config) : _validator = EndpointValidator(_config.validationConfig);
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_config.enabled) {
      handler.next(options);
      return;
    }
    
    try {
      // 端点验证
      if (_config.enableEndpointValidation) {
        final endpoint = '${options.baseUrl}${options.path}';
        final isValid = await _validator.validateEndpoint(endpoint);
        
        if (!isValid) {
          if (kDebugMode) {
            debugPrint('端点验证失败: $endpoint');
          }
          
          handler.reject(DioException(
            requestOptions: options,
            error: 'API端点不存在或不可用: $endpoint',
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: options,
              statusCode: 404,
              statusMessage: 'Endpoint not found',
            ),
          ));
          return;
        }
      }
      
      handler.next(options);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HTTP状态拦截器请求处理失败: $e');
      }
      handler.next(options);
    }
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!_config.enabled) {
      handler.next(response);
      return;
    }
    
    try {
      final statusCode = response.statusCode;
      if (statusCode != null) {
        // 记录状态码统计
        if (_config.enableStatistics) {
          final endpoint = '${response.requestOptions.baseUrl}${response.requestOptions.path}';
          _statistics.recordStatusCode(statusCode, endpoint);
        }
        
        // 检查是否为错误状态码
        if (statusCode >= 400) {
          final error = DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: 'HTTP错误: $statusCode',
          );
          
          handler.reject(error);
          return;
        }
      }
      
      handler.next(response);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HTTP状态拦截器响应处理失败: $e');
      }
      handler.next(response);
    }
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_config.enabled) {
      handler.next(err);
      return;
    }
    
    try {
      final statusCode = err.response?.statusCode;
      if (statusCode != null) {
        // 记录错误状态码统计
        if (_config.enableStatistics) {
          final endpoint = '${err.requestOptions.baseUrl}${err.requestOptions.path}';
          _statistics.recordStatusCode(statusCode, endpoint);
        }
        
        // 处理状态码错误
        final result = await _handleStatusCodeError(statusCode, err);
        
        if (result.shouldRetry && _config.enableSmartRetry) {
          // 执行重试
          final retryResult = await _performRetry(err.requestOptions, result.retryDelay);
          if (retryResult != null) {
            handler.resolve(retryResult);
            return;
          }
        }
        
        if (result.customError != null) {
          handler.reject(result.customError!);
          return;
        }
        
        if (!result.continueProcessing) {
          handler.reject(err);
          return;
        }
      }
      
      handler.next(err);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HTTP状态拦截器错误处理失败: $e');
      }
      handler.next(err);
    }
  }
  
  /// 处理状态码错误
  Future<HttpStatusResult> _handleStatusCodeError(int statusCode, DioException error) async {
    // 检查自定义处理器
    final customHandler = _config.customHandlers?[statusCode];
    if (customHandler != null) {
      return await customHandler.handle(statusCode, error, error.requestOptions);
    }
    
    // 根据恢复策略处理
    switch (_config.recoveryStrategy) {
      case HttpErrorRecoveryStrategy.failImmediately:
        return HttpStatusResult.fail();
        
      case HttpErrorRecoveryStrategy.alwaysRetry:
        return HttpStatusResult.retry(delay: _calculateRetryDelay(statusCode));
        
      case HttpErrorRecoveryStrategy.gracefulDegradation:
        return _handleGracefulDegradation(statusCode, error);
        
      case HttpErrorRecoveryStrategy.intelligent:
      default:
        return _handleIntelligentRecovery(statusCode, error);
    }
  }
  
  /// 智能恢复处理
  HttpStatusResult _handleIntelligentRecovery(int statusCode, DioException error) {
    // 检查是否为可重试的状态码
    if (_config.retryConfig.retryableStatusCodes.contains(statusCode)) {
      return HttpStatusResult.retry(delay: _calculateRetryDelay(statusCode));
    }
    
    // 检查是否为不可重试的状态码
    if (_config.retryConfig.nonRetryableStatusCodes.contains(statusCode)) {
      return HttpStatusResult.fail();
    }
    
    // 根据状态码类型决定处理方式
    if (statusCode >= 500) {
      // 服务器错误，通常可以重试
      return HttpStatusResult.retry(delay: _calculateRetryDelay(statusCode));
    } else if (statusCode == 429) {
      // 限流错误，延长重试间隔
      return HttpStatusResult.retry(delay: Duration(seconds: 30));
    } else if (statusCode >= 400 && statusCode < 500) {
      // 客户端错误，通常不应重试
      return HttpStatusResult.fail();
    }
    
    return HttpStatusResult.continue_();
  }
  
  /// 优雅降级处理
  HttpStatusResult _handleGracefulDegradation(int statusCode, DioException error) {
    // 根据状态码提供降级策略
    switch (statusCode) {
      case 503: // 服务不可用
      case 502: // 网关错误
        // 可以尝试使用缓存数据或备用服务
        return HttpStatusResult.retry(delay: Duration(seconds: 10));
        
      case 429: // 限流
        // 延长重试间隔
        return HttpStatusResult.retry(delay: Duration(seconds: 60));
        
      case 404: // 资源不存在
        // 可以尝试备用资源或提供默认数据
        return HttpStatusResult.fail();
        
      default:
        return _handleIntelligentRecovery(statusCode, error);
    }
  }
  
  /// 计算重试延迟
  Duration _calculateRetryDelay(int statusCode) {
    final baseDelay = _config.retryConfig.baseDelay;
    
    if (!_config.retryConfig.useExponentialBackoff) {
      return baseDelay;
    }
    
    // 获取当前重试次数
    final requestKey = _getRequestKey(statusCode);
    final attempts = _retryAttempts[requestKey] ?? 0;
    
    // 计算指数退避延迟
    final exponentialDelay = Duration(
      milliseconds: (baseDelay.inMilliseconds * pow(2, attempts)).round(),
    );
    
    // 限制最大延迟
    if (exponentialDelay > _config.retryConfig.maxBackoffDelay) {
      return _config.retryConfig.maxBackoffDelay;
    }
    
    return exponentialDelay;
  }
  
  /// 执行重试
  Future<Response?> _performRetry(RequestOptions options, Duration? delay) async {
    final requestKey = _getRequestKey(options.hashCode);
    final currentAttempts = _retryAttempts[requestKey] ?? 0;
    
    if (currentAttempts >= _config.retryConfig.maxRetries) {
      if (kDebugMode) {
        debugPrint('已达到最大重试次数: ${_config.retryConfig.maxRetries}');
      }
      return null;
    }
    
    // 更新重试次数
    _retryAttempts[requestKey] = currentAttempts + 1;
    
    // 等待重试延迟
    if (delay != null) {
      await Future.delayed(delay);
    }
    
    try {
      if (kDebugMode) {
        debugPrint('执行HTTP状态码重试: ${options.method} ${options.uri}, 第${currentAttempts + 1}次');
      }
      
      final dio = Dio();
      final response = await dio.request(
        options.path,
        data: options.data,
        queryParameters: options.queryParameters,
        options: Options(
          method: options.method,
          headers: options.headers,
          contentType: options.contentType,
          responseType: options.responseType,
          validateStatus: options.validateStatus,
          receiveDataWhenStatusError: options.receiveDataWhenStatusError,
          extra: options.extra,
        ),
        cancelToken: options.cancelToken,
        onSendProgress: options.onSendProgress,
        onReceiveProgress: options.onReceiveProgress,
      );
      
      // 重试成功，清除重试计数
      _retryAttempts.remove(requestKey);
      
      if (kDebugMode) {
        debugPrint('HTTP状态码重试成功: ${options.method} ${options.uri}');
      }
      
      return response;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HTTP状态码重试失败: ${options.method} ${options.uri}, 错误: $e');
      }
      return null;
    }
  }
  
  /// 获取请求键
  String _getRequestKey(dynamic identifier) {
    return 'http_status_retry_$identifier';
  }
  
  /// 获取统计信息
  HttpStatusStatistics get statistics => _statistics;
  
  /// 获取端点验证器
  EndpointValidator get validator => _validator;
  
  /// 清除重试计数
  void clearRetryAttempts() {
    _retryAttempts.clear();
  }
  
  /// 重置拦截器状态
  void reset() {
    _statistics.clear();
    _validator.clearCache();
    clearRetryAttempts();
  }
}

/// 常用HTTP状态码处理器
class CommonHttpStatusHandlers {
  /// 401未授权处理器
  static HttpStatusHandler unauthorizedHandler({
    required Future<bool> Function() onTokenRefresh,
  }) {
    return _UnauthorizedHandler(onTokenRefresh);
  }
  
  /// 429限流处理器
  static HttpStatusHandler rateLimitHandler({
    Duration delay = const Duration(seconds: 60),
  }) {
    return _RateLimitHandler(delay);
  }
  
  /// 503服务不可用处理器
  static HttpStatusHandler serviceUnavailableHandler({
    Duration delay = const Duration(seconds: 30),
    int maxRetries = 3,
  }) {
    return _ServiceUnavailableHandler(delay, maxRetries);
  }
}

/// 401未授权处理器实现
class _UnauthorizedHandler extends HttpStatusHandler {
  final Future<bool> Function() _onTokenRefresh;
  
  _UnauthorizedHandler(this._onTokenRefresh);
  
  @override
  Future<HttpStatusResult> handle(int statusCode, DioException error, RequestOptions options) async {
    try {
      final refreshed = await _onTokenRefresh();
      if (refreshed) {
        return HttpStatusResult.retry(delay: Duration(milliseconds: 500));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Token刷新失败: $e');
      }
    }
    
    return HttpStatusResult.fail(
      error: DioException(
        requestOptions: options,
        error: '认证失败，请重新登录',
        type: DioExceptionType.badResponse,
        response: error.response,
      ),
    );
  }
}

/// 429限流处理器实现
class _RateLimitHandler extends HttpStatusHandler {
  final Duration _delay;
  
  _RateLimitHandler(this._delay);
  
  @override
  Future<HttpStatusResult> handle(int statusCode, DioException error, RequestOptions options) async {
    return HttpStatusResult.retry(delay: _delay);
  }
}

/// 503服务不可用处理器实现
class _ServiceUnavailableHandler extends HttpStatusHandler {
  final Duration _delay;
  final int _maxRetries;
  int _currentRetries = 0;
  
  _ServiceUnavailableHandler(this._delay, this._maxRetries);
  
  @override
  Future<HttpStatusResult> handle(int statusCode, DioException error, RequestOptions options) async {
    if (_currentRetries < _maxRetries) {
      _currentRetries++;
      return HttpStatusResult.retry(delay: _delay);
    }
    
    return HttpStatusResult.fail(
      error: DioException(
        requestOptions: options,
        error: '服务暂时不可用，请稍后重试',
        type: DioExceptionType.badResponse,
        response: error.response,
      ),
    );
  }
}