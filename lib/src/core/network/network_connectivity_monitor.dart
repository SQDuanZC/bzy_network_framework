import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logging/logging.dart';

/// 网络连接状态
enum NetworkStatus {
  /// 网络连接正常
  connected,
  /// 网络不可达
  disconnected,
  /// 网络状态未知
  unknown,
}

/// 网络连接类型
enum NetworkType {
  /// WiFi连接
  wifi,
  /// 移动网络
  mobile,
  /// 以太网
  ethernet,
  /// VPN连接
  vpn,
  /// 蓝牙连接
  bluetooth,
  /// 其他连接类型
  other,
  /// 无连接
  none,
}

/// 网络状态变化事件
class NetworkStatusEvent {
  final NetworkStatus status;
  final NetworkType type;
  final DateTime timestamp;
  final String? reason;

  const NetworkStatusEvent({
    required this.status,
    required this.type,
    required this.timestamp,
    this.reason,
  });

  @override
  String toString() {
    return 'NetworkStatusEvent{status: $status, type: $type, timestamp: $timestamp, reason: $reason}';
  }
}

/// 网络连接监听器
class NetworkConnectivityMonitor {
  static final NetworkConnectivityMonitor _instance = NetworkConnectivityMonitor._internal();
  factory NetworkConnectivityMonitor() => _instance;
  NetworkConnectivityMonitor._internal();

  static NetworkConnectivityMonitor get instance => _instance;

  final Logger _logger = Logger('NetworkConnectivityMonitor');
  final Connectivity _connectivity = Connectivity();
  
  StreamSubscription<ConnectivityResult>? _subscription;
  final StreamController<NetworkStatusEvent> _statusController = StreamController<NetworkStatusEvent>.broadcast();
  
  NetworkStatus _currentStatus = NetworkStatus.unknown;
  NetworkType _currentType = NetworkType.none;
  DateTime? _lastStatusChange;
  bool _isInitialized = false;

  /// 当前网络状态
  NetworkStatus get currentStatus => _currentStatus;
  
  /// 当前网络类型
  NetworkType get currentType => _currentType;
  
  /// 最后状态变化时间
  DateTime? get lastStatusChange => _lastStatusChange;
  
  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 网络状态变化流
  Stream<NetworkStatusEvent> get statusStream => _statusController.stream;

  /// 初始化网络监听
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.warning('NetworkConnectivityMonitor already initialized');
      return;
    }

    try {
      // 获取初始网络状态
      final initialResult = await _connectivity.checkConnectivity();
      _updateNetworkStatus([initialResult], 'Initial check');
      
      // 开始监听网络状态变化
      _subscription = _connectivity.onConnectivityChanged.listen(
        (ConnectivityResult result) {
          _updateNetworkStatus([result], 'Status changed');
        },
        onError: (error) {
          _logger.severe('Network connectivity monitoring error: $error');
          _emitStatusEvent(NetworkStatus.unknown, NetworkType.none, 'Monitoring error: $error');
        },
      );
      
      _isInitialized = true;
      _logger.info('NetworkConnectivityMonitor initialized successfully');
    } catch (e) {
      _logger.severe('Failed to initialize NetworkConnectivityMonitor: $e');
      _emitStatusEvent(NetworkStatus.unknown, NetworkType.none, 'Initialization failed: $e');
    }
  }

  /// 停止网络监听
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _statusController.close();
    _isInitialized = false;
    _logger.info('NetworkConnectivityMonitor disposed');
  }

  /// 手动检查网络状态
  Future<NetworkStatus> checkNetworkStatus() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateNetworkStatus([result], 'Manual check');
      return _currentStatus;
    } catch (e) {
      _logger.warning('Failed to check network status: $e');
      return NetworkStatus.unknown;
    }
  }

  /// 检查是否有网络连接
  bool get isConnected => _currentStatus == NetworkStatus.connected;
  
  /// 检查是否为WiFi连接
  bool get isWiFiConnected => _currentType == NetworkType.wifi && isConnected;
  
  /// 检查是否为移动网络连接
  bool get isMobileConnected => _currentType == NetworkType.mobile && isConnected;

  /// 更新网络状态
  void _updateNetworkStatus(List<ConnectivityResult> results, String reason) {
    final previousStatus = _currentStatus;
    final previousType = _currentType;
    
    // 解析连接结果
    final (status, type) = _parseConnectivityResults(results);
    
    // 更新状态
    _currentStatus = status;
    _currentType = type;
    _lastStatusChange = DateTime.now();
    
    // 如果状态发生变化，发出事件
    if (previousStatus != status || previousType != type) {
      _logger.info('Network status changed: $previousStatus->$status, $previousType->$type, reason: $reason');
      _emitStatusEvent(status, type, reason);
    }
  }

  /// 解析连接结果
  (NetworkStatus, NetworkType) _parseConnectivityResults(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return (NetworkStatus.disconnected, NetworkType.none);
    }
    
    // 优先级：WiFi > 以太网 > 移动网络 > VPN > 蓝牙 > 其他
    if (results.contains(ConnectivityResult.wifi)) {
      return (NetworkStatus.connected, NetworkType.wifi);
    }
    
    if (results.contains(ConnectivityResult.ethernet)) {
      return (NetworkStatus.connected, NetworkType.ethernet);
    }
    
    if (results.contains(ConnectivityResult.mobile)) {
      return (NetworkStatus.connected, NetworkType.mobile);
    }
    
    if (results.contains(ConnectivityResult.vpn)) {
      return (NetworkStatus.connected, NetworkType.vpn);
    }
    
    if (results.contains(ConnectivityResult.bluetooth)) {
      return (NetworkStatus.connected, NetworkType.bluetooth);
    }
    
    if (results.contains(ConnectivityResult.other)) {
      return (NetworkStatus.connected, NetworkType.other);
    }
    
    return (NetworkStatus.unknown, NetworkType.none);
  }

  /// 发出状态变化事件
  void _emitStatusEvent(NetworkStatus status, NetworkType type, String? reason) {
    final event = NetworkStatusEvent(
      status: status,
      type: type,
      timestamp: DateTime.now(),
      reason: reason,
    );
    
    if (!_statusController.isClosed) {
      _statusController.add(event);
    }
  }

  /// 等待网络连接
  Future<bool> waitForConnection({Duration? timeout}) async {
    if (isConnected) {
      return true;
    }
    
    final completer = Completer<bool>();
    StreamSubscription<NetworkStatusEvent>? subscription;
    Timer? timeoutTimer;
    
    subscription = statusStream.listen((event) {
      if (event.status == NetworkStatus.connected) {
        timeoutTimer?.cancel();
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });
    
    if (timeout != null) {
      timeoutTimer = Timer(timeout, () {
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });
    }
    
    return completer.future;
  }

  /// 获取网络状态描述
  String getStatusDescription() {
    switch (_currentStatus) {
      case NetworkStatus.connected:
        return '网络已连接 (${_getTypeDescription()})';
      case NetworkStatus.disconnected:
        return '网络不可达';
      case NetworkStatus.unknown:
        return '网络状态未知';
    }
  }

  /// 获取网络类型描述
  String _getTypeDescription() {
    switch (_currentType) {
      case NetworkType.wifi:
        return 'WiFi';
      case NetworkType.mobile:
        return '移动网络';
      case NetworkType.ethernet:
        return '以太网';
      case NetworkType.vpn:
        return 'VPN';
      case NetworkType.bluetooth:
        return '蓝牙';
      case NetworkType.other:
        return '其他';
      case NetworkType.none:
        return '无连接';
    }
  }
}