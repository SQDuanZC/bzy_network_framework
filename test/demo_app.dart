import 'package:flutter/material.dart';
import 'package:bzy_network_framework/src/frameworks/unified_framework.dart';
import 'package:bzy_network_framework/src/config/network_config.dart';
import 'example_requests.dart';

/// 演示应用 - 展示统一网络框架的使用
class NetworkFrameworkDemoApp extends StatefulWidget {
  const NetworkFrameworkDemoApp({super.key});

  @override
  State<NetworkFrameworkDemoApp> createState() => _NetworkFrameworkDemoAppState();
}

class _NetworkFrameworkDemoAppState extends State<NetworkFrameworkDemoApp> {
  final UnifiedNetworkFramework _framework = UnifiedNetworkFramework.instance;
  bool _isInitialized = false;
  bool _isLoading = false;
  String _status = '未初始化';
  List<UserModel> _users = [];
  UserModel? _currentUser;
  String _logs = '';

  @override
  void initState() {
    super.initState();
    _initializeFramework();
  }

  /// 初始化网络框架
  Future<void> _initializeFramework() async {
    try {
      setState(() {
        _status = '正在初始化...';
      });

      await _framework.initialize(
        baseUrl: 'https://jsonplaceholder.typicode.com',
        config: {
          'connectTimeout': 30000,
          'receiveTimeout': 30000,
          'enableLogging': true,
          'enableCache': true,
          'environment': Environment.development,
        },
        plugins: [
          // 认证插件
          NetworkPluginFactory.createAuthPlugin(
            getToken: () => 'demo-token-12345',
          ),
          // 缓存插件
          NetworkPluginFactory.createCachePlugin(),
          // 重试插件
          NetworkPluginFactory.createRetryPlugin(),
          // 日志插件
          NetworkPluginFactory.createLoggingPlugin(),
        ],
      );

      setState(() {
        _isInitialized = true;
        _status = '初始化完成';
      });

      _addLog('✅ 网络框架初始化成功');
    } catch (e) {
      setState(() {
        _status = '初始化失败: $e';
      });
      _addLog('❌ 初始化失败: $e');
    }
  }

  /// 获取用户列表
  Future<void> _fetchUsers() async {
    if (!_isInitialized) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _addLog('🚀 开始获取用户列表...');
      
      final request = GetUsersListRequest(page: 1, pageSize: 10);
      final response = await _framework.execute(request);

      if (response.success && response.data != null) {
        setState(() {
          _users = response.data!;
        });
        _addLog('✅ 成功获取 ${_users.length} 个用户');
      } else {
        _addLog('❌ 获取用户列表失败: ${response.message}');
      }
    } catch (e) {
      _addLog('❌ 请求异常: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 获取单个用户信息
  Future<void> _fetchUser(String userId) async {
    if (!_isInitialized) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _addLog('🚀 开始获取用户 $userId 的信息...');
      
      final request = GetUserProfileRequest(userId: userId);
      final response = await _framework.execute(request);

      if (response.success && response.data != null) {
        setState(() {
          _currentUser = response.data;
        });
        _addLog('✅ 成功获取用户信息: ${_currentUser?.name}');
      } else {
        _addLog('❌ 获取用户信息失败: ${response.message}');
      }
    } catch (e) {
      _addLog('❌ 请求异常: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 批量获取用户
  Future<void> _batchFetchUsers() async {
    if (!_isInitialized) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _addLog('🚀 开始批量获取用户信息...');
      
      final requests = [
        GetUserProfileRequest(userId: '1'),
        GetUserProfileRequest(userId: '2'),
        GetUserProfileRequest(userId: '3'),
      ];

      final responses = await _framework.executeBatch(requests);
      
      final successCount = responses.where((r) => r.success).length;
      _addLog('✅ 批量请求完成: $successCount/${responses.length} 成功');
      
      // 更新用户列表
      final users = responses
          .where((r) => r.success && r.data != null)
          .map((r) => r.data!)
          .toList().cast<UserModel>();
      
      setState(() {
        _users = users;
      });
    } catch (e) {
      _addLog('❌ 批量请求异常: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 并发获取用户
  Future<void> _concurrentFetchUsers() async {
    if (!_isInitialized) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _addLog('🚀 开始并发获取用户信息...');
      
      final requests = List.generate(
        5,
        (index) => GetUserProfileRequest(userId: '${index + 1}'),
      );

      final responses = await _framework.executeConcurrent(
        requests,
        maxConcurrency: 2,
      );
      
      final successCount = responses.where((r) => r.success).length;
      _addLog('✅ 并发请求完成: $successCount/${responses.length} 成功');
      
      // 更新用户列表
      final users = responses
          .where((r) => r.success && r.data != null)
          .map((r) => r.data!)
          .toList().cast<UserModel>();
      
      setState(() {
        _users = users;
      });
    } catch (e) {
      _addLog('❌ 并发请求异常: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 测试缓存功能
  Future<void> _testCache() async {
    if (!_isInitialized) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _addLog('🚀 测试缓存功能...');
      
      final request = GetUserProfileRequest(userId: '1');
      
      // 第一次请求（从网络获取）
      final startTime1 = DateTime.now();
      final response1 = await _framework.execute(request);
      final duration1 = DateTime.now().difference(startTime1).inMilliseconds;
      
      if (response1.success) {
        _addLog('✅ 第一次请求成功 (${duration1}ms)');
      }
      
      // 第二次请求（从缓存获取）
      final startTime2 = DateTime.now();
      final response2 = await _framework.execute(request);
      final duration2 = DateTime.now().difference(startTime2).inMilliseconds;
      
      if (response2.success) {
        _addLog('✅ 第二次请求成功 (${duration2}ms) - 缓存加速: ${duration1 - duration2}ms');
      }
    } catch (e) {
      _addLog('❌ 缓存测试异常: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 更新配置
  void _updateConfig() {
    try {
      _framework.updateConfig({
        'connectTimeout': 15000,
        'enableCache': !(_framework.getStatus()['config']['enableCache'] ?? true),
      });
      
      final status = _framework.getStatus();
      final cacheEnabled = status['config']['enableCache'] ?? false;
      _addLog('⚙️ 配置已更新 - 缓存: ${cacheEnabled ? "启用" : "禁用"}');
    } catch (e) {
      _addLog('❌ 配置更新失败: $e');
    }
  }

  /// 获取框架状态
  void _getFrameworkStatus() {
    try {
      final status = _framework.getStatus();
      _addLog('📊 框架状态:');
      _addLog('  - 已初始化: ${status['isInitialized']}');
      _addLog('  - 插件数量: ${status['pluginsCount']}');
      _addLog('  - 拦截器数量: ${status['globalInterceptorsCount']}');
      _addLog('  - 待处理请求: ${status['executor']['pendingRequests']}');
      _addLog('  - 队列中请求: ${status['executor']['queuedRequests']}');
      _addLog('  - 缓存大小: ${status['executor']['cacheSize']}');
    } catch (e) {
      _addLog('❌ 获取状态失败: $e');
    }
  }

  /// 清理资源
  Future<void> _cleanup() async {
    try {
      await _framework.dispose();
      setState(() {
        _isInitialized = false;
        _status = '已清理';
        _users.clear();
        _currentUser = null;
      });
      _addLog('🧹 资源清理完成');
    } catch (e) {
      _addLog('❌ 清理失败: $e');
    }
  }

  /// 添加日志
  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _logs += '[$timestamp] $message\n';
    });
  }

  /// 清空日志
  void _clearLogs() {
    setState(() {
      _logs = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('统一网络框架演示'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 状态栏
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isInitialized ? Colors.green.shade100 : Colors.orange.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '框架状态: $_status',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
          
          // 操作按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _isInitialized && !_isLoading ? _fetchUsers : null,
                  child: const Text('获取用户列表'),
                ),
                ElevatedButton(
                  onPressed: _isInitialized && !_isLoading ? () => _fetchUser('1') : null,
                  child: const Text('获取用户1'),
                ),
                ElevatedButton(
                  onPressed: _isInitialized && !_isLoading ? _batchFetchUsers : null,
                  child: const Text('批量请求'),
                ),
                ElevatedButton(
                  onPressed: _isInitialized && !_isLoading ? _concurrentFetchUsers : null,
                  child: const Text('并发请求'),
                ),
                ElevatedButton(
                  onPressed: _isInitialized && !_isLoading ? _testCache : null,
                  child: const Text('测试缓存'),
                ),
                ElevatedButton(
                  onPressed: _isInitialized ? _updateConfig : null,
                  child: const Text('更新配置'),
                ),
                ElevatedButton(
                  onPressed: _isInitialized ? _getFrameworkStatus : null,
                  child: const Text('获取状态'),
                ),
                ElevatedButton(
                  onPressed: _isInitialized ? _cleanup : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('清理资源'),
                ),
              ],
            ),
          ),
          
          // 内容区域
          Expanded(
            child: Row(
              children: [
                // 用户列表
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '用户列表 (${_users.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(user.id),
                              ),
                              title: Text(user.name),
                              subtitle: Text(user.email),
                              trailing: const Chip(
                                label: Text('活跃'),
                                backgroundColor: Colors.green,
                              ),
                              onTap: () => _fetchUser(user.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                const VerticalDivider(),
                
                // 当前用户详情
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          '用户详情',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_currentUser != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentUser!.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('ID: ${_currentUser!.id}'),
                                  Text('姓名: ${_currentUser!.name}'),
                                  Text('邮箱: ${_currentUser!.email}'),
                                  const Text('状态: 活跃'),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('请选择一个用户查看详情'),
                        ),
                    ],
                  ),
                ),
                
                const VerticalDivider(),
                
                // 日志区域
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Text(
                              '操作日志',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _clearLogs,
                              child: const Text('清空'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _logs.isEmpty ? '暂无日志' : _logs,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _framework.dispose();
    super.dispose();
  }
}

/// 演示应用入口
class NetworkFrameworkDemo extends StatelessWidget {
  const NetworkFrameworkDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '统一网络框架演示',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const NetworkFrameworkDemoApp(),
      debugShowCheckedModeBanner: false,
    );
  }
}