# 网络框架指标监控模块

## 概述

网络框架指标监控模块提供了实时监控网络框架性能指标的功能，包括队列统计、缓存性能、拦截器执行情况等关键指标。

## 功能特性

- ✅ **实时监控**: 支持实时收集和显示网络框架性能指标
- ✅ **可视化界面**: 提供 Flutter Widget 组件，方便集成到应用中
- ✅ **多种指标**: 监控队列、缓存、拦截器、网络配置等多个维度
- ✅ **灵活配置**: 支持自定义监控间隔、显示详细程度等
- ✅ **回调支持**: 提供指标更新回调，支持自定义处理逻辑
- ✅ **报告生成**: 支持生成完整的性能报告

## 快速开始

### 1. 基本使用

```dart
import 'package:bzy_network_framework/bzy_network_framework.dart';

// 开始监控
MetricsCollector.instance.startMonitoring();

// 获取指标数据
final metrics = MetricsCollector.instance.getFullReport();
```

### 2. 在 Flutter 界面中使用

```dart
import 'package:flutter/material.dart';
import 'package:bzy_network_framework/bzy_network_framework.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            // 详细监控组件
            NetworkMetricsWidget(
              autoStart: true,
              showDetailedMetrics: true,
              onMetricsUpdate: (metrics) {
                print('指标更新: ${metrics['timestamp']}');
              },
            ),
            
            // 简化监控组件
            NetworkMetricsWidget(
              autoStart: false,
              showDetailedMetrics: false,
            ),
          ],
        ),
      ),
    );
  }
}
```

## API 参考

### MetricsCollector

指标收集器，负责收集和管理网络框架的性能指标。

#### 主要方法

- `startMonitoring({Duration interval})`: 开始监控
- `stopMonitoring()`: 停止监控
- `resetMetrics()`: 重置所有指标
- `getFullReport()`: 获取完整指标报告
- `addMetricsUpdateCallback(callback)`: 添加指标更新回调

#### 属性

- `queueMetrics`: 队列指标
- `cacheMetrics`: 缓存指标
- `interceptorMetrics`: 拦截器指标
- `networkMetrics`: 网络配置指标
- `isMonitoring`: 是否正在监控

### NetworkMetricsWidget

Flutter Widget 组件，提供指标监控的可视化界面。

#### 参数

- `autoStart`: 是否自动开始监控
- `updateInterval`: 监控更新间隔
- `showDetailedMetrics`: 是否显示详细指标
- `onMetricsUpdate`: 指标更新回调

## 监控指标说明

### 队列指标

- **总执行请求**: 已执行的请求总数
- **成功请求**: 成功完成的请求数
- **成功率**: 成功请求占总请求的百分比
- **平均响应时间**: 请求的平均响应时间
- **重复请求**: 被识别为重复的请求数
- **超时请求**: 超时的请求数

### 缓存指标

- **总请求数**: 缓存系统处理的请求总数
- **总命中率**: 缓存命中的总体比例
- **内存命中率**: 内存缓存命中率
- **磁盘命中率**: 磁盘缓存命中率
- **缓存效率**: 缓存效率评级（优秀/良好/一般/需要优化）

### 拦截器指标

- **总拦截器数**: 注册的拦截器总数
- **执行次数**: 拦截器执行的总次数
- **错误率**: 拦截器执行失败的比例
- **成功率**: 拦截器执行成功的比例

### 网络配置指标

- **基础URL**: 网络请求的基础URL
- **连接超时**: 连接超时时间
- **接收超时**: 接收数据超时时间
- **发送超时**: 发送数据超时时间
- **最大重试**: 最大重试次数
- **重试延迟**: 重试间隔时间
- **启用缓存**: 是否启用缓存
- **启用日志**: 是否启用日志
- **缓存时长**: 默认缓存时长
- **指数退避**: 是否启用指数退避
- **环境**: 当前运行环境

## 使用场景

### 1. 开发调试

在开发阶段使用详细监控，帮助调试网络请求问题：

```dart
NetworkMetricsWidget(
  autoStart: true,
  showDetailedMetrics: true,
  updateInterval: Duration(seconds: 1),
)
```

### 2. 生产监控

在生产环境中使用简化监控，只显示关键指标：

```dart
NetworkMetricsWidget(
  autoStart: true,
  showDetailedMetrics: false,
  updateInterval: Duration(seconds: 5),
)
```

### 3. 性能分析

使用回调函数进行自定义的性能分析：

```dart
MetricsCollector.instance.addMetricsUpdateCallback((metrics) {
  // 自定义性能分析逻辑
  if (metrics['queue']['successRate'] < 90) {
    // 成功率过低，发送告警
    _sendAlert('网络请求成功率过低: ${metrics['queue']['successRate']}%');
  }
});
```

### 4. 报告生成

定期生成性能报告：

```dart
Timer.periodic(Duration(minutes: 30), (timer) {
  final report = MetricsCollector.instance.getFullReport();
  _saveReport(report);
});
```

## 最佳实践

1. **合理设置监控间隔**: 开发环境可以设置较短的间隔（1秒），生产环境建议设置较长的间隔（5-10秒）

2. **及时处理异常**: 在回调函数中及时处理异常情况，避免影响应用性能

3. **资源管理**: 在不需要监控时及时停止，避免资源浪费

4. **数据持久化**: 对于重要的性能数据，建议进行持久化存储

5. **告警机制**: 设置合理的告警阈值，及时发现性能问题

## 注意事项

- 指标监控会消耗一定的系统资源，建议在不需要时及时停止
- 监控数据是实时计算的，重启应用后数据会重置
- 某些指标可能依赖于网络框架的具体实现，如果框架版本更新可能需要相应调整 