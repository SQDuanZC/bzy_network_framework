import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../utils/network_logger.dart';
import 'network_exception.dart';

/// Unified exception handling system
/// Provides unified exception classification, error code definition and exception handling mechanism
class UnifiedExceptionHandler {
  static UnifiedExceptionHandler? _instance;
  
  /// Singleton instance
  static UnifiedExceptionHandler get instance {
    _instance ??= UnifiedExceptionHandler._internal();
    return _instance!;
  }
  
  UnifiedExceptionHandler._internal();
  
  /// Global exception handler list
  final List<GlobalExceptionHandler> _globalHandlers = [];
  
  /// Exception statistics
  final Map<String, int> _exceptionStats = {};
  
  /// Register global exception handler
  void registerGlobalHandler(GlobalExceptionHandler handler) {
    _globalHandlers.add(handler);
  }
  
  /// Remove global exception handler
  void removeGlobalHandler(GlobalExceptionHandler handler) {
    _globalHandlers.remove(handler);
  }
  
  /// Create NetworkException from various error types
  NetworkException createNetworkException(dynamic error) {
    final unifiedException = _createUnifiedException(error);
    return NetworkException(
      message: unifiedException.message,
      statusCode: unifiedException.statusCode,
      errorCode: unifiedException.code.name,
      originalError: unifiedException.originalError,
    );
  }

  UnifiedException _createUnifiedException(dynamic error) {
    if (error is UnifiedException) {
      return error;
    } else if (error is DioException) {
      return _handleDioException(error);
    } else if (error is SocketException) {
      return _handleSocketException(error);
    } else if (error is TimeoutException) {
      return _handleTimeoutException(error);
    } else if (error is FormatException) {
      return _handleFormatException(error);
    } else {
      return _handleGenericException(error);
    }
  }

  /// Handle exception
  Future<UnifiedException> handleException(dynamic error, {
    String? context,
    Map<String, dynamic>? metadata,
  }) async {
    var unifiedException = _createUnifiedException(error);
    
    // Add context information
    if (context != null) {
      unifiedException = unifiedException.copyWith(
        context: context,
        metadata: {...?unifiedException.metadata, ...?metadata},
      );
    }
    
    // Record exception statistics
    _recordExceptionStats(unifiedException);
    
    // Call global exception handlers
    for (final handler in _globalHandlers) {
      try {
        await handler.onException(unifiedException);
      } catch (e) {
        NetworkLogger.general.warning('Global exception handler execution failed: $e');
      }
    }
    
    // Log exception
    _logException(unifiedException);
    
    return unifiedException;
  }
  
  /// Handle Dio exception
  UnifiedException _handleDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
          return UnifiedException(
            type: ExceptionType.network,
            code: ErrorCode.connectionTimeout,
            message: error.message ?? 'Connection timeout, please check network connection',
            originalError: error,
            statusCode: -1001,
          );
        
      case DioExceptionType.sendTimeout:
          return UnifiedException(
            type: ExceptionType.network,
            code: ErrorCode.sendTimeout,
            message: error.message ?? 'Send timeout, please try again later',
            originalError: error,
            statusCode: -1002,
          );
        
      case DioExceptionType.receiveTimeout:
          return UnifiedException(
            type: ExceptionType.network,
            code: ErrorCode.receiveTimeout,
            message: error.message ?? 'Receive timeout, please try again later',
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
          message: error.message ?? 'Request cancelled',
          originalError: error,
          statusCode: -1999,
        );
        
      case DioExceptionType.connectionError:
        return UnifiedException(
          type: ExceptionType.network,
          code: ErrorCode.connectionError,
          message: error.message ?? 'Network connection error, please check network settings',
          originalError: error,
          statusCode: -1004,
        );
        
      default:
        return UnifiedException(
          type: ExceptionType.unknown,
          code: ErrorCode.unknownError,
          message: error.message ?? 'Unknown network error',
          originalError: error,
          statusCode: -1000,
        );
    }
  }
  
  /// Handle HTTP status code
  UnifiedException _handleHttpStatusCode(int statusCode, DioException error) {
    switch (statusCode) {
      case 400:
          return UnifiedException(
            type: ExceptionType.client,
            code: ErrorCode.badRequest,
            message: error.message ?? 'Bad request parameters',
            originalError: error,
            statusCode: statusCode,
          );
        
      case 401:
          return UnifiedException(
            type: ExceptionType.auth,
            code: ErrorCode.unauthorized,
            message: error.message ?? 'Authentication failed, please login again',
            originalError: error,
            statusCode: statusCode,
          );
        
      case 403:
          return UnifiedException(
            type: ExceptionType.auth,
            code: ErrorCode.forbidden,
            message: error.message ?? 'Insufficient permissions, access denied',
            originalError: error,
            statusCode: statusCode,
          );
        
      case 404:
          return UnifiedException(
            type: ExceptionType.client,
            code: ErrorCode.notFound,
            message: error.message ?? 'Requested resource not found',
            originalError: error,
            statusCode: statusCode,
          );
        
      case 408:
          return UnifiedException(
            type: ExceptionType.network,
            code: ErrorCode.requestTimeout,
            message: error.message ?? 'Request timeout, please try again later',
            originalError: error,
            statusCode: statusCode,
          );
        
      case 429:
          return UnifiedException(
            type: ExceptionType.client,
            code: ErrorCode.tooManyRequests,
            message: error.message ?? 'Too many requests, please try again later',
            originalError: error,
            statusCode: statusCode,
          );
        
      case 500:
          return UnifiedException(
            type: ExceptionType.server,
            code: ErrorCode.internalServerError,
            message: error.message ?? 'Internal server error',
            originalError: error,
            statusCode: statusCode,
          );
        
      case 502:
          return UnifiedException(
            type: ExceptionType.server,
            code: ErrorCode.badGateway,
            message: error.message ?? 'Gateway error',
            originalError: error,
            statusCode: statusCode,
          );
        
      case 503:
          return UnifiedException(
            type: ExceptionType.server,
            code: ErrorCode.serviceUnavailable,
            message: error.message ?? 'Service temporarily unavailable',
            originalError: error,
            statusCode: statusCode,
          );
        
      case 504:
        return UnifiedException(
          type: ExceptionType.server,
          code: ErrorCode.gatewayTimeout,
          message: error.message ?? 'Gateway timeout',
          originalError: error,
          statusCode: statusCode,
        );
        
      default:
        if (statusCode >= 400 && statusCode < 500) {
          return UnifiedException(
            type: ExceptionType.client,
            code: ErrorCode.clientError,
            message: error.message ?? 'Client error ($statusCode)',
            originalError: error,
            statusCode: statusCode,
          );
        } else if (statusCode >= 500) {
          return UnifiedException(
            type: ExceptionType.server,
            code: ErrorCode.serverError,
            message: error.message ?? 'Server error ($statusCode)',
            originalError: error,
            statusCode: statusCode,
          );
        } else {
          return UnifiedException(
            type: ExceptionType.unknown,
            code: ErrorCode.unknownError,
            message: error.message ?? 'Unknown HTTP error ($statusCode)',
            originalError: error,
            statusCode: statusCode,
          );
        }
    }
  }
  
  /// Handle Socket exception
  UnifiedException _handleSocketException(SocketException error) {
    return UnifiedException(
      type: ExceptionType.network,
      code: ErrorCode.networkUnavailable,
      message: error.message ?? 'Network unavailable, please check network connection',
      originalError: error,
      statusCode: -2001,
    );
  }
  
  /// Handle timeout exception
  UnifiedException _handleTimeoutException(TimeoutException error) {
    return UnifiedException(
      type: ExceptionType.network,
      code: ErrorCode.operationTimeout,
      message: error.message ?? 'Operation timeout, please try again later',
      originalError: error,
      statusCode: -2002,
    );
  }
  
  /// Handle format exception
  UnifiedException _handleFormatException(FormatException error) {
    return UnifiedException(
      type: ExceptionType.data,
      code: ErrorCode.parseError,
      message: error.message ?? 'Data format error',
      originalError: error,
      statusCode: -3001,
    );
  }
  
  /// Handle generic exception
  UnifiedException _handleGenericException(dynamic error) {
    return UnifiedException(
      type: ExceptionType.unknown,
      code: ErrorCode.unknownError,
      message: error.toString(),
      originalError: error,
      statusCode: -9999,
    );
  }
  
  /// Record exception statistics
  void _recordExceptionStats(UnifiedException exception) {
    final key = '${exception.type.name}_${exception.code.name}';
    _exceptionStats[key] = (_exceptionStats[key] ?? 0) + 1;
  }
  
  /// Log exception
  void _logException(UnifiedException exception) {
    final level = _getLogLevel(exception.type);
    final message = 'Exception handling: ${exception.message} '
        '(Type: ${exception.type.name}, '
        'Error code: ${exception.code.name}, '
        'Status code: ${exception.statusCode})';
    
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
  
  /// Get log level
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
  
  /// Get exception statistics
  Map<String, int> getExceptionStats() {
    return Map.unmodifiable(_exceptionStats);
  }
  
  /// Clear exception statistics
  void clearExceptionStats() {
    _exceptionStats.clear();
  }
  
  /// Reset exception handler
  void reset() {
    _globalHandlers.clear();
    _exceptionStats.clear();
  }
}

/// Unified exception class
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
  
  /// Copy and modify exception
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
  
  /// Whether it is a network-related exception
  bool get isNetworkError => type == ExceptionType.network;
  
  /// Whether it is an authentication-related exception
  bool get isAuthError => type == ExceptionType.auth;
  
  /// Whether it is a server exception
  bool get isServerError => type == ExceptionType.server;
  
  /// Whether it is a client exception
  bool get isClientError => type == ExceptionType.client;
  
  /// Whether it is retryable
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

/// Exception type enumeration
enum ExceptionType {
  network,    // Network exception
  server,     // Server exception
  client,     // Client exception
  auth,       // Authentication exception
  data,       // Data exception
  operation,  // Operation exception
  unknown,    // Unknown exception
}

/// Error code enumeration
enum ErrorCode {
  // Network related error codes (1000-1999)
  connectionTimeout,
  sendTimeout,
  receiveTimeout,
  connectionError,
  networkUnavailable,
  requestTimeout,
  operationTimeout,
  
  // Authentication related error codes (2000-2999)
  unauthorized,
  forbidden,
  tokenExpired,
  tokenInvalid,
  
  // Client error codes (3000-3999)
  badRequest,
  notFound,
  methodNotAllowed,
  tooManyRequests,
  clientError,
  
  // Server error codes (4000-4999)
  internalServerError,
  badGateway,
  serviceUnavailable,
  gatewayTimeout,
  serverError,
  
  // Data related error codes (5000-5999)
  parseError,
  validationError,
  dataCorrupted,
  
  // Operation related error codes (6000-6999)
  requestCancelled,
  operationFailed,
  resourceBusy,
  
  // Unknown error codes (9000-9999)
  unknownError,
}

/// Global exception handler interface
abstract class GlobalExceptionHandler {
  /// Handle exception
  Future<void> onException(UnifiedException exception);
}

/// Log level enumeration
enum LogLevel {
  info,
  warning,
  severe,
}

/// Default global exception handler
class DefaultGlobalExceptionHandler implements GlobalExceptionHandler {
  @override
  Future<void> onException(UnifiedException exception) async {
    // Default global exception handling logic can be implemented here
    // For example: report exceptions to monitoring system, show user-friendly error messages, etc.
  }
}

/// Exception interceptor
class ExceptionInterceptor extends Interceptor {
  final UnifiedExceptionHandler _handler = UnifiedExceptionHandler.instance;
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    try {
      final unifiedException = await _handler.handleException(
        err,
        context: 'Network request exception',
        metadata: {
          'url': err.requestOptions.uri.toString(),
          'method': err.requestOptions.method,
        },
      );
      
      // Wrap unified exception back to DioException
      final wrappedError = DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: unifiedException,
        message: unifiedException.message,
      );
      
      handler.reject(wrappedError);
    } catch (e) {
      // If exception handler itself fails, use original exception
      handler.reject(err);
    }
  }
}