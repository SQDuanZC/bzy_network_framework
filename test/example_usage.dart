import 'package:flutter/material.dart';
import 'package:bzy_network_framework/src/metrics/metrics.dart';
import 'package:bzy_network_framework/src/core/cache/cache_manager.dart';
import 'package:bzy_network_framework/src/config/network_config.dart';

/// 指标监控使用示例
/// 
/// 展示如何在应用中使用网络框架指标监控功能
class MetricsExample extends StatefulWidget {
  @override
  _MetricsExampleState createState() => _MetricsExampleState();
}

class _MetricsExampleState extends State<MetricsExample> {
  @override
  void initState() {
    super.initState();
    // 初始化网络框架（这里应该在实际应用中进行）
    _initializeNetworkFramework();
  }

  void _initializeNetworkFramework() {
    // 这里应该初始化网络框架
    // 为了示例，我们直接开始监控
    MetricsCollector.instance.startMonitoring();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('网络框架指标监控示例'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // 详细监控组件
            NetworkMetricsWidget(
              autoStart: true,
              showDetailedMetrics: true,
              onMetricsUpdate: (metrics) {
                print('指标更新: ${metrics['timestamp']}');
              },
            ),
            
            SizedBox(height: 20),
            
            // 简化监控组件
            NetworkMetricsWidget(
              autoStart: false,
              showDetailedMetrics: false,
            ),
            
            SizedBox(height: 20),
            
            // 手动控制按钮
            _buildControlButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '手动控制',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      MetricsCollector.instance.startMonitoring();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('开始监控')),
                      );
                    },
                    child: Text('开始监控'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      MetricsCollector.instance.stopMonitoring();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('停止监控')),
                      );
                    },
                    child: Text('停止监控'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      MetricsCollector.instance.resetMetrics();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('重置指标')),
                      );
                    },
                    child: Text('重置指标'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final report = MetricsCollector.instance.getFullReport();
                      print('=== 完整指标报告 ===');
                      print(report);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('报告已生成，请查看控制台')),
                      );
                    },
                    child: Text('生成报告'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 快速集成示例
/// 
/// 展示如何在现有应用中快速集成指标监控
class QuickIntegrationExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('快速集成示例')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // 在现有界面中嵌入指标监控
            NetworkMetricsWidget(
              autoStart: true,
              showDetailedMetrics: false, // 只显示关键指标
            ),
            
            SizedBox(height: 20),
            
            // 其他应用内容
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('这里是应用的其他内容...'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 缓存功能使用示例
/// 
/// 展示如何在Flutter应用中使用缓存管理器的简化接口
class CacheUsageExample extends StatefulWidget {
  @override
  _CacheUsageExampleState createState() => _CacheUsageExampleState();
}

class _CacheUsageExampleState extends State<CacheUsageExample> {
  final CacheManager _cacheManager = CacheManager.instance;
  String _cacheStatus = '未初始化';
  Map<String, dynamic> _cacheData = {};

  @override
  void initState() {
    super.initState();
    _initializeCache();
  }

  void _initializeCache() {
    // 初始化网络配置
    NetworkConfig.instance.initialize(
      baseUrl: 'https://api.example.com',
      enableCache: true,
      defaultCacheDuration: 300,
    );
    
    setState(() {
      _cacheStatus = '已初始化';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('缓存功能使用示例'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 缓存状态显示
            _buildStatusCard(),
            
            SizedBox(height: 16),
            
            // 基础数据类型缓存
            _buildBasicTypesCard(),
            
            SizedBox(height: 16),
            
            // 集合类型缓存
            _buildCollectionTypesCard(),
            
            SizedBox(height: 16),
            
            // 缓存管理操作
            _buildManagementCard(),
            
            SizedBox(height: 16),
            
            // 缓存数据显示
            _buildDataDisplayCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '缓存状态',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('状态: $_cacheStatus'),
            SizedBox(height: 8),
            FutureBuilder<Map<String, dynamic>>(
              future: _getCacheStatistics(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final stats = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('总请求数: ${stats['totalRequests']}'),
                      Text('内存命中数: ${stats['memoryHits']}'),
                      Text('磁盘命中数: ${stats['diskHits']}'),
                      Text('未命中数: ${stats['misses']}'),
                      Text('总命中率: ${stats['hitRate']}%'),
                    ],
                  );
                }
                return Text('加载统计信息...');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicTypesCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '基础数据类型缓存',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _cacheString(),
                  child: Text('缓存字符串'),
                ),
                ElevatedButton(
                  onPressed: () => _cacheInt(),
                  child: Text('缓存整数'),
                ),
                ElevatedButton(
                  onPressed: () => _cacheDouble(),
                  child: Text('缓存浮点数'),
                ),
                ElevatedButton(
                  onPressed: () => _cacheBool(),
                  child: Text('缓存布尔值'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionTypesCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '集合类型缓存',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _cacheMap(),
                  child: Text('缓存Map'),
                ),
                ElevatedButton(
                  onPressed: () => _cacheList(),
                  child: Text('缓存List'),
                ),
                ElevatedButton(
                  onPressed: () => _cacheObject(),
                  child: Text('缓存对象'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '缓存管理',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _checkCacheExists(),
                  child: Text('检查存在'),
                ),
                ElevatedButton(
                  onPressed: () => _extendExpiry(),
                  child: Text('延长过期'),
                ),
                ElevatedButton(
                  onPressed: () => _clearByTag(),
                  child: Text('按标签清理'),
                ),
                ElevatedButton(
                  onPressed: () => _clearAllCache(),
                  child: Text('清空所有'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataDisplayCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '缓存数据',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _cacheData.isEmpty 
                  ? '暂无缓存数据' 
                  : _cacheData.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join('\n'),
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 缓存操作方法
  Future<void> _cacheString() async {
    await _cacheManager.putString(
      'demo_string', 
      'Hello, Cache!',
      expiry: Duration(minutes: 5),
      tags: {'demo', 'string'},
    );
    await _updateCacheData();
    _showSnackBar('字符串已缓存');
  }

  Future<void> _cacheInt() async {
    await _cacheManager.putInt(
      'demo_int', 
      42,
      expiry: Duration(minutes: 5),
      tags: {'demo', 'number'},
    );
    await _updateCacheData();
    _showSnackBar('整数已缓存');
  }

  Future<void> _cacheDouble() async {
    await _cacheManager.putDouble(
      'demo_double', 
      3.14159,
      expiry: Duration(minutes: 5),
      tags: {'demo', 'number'},
    );
    await _updateCacheData();
    _showSnackBar('浮点数已缓存');
  }

  Future<void> _cacheBool() async {
    await _cacheManager.putBool(
      'demo_bool', 
      true,
      expiry: Duration(minutes: 5),
      tags: {'demo', 'boolean'},
    );
    await _updateCacheData();
    _showSnackBar('布尔值已缓存');
  }

  Future<void> _cacheMap() async {
    await _cacheManager.putMap(
      'demo_map', 
      {'name': 'John', 'age': 30, 'city': 'New York'},
      expiry: Duration(minutes: 5),
      tags: {'demo', 'collection'},
    );
    await _updateCacheData();
    _showSnackBar('Map已缓存');
  }

  Future<void> _cacheList() async {
    await _cacheManager.putList<String>(
      'demo_list', 
      ['apple', 'banana', 'orange'],
      expiry: Duration(minutes: 5),
      tags: {'demo', 'collection'},
    );
    await _updateCacheData();
    _showSnackBar('List已缓存');
  }

  Future<void> _cacheObject() async {
    final user = DemoUser(id: 1, name: 'Alice', email: 'alice@example.com');
    await _cacheManager.putObject(
      'demo_object', 
      user,
      expiry: Duration(minutes: 5),
      tags: {'demo', 'object'},
    );
    await _updateCacheData();
    _showSnackBar('对象已缓存');
  }

  Future<void> _checkCacheExists() async {
    final exists = await _cacheManager.exists('demo_string');
    _showSnackBar('demo_string 存在: $exists');
  }

  Future<void> _extendExpiry() async {
    await _cacheManager.extendExpiry('demo_string', Duration(minutes: 10));
    _showSnackBar('已延长 demo_string 的过期时间');
  }

  Future<void> _clearByTag() async {
    await _cacheManager.clearByTag('demo');
    await _updateCacheData();
    _showSnackBar('已清理所有demo标签的缓存');
  }

  Future<void> _clearAllCache() async {
    await _cacheManager.clear();
    await _updateCacheData();
    _showSnackBar('已清空所有缓存');
  }

  Future<void> _updateCacheData() async {
    final data = <String, dynamic>{};
    
    // 获取各种类型的缓存数据
    data['string'] = await _cacheManager.getString('demo_string');
    data['int'] = await _cacheManager.getInt('demo_int');
    data['double'] = await _cacheManager.getDouble('demo_double');
    data['bool'] = await _cacheManager.getBool('demo_bool');
    data['map'] = await _cacheManager.getMap('demo_map');
    data['list'] = await _cacheManager.getList<String>('demo_list');
    
    final user = await _cacheManager.getObject<DemoUser>('demo_object');
    data['object'] = user != null ? '${user.name} (${user.email})' : null;
    
    // 移除null值
    data.removeWhere((key, value) => value == null);
    
    setState(() {
      _cacheData = data;
    });
  }

  Future<Map<String, dynamic>> _getCacheStatistics() async {
    final stats = _cacheManager.statistics;
    return {
      'totalRequests': stats.totalRequests,
      'memoryHits': stats.memoryHits,
      'diskHits': stats.diskHits,
      'misses': stats.misses,
      'hitRate': (stats.totalHitRate * 100).toStringAsFixed(1),
    };
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// 演示用户类
class DemoUser {
  final int id;
  final String name;
  final String email;

  DemoUser({required this.id, required this.name, required this.email});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
  };

  static DemoUser fromJson(Map<String, dynamic> json) => DemoUser(
    id: json['id'],
    name: json['name'],
    email: json['email'],
  );
}