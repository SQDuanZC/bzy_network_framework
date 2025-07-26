/// BZY 统一网络请求框架
/// 
/// 高性能、易扩展的 Flutter 网络解决方案
/// 提供完整的网络请求、缓存、拦截器、监控等功能
/// 
/// 作者: BZY 团队
/// 版本: 1.0.0
/// 
library bzy_network_framework;

// 核心配置
export 'config/network_config.dart';

// 核心组件
export 'requests/base_network_request.dart';
export 'requests/network_executor.dart';

// BZY 统一网络框架（推荐使用）
export 'frameworks/unified_framework.dart';

// 拦截器系统
export 'core/interceptor/logging_interceptor.dart';

// 数据模型
export 'model/response_wrapper.dart' hide NetworkException;
export 'model/network_response.dart';

// 工具类
export 'utils/network_utils.dart';

// 第三方依赖
export 'package:dio/dio.dart';

/// BZY 网络框架版本信息
const String bzyNetworkFrameworkVersion = '1.0.0';

/// BZY 网络框架名称
const String bzyNetworkFrameworkName = 'BZY Network Framework';