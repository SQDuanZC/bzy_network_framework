/// BZY 统一网络请求框架
library bzy_network_framework;

// 核心配置
export 'src/config/network_config.dart';

// 核心组件
export 'src/requests/base_network_request.dart';
export 'src/requests/network_executor.dart';

// 缓存管理
export 'src/core/cache/cache_manager.dart';

// BZY 统一网络框架（推荐使用）
export 'src/frameworks/unified_framework.dart';

// 拦截器系统
export 'src/core/interceptor/logging_interceptor.dart';

// 数据模型
export 'src/model/response_wrapper.dart';
export 'src/model/network_response.dart';

// 统一异常处理系统
export 'src/core/exception/unified_exception_handler.dart' hide LogLevel;

// 工具类
export 'src/utils/network_utils.dart';

// 第三方依赖
export 'package:dio/dio.dart';

/// BZY 网络框架版本信息
const String bzyNetworkFrameworkVersion = '1.0.0';

/// BZY 网络框架名称
const String bzyNetworkFrameworkName = 'BZY Network Framework';