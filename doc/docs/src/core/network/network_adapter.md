# 网络适配器 (NetworkAdapter) 文档

## 概述
`NetworkAdapter` 是网络框架的智能网络适配系统，提供网络状态监控、网络质量检测、自适应策略和弱网环境优化等功能，确保应用在各种网络环境下的稳定运行。

## 文件位置
```
lib/src/core/network/network_adapter.dart
```

## 核心特性

### 1. 网络状态监控
- 实时网络连接状态检测
- 网络变化事件监听
- 网络可用性验证

### 2. 网络质量检测
- 网络延迟测量
- 网络质量等级评估
- 弱网环境识别

### 3. 自适应策略
- 多种网络适配策略
- 智能策略选择
- 自动重试机制

### 4. 弱网优化
- 弱网环境检测
- 请求参数自动调整
- 降级处理策略

## 主要组件

### NetworkAdaptationStrategy 适配策略枚举
```dart
enum NetworkAdaptationStrategy {
  failImmediately,    // 立即失败
  waitForConnection,  // 等待网络恢复
  useCachedData,     // 使用缓存数据
  autoRetry,         // 自动重试
}
```

### NetworkAdapterConfig 适配器配置
```dart
class NetworkAdapterConfig {
  final Duration networkCheckTimeout;        // 网络检查超时时间
  final Duration maxWaitTime;               // 等待网络连接的最大时间
  final int maxRetryAttempts;               // 自动重试次数
  final Duration retryInterval;             // 重试间隔
  final NetworkAdaptationStrategy defaultStrategy; // 默认适配策略
  final bool enableNetworkQualityCheck;    // 是否启用网络质量检测
  final Duration qualityCheckInterval;      // 网络质量检测间隔
}
```

### NetworkQuality 网络质量信息
```dart
class NetworkQuality {
  final int latency;           // 网络延迟（毫秒）
  final int qualityLevel;      // 网络质量等级（1-5，5为最好）
  final DateTime timestamp;    // 检测时间
  final bool isWeakNetwork;    // 是否为弱网环境
}
```

## 核心方法

### 1. initialize() - 初始化适配器
```dart
Future<void> initialize({NetworkAdapterConfig? config}) async
```

**功能**：
- 初始化网络连接监听器
- 启动网络状态监听
- 开始网络质量检测
- 配置适配参数

### 2. checkNetworkAvailability() - 检查网络可用性
```dart
Future<bool> checkNetworkAvailability() async
```

**功能**：
- 检查网络连接状态
- 执行实际网络连通性测试
- 返回网络可用性结果

### 3. waitForConnection() - 等待网络连接
```dart
Future<bool> waitForConnection({Duration? timeout}) async
```

**功能**：
- 等待网络连接恢复
- 支持超时控制
- 返回连接恢复状态

### 4. executeWithAdaptation() - 自适应请求执行
```dart
Future<T> executeWithAdaptation<T>(
  Future<T> Function() request, {
  NetworkAdaptationStrategy? strategy,
  T? cachedData,
}) async
```

**功能**：
- 根据网络状态选择执行策略
- 自动处理网络异常
- 支持缓存数据降级
- 实现智能重试机制

### 5. checkNetworkQuality() - 网络质量检测
```dart
Future<NetworkQuality> checkNetworkQuality() async
```

**功能**：
- 测量网络延迟
- 评估网络质量等级
- 识别弱网环境
- 生成质量报告

## 适配策略详解

### 1. failImmediately - 立即失败
```dart
case NetworkAdaptationStrategy.failImmediately:
  throw NetworkException(
    message: '网络不可用',
    statusCode: -1,
    errorCode: 'NETWORK_UNAVAILABLE',
  );
```

**适用场景**：
- 对实时性要求极高的请求
- 不允许使用缓存数据的场景
- 快速失败需求

### 2. waitForConnection - 等待网络恢复
```dart
case NetworkAdaptationStrategy.waitForConnection:
  final connected = await waitForConnection();
  if (connected) {
    return await request();
  } else {
    throw TimeoutException('等待网络连接超时');
  }
```

**适用场景**：
- 重要的数据提交请求
- 用户主动触发的操作
- 可以等待的非紧急请求

### 3. useCachedData - 使用缓存数据
```dart
case NetworkAdaptationStrategy.useCachedData:
  if (cachedData != null) {
    _logger.info('使用缓存数据');
    return cachedData;
  } else {
    throw NetworkException(
      message: '网络不可用且无缓存数据',
      statusCode: -1,
      errorCode: 'NO_CACHED_DATA',
    );
  }
```

**适用场景**：
- 数据展示类请求
- 对数据实时性要求不高的场景
- 离线模式支持

### 4. autoRetry - 自动重试
```dart
case NetworkAdaptationStrategy.autoRetry:
  return await _executeWithRetry(request);
```

**适用场景**：
- 网络不稳定环境
- 临时网络故障
- 后台数据同步

## 网络质量检测

### 质量等级定义
```dart
NetworkQuality _calculateQuality(int latency) {
  int qualityLevel;
  bool isWeakNetwork;
  
  if (latency < 100) {
    qualityLevel = 5; // 优秀
    isWeakNetwork = false;
  } else if (latency < 300) {
    qualityLevel = 4; // 良好
    isWeakNetwork = false;
  } else if (latency < 600) {
    qualityLevel = 3; // 一般
    isWeakNetwork = false;
  } else if (latency < 1000) {
    qualityLevel = 2; // 较差
    isWeakNetwork = true;
  } else {
    qualityLevel = 1; // 很差
    isWeakNetwork = true;
  }
  
  return NetworkQuality(
    latency: latency,
    qualityLevel: qualityLevel,
    timestamp: DateTime.now(),
    isWeakNetwork: isWeakNetwork,
  );
}
```

### 质量监控
```dart
void _startQualityMonitoring() {
  _qualityCheckTimer = Timer.periodic(_config.qualityCheckInterval, (timer) async {
    try {
      _lastQuality = await checkNetworkQuality();
      _logger.info('网络质量更新: $_lastQuality');
    } catch (e) {
      _logger.warning('网络质量检测失败: $e');
    }
  });
}
```

## 弱网优化

### 弱网检测
```dart
bool get isWeakNetwork {
  return _lastQuality?.isWeakNetwork ?? false;
}
```

### 弱网适配
```dart
Future<T> _adaptForWeakNetwork<T>(Future<T> Function() request) async {
  if (isWeakNetwork) {
    // 调整请求参数
    final adaptedRequest = _adjustRequestForWeakNetwork(request);
    return await adaptedRequest();
  }
  return await request();
}
```

### 参数调整策略
```dart
Future<T> Function() _adjustRequestForWeakNetwork<T>(Future<T> Function() request) {
  return () async {
    // 增加超时时间
    // 减少并发请求
    // 启用数据压缩
    // 降低图片质量
    return await request();
  };
}
```

## 使用示例

### 基本初始化
```dart
// 初始化网络适配器
await NetworkAdapter.instance.initialize(
  config: NetworkAdapterConfig(
    networkCheckTimeout: Duration(seconds: 5),
    maxWaitTime: Duration(seconds: 30),
    maxRetryAttempts: 3,
    retryInterval: Duration(seconds: 2),
    defaultStrategy: NetworkAdaptationStrategy.autoRetry,
    enableNetworkQualityCheck: true,
    qualityCheckInterval: Duration(minutes: 1),
  ),
);
```

### 自适应请求执行
```dart
// 执行带适配策略的请求
final result = await NetworkAdapter.instance.executeWithAdaptation(
  () async {
    // 实际的网络请求
    return await apiService.fetchUserData();
  },
  strategy: NetworkAdaptationStrategy.useCachedData,
  cachedData: cachedUserData,
);
```

### 网络状态检查
```dart
// 检查网络可用性
final isAvailable = await NetworkAdapter.instance.checkNetworkAvailability();
if (isAvailable) {
  // 执行网络请求
  await performNetworkOperation();
} else {
  // 显示离线提示
  showOfflineMessage();
}
```

### 等待网络恢复
```dart
// 等待网络连接恢复
showLoadingDialog('等待网络连接...');
final connected = await NetworkAdapter.instance.waitForConnection(
  timeout: Duration(seconds: 30),
);

hideLoadingDialog();
if (connected) {
  // 网络已恢复，继续操作
  await continueOperation();
} else {
  // 超时，显示错误信息
  showTimeoutError();
}
```

### 网络质量监控
```dart
// 获取当前网络质量
final quality = NetworkAdapter.instance.lastQuality;
if (quality != null) {
  print('网络延迟: ${quality.latency}ms');
  print('质量等级: ${quality.qualityLevel}/5');
  print('是否弱网: ${quality.isWeakNetwork}');
  
  // 根据网络质量调整UI
  if (quality.isWeakNetwork) {
    enableLowQualityMode();
  } else {
    enableHighQualityMode();
  }
}
```

### 自定义适配策略
```dart
// 自定义适配逻辑
final result = await NetworkAdapter.instance.executeWithAdaptation(
  () async {
    return await complexApiCall();
  },
  strategy: isImportantData 
    ? NetworkAdaptationStrategy.waitForConnection
    : NetworkAdaptationStrategy.useCachedData,
  cachedData: fallbackData,
);
```

### 批量请求适配
```dart
// 批量请求的网络适配
final requests = [
  () => api.fetchPosts(),
  () => api.fetchComments(),
  () => api.fetchUserInfo(),
];

final results = <dynamic>[];
for (final request in requests) {
  try {
    final result = await NetworkAdapter.instance.executeWithAdaptation(
      request,
      strategy: NetworkAdaptationStrategy.autoRetry,
    );
    results.add(result);
  } catch (e) {
    // 单个请求失败不影响其他请求
    results.add(null);
  }
}
```

## 事件监听

### 网络状态变化监听
```dart
// 监听网络状态变化
NetworkAdapter.instance._connectivityMonitor.statusStream.listen((status) {
  switch (status) {
    case NetworkStatus.connected:
      onNetworkConnected();
      break;
    case NetworkStatus.disconnected:
      onNetworkDisconnected();
      break;
    case NetworkStatus.unknown:
      onNetworkUnknown();
      break;
  }
});
```

### 网络质量变化监听
```dart
// 监听网络质量变化
Timer.periodic(Duration(seconds: 30), (timer) {
  final quality = NetworkAdapter.instance.lastQuality;
  if (quality != null && quality.isWeakNetwork) {
    // 切换到弱网模式
    switchToLowBandwidthMode();
  } else {
    // 切换到正常模式
    switchToNormalMode();
  }
});
```

## 性能优化

### 1. 智能缓存
- 根据网络质量调整缓存策略
- 弱网环境下增加缓存使用
- 自动清理过期缓存

### 2. 请求优化
- 弱网环境下减少并发请求
- 自动调整超时时间
- 启用数据压缩

### 3. 资源管理
- 及时释放监听器资源
- 优化定时器使用
- 内存使用监控

## 错误处理

### 网络异常处理
```dart
try {
  final result = await NetworkAdapter.instance.executeWithAdaptation(request);
  return result;
} on NetworkException catch (e) {
  // 处理网络异常
  handleNetworkError(e);
} on TimeoutException catch (e) {
  // 处理超时异常
  handleTimeoutError(e);
} catch (e) {
  // 处理其他异常
  handleGenericError(e);
}
```

### 降级处理
```dart
Future<T> executeWithFallback<T>(
  Future<T> Function() primaryRequest,
  T fallbackData,
) async {
  try {
    return await NetworkAdapter.instance.executeWithAdaptation(
      primaryRequest,
      strategy: NetworkAdaptationStrategy.autoRetry,
    );
  } catch (e) {
    // 主请求失败，使用降级数据
    return fallbackData;
  }
}
```

## 设计模式

### 1. 单例模式
确保全局唯一的网络适配器实例。

### 2. 策略模式
不同的网络适配策略可以灵活切换。

### 3. 观察者模式
网络状态变化的监听和通知。

### 4. 装饰器模式
为请求添加网络适配功能。

## 注意事项

1. **初始化顺序**: 确保在使用前正确初始化适配器
2. **资源清理**: 应用退出时调用dispose()方法
3. **策略选择**: 根据业务场景选择合适的适配策略
4. **性能监控**: 定期检查网络质量和适配效果
5. **缓存管理**: 合理设置缓存数据的有效期
6. **错误处理**: 完善的异常处理和用户提示
7. **弱网优化**: 针对弱网环境进行专门优化