import 'dart:convert';
import 'package:dio/dio.dart';
import '../../config/network_config.dart';
import '../../utils/network_utils.dart';
import '../../utils/network_logger.dart';

/// 日志拦截器
/// 负责输出完整的请求和响应日志，支持敏感数据脱敏
class LoggingInterceptor extends Interceptor {
  final bool enableRequest;
  final bool enableResponse;
  final bool enableError;
  final int maxLogLength;
  
  LoggingInterceptor({
    this.enableRequest = true,
    this.enableResponse = true,
    this.enableError = true,
    this.maxLogLength = 1000,
  });
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (NetworkConfig.instance.enableLogging && enableRequest) {
      _logRequest(options);
    }
    super.onRequest(options, handler);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (NetworkConfig.instance.enableLogging && enableResponse) {
      _logResponse(response);
    }
    super.onResponse(response, handler);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (NetworkConfig.instance.enableLogging && enableError) {
      _logError(err);
    }
    super.onError(err, handler);
  }
  
  /// 记录请求日志
  void _logRequest(RequestOptions options) {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    options.extra['start_time'] = startTime;
    
    NetworkLogger.interceptor.info('\n┌─────────────────────────────────────────────────────────────');
    NetworkLogger.interceptor.info('│ 🚀 REQUEST');
    NetworkLogger.interceptor.info('├─────────────────────────────────────────────────────────────');
    NetworkLogger.interceptor.info('│ Method: ${options.method}');
    NetworkLogger.interceptor.info('│ URL: ${options.uri}');
    NetworkLogger.interceptor.info('│ Time: ${DateTime.now().toIso8601String()}');
    
    // 请求头
    if (options.headers.isNotEmpty) {
      NetworkLogger.interceptor.info('│ Headers:');
      final desensitizedHeaders = NetworkUtils.desensitizeData(
        Map<String, dynamic>.from(options.headers)
      );
      desensitizedHeaders.forEach((key, value) {
        NetworkLogger.interceptor.info('│   $key: $value');
      });
    }
    
    // 查询参数
    if (options.queryParameters.isNotEmpty) {
      NetworkLogger.interceptor.info('│ Query Parameters:');
      options.queryParameters.forEach((key, value) {
        NetworkLogger.interceptor.info('│   $key: $value');
      });
    }
    
    // 请求体
    if (options.data != null) {
      NetworkLogger.interceptor.info('│ Body:');
      final bodyStr = _formatData(options.data);
      final lines = bodyStr.split('\n');
      for (final line in lines) {
        if (line.isNotEmpty) {
          NetworkLogger.interceptor.info('│   $line');
        }
      }
    }
    
    NetworkLogger.interceptor.info('└─────────────────────────────────────────────────────────────\n');
  }
  
  /// 记录响应日志
  void _logResponse(Response response) {
    final startTime = response.requestOptions.extra['start_time'] as int?;
    final duration = startTime != null 
        ? DateTime.now().millisecondsSinceEpoch - startTime 
        : 0;
    
    NetworkLogger.interceptor.info('\n┌─────────────────────────────────────────────────────────────');
    NetworkLogger.interceptor.info('│ ✅ RESPONSE');
    NetworkLogger.interceptor.info('├─────────────────────────────────────────────────────────────');
    NetworkLogger.interceptor.info('│ Method: ${response.requestOptions.method}');
    NetworkLogger.interceptor.info('│ URL: ${response.requestOptions.uri}');
    NetworkLogger.interceptor.info('│ Status Code: ${response.statusCode}');
    NetworkLogger.interceptor.info('│ Duration: ${duration}ms');
    NetworkLogger.interceptor.info('│ Time: ${DateTime.now().toIso8601String()}');
    
    // 响应头
    if (response.headers.map.isNotEmpty) {
      NetworkLogger.interceptor.info('│ Headers:');
      response.headers.map.forEach((key, value) {
        NetworkLogger.interceptor.info('│   $key: ${value.join(', ')}');
      });
    }
    
    // 响应体
    if (response.data != null) {
      NetworkLogger.interceptor.info('│ Body:');
      final bodyStr = _formatData(response.data);
      final truncatedBody = bodyStr.length > maxLogLength 
          ? '${bodyStr.substring(0, maxLogLength)}...\n│   [数据过长，已截断]'
          : bodyStr;
      
      final lines = truncatedBody.split('\n');
      for (final line in lines) {
        if (line.isNotEmpty) {
          NetworkLogger.interceptor.info('│   $line');
        }
      }
    }
    
    NetworkLogger.interceptor.info('└─────────────────────────────────────────────────────────────\n');
  }
  
  /// 记录错误日志
  void _logError(DioException error) {
    final startTime = error.requestOptions.extra['start_time'] as int?;
    final duration = startTime != null 
        ? DateTime.now().millisecondsSinceEpoch - startTime 
        : 0;
    
    NetworkLogger.interceptor.severe('\n┌─────────────────────────────────────────────────────────────');
    NetworkLogger.interceptor.severe('│ ❌ ERROR');
    NetworkLogger.interceptor.severe('├─────────────────────────────────────────────────────────────');
    NetworkLogger.interceptor.severe('│ Method: ${error.requestOptions.method}');
    NetworkLogger.interceptor.severe('│ URL: ${error.requestOptions.uri}');
    NetworkLogger.interceptor.severe('│ Error Type: ${error.type}');
    NetworkLogger.interceptor.severe('│ Duration: ${duration}ms');
    NetworkLogger.interceptor.severe('│ Time: ${DateTime.now().toIso8601String()}');
    
    if (error.response != null) {
      NetworkLogger.interceptor.severe('│ Status Code: ${error.response!.statusCode}');
      NetworkLogger.interceptor.severe('│ Status Message: ${error.response!.statusMessage}');
      
      if (error.response!.data != null) {
        NetworkLogger.interceptor.severe('│ Error Body:');
        final bodyStr = _formatData(error.response!.data);
        final lines = bodyStr.split('\n');
        for (final line in lines) {
          if (line.isNotEmpty) {
            NetworkLogger.interceptor.severe('│   $line');
          }
        }
      }
    }
    
    if (error.message != null) {
      NetworkLogger.interceptor.severe('│ Message: ${error.message}');
    }
    
    NetworkLogger.interceptor.severe('└─────────────────────────────────────────────────────────────\n');
  }
  
  /// 格式化数据为字符串
  String _formatData(dynamic data) {
    try {
      if (data is Map || data is List) {
        // 对敏感数据进行脱敏处理
        dynamic processedData = data;
        if (data is Map<String, dynamic>) {
          processedData = NetworkUtils.desensitizeData(data);
        }
        
        const encoder = JsonEncoder.withIndent('  ');
        return encoder.convert(processedData);
      } else if (data is String) {
        // 尝试解析JSON字符串
        try {
          final decoded = json.decode(data);
          if (decoded is Map<String, dynamic>) {
            final desensitized = NetworkUtils.desensitizeData(decoded);
            const encoder = JsonEncoder.withIndent('  ');
            return encoder.convert(desensitized);
          }
          return data;
        } catch (_) {
          return data;
        }
      }
      return data.toString();
    } catch (e) {
      return data.toString();
    }
  }
}