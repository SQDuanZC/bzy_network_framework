import 'dart:async';
import 'dart:math';
import 'package:bzy_network_framework/src/requests/base_network_request.dart';
import 'package:bzy_network_framework/src/requests/network_executor.dart';
import 'package:bzy_network_framework/src/frameworks/unified_framework.dart';
import 'package:bzy_network_framework/src/core/queue/request_queue_manager.dart' as queue;
import 'package:bzy_network_framework/src/model/network_response.dart';

/// 网络请求综合Demo
/// 展示串行、并行、队列监控等功能
class NetworkDemo {
  late UnifiedNetworkFramework _framework;
  
  /// 初始化Demo
  Future<void> initialize() async {
    print('🚀 初始化网络框架Demo...');
    
    // 初始化统一网络框架
    _framework = UnifiedNetworkFramework.instance;
    await _framework.initialize(
      baseUrl: 'https://api.example.com',
      config: {
        'connectTimeout': 15000,
        'receiveTimeout': 15000,
        'enableLogging': true,
      },
    );
    
    print('✅ 网络框架初始化完成\n');
  }
  
  /// 运行所有Demo
  Future<void> runAllDemos() async {
    await initialize();
    
    print('='.padRight(50, '='));
    print('🎯 开始网络请求Demo演示');
    print('='.padRight(50, '='));
    
    // 1. 基础请求Demo
    await basicRequestDemo();
    await Future.delayed(Duration(seconds: 1));
    
    // 2. 串行请求Demo
    await sequentialRequestDemo();
    await Future.delayed(Duration(seconds: 1));
    
    // 3. 并行请求Demo
    await parallelRequestDemo();
    await Future.delayed(Duration(seconds: 1));
    
    // 4. 混合策略Demo
    await mixedStrategyDemo();
    await Future.delayed(Duration(seconds: 1));
    
    // 5. 优先级Demo
    await priorityDemo();
    await Future.delayed(Duration(seconds: 1));
    
    // 6. 显示完成信息
    print('\n📊 所有请求演示完成');
    
    print('\n🎉 所有Demo演示完成!');
  }
  
  /// 1. 基础请求Demo
  Future<void> basicRequestDemo() async {
    print('\n📱 === 基础请求Demo ===');
    
    try {
      // 创建一个简单的GET请求
      final request = DemoGetRequest('/api/user/profile');
      
      print('🔄 发送请求: ${request.path}');
      final response = await _framework.execute(request);
      
      print('✅ 请求成功: ${response.statusCode}');
      print('📄 响应数据: ${response.data}');
      
    } catch (e) {
      print('❌ 请求失败: $e');
    }
  }
  
  /// 2. 串行请求Demo
  Future<void> sequentialRequestDemo() async {
    print('\n🔗 === 串行请求Demo ===');
    
    final stopwatch = Stopwatch()..start();
    
    // 创建多个有依赖关系的请求
    final requests = [
      DemoGetRequest('/api/auth/login'),
      DemoGetRequest('/api/user/profile'),
      DemoGetRequest('/api/user/settings'),
      DemoGetRequest('/api/user/notifications'),
    ];
    
    print('🔄 开始串行执行 ${requests.length} 个请求...');
    
    try {
      // 方法1: 使用executeBatch (推荐)
      final responses = await _framework.executeBatch(requests);
      
      stopwatch.stop();
      print('✅ 串行请求完成!');
      print('⏱️ 总耗时: ${stopwatch.elapsedMilliseconds}ms');
      print('📊 成功响应: ${responses.length}个');
      
      // 显示每个响应的状态
      for (int i = 0; i < responses.length; i++) {
        print('   ${i + 1}. ${requests[i].path} -> ${responses[i].statusCode}');
      }
      
    } catch (e) {
      print('❌ 串行请求失败: $e');
    }
  }
  
  /// 3. 并行请求Demo
  Future<void> parallelRequestDemo() async {
    print('\n⚡ === 并行请求Demo ===');
    
    final stopwatch = Stopwatch()..start();
    
    // 创建多个独立的请求
    final requests = [
      DemoGetRequest('/api/weather'),
      DemoGetRequest('/api/news'),
      DemoGetRequest('/api/stocks'),
      DemoGetRequest('/api/sports'),
      DemoGetRequest('/api/entertainment'),
    ];
    
    print('🔄 开始并行执行 ${requests.length} 个请求 (最大并发: 3)...');
    
    try {
      // 方法1: 使用executeConcurrent (推荐)
      final responses = await _framework.executeConcurrent(
        requests,
        maxConcurrency: 3,
      );
      
      stopwatch.stop();
      print('✅ 并行请求完成!');
      print('⏱️ 总耗时: ${stopwatch.elapsedMilliseconds}ms');
      print('📊 成功响应: ${responses.length}个');
      
      // 显示每个响应的状态
      for (int i = 0; i < responses.length; i++) {
        print('   ${i + 1}. ${requests[i].path} -> ${responses[i].statusCode}');
      }
      
      print('\n🔄 对比: 使用Future.wait完全并行...');
      
      // 方法2: 使用Future.wait (完全并行)
      final stopwatch2 = Stopwatch()..start();
      final futures = requests.map((r) => _framework.execute(r)).toList();
      final responses2 = await Future.wait(futures);
      stopwatch2.stop();
      
      print('✅ 完全并行完成!');
      print('⏱️ 耗时: ${stopwatch2.elapsedMilliseconds}ms');
      print('📊 响应: ${responses2.length}个');
      
    } catch (e) {
      print('❌ 并行请求失败: $e');
    }
  }
  
  /// 4. 混合策略Demo
  Future<void> mixedStrategyDemo() async {
    print('\n🎯 === 混合策略Demo ===');
    
    final stopwatch = Stopwatch()..start();
    
    try {
      print('🔄 第一阶段: 串行加载关键数据...');
      
      // 阶段1: 串行加载关键数据
      final criticalRequests = [
        DemoGetRequest('/api/auth/token'),
        DemoGetRequest('/api/user/config'),
      ];
      
      final criticalResponses = await _framework.executeBatch(criticalRequests);
      print('✅ 关键数据加载完成: ${criticalResponses.length}个');
      
      print('🔄 第二阶段: 并行加载次要数据...');
      
      // 阶段2: 并行加载次要数据
      final secondaryRequests = [
        DemoGetRequest('/api/ads'),
        DemoGetRequest('/api/recommendations'),
        DemoGetRequest('/api/analytics'),
      ];
      
      final secondaryResponses = await _framework.executeConcurrent(
        secondaryRequests,
        maxConcurrency: 3,
      );
      
      stopwatch.stop();
      print('✅ 次要数据加载完成: ${secondaryResponses.length}个');
      print('⏱️ 混合策略总耗时: ${stopwatch.elapsedMilliseconds}ms');
      
    } catch (e) {
      print('❌ 混合策略失败: $e');
    }
  }
  
  /// 5. 优先级Demo
  Future<void> priorityDemo() async {
    print('\n🏆 === 优先级请求Demo ===');
    
    try {
      // 创建不同优先级的请求
      final requests = [
        DemoPriorityRequest('/api/low-priority', RequestPriority.low),
        DemoPriorityRequest('/api/critical', RequestPriority.critical),
        DemoPriorityRequest('/api/normal', RequestPriority.normal),
        DemoPriorityRequest('/api/high-priority', RequestPriority.high),
        DemoPriorityRequest('/api/another-low', RequestPriority.low),
      ];
      
      print('🔄 发送不同优先级的请求...');
      print('   📋 请求顺序: LOW -> CRITICAL -> NORMAL -> HIGH -> LOW');
      print('   🎯 执行顺序应该是: CRITICAL -> HIGH -> NORMAL -> LOW -> LOW');
      
      // 同时发送所有请求，观察执行顺序
      final futures = requests.map((r) => _framework.execute(r)).toList();
      final responses = await Future.wait(futures);
      
      print('✅ 优先级请求完成: ${responses.length}个');
      
    } catch (e) {
      print('❌ 优先级请求失败: $e');
    }
  }
  

}

/// Demo用的GET请求
class DemoGetRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String _path;
  
  DemoGetRequest(this._path);
  
  @override
  String get path => _path;
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  RequestPriority get priority => RequestPriority.normal;
  
  @override
  Map<String, dynamic> parseResponse(dynamic responseData) {
    throw UnimplementedError('parseResponse not implemented for DemoGetRequest');
    // 模拟解析响应数据
    // return {
    //   'path': path,
    //   'timestamp': DateTime.now().toIso8601String(),
    //   'data': 'Mock response for $path',
    //   'random': Random().nextInt(1000),
    // };
  }
  
  @override
  Future<void> onRequestStart() async {
    print('   🔄 开始请求: $path');
  }
  
  @override
  Future<void> onRequestComplete(NetworkResponse response) async {
    print('   ✅ 请求完成: $path (${response.statusCode})');
  }
  
  @override
  Future<void> onRequestError(dynamic error) async {
    print('   ❌ 请求失败: $path ($error)');
  }
}

/// Demo用的优先级请求
class DemoPriorityRequest extends DemoGetRequest {
  final RequestPriority _priority;
  
  DemoPriorityRequest(String path, this._priority) : super(path);
  
  @override
  RequestPriority get priority => _priority;
  
  @override
  Future<void> onRequestStart() async {
    print('   🔄 [${priority.name.toUpperCase()}] 开始请求: $path');
  }
  
  @override
  Future<void> onRequestComplete(NetworkResponse response) async {
    print('   ✅ [${priority.name.toUpperCase()}] 请求完成: $path (${response.statusCode})');
  }
}

/// Demo主函数
void main() async {
  final demo = NetworkDemo();
  await demo.runAllDemos();
}

/// 使用示例类
class NetworkDemoUsage {
  /// 在实际应用中的使用示例
  static Future<void> exampleUsage() async {
    final demo = NetworkDemo();
    await demo.initialize();
    
    // 只运行特定的Demo
    await demo.basicRequestDemo();
    await demo.parallelRequestDemo();
    
    // 显示完成信息
    print('Demo使用示例完成');
  }
  
  /// 在Flutter Widget中的使用示例
  static Future<void> widgetUsage() async {
    // 在initState中初始化
    final demo = NetworkDemo();
    await demo.initialize();
    
    // 在按钮点击时执行请求
    // await demo.basicRequestDemo();
  }
}