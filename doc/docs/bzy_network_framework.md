# BZY Network Framework 主入口文档

## 概述
`bzy_network_framework.dart` 是整个网络框架的主入口文件，负责统一导出所有核心组件和功能模块。

## 文件位置
```
lib/bzy_network_framework.dart
```

## 主要功能

### 1. 统一导出接口
该文件作为框架的门面模式实现，将所有内部模块的公共接口统一导出，为用户提供简洁的API访问方式。

### 2. 模块分类导出

#### 核心配置模块
- `src/config/network_config.dart` - 网络配置管理

#### 核心组件模块
- `src/requests/base_network_request.dart` - 基础网络请求
- `src/requests/network_executor.dart` - 网络执行器
- `src/requests/batch_request.dart` - 批量请求处理

#### 缓存管理模块
- `src/core/cache/cache_manager.dart` - 缓存管理器

#### 统一框架模块
- `src/frameworks/unified_framework.dart` - 统一网络框架（推荐使用）

#### 拦截器系统
- `src/core/interceptor/interceptor_manager.dart` - 拦截器管理器（通过管理器统一导出）

#### 队列和调度系统
- `src/core/queue/request_queue_manager.dart` - 请求队列管理器（隐藏RequestPriority）
- `src/core/scheduler/task_scheduler.dart` - 任务调度器

#### 配置管理系统
- `src/core/config/config_manager.dart` - 配置管理器（通过管理器统一导出）

#### 依赖注入
- `src/core/di/service_locator.dart` - 服务定位器

#### 网络适配和监控
- `src/core/network/network_adapter.dart` - 网络适配器
- `src/core/network/network_connectivity_monitor.dart` - 网络连接监控

#### 数据模型
- `src/model/response_wrapper.dart` - 响应包装器
- `src/model/network_response.dart` - 网络响应模型

#### 异常处理
- `src/core/exception/unified_exception_handler.dart` - 统一异常处理系统（隐藏LogLevel）

#### 工具类
- `src/utils/network_utils.dart` - 网络工具类

#### 指标监控
- `src/metrics/metrics.dart` - 指标监控模块

### 3. 第三方依赖管理
框架选择性导出Dio库的核心组件：
- `Dio` - HTTP客户端
- `Response` - 响应对象
- `RequestOptions` - 请求选项
- `DioException` - Dio异常
- `Interceptor` - 拦截器接口
- `ErrorInterceptorHandler` - 错误拦截器处理器

### 4. 版本信息
- `bzyNetworkFrameworkVersion` - 框架版本号（当前版本：'6'，对应pubspec版本：1.0.6）
- `bzyNetworkFrameworkName` - 框架名称（'BZY Network Framework'）

## 使用方式

```dart
import 'package:bzy_network_framework/bzy_network_framework.dart';

// 现在可以直接使用所有导出的组件
void main() {
  // 使用统一框架
  UnifiedNetworkFramework.initialize();
  
  // 使用网络配置
  NetworkConfig.instance.configure(/* ... */);
  
  // 使用其他组件...
}
```

## 设计原则

1. **单一入口**: 所有公共API通过单一文件导出
2. **模块化**: 按功能模块分类导出
3. **选择性导出**: 只导出必要的第三方依赖组件
4. **版本管理**: 提供版本信息便于管理

## 注意事项

- 某些内部类型（如`RequestPriority`、`LogLevel`）被隐藏，避免API污染
- 第三方依赖只导出必要组件，减少命名空间污染
- 版本信息应与pubspec.yaml保持同步