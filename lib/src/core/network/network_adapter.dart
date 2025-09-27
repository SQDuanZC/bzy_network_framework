import 'dart:async';
import 'package:logging/logging.dart';
import 'network_connectivity_monitor.dart';
import '../exception/unified_exception_handler.dart';
import '../exception/network_exception.dart';
import '../../utils/network_utils.dart';

/// 网络适配策略
enum NetworkAdaptationStrategy {
  /// 立即失败
  failImmediately,
  /// 等待网络恢复
  waitForConnection,
  /// 使用缓存数据
  useCachedData,
  /// 自动重试
  autoRetry,
}

/// 网络适配配置
class NetworkAdapterConfig {
  /// 网络检查超时时间
  final Duration networkCheckTimeout;
  
  /// 等待网络连接的最大时间
  final Duration maxWaitTime;
  
  /// 自动重试次数
  final int maxRetryAttempts;
  
  /// 重试间隔
  final Duration retryInterval;
  
  /// 默认适配策略
  final NetworkAdaptationStrategy defaultStrategy;
  
  /// 是否启用网络质量检测
  final bool enableNetworkQualityCheck;
  
  /// 网络质量检测间隔
  final Duration qualityCheckInterval;

  NetworkAdapterConfig({
    this.networkCheckTimeout = const Duration(seconds: 5),
    this.maxWaitTime = const Duration(seconds: 30),
    this.maxRetryAttempts = 3,
    this.retryInterval = const Duration(seconds: 2),
    this.defaultStrategy = NetworkAdaptationStrategy.autoRetry,
    this.enableNetworkQualityCheck = true,
    this.qualityCheckInterval = const Duration(minutes: 1),
  }) : assert(networkCheckTimeout.inMilliseconds > 0, 'networkCheckTimeout must be positive'),
       assert(maxWaitTime.inMilliseconds > 0, 'maxWaitTime must be positive'),
       assert(maxRetryAttempts >= 0, 'maxRetryAttempts must be non-negative'),
       assert(retryInterval.inMilliseconds >= 0, 'retryInterval must be non-negative'),
       assert(qualityCheckInterval.inMilliseconds > 0, 'qualityCheckInterval must be positive');
}

/// 网络质量信息
class NetworkQuality {
  /// 网络延迟（毫秒）
  final int latency;
  
  /// 网络质量等级（1-5，5为最好）
  final int qualityLevel;
  
  /// 检测时间
  final DateTime timestamp;
  
  /// 是否为弱网环境
  final bool isWeakNetwork;

  const NetworkQuality({
    required this.latency,
    required this.qualityLevel,
    required this.timestamp,
    required this.isWeakNetwork,
  });

  @override
  String toString() {
    return 'NetworkQuality{latency: ${latency}ms, level: $qualityLevel, weak: $isWeakNetwork}';
  }
}

/// 网络适配器
class NetworkAdapter {
  static final NetworkAdapter _instance = NetworkAdapter._internal();
  factory NetworkAdapter() => _instance;
  NetworkAdapter._internal();

  static NetworkAdapter get instance => _instance;

  final Logger _logger = Logger('NetworkAdapter');
  final NetworkConnectivityMonitor _connectivityMonitor = NetworkConnectivityMonitor.instance;
  
  NetworkAdapterConfig _config = NetworkAdapterConfig();
  NetworkQuality? _lastQuality;
  Timer? _qualityCheckTimer;
  bool _isInitialized = false;
  
  /// 当前配置
  NetworkAdapterConfig get config => _config;
  
  /// 最后检测的网络质量
  NetworkQuality? get lastQuality => _lastQuality;
  
  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 初始化网络适配器
  Future<void> initialize({NetworkAdapterConfig? config}) async {
    if (_isInitialized) {
      _logger.warning('NetworkAdapter already initialized');
      return;
    }

    _config = config ?? _config;
    
    try {
      // 初始化网络连接监听器
      await _connectivityMonitor.initialize();
      
      // 监听网络状态变化
      _connectivityMonitor.statusStream.listen(_onNetworkStatusChanged);
      
      // 启动网络质量检测
      if (_config.enableNetworkQualityCheck) {
        _startQualityMonitoring();
      }
      
      _isInitialized = true;
      _logger.info('NetworkAdapter initialized successfully');
    } catch (e) {
      _logger.severe('Failed to initialize NetworkAdapter: $e');
      rethrow;
    }
  }

  /// 停止网络适配器
  Future<void> dispose() async {
    _qualityCheckTimer?.cancel();
    _qualityCheckTimer = null;
    await _connectivityMonitor.dispose();
    _isInitialized = false;
    _logger.info('NetworkAdapter disposed');
  }

  /// 更新配置
  void updateConfig(NetworkAdapterConfig config) {
    _config = config;
    
    // 重新启动质量监控
    if (_config.enableNetworkQualityCheck && _qualityCheckTimer == null) {
      _startQualityMonitoring();
    } else if (!_config.enableNetworkQualityCheck && _qualityCheckTimer != null) {
      _qualityCheckTimer?.cancel();
      _qualityCheckTimer = null;
    }
    
    _logger.info('NetworkAdapter config updated');
  }

  /// 检查网络可用性
  Future<bool> checkNetworkAvailability() async {
    try {
      // 首先检查连接状态
      if (!_connectivityMonitor.isConnected) {
        return false;
      }
      
      // 进行实际网络连通性测试
      return await NetworkUtils.isNetworkAvailable()
          .timeout(_config.networkCheckTimeout);
    } catch (e) {
      _logger.warning('Network availability check failed: $e');
      return false;
    }
  }

  /// 等待网络连接
  Future<bool> waitForConnection({Duration? timeout}) async {
    final waitTimeout = timeout ?? _config.maxWaitTime;
    return await _connectivityMonitor.waitForConnection(timeout: waitTimeout);
  }

  /// 执行网络请求（带适配策略）
  Future<T> executeWithAdaptation<T>(
    Future<T> Function() request, {
    NetworkAdaptationStrategy? strategy,
    T? cachedData,
  }) async {
    final adaptationStrategy = strategy ?? _config.defaultStrategy;
    
    // 检查网络状态
    final isNetworkAvailable = await checkNetworkAvailability();
    
    if (isNetworkAvailable) {
      // 网络可用，直接执行请求
      try {
        return await request();
      } catch (e) {
        // 请求失败，根据策略处理
        return await _handleRequestFailure(request, e, adaptationStrategy, cachedData);
      }
    } else {
      // 网络不可用，根据策略处理
      return await _handleNetworkUnavailable(request, adaptationStrategy, cachedData);
    }
  }

  /// 检测网络质量
  Future<NetworkQuality> checkNetworkQuality() async {
    final startTime = DateTime.now();
    
    try {
      // 执行网络延迟测试
      final isAvailable = await NetworkUtils.isNetworkAvailable()
          .timeout(const Duration(seconds: 5));
      
      final endTime = DateTime.now();
      final latency = endTime.difference(startTime).inMilliseconds;
      
      if (!isAvailable) {
        return NetworkQuality(
          latency: 9999,
          qualityLevel: 0,
          timestamp: endTime,
          isWeakNetwork: true,
        );
      }
      
      // 根据延迟判断网络质量
      final qualityLevel = _calculateQualityLevel(latency);
      final isWeakNetwork = qualityLevel <= 2;
      
      final quality = NetworkQuality(
        latency: latency,
        qualityLevel: qualityLevel,
        timestamp: endTime,
        isWeakNetwork: isWeakNetwork,
      );
      
      _lastQuality = quality;
      _logger.fine('Network quality checked: $quality');
      
      return quality;
    } catch (e) {
      _logger.warning('Network quality check failed: $e');
      
      final quality = NetworkQuality(
        latency: 9999,
        qualityLevel: 0,
        timestamp: DateTime.now(),
        isWeakNetwork: true,
      );
      
      _lastQuality = quality;
      return quality;
    }
  }

  /// 获取推荐的超时时间
  Duration getRecommendedTimeout({Duration? baseTimeout}) {
    final base = baseTimeout ?? const Duration(seconds: 10);
    
    if (_lastQuality == null) {
      return base;
    }
    
    // 根据网络质量调整超时时间
    switch (_lastQuality!.qualityLevel) {
      case 5: // 优秀
        return Duration(milliseconds: (base.inMilliseconds * 0.8).round());
      case 4: // 良好
        return base;
      case 3: // 一般
        return Duration(milliseconds: (base.inMilliseconds * 1.5).round());
      case 2: // 较差
        return Duration(milliseconds: (base.inMilliseconds * 2.0).round());
      case 1: // 很差
        return Duration(milliseconds: (base.inMilliseconds * 3.0).round());
      default: // 无网络
        return Duration(milliseconds: (base.inMilliseconds * 5.0).round());
    }
  }

  /// 获取推荐的重试次数
  int getRecommendedRetryCount({int? baseRetryCount}) {
    final base = baseRetryCount ?? _config.maxRetryAttempts;
    
    if (_lastQuality == null) {
      return base;
    }
    
    // 根据网络质量调整重试次数
    if (_lastQuality!.isWeakNetwork) {
      return (base * 1.5).round();
    } else {
      return base;
    }
  }

  /// 处理网络状态变化
  void _onNetworkStatusChanged(NetworkStatusEvent event) {
    _logger.info('Network status changed: ${event.status} (${event.type})');
    
    if (event.status == NetworkStatus.connected) {
      // 网络恢复，立即检测网络质量
      if (_config.enableNetworkQualityCheck) {
        checkNetworkQuality();
      }
    }
  }

  /// 启动网络质量监控
  void _startQualityMonitoring() {
    _qualityCheckTimer?.cancel();
    
    _qualityCheckTimer = Timer.periodic(_config.qualityCheckInterval, (timer) {
      if (_connectivityMonitor.isConnected) {
        checkNetworkQuality();
      }
    });
    
    // 立即执行一次检测
    if (_connectivityMonitor.isConnected) {
      checkNetworkQuality();
    }
  }

  /// 计算网络质量等级
  int _calculateQualityLevel(int latency) {
    if (latency <= 50) return 5;   // 优秀
    if (latency <= 100) return 4;  // 良好
    if (latency <= 200) return 3;  // 一般
    if (latency <= 500) return 2;  // 较差
    if (latency <= 1000) return 1; // 很差
    return 0; // 无网络
  }

  /// 处理请求失败
  Future<T> _handleRequestFailure<T>(
    Future<T> Function() request,
    dynamic error,
    NetworkAdaptationStrategy strategy,
    T? cachedData,
  ) async {
    _logger.warning('Request failed: $error, strategy: $strategy');
    
    switch (strategy) {
      case NetworkAdaptationStrategy.failImmediately:
        throw error;
        
      case NetworkAdaptationStrategy.waitForConnection:
        final connected = await waitForConnection();
        if (connected) {
          return await request();
        } else {
          throw NetworkException(message: 'Network connection timeout', originalError: error);
        }
        
      case NetworkAdaptationStrategy.useCachedData:
        if (cachedData != null) {
          _logger.info('Using cached data due to network failure');
          return cachedData;
        } else {
          throw NetworkException(message: 'No cached data available', originalError: error);
        }
        
      case NetworkAdaptationStrategy.autoRetry:
        return await _retryRequest(request, error);
    }
  }

  /// 处理网络不可用
  Future<T> _handleNetworkUnavailable<T>(
    Future<T> Function() request,
    NetworkAdaptationStrategy strategy,
    T? cachedData,
  ) async {
    _logger.warning('Network unavailable, strategy: $strategy');
    
    switch (strategy) {
      case NetworkAdaptationStrategy.failImmediately:
        throw NetworkException(message: 'Network not available');
        
      case NetworkAdaptationStrategy.waitForConnection:
        final connected = await waitForConnection();
        if (connected) {
          return await request();
        } else {
          throw NetworkException(message: 'Network connection timeout');
        }
        
      case NetworkAdaptationStrategy.useCachedData:
        if (cachedData != null) {
          _logger.info('Using cached data due to network unavailability');
          return cachedData;
        } else {
          throw NetworkException(message: 'Network not available and no cached data');
        }
        
      case NetworkAdaptationStrategy.autoRetry:
        // 等待网络恢复后重试
        final connected = await waitForConnection();
        if (connected) {
          return await request();
        } else {
          throw NetworkException(message: 'Network connection timeout after retry');
        }
    }
  }

  /// 自动重试请求
  Future<T> _retryRequest<T>(Future<T> Function() request, dynamic originalError) async {
    int attempts = 0;
    dynamic lastError = originalError;
    
    while (attempts < _config.maxRetryAttempts) {
      attempts++;
      
      // 等待重试间隔
      await Future.delayed(_config.retryInterval);
      
      // 检查网络状态
      final isAvailable = await checkNetworkAvailability();
      if (!isAvailable) {
        _logger.fine('Network still unavailable, attempt $attempts/${_config.maxRetryAttempts}');
        continue;
      }
      
      try {
        _logger.fine('Retrying request, attempt $attempts/${_config.maxRetryAttempts}');
        return await request();
      } catch (e) {
        lastError = e;
        _logger.warning('Retry attempt $attempts failed: $e');
      }
    }
    
    throw NetworkException(message: 'Request failed after ${_config.maxRetryAttempts} retry attempts', originalError: lastError);
  }
}