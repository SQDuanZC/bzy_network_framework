/// BZY 统一网络请求框架
library bzy_network_framework;

// 核心配置
export 'src/config/network_config.dart';

// 核心组件
export 'src/requests/base_network_request.dart';
export 'src/requests/network_executor.dart';
export 'src/requests/batch_request.dart';

// 缓存管理
export 'src/core/cache/cache_manager.dart';

// BZY 统一网络框架（推荐使用）
export 'src/frameworks/unified_framework.dart';

// 拦截器系统（通过管理器统一导出）
export 'src/core/interceptor/interceptor_manager.dart';

// 队列和调度系统
export 'src/core/queue/request_queue_manager.dart' hide RequestPriority;
export 'src/core/scheduler/task_scheduler.dart';

// 配置管理（通过管理器统一导出）
export 'src/core/config/config_manager.dart';

// 服务定位器
export 'src/core/di/service_locator.dart';

// 网络适配和监控
export 'src/core/network/network_adapter.dart';
export 'src/core/network/network_connectivity_monitor.dart';

// 数据模型
export 'src/model/response_wrapper.dart';
export 'src/model/network_response.dart';

// 统一异常处理系统
export 'src/core/exception/unified_exception_handler.dart' hide LogLevel;

// 工具类
export 'src/utils/network_utils.dart';

// 指标监控模块
export 'src/metrics/metrics.dart';

// 第三方依赖 - 只导出必要的组件
export 'package:dio/dio.dart' show Dio, Response, RequestOptions, DioException, Interceptor, ErrorInterceptorHandler;

/// BZY 网络框架版本信息
const String bzyNetworkFrameworkVersion = '1.1.1';


/// BZY 网络框架名称
const String bzyNetworkFrameworkName = 'BZY Network Framework';