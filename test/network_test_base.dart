import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

import '../core/cache/cache_manager.dart';
import '../core/config/network_config.dart';
import '../frameworks/unified_framework.dart';
import '../requests/base_network_request.dart';
import '../model/network_response.dart';

import '../core/di/service_locator.dart';
import '../model/response_wrapper.dart';


// =============================================================================
// 测试基础设施
// =============================================================================

/// 网络测试基类
abstract class NetworkTestBase {
  late MockUnifiedNetworkFramework mockNetworkFramework;
  late MockCacheManager mockCacheManager;
  late ServiceLocator testLocator;
  
  /// 设置测试环境
  void setUp() {
    // 创建模拟对象
    mockNetworkFramework = MockUnifiedNetworkFramework();
    mockCacheManager = MockCacheManager();
    
    // 创建测试服务定位器
    testLocator = ServiceLocator.instance;
    testLocator.reset();
    
    // 注册模拟服务
    _registerMockServices();
  }
  
  /// 清理测试环境
  void tearDown() {
    mockNetworkFramework.dispose();
    mockCacheManager.dispose();
    testLocator.reset();
  }
  
  /// 注册模拟服务
  void _registerMockServices() {
    testLocator.registerInstance<UnifiedNetworkFramework>(mockNetworkFramework);
    testLocator.registerInstance<CacheManager>(mockCacheManager);
    testLocator.registerInstance<NetworkConfig>(NetworkConfig.instance);
  }
  
  /// 创建测试请求
  T createTestRequest<T extends BaseNetworkRequest>(T request) {
    // 可以在这里设置测试特定的配置
    return request;
  }
}

// =============================================================================
// 模拟网络管理器
// =============================================================================

/// 模拟统一网络框架
class MockUnifiedNetworkFramework implements UnifiedNetworkFramework {
  final Map<String, MockResponse> _mockResponses = {};
  final List<RequestRecord> _requestHistory = [];
  final Map<String, Exception> _mockErrors = {};
  final Map<String, Duration> _mockDelays = {};
  bool _isDisposed = false;
  
  /// 设置模拟响应
  void setMockResponse(String url, MockResponse response) {
    _mockResponses[url] = response;
  }
  
  /// 设置模拟错误
  void setMockError(String url, Exception error) {
    _mockErrors[url] = error;
  }
  
  /// 设置模拟延迟
  void setMockDelay(String url, Duration delay) {
    _mockDelays[url] = delay;
  }
  
  /// 获取请求历史
  List<RequestRecord> get requestHistory => List.unmodifiable(_requestHistory);
  
  /// 清除请求历史
  void clearHistory() {
    _requestHistory.clear();
  }
  
  /// 验证请求是否被调用
  bool wasRequestMade(String url, {String? method}) {
    return _requestHistory.any((record) => 
        record.url == url && (method == null || record.method == method));
  }
  
  /// 获取请求调用次数
  int getRequestCount(String url, {String? method}) {
    return _requestHistory.where((record) => 
        record.url == url && (method == null || record.method == method)).length;
  }
  
  @override
  Future<NetworkResponse<T>> execute<T>(BaseNetworkRequest<T> request) async {
    if (_isDisposed) {
      throw Exception('MockUnifiedNetworkFramework has been disposed');
    }
    
    // 构建完整URL
    final fullUrl = request.path;
    
    // 记录请求
    final record = RequestRecord(
      method: request.method.value,
      url: fullUrl,
      data: null,
      queryParameters: request.queryParameters,
      options: null,
      timestamp: DateTime.now(),
    );
    _requestHistory.add(record);
    
    // 模拟延迟
    final delay = _mockDelays[fullUrl];
    if (delay != null) {
      await Future.delayed(delay);
    }
    
    // 检查是否有模拟错误
    final error = _mockErrors[fullUrl];
    if (error != null) {
      throw error;
    }
    
    // 获取模拟响应
    final mockResponse = _mockResponses[fullUrl];
    if (mockResponse == null) {
      throw Exception('No mock response configured for $fullUrl');
    }
    
    // 返回模拟响应
    return NetworkResponse<T>(
      data: mockResponse.data,
      statusCode: mockResponse.statusCode,
      message: mockResponse.message,
      success: mockResponse.isSuccess,
      timestamp: DateTime.now(),
    );
  }
  
  @override
  Future<List<NetworkResponse>> executeBatch(List<BaseNetworkRequest> requests) async {
    final results = <NetworkResponse>[];
    for (final request in requests) {
      final response = await execute(request);
      results.add(response);
    }
    return results;
  }
  
  @override
  Future<List<NetworkResponse>> executeConcurrent(
    List<BaseNetworkRequest> requests, {
    int maxConcurrency = 3,
  }) async {
    final results = <NetworkResponse>[];
    for (final request in requests) {
      final response = await execute(request);
      results.add(response);
    }
    return results;
  }
  
  @override
  void cancelRequest(BaseNetworkRequest request) {
    _requestHistory.removeWhere((record) => record.url == request.path);
  }
  
  @override
  void cancelAllRequests() {
    _requestHistory.clear();
  }
  
  // 实现 UnifiedNetworkFramework 的其他必需方法
  @override
  Future<void> initialize({
    required String baseUrl,
    Map<String, dynamic>? config,
    List<NetworkPlugin>? plugins,
    List<GlobalInterceptor>? interceptors,
  }) async {
    // Mock implementation - 不需要实际初始化
  }
  
  @override
  Future<void> registerPlugin(NetworkPlugin plugin) async {
    // Mock implementation - 不需要实际注册插件
  }
  
  @override
  Future<void> unregisterPlugin(String pluginName) async {
    // Mock implementation - 不需要实际注销插件
  }
  
  @override
  void registerGlobalInterceptor(GlobalInterceptor interceptor) {
    // Mock implementation - 不需要实际注册拦截器
  }
  
  @override
  void removeGlobalInterceptor(GlobalInterceptor interceptor) {
    // Mock implementation - 不需要实际移除拦截器
  }
  
  @override
  void updateConfig(Map<String, dynamic> config) {
    // Mock implementation - 不需要实际更新配置
  }
  
  @override
  T? getPlugin<T extends NetworkPlugin>(String name) {
    // Mock implementation - 返回 null
    return null;
  }
  
  @override
  List<NetworkPlugin> get plugins => [];
  
  @override
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': true,
      'pluginsCount': 0,
      'globalInterceptorsCount': 0,
      'requestHistory': _requestHistory.length,
    };
  }
  

  

  

  
  /// 清理资源
  @override
  Future<void> dispose() async {
    _isDisposed = true;
    _mockResponses.clear();
    _requestHistory.clear();
    _mockErrors.clear();
    _mockDelays.clear();
  }
}

// =============================================================================
// 模拟缓存管理器
// =============================================================================

/// 模拟缓存管理器
class MockCacheManager implements CacheManager {
  final Map<String, CacheEntry> _cache = {};
  final List<CacheOperation> _operations = [];
  bool _isDisposed = false;
  
  @override
  CacheConfig get config => CacheConfig();
  
  /// 获取缓存操作历史
  List<CacheOperation> get operations => List.unmodifiable(_operations);
  
  /// 清除操作历史
  void clearOperations() {
    _operations.clear();
  }
  
  /// 验证缓存操作
  bool wasOperationPerformed(CacheOperationType type, String key) {
    return _operations.any((op) => op.type == type && op.key == key);
  }
  
  @override
  Future<BaseResponse<T>?> get<T>(String key, {T Function(dynamic)? fromJson}) async {
    if (_isDisposed) return null;
    
    _operations.add(CacheOperation(
      type: CacheOperationType.get,
      key: key,
      timestamp: DateTime.now(),
    ));
    
    final entry = _cache[key];
    if (entry == null || entry.isExpired) {
      return null;
    }
    
    // 如果缓存的是BaseResponse，直接返回
    if (entry.value is BaseResponse<T>) {
      return entry.value as BaseResponse<T>;
    }
    
    // 否则包装成BaseResponse
    return BaseResponse<T>(
      data: entry.value as T?,
      code: 200,
      message: 'From cache',
      success: true,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
  
  @override
  Future<void> set<T>(
    String key,
    BaseResponse<T> response, {
    Duration? expiry,
    CachePriority priority = CachePriority.normal,
    Set<String> tags = const {},
    bool? enableCompression,
    bool? enableEncryption,
  }) async {
    if (_isDisposed) return;
    
    _operations.add(CacheOperation(
      type: CacheOperationType.set,
      key: key,
      value: response,
      expiry: expiry,
      timestamp: DateTime.now(),
    ));
    
    final expiryTime = expiry != null 
        ? DateTime.now().add(expiry)
        : DateTime.now().add(const Duration(hours: 1));
    
    _cache[key] = CacheEntry(
      value: response,
      expiryTime: expiryTime,
    );
  }
  
  @override
  Future<void> remove(String key) async {
    if (_isDisposed) return;
    
    _operations.add(CacheOperation(
      type: CacheOperationType.remove,
      key: key,
      timestamp: DateTime.now(),
    ));
    
    _cache.remove(key);
  }
  
  @override
  Future<void> clear() async {
    if (_isDisposed) return;
    
    _operations.add(CacheOperation(
      type: CacheOperationType.clear,
      key: 'all',
      timestamp: DateTime.now(),
    ));
    
    _cache.clear();
  }
  
  Future<bool> contains(String key) async {
    if (_isDisposed) return false;
    
    final entry = _cache[key];
    return entry != null && !entry.isExpired;
  }
  
  Future<List<String>> getKeys() async {
    if (_isDisposed) return [];
    
    return _cache.keys
        .where((key) => !_cache[key]!.isExpired)
        .toList();
  }
  

  
  @override
  Future<void> dispose() async {
    _isDisposed = true;
    _cache.clear();
    _operations.clear();
  }
  
  // 实现缺失的抽象方法
  @override
  Future<void> addTag(String key, String tag) async {
    // Mock implementation
  }
  
  @override
  Future<void> removeTag(String key, String tag) async {
    // Mock implementation
  }
  
  @override
  Future<void> clearByTag(String tag) async {
    // Mock implementation
  }
  
  @override
  Future<void> clearByTags(List<String> tags) async {
    // Mock implementation
  }
  
  @override
  Map<String, dynamic> getCacheInfo() {
    return {
      'memoryEntries': _cache.length,
      'diskEntries': 0,
      'memoryUsage': _cache.length * 1024, // 估算
      'diskUsage': 0,
      'hitRate': 0.8, // 模拟命中率
      'totalRequests': _operations.length,
      'lastCleanup': DateTime.now().toIso8601String(),
    };
  }
  
  Future<void> cleanupExpired() async {
    // Mock implementation
  }
  
  Future<void> optimizeStorage() async {
    // Mock implementation
  }
  
  @override
  Set<String> getKeysByTag(String tag) {
    // 模拟根据标签获取键
    return <String>{};
  }

  @override
  Set<String> getTagsByKey(String key) {
    // 模拟根据键获取标签
    return <String>{};
  }

  @override
  void recordTagHit(String tag) {
    // 模拟记录标签命中
  }

  @override
  void recordEndpointHit(String endpoint) {
    // 模拟记录端点命中
  }

  @override
  CacheStatistics get statistics {
    final getOperations = _operations.where((op) => op.type == CacheOperationType.get).length;
    final hitOperations = _operations.where((op) => 
        op.type == CacheOperationType.get && _cache.containsKey(op.key)).length;
    
    final stats = CacheStatistics();
    stats.totalRequests = getOperations;
    stats.memoryHits = hitOperations;
    stats.misses = getOperations - hitOperations;
    return stats;
  }

  @override
  void updateConfig(CacheConfig newConfig) {
    // 模拟更新配置
  }
}

// =============================================================================
// 测试数据模型
// =============================================================================

/// 请求记录
class RequestRecord {
  final String method;
  final String url;
  final dynamic data;
  final Map<String, dynamic>? queryParameters;
  final Options? options;
  final DateTime timestamp;
  
  RequestRecord({
    required this.method,
    required this.url,
    this.data,
    this.queryParameters,
    this.options,
    required this.timestamp,
  });
  
  @override
  String toString() {
    return 'RequestRecord(method: $method, url: $url, timestamp: $timestamp)';
  }
}

/// 模拟响应
class MockResponse {
  final dynamic data;
  final int statusCode;
  final String message;
  final bool isSuccess;
  
  MockResponse({
    required this.data,
    this.statusCode = 200,
    this.message = 'Success',
    this.isSuccess = true,
  });
  
  /// 创建成功响应
  factory MockResponse.success(dynamic data, {String message = 'Success'}) {
    return MockResponse(
      data: data,
      statusCode: 200,
      message: message,
      isSuccess: true,
    );
  }
  
  /// 创建错误响应
  factory MockResponse.error({
    int statusCode = 500,
    String message = 'Internal Server Error',
    dynamic data,
  }) {
    return MockResponse(
      data: data,
      statusCode: statusCode,
      message: message,
      isSuccess: false,
    );
  }
}

/// 缓存条目
class CacheEntry {
  final dynamic value;
  final DateTime expiryTime;
  
  CacheEntry({
    required this.value,
    required this.expiryTime,
  });
  
  bool get isExpired => DateTime.now().isAfter(expiryTime);
}

/// 缓存操作类型
enum CacheOperationType {
  get,
  set,
  remove,
  clear,
}

/// 缓存操作记录
class CacheOperation {
  final CacheOperationType type;
  final String key;
  final dynamic value;
  final Duration? expiry;
  final DateTime timestamp;
  
  CacheOperation({
    required this.type,
    required this.key,
    this.value,
    this.expiry,
    required this.timestamp,
  });
  
  @override
  String toString() {
    return 'CacheOperation(type: $type, key: $key, timestamp: $timestamp)';
  }
}

// =============================================================================
// 测试工具类
// =============================================================================

/// 测试工具
class NetworkTestUtils {
  /// 创建测试用户数据
  static Map<String, dynamic> createTestUserData({
    String id = 'test_user_123',
    String name = 'Test User',
    String email = 'test@example.com',
  }) {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar': 'https://example.com/avatar.jpg',
      'lastLoginAt': DateTime.now().toIso8601String(),
    };
  }
  
  /// 创建测试新闻数据
  static Map<String, dynamic> createTestNewsData({
    int count = 5,
    String category = 'tech',
  }) {
    final articles = List.generate(count, (index) => {
      'id': 'article_$index',
      'title': 'Test Article $index',
      'content': 'This is test content for article $index',
      'author': 'Test Author $index',
      'publishedAt': DateTime.now().subtract(Duration(hours: index)).toIso8601String(),
      'tags': ['test', category],
    });
    
    return {
      'articles': articles,
      'total': count,
      'page': 1,
      'pageSize': count,
    };
  }
  
  /// 创建测试配置数据
  static Map<String, dynamic> createTestConfigData() {
    return {
      'version': '1.0.0',
      'features': {
        'enableCache': true,
        'enableLogging': true,
        'maxRetries': 3,
      },
      'urls': {
        'api': 'https://api.example.com',
        'cdn': 'https://cdn.example.com',
      },
    };
  }
  
  /// 等待异步操作完成
  static Future<void> waitForAsync([Duration? duration]) async {
    await Future.delayed(duration ?? const Duration(milliseconds: 10));
  }
  
  /// 验证JSON数据
  static bool isValidJson(String jsonString) {
    try {
      json.decode(jsonString);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// 比较两个Map是否相等
  static bool mapsEqual(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.length != map2.length) return false;
    
    for (final key in map1.keys) {
      if (!map2.containsKey(key) || map1[key] != map2[key]) {
        return false;
      }
    }
    
    return true;
  }
}

// =============================================================================
// 断言工具
// =============================================================================

/// 网络测试断言
class NetworkAssert {
  /// 断言请求被调用
  static void requestWasMade(
    MockUnifiedNetworkFramework mockManager,
    String url, {
    String? method,
    String? message,
  }) {
    final wasMade = mockManager.wasRequestMade(url, method: method);
    if (!wasMade) {
      final methodPart = method != null ? ' with method $method' : '';
      throw AssertionError(
        message ?? 'Expected request to $url$methodPart to be made, but it was not'
      );
    }
  }
  
  /// 断言请求未被调用
  static void requestWasNotMade(
    MockUnifiedNetworkFramework mockManager,
    String url, {
    String? method,
    String? message,
  }) {
    final wasMade = mockManager.wasRequestMade(url, method: method);
    if (wasMade) {
      final methodPart = method != null ? ' with method $method' : '';
      throw AssertionError(
        message ?? 'Expected request to $url$methodPart not to be made, but it was'
      );
    }
  }
  
  /// 断言请求调用次数
  static void requestCallCount(
    MockUnifiedNetworkFramework mockManager,
    String url,
    int expectedCount, {
    String? method,
    String? message,
  }) {
    final actualCount = mockManager.getRequestCount(url, method: method);
    if (actualCount != expectedCount) {
      final methodPart = method != null ? ' with method $method' : '';
      throw AssertionError(
        message ?? 'Expected $expectedCount calls to $url$methodPart, but got $actualCount'
      );
    }
  }
  
  /// 断言缓存操作被执行
  static void cacheOperationWasPerformed(
    MockCacheManager mockCache,
    CacheOperationType type,
    String key, {
    String? message,
  }) {
    final wasPerformed = mockCache.wasOperationPerformed(type, key);
    if (!wasPerformed) {
      throw AssertionError(
        message ?? 'Expected cache operation $type for key $key to be performed, but it was not'
      );
    }
  }
  
  /// 断言响应成功
  static void responseIsSuccess<T>(BaseResponse<T> response, {String? message}) {
    if (!response.success) {
      throw AssertionError(
        message ?? 'Expected response to be successful, but got: ${response.message}'
      );
    }
  }
  
  /// 断言响应失败
  static void responseIsFailure<T>(BaseResponse<T> response, {String? message}) {
    if (response.success) {
      throw AssertionError(
        message ?? 'Expected response to be failure, but it was successful'
      );
    }
  }
  
  /// 断言响应数据不为空
  static void responseDataIsNotNull<T>(BaseResponse<T> response, {String? message}) {
    if (response.data == null) {
      throw AssertionError(
        message ?? 'Expected response data to be not null, but it was null'
      );
    }
  }
}