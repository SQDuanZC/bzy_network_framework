/// 网络框架指标监控模块
/// 
/// 提供网络框架性能指标的收集、监控和可视化功能
/// 
/// ## 使用示例
/// 
/// ```dart
/// import 'package:bzy_network_framework/src/metrics/metrics.dart';
/// 
/// // 开始监控
/// MetricsCollector.instance.startMonitoring();
/// 
/// // 获取指标数据
/// final metrics = MetricsCollector.instance.getFullReport();
/// 
/// // 在 Flutter 界面中使用监控组件
/// NetworkMetricsWidget(
///   autoStart: true,
///   showDetailedMetrics: true,
///   onMetricsUpdate: (metrics) {
///     print('指标更新: $metrics');
///   },
/// )
/// ```
library bzy_network_framework_metrics;

export 'metrics_collector.dart';
export 'metrics_widget.dart'; 