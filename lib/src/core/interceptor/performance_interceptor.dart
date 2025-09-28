import 'package:dio/dio.dart';
import 'interceptor_manager.dart';

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