import 'package:flutter/material.dart';
import 'metrics_collector.dart';

/// 网络框架指标监控 Widget
class NetworkMetricsWidget extends StatefulWidget {
  final bool autoStart;
  final Duration updateInterval;
  final bool showDetailedMetrics;
  final Function(Map<String, dynamic>)? onMetricsUpdate;

  const NetworkMetricsWidget({
    Key? key,
    this.autoStart = false,
    this.updateInterval = const Duration(seconds: 1),
    this.showDetailedMetrics = true,
    this.onMetricsUpdate,
  }) : super(key: key);

  @override
  _NetworkMetricsWidgetState createState() => _NetworkMetricsWidgetState();
}

class _NetworkMetricsWidgetState extends State<NetworkMetricsWidget> {
  final MetricsCollector _collector = MetricsCollector.instance;
  Map<String, dynamic> _queueMetrics = {};
  Map<String, dynamic> _cacheMetrics = {};
  Map<String, dynamic> _interceptorMetrics = {};
  Map<String, dynamic> _networkMetrics = {};
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      _startMonitoring();
    }
  }

  @override
  void dispose() {
    _stopMonitoring();
    super.dispose();
  }

  void _startMonitoring() {
    if (_isMonitoring) return;
    
    setState(() {
      _isMonitoring = true;
    });
    
    _collector.addMetricsUpdateCallback(_onMetricsUpdate);
    _collector.startMonitoring(interval: widget.updateInterval);
  }

  void _stopMonitoring() {
    if (!_isMonitoring) return;
    
    setState(() {
      _isMonitoring = false;
    });
    
    _collector.removeMetricsUpdateCallback(_onMetricsUpdate);
    _collector.stopMonitoring();
  }

  void _onMetricsUpdate(Map<String, dynamic> metrics) {
    setState(() {
      _queueMetrics = metrics['queue'] ?? {};
      _cacheMetrics = metrics['cache'] ?? {};
      _interceptorMetrics = metrics['interceptors'] ?? {};
      _networkMetrics = metrics['network'] ?? {};
    });
    
    widget.onMetricsUpdate?.call(metrics);
  }

  void _resetMetrics() {
    _collector.resetMetrics();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 16),
            if (widget.showDetailedMetrics) ...[
              _buildQueueMetricsSection(),
              SizedBox(height: 16),
              _buildCacheMetricsSection(),
              SizedBox(height: 16),
              _buildInterceptorMetricsSection(),
            ] else ...[
              _buildSummaryMetrics(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '网络框架指标监控',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
              onPressed: _isMonitoring ? _stopMonitoring : _startMonitoring,
            ),
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _resetMetrics,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryMetrics() {
    return Column(
      children: [
        _buildMetricRow('监控状态', _isMonitoring ? '运行中' : '已停止'),
        _buildMetricRow('队列成功率', '${(_queueMetrics['successRate'] ?? 0).toStringAsFixed(1)}%'),
        _buildMetricRow('缓存命中率', '${(_cacheMetrics['totalHitRate'] ?? 0).toStringAsFixed(1)}%'),
        _buildMetricRow('平均响应时间', '${_queueMetrics['averageExecutionTime'] ?? 0}ms'),
      ],
    );
  }

  Widget _buildQueueMetricsSection() {
    return _buildMetricsSection(
      '队列指标',
      [
        _buildMetricRow('总执行请求', '${_queueMetrics['totalExecuted'] ?? 0}'),
        _buildMetricRow('成功请求', '${_queueMetrics['successfulRequests'] ?? 0}'),
        _buildMetricRow('成功率', '${(_queueMetrics['successRate'] ?? 0).toStringAsFixed(1)}%'),
        _buildMetricRow('平均响应时间', '${_queueMetrics['averageExecutionTime'] ?? 0}ms'),
      ],
    );
  }

  Widget _buildCacheMetricsSection() {
    return _buildMetricsSection(
      '缓存指标',
      [
        _buildMetricRow('总请求数', '${_cacheMetrics['totalRequests'] ?? 0}'),
        _buildMetricRow('总命中率', '${(_cacheMetrics['totalHitRate'] ?? 0).toStringAsFixed(1)}%'),
        _buildMetricRow('内存命中率', '${(_cacheMetrics['memoryHitRate'] ?? 0).toStringAsFixed(1)}%'),
        _buildMetricRow('缓存效率', '${_cacheMetrics['efficiency'] ?? 'N/A'}'),
      ],
    );
  }

  Widget _buildInterceptorMetricsSection() {
    return _buildMetricsSection(
      '拦截器指标',
      [
        _buildMetricRow('总拦截器数', '${_interceptorMetrics['totalInterceptors'] ?? 0}'),
        _buildMetricRow('执行次数', '${_interceptorMetrics['executionCount'] ?? 0}'),
        _buildMetricRow('错误率', '${(_interceptorMetrics['errorRate'] ?? 0).toStringAsFixed(1)}%'),
        _buildMetricRow('成功率', '${(_interceptorMetrics['successRate'] ?? 0).toStringAsFixed(1)}%'),
      ],
    );
  }

  Widget _buildMetricsSection(String title, List<Widget> metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        ...metrics,
      ],
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
} 