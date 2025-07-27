# 测试文件夹说明

本文件夹包含了 BZY Network Framework 统一异常处理机制的完整测试示例和工具。

## 文件结构

```
test/
├── README.md                      # 本说明文件
├── test_config.dart               # 测试配置和工具类
├── test_suite.dart                # 完整测试套件
├── unified_exception_test.dart    # 统一异常处理完整测试
├── simple_exception_test.dart     # 简单异常处理测试示例
├── usage_examples.dart            # 网络框架使用示例
├── network_demo.dart              # 网络请求综合Demo
├── demo_app.dart                  # Flutter Demo应用
└── network_test_base.dart         # 网络测试基础设施
```

## 测试文件说明

### 1. test_config.dart
测试配置和工具类，包含：
- `TestConfig`: 测试环境配置
- `TestApiRequest`: 测试用的网络请求类
- `TestExceptionGenerator`: 异常生成器
- `TestAssertions`: 测试断言工具
- `TestDataGenerator`: 测试数据生成器
- `TestPerformanceMonitor`: 性能监控工具

### 2. unified_exception_test.dart
完整的统一异常处理测试，包含：
- DioException 转换测试
- HTTP 状态码处理测试
- SocketException 处理测试
- FormatException 处理测试
- 自定义异常处理测试
- 异常统计功能测试
- 全局异常处理器测试
- 异常上下文和元数据测试
- 异常重试判断测试
- 异常类型判断测试
- 异常拦截器测试
- 网络框架集成测试
- 性能测试
- 边界测试

### 3. simple_exception_test.dart
简单的异常处理测试示例，适合快速了解和学习：
- 基本异常转换
- HTTP错误处理
- 自定义异常
- 异常统计
- 异常属性判断
- 异常上下文和元数据
- 全局异常处理器

### 4. test_suite.dart
完整的测试套件，运行所有测试：
- 统一异常处理测试
- 性能测试
- 边界测试

## 运行测试

### 运行所有测试
```bash
# 在项目根目录运行
flutter test test/test_suite.dart
```

### 运行特定测试
```bash
# 运行简单测试示例
flutter test test/simple_exception_test.dart

# 运行完整异常处理测试
flutter test test/unified_exception_test.dart
```

### 运行单个测试用例
```bash
# 运行特定的测试组
flutter test test/simple_exception_test.dart --name "测试基本异常转换"
```

## 测试覆盖率

```bash
# 生成测试覆盖率报告
flutter test --coverage

# 查看覆盖率报告（需要安装 lcov）
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## 使用示例

### 1. 基本测试用法

```dart
import 'package:test/test.dart';
import 'package:bzy_network_framework/bzy_network_framework.dart';
import 'test_config.dart';

void main() {
  group('我的异常处理测试', () {
    setUp(() async {
      await TestConfig.setupTestEnvironment();
    });
    
    tearDown(() async {
      await TestConfig.cleanupTestEnvironment();
    });
    
    test('测试自定义异常', () async {
      // 创建异常
      final error = TestExceptionGenerator.createCustomException(
        type: ExceptionType.client,
        code: ErrorCode.validationError,
        message: '测试异常',
      );
      
      // 处理异常
      final result = await UnifiedExceptionHandler.instance
          .handleException(error);
      
      // 验证结果
      TestAssertions.assertException(
        result,
        expectedType: ExceptionType.client,
        expectedCode: ErrorCode.validationError,
      );
    });
  });
}
```

### 2. 性能测试用法

```dart
test('性能测试示例', () async {
  final monitor = TestPerformanceMonitor();
  
  monitor.start();
  
  // 执行需要测试性能的代码
  for (int i = 0; i < 1000; i++) {
    final error = TestExceptionGenerator.createTimeoutException();
    await UnifiedExceptionHandler.instance.handleException(error);
  }
  
  final duration = monitor.stop();
  
  // 验证性能要求
  expect(duration.inMilliseconds, lessThan(1000)); // 1秒内完成
  expect(monitor.averageDuration.inMicroseconds, lessThan(1000)); // 平均1ms内
});
```

### 3. 模拟网络请求测试

```dart
test('模拟网络请求测试', () async {
  final request = TestApiRequest(
    endpoint: '/users/123',
    requestMethod: HttpMethod.get,
    expectedStatusCode: 404, // 期望404错误
  );
  
  try {
    final framework = UnifiedNetworkFramework.instance;
    await framework.execute(request);
    fail('应该抛出异常');
  } catch (e) {
    expect(e, isA<DioException>());
    final dioError = e as DioException;
    expect(dioError.error, isA<UnifiedException>());
  }
});
```

## 最佳实践

### 1. 测试组织
- 使用 `group` 组织相关测试
- 使用 `setUp` 和 `tearDown` 管理测试环境
- 使用描述性的测试名称

### 2. 异常测试
- 使用 `TestExceptionGenerator` 生成标准异常
- 使用 `TestAssertions` 进行断言
- 测试异常的所有重要属性

### 3. 性能测试
- 使用 `TestPerformanceMonitor` 监控性能
- 设置合理的性能期望
- 测试大量数据的处理能力

### 4. 集成测试
- 测试与网络框架的集成
- 测试全局异常处理器
- 测试异常统计功能

## 故障排除

### 常见问题

1. **测试环境初始化失败**
   - 检查网络连接
   - 确保测试配置正确
   - 查看错误日志

2. **异常类型不匹配**
   - 检查 ErrorCode 枚举定义
   - 确保使用正确的异常类型
   - 查看异常转换逻辑

3. **性能测试失败**
   - 调整性能期望值
   - 检查测试环境性能
   - 优化测试代码

### 调试技巧

1. **启用详细日志**
   ```dart
   TestConfig.testNetworkConfig['logLevel'] = LogLevel.debug;
   ```

2. **打印异常详情**
   ```dart
   print('异常详情: ${exception.toString()}');
   print('异常类型: ${exception.type}');
   print('错误码: ${exception.code}');
   ```

3. **检查异常统计**
   ```dart
   final stats = UnifiedExceptionHandler.instance.getExceptionStats();
   print('异常统计: $stats');
   ```

## 贡献指南

如果您想添加新的测试用例或改进现有测试：

1. 遵循现有的代码风格
2. 添加适当的注释和文档
3. 确保测试覆盖率
4. 运行所有测试确保没有回归
5. 更新相关文档

## 相关文档

- [统一异常处理文档](../docs/UNIFIED_EXCEPTION_HANDLING.md)
- [快速开始指南](../docs/QUICK_START_GUIDE.md)
- [项目概览](../docs/PROJECT_OVERVIEW.md)
- [使用示例](../example/unified_exception_example.dart)