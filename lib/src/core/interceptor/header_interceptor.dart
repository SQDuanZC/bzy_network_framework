import 'dart:io';
import 'package:dio/dio.dart';

/// 请求头拦截器
/// 负责全局统一添加Token、版本号、设备信息等请求头
class HeaderInterceptor extends Interceptor {
  String? _token;
  String? _refreshToken;
  Map<String, String> _staticHeaders = {};
  final Map<String, String> _deviceInfo = {};
  
  HeaderInterceptor() {
    _initializeDeviceInfo();
  }
  
  /// 设置Token
  void setToken(String? token) {
    _token = token;
  }
  
  /// 设置刷新Token
  void setRefreshToken(String? refreshToken) {
    _refreshToken = refreshToken;
  }
  
  /// 获取当前Token
  String? get token => _token;
  
  /// 获取刷新Token
  String? get refreshToken => _refreshToken;
  
  /// 设置静态请求头
  void setStaticHeaders(Map<String, String> headers) {
    _staticHeaders = Map.from(headers);
  }
  
  /// 添加单个静态请求头
  void addStaticHeader(String key, String value) {
    _staticHeaders[key] = value;
  }
  
  /// 移除静态请求头
  void removeStaticHeader(String key) {
    _staticHeaders.remove(key);
  }
  
  /// 清除所有Token
  void clearTokens() {
    _token = null;
    _refreshToken = null;
  }
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 添加基础请求头
    _addBasicHeaders(options);
    
    // 添加认证头
    _addAuthHeaders(options);
    
    // 添加设备信息头
    _addDeviceHeaders(options);
    
    // 添加静态请求头
    _addStaticHeaders(options);
    
    super.onRequest(options, handler);
  }
  
  /// 添加基础请求头
  void _addBasicHeaders(RequestOptions options) {
    // Content-Type
    if (!options.headers.containsKey('Content-Type')) {
      if (options.data is FormData) {
        options.headers['Content-Type'] = 'multipart/form-data';
      } else {
        options.headers['Content-Type'] = 'application/json; charset=utf-8';
      }
    }
    
    // Accept
    if (!options.headers.containsKey('Accept')) {
      options.headers['Accept'] = 'application/json';
    }
    
    // Accept-Encoding
    if (!options.headers.containsKey('Accept-Encoding')) {
      options.headers['Accept-Encoding'] = 'gzip, deflate, br';
    }
    
    // User-Agent
    if (!options.headers.containsKey('User-Agent')) {
      options.headers['User-Agent'] = _generateUserAgent();
    }
    
    // 请求ID（用于链路追踪）
    if (!options.headers.containsKey('X-Request-ID')) {
      options.headers['X-Request-ID'] = _generateRequestId();
    }
    
    // 时间戳
    options.headers['X-Timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();
  }
  
  /// 添加认证请求头
  void _addAuthHeaders(RequestOptions options) {
    // 添加访问Token
    if (_token != null && _token!.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $_token';
    }
    
    // 添加刷新Token（如果需要）
    if (_refreshToken != null && _refreshToken!.isNotEmpty) {
      options.headers['X-Refresh-Token'] = _refreshToken;
    }
  }
  
  /// 添加设备信息请求头
  void _addDeviceHeaders(RequestOptions options) {
    _deviceInfo.forEach((key, value) {
      if (!options.headers.containsKey(key)) {
        options.headers[key] = value;
      }
    });
  }
  
  /// 添加静态请求头
  void _addStaticHeaders(RequestOptions options) {
    _staticHeaders.forEach((key, value) {
      options.headers[key] = value;
    });
  }
  
  /// 初始化设备信息
  Future<void> _initializeDeviceInfo() async {
    try {
      // 设置基础应用信息（可在实际项目中通过package_info_plus获取）
      _deviceInfo['X-App-Version'] = '1.0.0';
      _deviceInfo['X-App-Build'] = '1';
      _deviceInfo['X-App-Package'] = 'com.example.app';
      
      // 设置基础设备信息
      _deviceInfo['X-Platform'] = Platform.operatingSystem;
      _deviceInfo['X-Platform-Version'] = Platform.operatingSystemVersion;
      
      // 根据平台设置更多信息
      if (Platform.isAndroid) {
        _deviceInfo['X-Platform'] = 'Android';
      } else if (Platform.isIOS) {
        _deviceInfo['X-Platform'] = 'iOS';
      } else if (Platform.isMacOS) {
        _deviceInfo['X-Platform'] = 'macOS';
      } else if (Platform.isWindows) {
        _deviceInfo['X-Platform'] = 'Windows';
      } else if (Platform.isLinux) {
        _deviceInfo['X-Platform'] = 'Linux';
      }
      
      // 注意：要获取详细的设备信息，请安装并导入以下包：
      // - package_info_plus: 获取应用信息
      // - device_info_plus: 获取设备详细信息
      
    } catch (e) {
      // 获取设备信息失败: $e
      // 设置默认值
      _deviceInfo['X-Platform'] = Platform.operatingSystem;
      _deviceInfo['X-Platform-Version'] = Platform.operatingSystemVersion;
    }
  }
  
  /// 生成User-Agent
  String _generateUserAgent() {
    final platform = _deviceInfo['X-Platform'] ?? Platform.operatingSystem;
    final version = _deviceInfo['X-App-Version'] ?? '1.0.0';
    final build = _deviceInfo['X-App-Build'] ?? '1';
    
    return 'MyApp/$version ($platform; Build $build)';
  }
  
  /// 生成请求ID
  String _generateRequestId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'req_${timestamp}_$random';
  }
  
  /// 获取设备信息
  Map<String, String> get deviceInfo => Map.unmodifiable(_deviceInfo);
  
  /// 获取静态请求头
  Map<String, String> get staticHeaders => Map.unmodifiable(_staticHeaders);
}