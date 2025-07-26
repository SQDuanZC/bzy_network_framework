import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../model/response_wrapper.dart';

/// 网络工具类
/// 提供网络状态检查、异常处理、响应解析等工具方法
class NetworkUtils {
  NetworkUtils._();
  
  /// 检查网络连接状态
  static Future<bool> isNetworkAvailable() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
  
  /// 判断异常类型
  static NetworkErrorType getErrorType(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return NetworkErrorType.timeout;
        case DioExceptionType.connectionError:
          return NetworkErrorType.noNetwork;
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          if (statusCode != null) {
            if (statusCode == 401) return NetworkErrorType.unauthorized;
            if (statusCode == 403) return NetworkErrorType.forbidden;
            if (statusCode == 404) return NetworkErrorType.notFound;
            if (statusCode >= 500) return NetworkErrorType.serverError;
          }
          return NetworkErrorType.serverError;
        case DioExceptionType.cancel:
          return NetworkErrorType.unknown;
        case DioExceptionType.unknown:
        default:
          return NetworkErrorType.unknown;
      }
    } else if (error is SocketException) {
      return NetworkErrorType.noNetwork;
    } else if (error is FormatException) {
      return NetworkErrorType.parseError;
    }
    return NetworkErrorType.unknown;
  }
  
  /// 获取错误信息
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return '连接超时，请检查网络设置';
        case DioExceptionType.sendTimeout:
          return '请求超时，请稍后重试';
        case DioExceptionType.receiveTimeout:
          return '响应超时，请稍后重试';
        case DioExceptionType.connectionError:
          return '网络连接失败，请检查网络设置';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final message = error.response?.data?['message'] ?? 
                         error.response?.data?['msg'];
          if (message != null) return message;
          
          if (statusCode != null) {
            switch (statusCode) {
              case 400:
                return '请求参数错误';
              case 401:
                return '未授权，请重新登录';
              case 403:
                return '禁止访问';
              case 404:
                return '请求的资源不存在';
              case 500:
                return '服务器内部错误';
              case 502:
                return '网关错误';
              case 503:
                return '服务不可用';
              default:
                return '请求失败（$statusCode）';
            }
          }
          return '请求失败';
        case DioExceptionType.cancel:
          return '请求已取消';
        case DioExceptionType.unknown:
        default:
          return error.message ?? '未知错误';
      }
    } else if (error is SocketException) {
      return '网络连接失败，请检查网络设置';
    } else if (error is FormatException) {
      return '数据解析失败';
    }
    return error.toString();
  }
  
  /// 创建网络异常
  static NetworkException createNetworkException(dynamic error) {
    return NetworkException(
      message: getErrorMessage(error),
      code: error is DioException ? error.response?.statusCode : null,
      type: getErrorType(error),
      data: error is DioException ? error.response?.data : null,
    );
  }
  
  /// 安全解析JSON
  static Map<String, dynamic>? safeParseJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;
    
    try {
      final decoded = json.decode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (e) {
      // JSON解析失败，返回null
      return null;
    }
  }
  
  /// 脱敏处理敏感数据
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
  

  
  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
  
  /// 判断是否为幂等请求
  static bool isIdempotentRequest(String method) {
    final idempotentMethods = ['GET', 'PUT', 'DELETE', 'HEAD', 'OPTIONS'];
    return idempotentMethods.contains(method.toUpperCase());
  }
  
  /// 生成请求唯一标识
  static String generateRequestId(String path, [Map<String, dynamic>? queryParameters]) {
    final buffer = StringBuffer();
    buffer.write(path);
    
    if (queryParameters != null && queryParameters.isNotEmpty) {
      // 对查询参数进行排序，确保相同参数生成相同ID
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
    
    // 生成哈希作为唯一标识
    final requestString = buffer.toString();
    return requestString.hashCode.toString();
  }
}