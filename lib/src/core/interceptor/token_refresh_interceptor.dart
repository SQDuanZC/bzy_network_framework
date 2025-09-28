import 'dart:async';
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:synchronized/synchronized.dart';
import 'interceptor_manager.dart';

/// Token自动刷新拦截器
/// 处理Token过期自动刷新、并发请求等待、刷新失败处理
class TokenRefreshInterceptor extends PluginInterceptor {
  final Dio _dio;
  
  @override
  String get name => 'token_refresh';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => 'Token自动刷新拦截器';
  
  // Token刷新配置
  late TokenRefreshConfig _config;
  
  // 是否正在刷新Token
  bool _isRefreshing = false;
  
  // 等待刷新完成的请求队列
  final List<_PendingRequest> _pendingRequests = [];
  
  // 刷新Token的Completer
  Completer<bool>? _refreshCompleter;
  
  // 刷新失败次数
  int _refreshFailureCount = 0;
  
  // 最后刷新时间
  DateTime? _lastRefreshTime;
  
  // 并发控制锁
  final Lock _refreshLock = Lock();
  
  TokenRefreshInterceptor(TokenRefreshConfig config) : _dio = Dio() {
    _config = config;
  }
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 检查是否需要预防性刷新Token
    if (_shouldPreventiveRefresh(options)) {
      _performPreventiveRefresh(options, handler);
      return;
    }
    
    super.onRequest(options, handler);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // 重置刷新失败计数
    if (response.statusCode == 200) {
      _refreshFailureCount = 0;
    }
    
    super.onResponse(response, handler);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 检查是否是Token过期错误
    if (_isTokenExpiredError(err)) {
      try {
        // 尝试刷新Token并重试请求
        final success = await _handleTokenExpired(err.requestOptions);
        if (success) {
          // Token刷新成功，重试原请求
          final response = await _retryRequest(err.requestOptions);
          handler.resolve(response);
          return;
        }
      } catch (e) {
        // Token刷新处理失败: $e
      }
    }
    
    super.onError(err, handler);
  }
  
  /// 检查是否应该预防性刷新Token
  bool _shouldPreventiveRefresh(RequestOptions options) {
    if (!_config.enablePreventiveRefresh) return false;
    if (_isRefreshTokenRequest(options)) return false;
    if (_isRefreshing) return false;
    
    // 检查Token是否即将过期
    final token = _getTokenFromOptions(options);
    if (token == null) return false;
    
    return _isTokenNearExpiry(token);
  }
  
  /// 执行预防性刷新
  void _performPreventiveRefresh(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final success = await _refreshToken();
      if (success) {
        // 更新请求的Token
        _updateRequestToken(options);
      }
    } catch (e) {
      // 预防性Token刷新失败: $e
    }
    
    handler.next(options);
  }
  
  /// 检查是否是Token过期错误
  bool _isTokenExpiredError(DioException error) {
    // 检查状态码
    if (error.response?.statusCode == 401) {
      return true;
    }
    
    // 检查错误消息
    final errorMessage = error.response?.data?.toString().toLowerCase() ?? '';
    return _config.tokenExpiredMessages.any((msg) => errorMessage.contains(msg.toLowerCase()));
  }
  
  /// 处理Token过期
  Future<bool> _handleTokenExpired(RequestOptions options) async {
    // 如果是刷新Token的请求失败，直接返回失败
    if (_isRefreshTokenRequest(options)) {
      _handleRefreshTokenFailure();
      return false;
    }
    
    // 如果正在刷新，等待刷新完成
    if (_isRefreshing) {
      return await _waitForRefreshCompletion();
    }
    
    // 执行Token刷新
    return await _refreshToken();
  }
  
  /// 刷新Token
  Future<bool> _refreshToken() async {
    return await _refreshLock.synchronized(() async {
      if (_isRefreshing) {
        return await _waitForRefreshCompletion();
      }
      
      _isRefreshing = true;
      _refreshCompleter = Completer<bool>();
      
      try {
        // 检查刷新频率限制
        if (_isRefreshTooFrequent()) {
          throw Exception('Token刷新过于频繁');
        }
        
        // 检查刷新失败次数
        if (_refreshFailureCount >= _config.maxRefreshRetries) {
          throw Exception('Token刷新失败次数过多');
        }
        
        // 获取刷新Token
        final refreshToken = await _getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          throw Exception('刷新Token不存在');
        }
        
        // 执行刷新请求
        final response = await _performRefreshRequest(refreshToken);
        
        // 解析新Token
        final newTokens = _parseRefreshResponse(response);
        if (newTokens == null) {
          throw Exception('刷新响应解析失败');
        }
        
        // 保存新Token
        await _saveNewTokens(newTokens);
        
        // 更新最后刷新时间
        _lastRefreshTime = DateTime.now();
        
        // 重置失败计数
        _refreshFailureCount = 0;
        
        // 处理等待的请求
        _processPendingRequests(true);
        
        _refreshCompleter!.complete(true);
        return true;
      } catch (e) {
        // Token刷新失败: $e
        _refreshFailureCount++;
        
        // 处理等待的请求
        _processPendingRequests(false);
        
        _refreshCompleter!.complete(false);
        
        // 如果刷新失败次数过多，触发登出
        if (_refreshFailureCount >= _config.maxRefreshRetries) {
          _handleRefreshTokenFailure();
        }
        
        return false;
      } finally {
        _isRefreshing = false;
        _refreshCompleter = null;
      }
    });
  }
  
  /// 等待刷新完成
  Future<bool> _waitForRefreshCompletion() async {
    if (_refreshCompleter != null) {
      return await _refreshCompleter!.future;
    }
    return false;
  }
  
  /// 执行刷新请求
  Future<Response> _performRefreshRequest(String refreshToken) async {
    final options = Options(
      headers: {
        'Content-Type': 'application/json',
        if (_config.refreshTokenHeader != null)
          _config.refreshTokenHeader!: refreshToken,
      },
    );
    
    final data = _config.refreshTokenInBody
        ? {_config.refreshTokenKey: refreshToken}
        : null;
    
    return await _dio.post(
      _config.refreshEndpoint,
      data: data,
      options: options,
    );
  }
  
  /// 解析刷新响应
  TokenPair? _parseRefreshResponse(Response response) {
    try {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final accessToken = data[_config.accessTokenKey] as String?;
        final refreshToken = data[_config.refreshTokenKey] as String?;
        
        if (accessToken != null) {
          return TokenPair(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: data[_config.expiresInKey] as int?,
          );
        }
      }
      return null;
    } catch (e) {
      // 解析刷新响应失败: $e
      return null;
    }
  }
  
  /// 保存新Token
  Future<void> _saveNewTokens(TokenPair tokens) async {
    if (_config.onTokenRefreshed != null) {
      await _config.onTokenRefreshed!(tokens);
    }
  }
  
  /// 获取刷新Token
  Future<String?> _getRefreshToken() async {
    if (_config.getRefreshToken != null) {
      return await _config.getRefreshToken!();
    }
    return null;
  }
  
  /// 处理等待的请求
  void _processPendingRequests(bool success) {
    for (final pendingRequest in _pendingRequests) {
      if (success) {
        // 更新请求Token并重试
        _updateRequestToken(pendingRequest.options);
        _retryRequest(pendingRequest.options).then((response) {
          pendingRequest.completer.complete(response);
        }).catchError((error) {
          pendingRequest.completer.completeError(error);
        });
      } else {
        // 刷新失败，返回原错误
        pendingRequest.completer.completeError(pendingRequest.error);
      }
    }
    _pendingRequests.clear();
  }
  
  /// 重试请求
  Future<Response> _retryRequest(RequestOptions options) async {
    return await _dio.request(
      options.path,
      data: options.data,
      queryParameters: options.queryParameters,
      options: Options(
        method: options.method,
        headers: options.headers,
        contentType: options.contentType,
        responseType: options.responseType,
        followRedirects: options.followRedirects,
        maxRedirects: options.maxRedirects,
        receiveTimeout: options.receiveTimeout,
        sendTimeout: options.sendTimeout,
      ),
    );
  }
  
  /// 更新请求Token
  void _updateRequestToken(RequestOptions options) {
    if (_config.getAccessToken != null) {
      _config.getAccessToken!().then((token) {
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      });
    }
  }
  
  /// 获取请求中的Token
  String? _getTokenFromOptions(RequestOptions options) {
    final authHeader = options.headers['Authorization'] as String?;
    if (authHeader != null && authHeader.startsWith('Bearer ')) {
      return authHeader.substring(7);
    }
    return null;
  }
  
  /// 检查Token是否即将过期
  bool _isTokenNearExpiry(String token) {
    // 这里应该解析JWT Token的过期时间
    // 简化实现，可以根据实际需求完善
    try {
      // 解析JWT Token（需要jwt_decode包）
      // final payload = JwtDecoder.decode(token);
      // final exp = payload['exp'] as int?;
      // if (exp != null) {
      //   final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      //   final now = DateTime.now();
      //   return expiryTime.difference(now).inMinutes < _config.preventiveRefreshThreshold.inMinutes;
      // }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// 检查是否是刷新Token请求
  bool _isRefreshTokenRequest(RequestOptions options) {
    return options.path.contains(_config.refreshEndpoint);
  }
  
  /// 检查刷新是否过于频繁
  bool _isRefreshTooFrequent() {
    if (_lastRefreshTime == null) return false;
    
    final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
    return timeSinceLastRefresh < _config.minRefreshInterval;
  }
  
  /// 处理刷新Token失败
  void _handleRefreshTokenFailure() {
    if (_config.onRefreshTokenFailure != null) {
      _config.onRefreshTokenFailure!();
    }
  }
  
  /// 获取配置
  TokenRefreshConfig get config => _config;
  
  /// 更新配置
  void updateConfig(TokenRefreshConfig config) {
    _config = config;
  }
  
  /// 重置状态
  void reset() {
    _isRefreshing = false;
    _refreshFailureCount = 0;
    _lastRefreshTime = null;
    _pendingRequests.clear();
    _refreshCompleter = null;
  }
}

/// 等待中的请求
class _PendingRequest {
  final RequestOptions options;
  final DioException error;
  final Completer<Response> completer;
  
  _PendingRequest({
    required this.options,
    required this.error,
    required this.completer,
  });
}

/// Token对
class TokenPair {
  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;
  
  const TokenPair({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
  });
}

/// Token刷新配置
class TokenRefreshConfig {
  /// 刷新端点
  final String refreshEndpoint;
  
  /// 访问Token键名
  final String accessTokenKey;
  
  /// 刷新Token键名
  final String refreshTokenKey;
  
  /// 过期时间键名
  final String expiresInKey;
  
  /// 刷新Token请求头
  final String? refreshTokenHeader;
  
  /// 是否在请求体中发送刷新Token
  final bool refreshTokenInBody;
  
  /// 最大刷新重试次数
  final int maxRefreshRetries;
  
  /// 最小刷新间隔
  final Duration minRefreshInterval;
  
  /// 是否启用预防性刷新
  final bool enablePreventiveRefresh;
  
  /// 预防性刷新阈值
  final Duration preventiveRefreshThreshold;
  
  /// Token过期错误消息
  final List<String> tokenExpiredMessages;
  
  /// 获取访问Token回调
  final Future<String?> Function()? getAccessToken;
  
  /// 获取刷新Token回调
  final Future<String?> Function()? getRefreshToken;
  
  /// Token刷新成功回调
  final Future<void> Function(TokenPair tokens)? onTokenRefreshed;
  
  /// 刷新Token失败回调
  final void Function()? onRefreshTokenFailure;
  
  const TokenRefreshConfig({
    this.refreshEndpoint = '/auth/refresh',
    this.accessTokenKey = 'access_token',
    this.refreshTokenKey = 'refresh_token',
    this.expiresInKey = 'expires_in',
    this.refreshTokenHeader,
    this.refreshTokenInBody = true,
    this.maxRefreshRetries = 3,
    this.minRefreshInterval = const Duration(seconds: 30),
    this.enablePreventiveRefresh = true,
    this.preventiveRefreshThreshold = const Duration(minutes: 5),
    this.tokenExpiredMessages = const [
      'token expired',
      'token invalid',
      'unauthorized',
      'access denied',
    ],
    this.getAccessToken,
    this.getRefreshToken,
    this.onTokenRefreshed,
    this.onRefreshTokenFailure,
  });
  
  /// 创建配置副本
  TokenRefreshConfig copyWith({
    String? refreshEndpoint,
    String? accessTokenKey,
    String? refreshTokenKey,
    String? expiresInKey,
    String? refreshTokenHeader,
    bool? refreshTokenInBody,
    int? maxRefreshRetries,
    Duration? minRefreshInterval,
    bool? enablePreventiveRefresh,
    Duration? preventiveRefreshThreshold,
    List<String>? tokenExpiredMessages,
    Future<String?> Function()? getAccessToken,
    Future<String?> Function()? getRefreshToken,
    Future<void> Function(TokenPair)? onTokenRefreshed,
    void Function()? onRefreshTokenFailure,
    String? accessToken,
    String? refreshToken,
  }) {
    return TokenRefreshConfig(
      refreshEndpoint: refreshEndpoint ?? this.refreshEndpoint,
      accessTokenKey: accessTokenKey ?? this.accessTokenKey,
      refreshTokenKey: refreshTokenKey ?? this.refreshTokenKey,
      expiresInKey: expiresInKey ?? this.expiresInKey,
      refreshTokenHeader: refreshTokenHeader ?? this.refreshTokenHeader,
      refreshTokenInBody: refreshTokenInBody ?? this.refreshTokenInBody,
      maxRefreshRetries: maxRefreshRetries ?? this.maxRefreshRetries,
      minRefreshInterval: minRefreshInterval ?? this.minRefreshInterval,
      enablePreventiveRefresh: enablePreventiveRefresh ?? this.enablePreventiveRefresh,
      preventiveRefreshThreshold: preventiveRefreshThreshold ?? this.preventiveRefreshThreshold,
      tokenExpiredMessages: tokenExpiredMessages ?? this.tokenExpiredMessages,
      getAccessToken: getAccessToken ?? this.getAccessToken,
      getRefreshToken: getRefreshToken ?? this.getRefreshToken,
      onTokenRefreshed: onTokenRefreshed ?? this.onTokenRefreshed,
      onRefreshTokenFailure: onRefreshTokenFailure ?? this.onRefreshTokenFailure,
    );
  }
}