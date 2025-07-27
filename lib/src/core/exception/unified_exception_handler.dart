import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../utils/network_logger.dart';

/// 统一异常处理系统
/// 提供统一的异常分类、错误码定义和异常处理机制
class UnifiedExceptionHandler {
  static UnifiedExceptionHandler? _instance;
  
  /// 单例实例
  static UnifiedExceptionHandler get instance {
    _instance ??= UnifiedExceptionHandler._internal();
    return _instance!;
  }
  
  UnifiedExceptionHandler._internal();
  
  /// 全局异常处理器列表
  final List<GlobalExceptionHandler> _globalHandlers = [];
  
  /// 异常统计
  final Map<String, int> _exceptionStats = {};
  
  /// 注册全局异常处理器
  void registerGlobalHandler(GlobalExceptionHandler handler) {
    _globalHandlers.add(handler);
  }
  
  /// 移除全局异常处理器
  void removeGlobalHandler(GlobalExceptionHandler handler) {
    _globalHandlers.remove(handler);
  }
  
  /// 处理异常
  Future<UnifiedException> handleException(dynamic error, {
    String? context,
    Map<String, dynamic>? metadata,
  }) async {
    UnifiedException unifiedException;
    
    if (error is UnifiedException) {
      unifiedException = error;
    } else if (error is DioException) {
      unifiedException = _handleDioException(error);
    } else if (error is SocketException) {
      unifiedException = _handleSocketException(error);
    } else if (error is TimeoutException) {
      unifiedException = _handleTimeoutException(error);
    } else if (error is FormatException) {
      unifiedException = _handleFormatException(error);
    } else {
      unifiedException = _handleGenericException(error);
    }
    
    // 添加上下文信息
    if (context != null) {
      unifiedException = unifiedException.copyWith(
        context: context,
        metadata: {...?unifiedException.metadata, ...?metadata},
      );
    }
    
    // 记录异常统计
    _recordExceptionStats(unifiedException);
    
    // 调用全局异常处理器
    for (final handler in _globalHandlers) {
      try {
        await handler.onException(unifiedException);
      } catch (e) {
        NetworkLogger.general.warning('全局异常处理器执行失败: $e');
      }
    }
    
    // 记录异常日志
    _logException(unifiedException);
    
    return unifiedException;
  }
  
  /// 处理 Dio 异常
  UnifiedException _handleDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return UnifiedException(
          type: ExceptionType.network,
          code: ErrorCode.connectionTimeout,
          message: '连接超时，请检查网络连接',
          originalError: error,
          statusCode: -1001,
        );
        
      case DioExceptionType.sendTimeout:
        return UnifiedException(
          type: ExceptionType.network,
          code: ErrorCode.sendTimeout,
          message: '发送超时，请稍后重试',
          originalError: error,
          statusCode: -1002,
        );
        
      case DioExceptionType.receiveTimeout:
        return UnifiedException(
          type: ExceptionType.network,
          code: ErrorCode.receiveTimeout,
          message: '接收超时，请稍后重试',
          originalError: error,
          statusCode: -1003,
        );
        
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? -1;
        return _handleHttpStatusCode(statusCode, error);
        
      case DioExceptionType.cancel:
        return UnifiedException(
          type: ExceptionType.operation,
          code: ErrorCode.requestCancelled,
          message: '请求已取消',
          originalError: error,
          statusCode: -1999,
        );
        
      case DioExceptionType.connectionError:
        return UnifiedException(
          type: ExceptionType.network,
          code: ErrorCode.connectionError,
          message: '网络连接错误，请检查网络设置',
          originalError: error,
          statusCode: -1004,
        );
        
      default:
        return UnifiedException(
          type: ExceptionType.unknown,
          code: ErrorCode.unknownError,
          message: error.message ?? '未知网络错误',
          originalError: error,
          statusCode: -1000,
        );
    }
  }
  
  /// 处理 HTTP 状态码
  UnifiedException _handleHttpStatusCode(int statusCode, DioException error) {
    switch (statusCode) {
      case 400:
        return UnifiedException(
          type: ExceptionType.client,
          code: ErrorCode.badRequest,
          message: '请求参数错误',
          originalError: error,
          statusCode: statusCode,
        );
        
      case 401:
        return UnifiedException(
          type: ExceptionType.auth,
          code: ErrorCode.unauthorized,
          message: '认证失败，请重新登录',
          originalError: error,
          statusCode: statusCode,
        );
        
      case 403:
        return UnifiedException(
          type: ExceptionType.auth,
          code: ErrorCode.forbidden,
          message: '权限不足，无法访问',
          originalError: error,
          statusCode: statusCode,
        );
        
      case 404:
        return UnifiedException(
          type: ExceptionType.client,
          code: ErrorCode.notFound,
          message: '请求的资源不存在',
          originalError: error,
          statusCode: statusCode,
        );
        
      case 408:
        return UnifiedException(
          type: ExceptionType.network,
          code: ErrorCode.requestTimeout,
          message: '请求超时，请稍后重试',
          originalError: error,
          statusCode: statusCode,
        );
        
      case 429:
        return UnifiedException(
          type: ExceptionType.client,
          code: ErrorCode.tooManyRequests,
          message: '请求过于频繁，请稍后重试',
          originalError: error,
          statusCode: statusCode,
        );
        
      case 500:
        return UnifiedException(
          type: ExceptionType.server,
          code: ErrorCode.internalServerError,
          message: '服务器内部错误',
          originalError: error,
          statusCode: statusCode,
        );
        
      case 502:
        return UnifiedException(
          type: ExceptionType.server,
          code: ErrorCode.badGateway,
          message: '网关错误',
          originalError: error,
          statusCode: statusCode,
        );
        
      case 503:
        return UnifiedException(
          type: ExceptionType.server,
          code: ErrorCode.serviceUnavailable,
          message: '服务暂时不可用',
          originalError: error,
          statusCode: statusCode,
        );
        
      case 504:
        return UnifiedException(
          type: ExceptionType.server,
          code: ErrorCode.gatewayTimeout,
          message: '网关超时',
          originalError: error,
          statusCode: statusCode,
        );
        
      default:
        if (statusCode >= 400 && statusCode < 500) {
          return UnifiedException(
            type: ExceptionType.client,
            code: ErrorCode.clientError,
            message: '客户端错误 ($statusCode)',
            originalError: error,
            statusCode: statusCode,
          );
        } else if (statusCode >= 500) {
          return UnifiedException(
            type: ExceptionType.server,
            code: ErrorCode.serverError,
            message: '服务器错误 ($statusCode)',
            originalError: error,
            statusCode: statusCode,
          );
        } else {
          return UnifiedException(
            type: ExceptionType.unknown,
            code: ErrorCode.unknownError,
            message: '未知HTTP错误 ($statusCode)',
            originalError: error,
            statusCode: statusCode,
          );
        }
    }
  }
  
  /// 处理 Socket 异常
  UnifiedException _handleSocketException(SocketException error) {
    return UnifiedException(
      type: ExceptionType.network,
      code: ErrorCode.networkUnavailable,
      message: '网络不可用，请检查网络连接',
      originalError: error,
      statusCode: -2001,
    );
  }
  
  /// 处理超时异常
  UnifiedException _handleTimeoutException(TimeoutException error) {
    return UnifiedException(
      type: ExceptionType.network,
      code: ErrorCode.operationTimeout,
      message: '操作超时，请稍后重试',
      originalError: error,
      statusCode: -2002,
    );
  }
  
  /// 处理格式异常
  UnifiedException _handleFormatException(FormatException error) {
    return UnifiedException(
      type: ExceptionType.data,
      code: ErrorCode.parseError,
      message: '数据解析失败',
      originalError: error,
      statusCode: -3001,
    );
  }
  
  /// 处理通用异常
  UnifiedException _handleGenericException(dynamic error) {
    return UnifiedException(
      type: ExceptionType.unknown,
      code: ErrorCode.unknownError,
      message: error.toString(),
      originalError: error,
      statusCode: -9999,
    );
  }
  
  /// 记录异常统计
  void _recordExceptionStats(UnifiedException exception) {
    final key = '${exception.type.name}_${exception.code.name}';
    _exceptionStats[key] = (_exceptionStats[key] ?? 0) + 1;
  }
  
  /// 记录异常日志
  void _logException(UnifiedException exception) {
    final level = _getLogLevel(exception.type);
    final message = '异常处理: ${exception.message} '
        '(类型: ${exception.type.name}, '
        '错误码: ${exception.code.name}, '
        '状态码: ${exception.statusCode})';
    
    switch (level) {
      case LogLevel.severe:
        NetworkLogger.general.severe(message);
        break;
      case LogLevel.warning:
        NetworkLogger.general.warning(message);
        break;
      case LogLevel.info:
        NetworkLogger.general.info(message);
        break;
    }
  }
  
  /// 获取日志级别
  LogLevel _getLogLevel(ExceptionType type) {
    switch (type) {
      case ExceptionType.server:
      case ExceptionType.unknown:
        return LogLevel.severe;
      case ExceptionType.network:
      case ExceptionType.auth:
        return LogLevel.warning;
      case ExceptionType.client:
      case ExceptionType.data:
      case ExceptionType.operation:
        return LogLevel.info;
    }
  }
  
  /// 获取异常统计
  Map<String, int> getExceptionStats() {
    return Map.unmodifiable(_exceptionStats);
  }
  
  /// 清空异常统计
  void clearExceptionStats() {
    _exceptionStats.clear();
  }
  
  /// 重置异常处理器
  void reset() {
    _globalHandlers.clear();
    _exceptionStats.clear();
  }
}

/// 统一异常类
class UnifiedException implements Exception {
  final ExceptionType type;
  final ErrorCode code;
  final String message;
  final int statusCode;
  final dynamic originalError;
  final String? context;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;
  
  UnifiedException({
    required this.type,
    required this.code,
    required this.message,
    required this.statusCode,
    this.originalError,
    this.context,
    this.metadata,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  /// 复制并修改异常
  UnifiedException copyWith({
    ExceptionType? type,
    ErrorCode? code,
    String? message,
    int? statusCode,
    dynamic originalError,
    String? context,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  }) {
    return UnifiedException(
      type: type ?? this.type,
      code: code ?? this.code,
      message: message ?? this.message,
      statusCode: statusCode ?? this.statusCode,
      originalError: originalError ?? this.originalError,
      context: context ?? this.context,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
    );
  }
  
  /// 是否为网络相关异常
  bool get isNetworkError => type == ExceptionType.network;
  
  /// 是否为认证相关异常
  bool get isAuthError => type == ExceptionType.auth;
  
  /// 是否为服务器异常
  bool get isServerError => type == ExceptionType.server;
  
  /// 是否为客户端异常
  bool get isClientError => type == ExceptionType.client;
  
  /// 是否可重试
  bool get isRetryable {
    switch (type) {
      case ExceptionType.network:
      case ExceptionType.server:
        return true;
      case ExceptionType.auth:
      case ExceptionType.client:
      case ExceptionType.data:
      case ExceptionType.operation:
      case ExceptionType.unknown:
        return false;
    }
  }
  
  @override
  String toString() {
    return 'UnifiedException{'
        'type: ${type.name}, '
        'code: ${code.name}, '
        'message: $message, '
        'statusCode: $statusCode'
        '${context != null ? ', context: $context' : ''}'
        '}';
  }
}

/// 异常类型枚举
enum ExceptionType {
  network,    // 网络异常
  server,     // 服务器异常
  client,     // 客户端异常
  auth,       // 认证异常
  data,       // 数据异常
  operation,  // 操作异常
  unknown,    // 未知异常
}

/// 错误码枚举
enum ErrorCode {
  // 网络相关错误码 (1000-1999)
  connectionTimeout,
  sendTimeout,
  receiveTimeout,
  connectionError,
  networkUnavailable,
  requestTimeout,
  operationTimeout,
  
  // 认证相关错误码 (2000-2999)
  unauthorized,
  forbidden,
  tokenExpired,
  tokenInvalid,
  
  // 客户端错误码 (3000-3999)
  badRequest,
  notFound,
  methodNotAllowed,
  tooManyRequests,
  clientError,
  
  // 服务器错误码 (4000-4999)
  internalServerError,
  badGateway,
  serviceUnavailable,
  gatewayTimeout,
  serverError,
  
  // 数据相关错误码 (5000-5999)
  parseError,
  validationError,
  dataCorrupted,
  
  // 操作相关错误码 (6000-6999)
  requestCancelled,
  operationFailed,
  resourceBusy,
  
  // 未知错误码 (9000-9999)
  unknownError,
}

/// 全局异常处理器接口
abstract class GlobalExceptionHandler {
  /// 处理异常
  Future<void> onException(UnifiedException exception);
}

/// 日志级别枚举
enum LogLevel {
  info,
  warning,
  severe,
}

/// 默认的全局异常处理器
class DefaultGlobalExceptionHandler implements GlobalExceptionHandler {
  @override
  Future<void> onException(UnifiedException exception) async {
    // 可以在这里实现默认的全局异常处理逻辑
    // 例如：上报异常到监控系统、显示用户友好的错误提示等
  }
}

/// 异常拦截器
class ExceptionInterceptor extends Interceptor {
  final UnifiedExceptionHandler _handler = UnifiedExceptionHandler.instance;
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    try {
      final unifiedException = await _handler.handleException(
        err,
        context: '网络请求异常',
        metadata: {
          'url': err.requestOptions.uri.toString(),
          'method': err.requestOptions.method,
        },
      );
      
      // 将统一异常包装回 DioException
      final wrappedError = DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: unifiedException,
        message: unifiedException.message,
      );
      
      handler.reject(wrappedError);
    } catch (e) {
      // 如果异常处理器本身出错，则使用原始异常
      handler.reject(err);
    }
  }
}