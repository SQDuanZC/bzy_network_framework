import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/network_config.dart';
import '../../utils/network_utils.dart';

/// 重试拦截器
/// 实现安全重试策略，仅在网络错误/服务器异常时重试，避免重复提交
class RetryInterceptor extends Interceptor {
  final int maxRetryCount;
  final Duration retryDelay;
  final List<int> retryStatusCodes;
  final bool enableRetryOnTimeout;
  final bool enableRetryOnConnectionError;
  
  RetryInterceptor({
    int? maxRetryCount,
    Duration? retryDelay,
    this.retryStatusCodes = const [500, 502, 503, 504],
    this.enableRetryOnTimeout = true,
    this.enableRetryOnConnectionError = true,
  }) : maxRetryCount = maxRetryCount ?? NetworkConfig.instance.maxRetryCount,
       retryDelay = retryDelay ?? Duration(milliseconds: NetworkConfig.instance.retryDelay);
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final requestOptions = err.requestOptions;
    
    // 检查是否应该重试
    if (_shouldRetry(err, requestOptions)) {
      try {
        // 执行重试
        final response = await _retry(requestOptions);
        handler.resolve(response);
        return;
      } catch (retryError) {
        // 重试失败，返回最后一次的错误
        if (retryError is DioException) {
          handler.reject(retryError);
        } else {
          handler.reject(err);
        }
        return;
      }
    }
    
    super.onError(err, handler);
  }
  
  /// 判断是否应该重试
  bool _shouldRetry(DioException error, RequestOptions requestOptions) {
    // 检查重试次数
    final retryCount = requestOptions.extra['retry_count'] as int? ?? 0;
    if (retryCount >= maxRetryCount) {
      if (kDebugMode) {
        debugPrint('已达到最大重试次数: $maxRetryCount');
      }
      return false;
    }
    
    // 检查请求方法是否为幂等性请求
    if (!NetworkUtils.isIdempotentRequest(requestOptions.method)) {
      // 非幂等性请求（如POST）默认不重试，除非明确标记可重试
      final allowRetry = requestOptions.extra['allow_retry'] as bool? ?? false;
      if (!allowRetry) {
        if (kDebugMode) {
          debugPrint('非幂等性请求，跳过重试: ${requestOptions.method}');
        }
        return false;
      }
    }
    
    // 检查错误类型
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return enableRetryOnTimeout;
        
      case DioExceptionType.connectionError:
        return enableRetryOnConnectionError;
        
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode != null) {
          // 检查状态码是否在重试列表中
          return retryStatusCodes.contains(statusCode);
        }
        return false;
        
      case DioExceptionType.cancel:
        // 用户取消的请求不重试
        return false;
        
      case DioExceptionType.unknown:
        // 检查是否为网络连接错误
        if (error.error is SocketException) {
          return enableRetryOnConnectionError;
        }
        return false;
        
      default:
        return false;
    }
  }
  
  /// 执行重试
  Future<Response> _retry(RequestOptions requestOptions) async {
    final retryCount = requestOptions.extra['retry_count'] as int? ?? 0;
    final newRetryCount = retryCount + 1;
    
    if (kDebugMode) {
      debugPrint('开始第 $newRetryCount 次重试: ${requestOptions.method} ${requestOptions.uri}');
    }
    
    // 更新重试次数
    requestOptions.extra['retry_count'] = newRetryCount;
    
    // 计算延迟时间（指数退避）
    final delay = _calculateDelay(newRetryCount);
    if (delay.inMilliseconds > 0) {
      if (kDebugMode) {
        debugPrint('重试延迟: ${delay.inMilliseconds}ms');
      }
      await Future.delayed(delay);
    }
    
    // 创建新的Dio实例进行重试（避免拦截器循环）
    final dio = Dio();
    
    // 复制基础配置
    dio.options.baseUrl = requestOptions.baseUrl;
    dio.options.connectTimeout = requestOptions.connectTimeout;
    dio.options.receiveTimeout = requestOptions.receiveTimeout;
    dio.options.sendTimeout = requestOptions.sendTimeout;
    dio.options.headers = Map.from(requestOptions.headers);
    
    try {
      final response = await dio.request(
        requestOptions.path,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
        options: Options(
          method: requestOptions.method,
          headers: requestOptions.headers,
          responseType: requestOptions.responseType,
          contentType: requestOptions.contentType,
          validateStatus: requestOptions.validateStatus,
          receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
          extra: requestOptions.extra,
        ),
        cancelToken: requestOptions.cancelToken,
        onSendProgress: requestOptions.onSendProgress,
        onReceiveProgress: requestOptions.onReceiveProgress,
      );
      
      if (kDebugMode) {
        debugPrint('重试成功: ${requestOptions.method} ${requestOptions.uri}');
      }
      return response;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('重试失败: ${requestOptions.method} ${requestOptions.uri}, 错误: $error');
      }
      rethrow;
    }
  }
  
  /// 计算重试延迟时间（指数退避算法）
  Duration _calculateDelay(int retryCount) {
    // 基础延迟时间
    final baseDelay = retryDelay.inMilliseconds;
    
    // 指数退避：delay = baseDelay * (2 ^ (retryCount - 1))
    final exponentialDelay = baseDelay * (1 << (retryCount - 1));
    
    // 添加随机抖动，避免雷群效应
    final jitter = (exponentialDelay * 0.1 * (0.5 - (retryCount % 10) / 10)).round();
    
    // 最大延迟时间限制（30秒）
    final maxDelay = 30000;
    final finalDelay = (exponentialDelay + jitter).clamp(0, maxDelay);
    
    return Duration(milliseconds: finalDelay);
  }
}

/// 重试配置扩展
extension RetryOptionsExtension on RequestOptions {
  /// 设置允许重试（用于非幂等性请求）
  void allowRetry([bool allow = true]) {
    extra['allow_retry'] = allow;
  }
  
  /// 设置禁止重试
  void disableRetry() {
    extra['allow_retry'] = false;
  }
  
  /// 设置自定义重试次数
  void setMaxRetryCount(int count) {
    extra['max_retry_count'] = count;
  }
  
  /// 获取当前重试次数
  int get currentRetryCount => extra['retry_count'] as int? ?? 0;
  
  /// 检查是否允许重试
  bool get isRetryAllowed => extra['allow_retry'] as bool? ?? NetworkUtils.isIdempotentRequest(method);
}