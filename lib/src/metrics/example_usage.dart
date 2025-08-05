import 'package:flutter/material.dart';
import 'metrics.dart';

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