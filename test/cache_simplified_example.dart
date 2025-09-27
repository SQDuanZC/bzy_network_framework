import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/src/core/cache/cache_manager.dart';
import 'package:bzy_network_framework/src/config/network_config.dart';
import 'package:bzy_network_framework/src/utils/network_logger.dart';
import 'package:logging/logging.dart';

/// 缓存简化接口使用示例
/// 
/// 本文件展示了如何使用CacheManager的简化接口来缓存各种类型的数据
/// 包括基础类型、集合类型、自定义对象等
void main() {
  group('缓存简化接口使用示例', () {
    late CacheManager cacheManager;

    setUp(() {
      // 初始化网络配置
      NetworkConfig.instance.initialize(
        baseUrl: 'https://api.example.com',
        enableCache: true,
        defaultCacheDuration: 300,
      );

      cacheManager = CacheManager.instance;

      // 配置日志
      NetworkLogger.configure(
        level: Level.INFO,
        enableConsoleOutput: false,
      );
    });

    test('基础数据类型缓存示例', () async {
      print('=== 基础数据类型缓存示例 ===');
      
      // 字符串缓存
      await cacheManager.putString('user_name', 'Alice');
      final userName = await cacheManager.getString('user_name');
      print('用户名: $userName');
      expect(userName, equals('Alice'));

      // 整数缓存
      await cacheManager.putInt('user_age', 25);
      final userAge = await cacheManager.getInt('user_age');
      print('用户年龄: $userAge');
      expect(userAge, equals(25));

      // 浮点数缓存
      await cacheManager.putDouble('user_score', 95.5);
      final userScore = await cacheManager.getDouble('user_score');
      print('用户评分: $userScore');
      expect(userScore, equals(95.5));

      // 布尔值缓存
      await cacheManager.putBool('is_premium', true);
      final isPremium = await cacheManager.getBool('is_premium');
      print('是否为高级用户: $isPremium');
      expect(isPremium, equals(true));
    });

    test('集合类型缓存示例', () async {
      print('\n=== 集合类型缓存示例 ===');
      
      // Map缓存
      final userInfo = {
        'id': 1001,
        'name': 'Bob',
        'email': 'bob@example.com',
        'department': 'Engineering'
      };
      await cacheManager.putMap('user_info', userInfo);
      final cachedUserInfo = await cacheManager.getMap('user_info');
      print('用户信息: $cachedUserInfo');
      expect(cachedUserInfo, equals(userInfo));

      // List缓存
      final hobbies = ['reading', 'swimming', 'coding', 'traveling'];
      await cacheManager.putList<String>('user_hobbies', hobbies);
      final cachedHobbies = await cacheManager.getList<String>('user_hobbies');
      print('用户爱好: $cachedHobbies');
      expect(cachedHobbies, equals(hobbies));

      // 数字列表缓存
      final scores = [85, 92, 78, 96, 88];
      await cacheManager.putList<int>('test_scores', scores);
      final cachedScores = await cacheManager.getList<int>('test_scores');
      print('考试成绩: $cachedScores');
      expect(cachedScores, equals(scores));
    });

    test('自定义对象缓存示例', () async {
      print('\n=== 自定义对象缓存示例 ===');
      
      // 创建用户对象
      final user = User(
        id: 1001,
        name: 'Charlie',
        email: 'charlie@example.com',
        profile: UserProfile(
          avatar: 'https://example.com/avatar.jpg',
          bio: 'Software Engineer',
          location: 'San Francisco',
        ),
      );

      // 使用putObject缓存对象
      await cacheManager.putObject('current_user', user);
      final cachedUser = await cacheManager.getObject<User>('current_user');
      print('缓存的用户: ${cachedUser?.name} (${cachedUser?.email})');
      expect(cachedUser?.id, equals(user.id));
      expect(cachedUser?.name, equals(user.name));

      // 使用putJsonObject缓存JSON序列化对象
      await cacheManager.putJsonObject('user_json', user, User.fromJson);
      final jsonUser = await cacheManager.getJsonObject('user_json', User.fromJson);
      print('JSON用户: ${jsonUser?.name} - ${jsonUser?.profile?.bio}');
      expect(jsonUser?.id, equals(user.id));
      expect(jsonUser?.profile?.bio, equals(user.profile?.bio));
    });

    test('带过期时间和标签的缓存示例', () async {
      print('\n=== 带过期时间和标签的缓存示例 ===');
      
      // 短期缓存（5秒过期）
      await cacheManager.putString(
        'temp_token',
        'abc123xyz',
        expiry: Duration(seconds: 5),
        tags: {'auth', 'temporary'},
      );

      // 中期缓存（1小时过期）
      await cacheManager.putMap(
        'session_data',
        {'sessionId': 'sess_456', 'userId': 1001},
        expiry: Duration(hours: 1),
        tags: {'auth', 'session'},
      );

      // 长期缓存（7天过期）
      await cacheManager.putList<String>(
        'user_preferences',
        ['dark_theme', 'notifications_on', 'auto_save'],
        expiry: Duration(days: 7),
        tags: {'user', 'settings'},
      );

      // 检查缓存是否存在
      expect(await cacheManager.exists('temp_token'), true);
      expect(await cacheManager.exists('session_data'), true);
      expect(await cacheManager.exists('user_preferences'), true);

      // 获取过期时间
      final tokenExpiry = await cacheManager.getExpiryTime('temp_token');
      print('临时令牌过期时间: $tokenExpiry');
      expect(tokenExpiry, isNotNull);

      // 延长过期时间
      await cacheManager.extendExpiry('temp_token', Duration(minutes: 10));
      final newTokenExpiry = await cacheManager.getExpiryTime('temp_token');
      print('延长后的过期时间: $newTokenExpiry');
      expect(newTokenExpiry!.isAfter(tokenExpiry!), true);
    });

    test('标签管理示例', () async {
      print('\n=== 标签管理示例 ===');
      
      // 创建带不同标签的缓存项
      await cacheManager.putString('user_1_name', 'Alice', tags: {'user', 'profile', 'user_1'});
      await cacheManager.putString('user_1_email', 'alice@example.com', tags: {'user', 'contact', 'user_1'});
      await cacheManager.putString('user_2_name', 'Bob', tags: {'user', 'profile', 'user_2'});
      await cacheManager.putString('user_2_email', 'bob@example.com', tags: {'user', 'contact', 'user_2'});
      await cacheManager.putString('app_version', '1.0.0', tags: {'app', 'config'});

      // 验证数据存在
      expect(await cacheManager.getString('user_1_name'), equals('Alice'));
      expect(await cacheManager.getString('user_2_name'), equals('Bob'));
      expect(await cacheManager.getString('app_version'), equals('1.0.0'));

      // 清理特定用户的数据
      await cacheManager.clearByTag('user_1');
      
      // 验证user_1的数据被清理，但user_2和app数据保留
      expect(await cacheManager.getString('user_1_name'), isNull);
      expect(await cacheManager.getString('user_1_email'), isNull);
      expect(await cacheManager.getString('user_2_name'), equals('Bob'));
      expect(await cacheManager.getString('app_version'), equals('1.0.0'));

      // 清理所有用户数据
      await cacheManager.clearByTag('user');
      
      // 验证所有用户数据被清理，但app数据保留
      expect(await cacheManager.getString('user_2_name'), isNull);
      expect(await cacheManager.getString('user_2_email'), isNull);
      expect(await cacheManager.getString('app_version'), equals('1.0.0'));
    });

    test('实际业务场景示例', () async {
      print('\n=== 实际业务场景示例 ===');
      
      // 场景1: 用户登录信息缓存
      final loginService = LoginCacheService();
      await loginService.cacheUserLogin(
        userId: 1001,
        token: 'jwt_token_here',
        refreshToken: 'refresh_token_here',
        userInfo: {
          'name': 'John Doe',
          'email': 'john@example.com',
          'role': 'admin',
        },
      );

      final isLoggedIn = await loginService.isUserLoggedIn();
      final userInfo = await loginService.getUserInfo();
      print('用户登录状态: $isLoggedIn');
      print('用户信息: $userInfo');
      expect(isLoggedIn, true);
      expect(userInfo?['name'], equals('John Doe'));

      // 场景2: API响应缓存
      final apiService = ApiCacheService();
      final apiResponse = {
        'data': [
          {'id': 1, 'title': 'Post 1'},
          {'id': 2, 'title': 'Post 2'},
        ],
        'total': 2,
        'page': 1,
      };

      await apiService.cacheApiResponse('/posts', {'page': 1}, apiResponse);
      final cachedResponse = await apiService.getCachedApiResponse('/posts', {'page': 1});
      print('缓存的API响应: $cachedResponse');
      expect(cachedResponse, equals(apiResponse));

      // 场景3: 应用配置缓存
      final configService = AppConfigService();
      await configService.saveTheme('dark');
      await configService.saveLanguage('zh-CN');
      await configService.saveNotificationSettings({
        'push_enabled': true,
        'email_enabled': false,
        'sound_enabled': true,
      });

      final theme = await configService.getTheme();
      final language = await configService.getLanguage();
      final notifications = await configService.getNotificationSettings();
      
      print('应用主题: $theme');
      print('应用语言: $language');
      print('通知设置: $notifications');
      
      expect(theme, equals('dark'));
      expect(language, equals('zh-CN'));
      expect(notifications['push_enabled'], true);
    });

    test('缓存性能和统计示例', () async {
      print('\n=== 缓存性能和统计示例 ===');
      
      // 批量缓存操作
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 50; i++) {
        await Future.wait([
          cacheManager.putString('batch_string_$i', 'value_$i'),
          cacheManager.putInt('batch_int_$i', i),
          cacheManager.putMap('batch_map_$i', {'index': i, 'name': 'item_$i'}),
        ]);
      }
      
      stopwatch.stop();
      print('批量缓存50组数据耗时: ${stopwatch.elapsedMilliseconds}ms');
      
      // 获取缓存统计信息
      final stats = cacheManager.statistics;
      print('缓存统计信息:');
      print('  总请求数: ${stats.totalRequests}');
      print('  内存命中数: ${stats.memoryHits}');
      print('  磁盘命中数: ${stats.diskHits}');
      print('  未命中数: ${stats.misses}');
      print('  总命中率: ${(stats.totalHitRate * 100).toStringAsFixed(2)}%');
      print('  内存命中率: ${(stats.memoryHitRate * 100).toStringAsFixed(2)}%');
      
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      expect(stats.totalRequests, greaterThan(0));
    });
  });
}

/// 用户类
class User {
  final int id;
  final String name;
  final String email;
  final UserProfile? profile;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.profile,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'profile': profile?.toJson(),
  };

  static User fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    profile: json['profile'] != null ? UserProfile.fromJson(json['profile']) : null,
  );
}

/// 用户资料类
class UserProfile {
  final String avatar;
  final String bio;
  final String location;

  UserProfile({
    required this.avatar,
    required this.bio,
    required this.location,
  });

  Map<String, dynamic> toJson() => {
    'avatar': avatar,
    'bio': bio,
    'location': location,
  };

  static UserProfile fromJson(Map<String, dynamic> json) => UserProfile(
    avatar: json['avatar'],
    bio: json['bio'],
    location: json['location'],
  );
}

/// 登录缓存服务
class LoginCacheService {
  final CacheManager _cache = CacheManager.instance;

  /// 缓存用户登录信息
  Future<void> cacheUserLogin({
    required int userId,
    required String token,
    required String refreshToken,
    required Map<String, dynamic> userInfo,
  }) async {
    await Future.wait([
      _cache.putInt('current_user_id', userId, 
        expiry: Duration(days: 7), tags: {'auth', 'user'}),
      _cache.putString('access_token', token, 
        expiry: Duration(hours: 2), tags: {'auth', 'token'}),
      _cache.putString('refresh_token', refreshToken, 
        expiry: Duration(days: 30), tags: {'auth', 'token'}),
      _cache.putMap('user_info', userInfo, 
        expiry: Duration(days: 7), tags: {'auth', 'user'}),
    ]);
  }

  /// 检查用户是否已登录
  Future<bool> isUserLoggedIn() async {
    final userId = await _cache.getInt('current_user_id');
    final token = await _cache.getString('access_token');
    return userId != null && token != null;
  }

  /// 获取用户信息
  Future<Map<String, dynamic>?> getUserInfo() async {
    return await _cache.getMap('user_info');
  }

  /// 获取访问令牌
  Future<String?> getAccessToken() async {
    return await _cache.getString('access_token');
  }

  /// 清理登录信息
  Future<void> logout() async {
    await _cache.clearByTag('auth');
  }
}

/// API缓存服务
class ApiCacheService {
  final CacheManager _cache = CacheManager.instance;

  /// 缓存API响应
  Future<void> cacheApiResponse(
    String endpoint,
    Map<String, dynamic> params,
    dynamic responseData, {
    Duration? cacheDuration,
  }) async {
    final cacheKey = _generateCacheKey(endpoint, params);
    await _cache.putObject(
      cacheKey,
      responseData,
      expiry: cacheDuration ?? Duration(minutes: 15),
      tags: {'api', 'endpoint_${endpoint.replaceAll('/', '_')}'},
    );
  }

  /// 获取缓存的API响应
  Future<dynamic> getCachedApiResponse(
    String endpoint,
    Map<String, dynamic> params,
  ) async {
    final cacheKey = _generateCacheKey(endpoint, params);
    return await _cache.getObject(cacheKey);
  }

  /// 清理特定端点的缓存
  Future<void> clearEndpointCache(String endpoint) async {
    await _cache.clearByTag('endpoint_${endpoint.replaceAll('/', '_')}');
  }

  /// 生成缓存键
  String _generateCacheKey(String endpoint, Map<String, dynamic> params) {
    final sortedParams = Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
    final paramString = jsonEncode(sortedParams);
    return '${endpoint}_${paramString.hashCode}';
  }
}

/// 应用配置服务
class AppConfigService {
  final CacheManager _cache = CacheManager.instance;

  /// 保存应用主题
  Future<void> saveTheme(String theme) async {
    await _cache.putString('app_theme', theme, 
      expiry: Duration(days: 30), tags: {'config', 'ui'});
  }

  /// 获取应用主题
  Future<String> getTheme() async {
    return await _cache.getString('app_theme') ?? 'light';
  }

  /// 保存应用语言
  Future<void> saveLanguage(String language) async {
    await _cache.putString('app_language', language, 
      expiry: Duration(days: 30), tags: {'config', 'locale'});
  }

  /// 获取应用语言
  Future<String> getLanguage() async {
    return await _cache.getString('app_language') ?? 'en';
  }

  /// 保存通知设置
  Future<void> saveNotificationSettings(Map<String, dynamic> settings) async {
    await _cache.putMap('notification_settings', settings, 
      expiry: Duration(days: 30), tags: {'config', 'notifications'});
  }

  /// 获取通知设置
  Future<Map<String, dynamic>> getNotificationSettings() async {
    return await _cache.getMap('notification_settings') ?? {
      'push_enabled': true,
      'email_enabled': true,
      'sound_enabled': true,
    };
  }

  /// 清理所有配置
  Future<void> clearAllConfig() async {
    await _cache.clearByTag('config');
  }
}