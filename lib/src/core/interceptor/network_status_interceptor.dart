import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'interceptor_manager.dart';
import '../network/network_connectivity_monitor.dart';
import '../network/network_adapter.dart';
import '../exception/network_exception.dart';

/// 网络状态拦截器配置
class NetworkStatusInterceptorConfig {
  /// 是否启用网络状态检查
  final bool enableNetworkCheck;
  
  /// 是否启用自动重试
  final bool enableAutoRetry;
  
  /// 是否启用网络质量适配
  final bool enableQualityAdaptation;
  
  /// 网络不可达时的处理策略
  final NetworkAdaptationStrategy networkUnavailableStrategy;
  
  /// 是否在请求前检查网络状态
  final bool checkBeforeRequest;
  
  /// 是否在响应错误时检查网络状态
  final bool checkOnError;
  
  /// 出错时是否继续执行后续拦截器
  final bool continueOnError;

  const NetworkStatusInterceptorConfig({
    this.enableNetworkCheck = true,
    this.enableAutoRetry = true,
    this.enableQualityAdaptation = true,
    this.networkUnavailableStrategy = NetworkAdaptationStrategy.autoRetry,
    this.checkBeforeRequest = true,
    this.checkOnError = true,
    this.continueOnError = false,
  });
}

/// 网络状态拦截器
/// 负责在请求前后检查网络状态，并根据网络质量调整请求参数
class NetworkStatusInterceptor extends PluginInterceptor {
  final Logger _logger = Logger('NetworkStatusInterceptor');
  final NetworkConnectivityMonitor _connectivityMonitor = NetworkConnectivityMonitor.instance;
  final NetworkAdapter _networkAdapter = NetworkAdapter.instance;
  final NetworkStatusInterceptorConfig _config;

  NetworkStatusInterceptor({
    NetworkStatusInterceptorConfig? config,
  }) : _config = config ?? const NetworkStatusInterceptorConfig();

  @override
  Future<RequestOptions> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_config.enableNetworkCheck || !_config.checkBeforeRequest) {
      return options;
    }

    try {
      // 检查网络连接状态
      final isConnected = _connectivityMonitor.isConnected;
      if (!isConnected) {
        _logger.warning('Network not available for ${options.uri}');
        
        if (_config.networkUnavailableStrategy == NetworkAdaptationStrategy.waitForConnection) {
          await _networkAdapter.waitForConnection();
        } else if (_config.networkUnavailableStrategy == NetworkAdaptationStrategy.failImmediately) {
          throw NetworkException(
            message: 'Network not available',
            originalError: null,
          );
        }
      }

      // 根据网络质量调整请求参数
      if (_config.enableQualityAdaptation) {
        final quality = await _networkAdapter.checkNetworkQuality();
        final recommendedTimeout = _networkAdapter.getRecommendedTimeout();
        
        options.connectTimeout = recommendedTimeout;
        options.receiveTimeout = recommendedTimeout;
        _logger.fine('Adjusted timeout to ${recommendedTimeout.inMilliseconds}ms for ${quality.qualityLevel} network quality');
      }

      _logger.fine('Network check passed for ${options.uri}');
      return options;
    } catch (e) {
      _logger.severe('Network status check failed: $e');
      
      if (_config.continueOnError) {
        return options;
      } else {
        throw DioException(
          requestOptions: options,
          error: NetworkException(
            message: 'Network status check failed',
            originalError: e,
          ),
          type: DioExceptionType.unknown,
        );
      }
    }
  }

  @override
  Future<Response> onResponse(Response response, ResponseInterceptorHandler handler) async {
    _logger.fine('Request successful to ${response.requestOptions.uri}');
    return response;
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_config.enableNetworkCheck || !_config.checkOnError) {
      // 继续传递错误
      return;
    }

    try {
      // 检查是否为网络相关错误
      if (_isNetworkError(err)) {
        _logger.warning('Network error detected: ${err.message}');
        
        // 检查当前网络状态
        final isConnected = _connectivityMonitor.isConnected;
        if (!isConnected) {
          _logger.warning('Network connection lost');
          
          // 根据策略处理网络断开
          if (_config.networkUnavailableStrategy == NetworkAdaptationStrategy.waitForConnection) {
            await _networkAdapter.waitForConnection();
          }
        }
      }

      // 继续传递错误
    } catch (e) {
      _logger.severe('Error handling network error: $e');
    }
  }

  /// 判断是否为网络相关错误
  bool _isNetworkError(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
           error.type == DioExceptionType.sendTimeout ||
           error.type == DioExceptionType.receiveTimeout ||
           error.type == DioExceptionType.connectionError;
  }

  @override
  String get name => 'network_status';
  
  @override
  String get version => '1.0.0';

  @override
  String get description => 'Monitors network status and adapts requests based on network quality';
  
  /// 获取统计信息
  Map<String, dynamic> getStatistics() {
    return {
      'network_status': _connectivityMonitor.currentStatus.toString(),
      'network_type': _connectivityMonitor.currentType.toString(),
      'network_quality': _networkAdapter.lastQuality?.toString() ?? 'Unknown',
      'last_status_change': _connectivityMonitor.lastStatusChange?.toIso8601String(),
    };
  }
}