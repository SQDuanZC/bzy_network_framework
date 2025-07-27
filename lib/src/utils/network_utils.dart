import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../core/exception/unified_exception_handler.dart';
import '../requests/base_network_request.dart';

/// Network utility class
/// Provides network status checking, exception handling, response parsing and other utility methods
class NetworkUtils {
  NetworkUtils._();
  
  /// Check network connection status
  static Future<bool> isNetworkAvailable() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
  
  /// Determine exception type
  static ExceptionType getErrorType(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ExceptionType.network;
        case DioExceptionType.connectionError:
          return ExceptionType.network;
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          if (statusCode != null) {
            if (statusCode == 401) return ExceptionType.auth;
            if (statusCode == 403) return ExceptionType.auth;
            if (statusCode == 404) return ExceptionType.client;
            if (statusCode >= 500) return ExceptionType.server;
          }
          return ExceptionType.server;
        case DioExceptionType.cancel:
          return ExceptionType.operation;
        case DioExceptionType.unknown:
        default:
          return ExceptionType.unknown;
      }
    } else if (error is SocketException) {
      return ExceptionType.network;
    } else if (error is FormatException) {
      return ExceptionType.data;
    }
    return ExceptionType.unknown;
  }
  
  /// Get error message
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return 'Connection timeout, please check network settings';
        case DioExceptionType.sendTimeout:
          return 'Request timeout, please try again later';
        case DioExceptionType.receiveTimeout:
          return 'Response timeout, please try again later';
        case DioExceptionType.connectionError:
          return 'Network connection failed, please check network settings';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final message = error.response?.data?['message'] ?? 
                         error.response?.data?['msg'];
          if (message != null) return message;
          
          if (statusCode != null) {
            switch (statusCode) {
              case 400:
                return 'Invalid request parameters';
              case 401:
                return 'Unauthorized, please login again';
              case 403:
                return 'Access forbidden';
              case 404:
                return 'Requested resource not found';
              case 500:
                return 'Internal server error';
              case 502:
                return 'Gateway error';
              case 503:
                return 'Service unavailable';
              default:
                return 'Request failed ($statusCode)';
            }
          }
          return 'Request failed';
        case DioExceptionType.cancel:
          return 'Request cancelled';
        case DioExceptionType.unknown:
        default:
          return error.message ?? 'Unknown error';
      }
    } else if (error is SocketException) {
      return 'Network connection failed, please check network settings';
    } else if (error is FormatException) {
      return 'Data parsing failed';
    }
    return error.toString();
  }
  
  /// Create network exception
  static NetworkException createNetworkException(dynamic error) {
    return NetworkException(
      message: getErrorMessage(error),
      statusCode: error is DioException ? error.response?.statusCode : null,
      errorCode: _getErrorCode(error),
      originalError: error,
    );
  }
  
  /// Get error code
  static String _getErrorCode(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return 'CONNECTION_TIMEOUT';
        case DioExceptionType.sendTimeout:
          return 'SEND_TIMEOUT';
        case DioExceptionType.receiveTimeout:
          return 'RECEIVE_TIMEOUT';
        case DioExceptionType.connectionError:
          return 'CONNECTION_ERROR';
        case DioExceptionType.badResponse:
          return 'BAD_RESPONSE';
        case DioExceptionType.cancel:
          return 'REQUEST_CANCELLED';
        default:
          return 'UNKNOWN_ERROR';
      }
    } else if (error is SocketException) {
      return 'NETWORK_UNAVAILABLE';
    } else if (error is FormatException) {
      return 'PARSE_ERROR';
    }
    return 'UNKNOWN_ERROR';
  }
  
  /// Safe JSON parsing
  static Map<String, dynamic>? safeParseJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;
    
    try {
      final decoded = json.decode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (e) {
      // JSON parsing failed, return null
      return null;
    }
  }
  
  /// Desensitize sensitive data
  static Map<String, dynamic> desensitizeData(Map<String, dynamic> data) {
    final sensitiveKeys = ['password', 'token', 'accessToken', 'refreshToken', 
                          'secret', 'key', 'authorization'];
    
    final result = Map<String, dynamic>.from(data);
    
    for (final key in sensitiveKeys) {
      if (result.containsKey(key)) {
        final value = result[key];
        if (value is String && value.isNotEmpty) {
          result[key] = '${value.substring(0, 1)}***${value.substring(value.length - 1)}';
        }
      }
    }
    
    return result;
  }
  

  
  /// Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
  
  /// Check if request is idempotent
  static bool isIdempotentRequest(String method) {
    final idempotentMethods = ['GET', 'PUT', 'DELETE', 'HEAD', 'OPTIONS'];
    return idempotentMethods.contains(method.toUpperCase());
  }
  
  /// Generate unique request identifier
  static String generateRequestId(String path, [Map<String, dynamic>? queryParameters]) {
    final buffer = StringBuffer();
    buffer.write(path);
    
    if (queryParameters != null && queryParameters.isNotEmpty) {
      // Sort query parameters to ensure same parameters generate same ID
      final sortedKeys = queryParameters.keys.toList()..sort();
      buffer.write('?');
      
      for (int i = 0; i < sortedKeys.length; i++) {
        final key = sortedKeys[i];
        final value = queryParameters[key];
        
        if (i > 0) {
          buffer.write('&');
        }
        
        buffer.write('$key=$value');
      }
    }
    
    // Generate hash as unique identifier
    final requestString = buffer.toString();
    return requestString.hashCode.toString();
  }
}