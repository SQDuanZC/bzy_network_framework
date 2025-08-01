import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/bzy_network_framework.dart';

/// Cache Functionality Examples / 缓存功能示例 (Cache Functionality Examples)
/// Demonstrates the usage of network request caching / 演示网络请求缓存的使用方法 (demonstrates the usage of network request caching)
void main() {
  group('Cache Functionality Examples / 缓存功能示例 (Cache Functionality Examples)', () {
    setUpAll(() async {
      // Initialize network framework with cache enabled / 初始化网络框架，启用缓存 (initialize network framework with cache enabled)
      await UnifiedNetworkFramework.instance.initialize(
        baseUrl: 'https://jsonplaceholder.typicode.com',
        config: {
          'enableLogging': true,
          'enableCache': true,
          'defaultCacheDuration': 300, // Default cache 5 minutes / 默认缓存5分钟 (default cache 5 minutes)
      'maxCacheSize': 50, // Max cache 50MB / 最大缓存50MB (max cache 50MB)
        },
      );
    });

    test('Request with Cache Enabled / 启用缓存的请求 (Request with Cache Enabled)', () async {
      final request = CachedRequest();
      final executor = NetworkExecutor.instance;
      
      // First request (from network) / 第一次请求（从网络获取） (first request from network)
      print('=== First request (from network) ===');
      final startTime1 = DateTime.now();
      final response1 = await executor.execute(request);
      final duration1 = DateTime.now().difference(startTime1).inMilliseconds;
      
      print('First request duration: ${duration1}ms');
      print('From cache: ${response1.fromCache}');
      print('Response data: ${response1.data}');
      
      expect(response1.success, true);
      expect(response1.fromCache, false);
      
      // Second request (from cache) / 第二次请求（从缓存获取） (second request from cache)
      print('\n=== Second request (from cache) ===');
      final startTime2 = DateTime.now();
      final response2 = await executor.execute(request);
      final duration2 = DateTime.now().difference(startTime2).inMilliseconds;
      
      print('Second request duration: ${duration2}ms');
      print('From cache: ${response2.fromCache}');
      print('Response data: ${response2.data}');
      
      expect(response2.success, true);
      expect(response2.fromCache, true);
      expect(duration2 < duration1, true); // Cache request should be faster / 缓存请求应该更快 (cache request should be faster)
    });

    test('Request with Custom Cache Duration / 自定义缓存时长的请求 (Request with Custom Cache Duration)', () async {
      final request = CustomCacheDurationRequest();
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await executor.execute(request);
        print('Custom cache duration request successful: ${response.data}');
        print('Cache duration: ${request.cacheDuration} seconds');
        expect(response.success, true);
      } catch (e) {
        print('Custom cache duration request failed: $e');
      }
    });

    test('Request with Custom Cache Key / 自定义缓存键的请求 (Request with Custom Cache Key)', () async {
      final request = CustomCacheKeyRequest(userId: 123);
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await executor.execute(request);
        print('Custom cache key request successful: ${response.data}');
        print('Cache key: ${request.cacheKey}');
        expect(response.success, true);
      } catch (e) {
        print('Custom cache key request failed: $e');
      }
    });

    test('Request with Cache Disabled / 禁用缓存的请求 (Request with Cache Disabled)', () async {
      final request = NoCacheRequest();
      final executor = NetworkExecutor.instance;
      
      // Two consecutive requests, both should fetch from network / 连续两次请求，都应该从网络获取 (two consecutive requests, both should fetch from network)
      final response1 = await executor.execute(request);
      final response2 = await executor.execute(request);
      
      print('First request from cache: ${response1.fromCache}');
      print('Second request from cache: ${response2.fromCache}');
      
      expect(response1.fromCache, false);
      expect(response2.fromCache, false);
    });
  });
}

/// Request with cache enabled / 启用缓存的请求 (Request with cache enabled)
/// This request demonstrates basic caching functionality / 此请求演示基本缓存功能 (this request demonstrates basic caching functionality)
class CachedRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  bool get enableCache => true;
  
  @override
  int get cacheDuration => 300; // Cache for 5 minutes / 缓存5分钟 (cache for 5 minutes)
  // Default cache duration setting / 默认缓存时长设置 (default cache duration setting)
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// Request with custom cache duration / 自定义缓存时长的请求 (Request with custom cache duration)
/// Shows how to set different cache durations for different requests / 展示如何为不同请求设置不同的缓存时长 (shows how to set different cache durations for different requests)
class CustomCacheDurationRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/2';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  bool get enableCache => true;
  
  @override
  int get cacheDuration => 600; // Cache for 10 minutes / 缓存10分钟 (cache for 10 minutes)
  // Extended cache duration for less frequently changing data / 为变化较少的数据设置更长的缓存时间 (extended cache duration for less frequently changing data)
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// Request with custom cache key / 自定义缓存键的请求 (Request with custom cache key)
/// Demonstrates how to use custom cache keys for better cache management / 演示如何使用自定义缓存键进行更好的缓存管理 (demonstrates how to use custom cache keys for better cache management)
class CustomCacheKeyRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final int userId;
  
  CustomCacheKeyRequest({required this.userId});
  
  @override
  String get path => '/posts/3';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  bool get enableCache => true;
  
  @override
  int get cacheDuration => 300;
  
  @override
  String? get cacheKey => 'user_post_$userId';
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// Request with cache disabled / 禁用缓存的请求 (Request with cache disabled)
/// Shows how to disable caching for requests that need fresh data / 展示如何为需要新鲜数据的请求禁用缓存 (shows how to disable caching for requests that need fresh data)
class NoCacheRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/4';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  bool get enableCache => false; // Disable cache / 禁用缓存 (disable cache)
  // Always fetch fresh data from network / 始终从网络获取新鲜数据 (always fetch fresh data from network)
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}