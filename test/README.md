# BZY Network Framework Demo 示例

This directory contains complete example code for BZY Network Framework, covering all core features from basic functionality to advanced applications. / 本目录包含了 BZY Network Framework 的完整示例代码 (complete example code)，从基础功能到高级应用 (from basic functionality to advanced applications)，涵盖了框架的所有核心特性 (covering all core features)。

## 📁 Demo File List / Demo 文件列表 (Demo File List)

### 1. Basic Examples / 基础示例 (Basic Examples) (01-03)

#### `01_basic_demo.dart` - Basic Network Requests / 基础网络请求 (Basic Network Requests)
- **Function / 功能 (Function)**: Demonstrates basic GET, POST, PUT, DELETE requests / 演示最基本的 GET、POST、PUT、DELETE 请求 (demonstrates basic HTTP methods)
- **Features / 特点 (Features)**: Simple and easy to understand, suitable for beginners / 简单易懂 (simple and easy to understand)，适合初学者 (suitable for beginners)
- **Includes / 包含 (Includes)**:
- Basic HTTP method usage / 基础 HTTP 方法使用 (basic HTTP method usage)
- Simple response handling / 简单的响应处理 (simple response handling)
- Basic error handling / 基本错误处理 (basic error handling)

#### `02_advanced_demo.dart` - Advanced Network Features / 高级网络功能 (Advanced Network Features)
- **Function / 功能 (Function)**: Demonstrates advanced network features / 展示高级网络特性 (demonstrates advanced network features)
- **Features / 特点 (Features)**: Covers caching, retry, interceptors, etc. / 涵盖缓存、重试、拦截器等 (covers caching, retry, interceptors, etc.)
- **Includes / 包含 (Includes)**:
- Request caching mechanism / 请求缓存机制 (request caching mechanism)
- Automatic retry strategy / 自动重试策略 (automatic retry strategy)
- Custom interceptors / 自定义拦截器 (custom interceptors)
- Request priority settings / 请求优先级设置 (request priority settings)
- Timeout configuration / 超时配置 (timeout configuration)

#### `03_file_operations_demo.dart` - File Operations / 文件操作 (File Operations)
- **Function / 功能 (Function)**: File upload and download functionality / 文件上传和下载功能 (file upload and download functionality)
- **Features / 特点 (Features)**: Supports progress monitoring and batch operations / 支持进度监控和批量操作 (supports progress monitoring and batch operations)
- **Includes / 包含 (Includes)**:
- Single file upload / 单文件上传 (single file upload)
- Multiple file batch upload / 多文件批量上传 (multiple file batch upload)
- File download / 文件下载 (file download)
- Upload/download progress monitoring / 上传/下载进度监控 (upload/download progress monitoring)
- File type validation / 文件类型验证 (file type validation)

### 2. Intermediate Examples / 中级示例 (Intermediate Examples) (04-06)

#### `04_interceptors_demo.dart` - Interceptor System / 拦截器系统 (Interceptor System)
- **Function / 功能 (Function)**: In-depth demonstration of interceptor usage / 深入展示拦截器的使用 (in-depth demonstration of interceptor usage)
- **Features / 特点 (Features)**: Multiple interceptor types and application scenarios / 多种拦截器类型和应用场景 (multiple interceptor types and application scenarios)
- **Includes / 包含 (Includes)**:
  - Authentication interceptor / 认证拦截器 (authentication interceptor)
  - Logging interceptor / 日志拦截器 (logging interceptor)
  - Cache interceptor / 缓存拦截器 (cache interceptor)
  - Error handling interceptor / 错误处理拦截器 (error handling interceptor)
  - Interceptor chain management / 拦截器链管理 (interceptor chain management)

#### `05_exception_handling_demo.dart` - Exception Handling / 异常处理 (Exception Handling)
- **Function / 功能 (Function)**: Comprehensive exception handling mechanism / 全面的异常处理机制 (comprehensive exception handling mechanism)
- **Features / 特点 (Features)**: Multi-level exception handling and recovery strategies / 多层次异常处理和恢复策略 (multi-level exception handling and recovery strategies)
- **Includes / 包含 (Includes)**:
  - Network exception handling / 网络异常处理 (network exception handling)
  - Business exception handling / 业务异常处理 (business exception handling)
  - Global exception handler / 全局异常处理器 (global exception handler)
  - Exception recovery strategies / 异常恢复策略 (exception recovery strategies)
  - Degradation handling / 降级处理 (degradation handling)

#### `06_cache_demo.dart` - Cache System / 缓存系统 (Cache System)
- **Function / 功能 (Function)**: Intelligent cache management / 智能缓存管理 (intelligent cache management)
- **Features / 特点 (Features)**: Multiple cache strategies and lifecycle management / 多种缓存策略和生命周期管理 (multiple cache strategies and lifecycle management)
- **Includes / 包含 (Includes)**:
  - Memory cache / 内存缓存 (memory cache)
  - Disk cache / 磁盘缓存 (disk cache)
  - Cache strategy configuration / 缓存策略配置 (cache strategy configuration)
  - Cache invalidation mechanism / 缓存失效机制 (cache invalidation mechanism)
  - Cache statistics / 缓存统计信息 (cache statistics)

### 3. Advanced Examples / 高级示例 (Advanced Examples) (07-09)

#### `07_concurrent_demo.dart` - Concurrent Processing / 并发处理 (Concurrent Processing)
- **Function / 功能 (Function)**: High-concurrency request management / 高并发请求管理 (high-concurrency request management)
- **Features / 特点 (Features)**: Concurrency control and performance optimization / 并发控制和性能优化 (concurrency control and performance optimization)
- **Includes / 包含 (Includes)**:
  - Concurrent request limiting / 并发请求限制 (concurrent request limiting)
  - Request queue management / 请求队列管理 (request queue management)
  - Batch request processing / 批量请求处理 (batch request processing)
  - Concurrent performance monitoring / 并发性能监控 (concurrent performance monitoring)
  - Resource pool management / 资源池管理 (resource pool management)

#### `08_websocket_demo.dart` - WebSocket Communication / WebSocket 通信 (WebSocket Communication)
- **Function / 功能 (Function)**: Real-time bidirectional communication / 实时双向通信 (real-time bidirectional communication)
- **Features / 特点 (Features)**: Complete WebSocket lifecycle management / 完整的 WebSocket 生命周期管理 (complete WebSocket lifecycle management)
- **Includes / 包含 (Includes)**:
  - WebSocket connection management / WebSocket 连接管理 (WebSocket connection management)
  - Message sending and receiving / 消息发送和接收 (message sending and receiving)
  - Connection status monitoring / 连接状态监控 (connection status monitoring)
  - Automatic reconnection mechanism / 自动重连机制 (automatic reconnection mechanism)
  - Heartbeat detection / 心跳检测 (heartbeat detection)

#### `09_graphql_demo.dart` - GraphQL Support / GraphQL 支持 (GraphQL Support)
- **Function / 功能 (Function)**: GraphQL queries and mutations / GraphQL 查询和变更 (GraphQL queries and mutations)
- **Features / 特点 (Features)**: Modern API query approach / 现代化的 API 查询方式 (modern API query approach)
- **Includes / 包含 (Includes)**:
  - GraphQL queries / GraphQL 查询 (GraphQL queries)
  - GraphQL mutations / GraphQL 变更 (GraphQL mutations)
  - Subscription functionality / 订阅功能 (subscription functionality)
  - Query optimization / 查询优化 (query optimization)
  - Error handling / 错误处理 (error handling)

### 4. Comprehensive Application / 综合应用 (Comprehensive Application) (10)

#### `10_comprehensive_demo.dart` - Comprehensive Application Example / 综合应用示例 (Comprehensive Application Example)
- **Function / 功能 (Function)**: Complete application scenario demonstration / 完整的应用场景演示 (complete application scenario demonstration)
- **Features / 特点 (Features)**: Practical application integrating all features / 集成所有功能的实际应用 (practical application integrating all features)
- **Includes / 包含 (Includes)**:
  - User management system / 用户管理系统 (user management system)
  - File management system / 文件管理系统 (file management system)
  - Data synchronization service / 数据同步服务 (data synchronization service)
  - Notification system / 通知系统 (notification system)
  - Performance monitoring / 性能监控 (performance monitoring)
  - Error recovery / 错误恢复 (error recovery)

## 🚀 Quick Start / 快速开始 (Quick Start)

### Run Individual Examples / 运行单个示例 (Run Individual Examples)

```bash
# Run basic examples / 运行基础示例
flutter test test/01_basic_demo.dart

# Run advanced feature examples / 运行高级功能示例
flutter test test/02_advanced_demo.dart

# Run file operation examples / 运行文件操作示例
flutter test test/03_file_operations_demo.dart
```

### Run All Examples / 运行所有示例 (Run All Examples)

```bash
# Run all tests / 运行所有测试 (run all tests)
flutter test test/

# Run specific pattern tests / 运行特定模式的测试 (run specific pattern tests)
flutter test test/ --name="Basic Features"
```

## 📋 Feature Overview / 功能特性总览 (Feature Overview)

### Core Features / 核心功能 (Core Features)
- ✅ HTTP/HTTPS request support / HTTP/HTTPS 请求支持 (HTTP/HTTPS request support)
- ✅ RESTful API support / RESTful API 支持 (RESTful API support)
- ✅ GraphQL support / GraphQL 支持 (GraphQL support)
- ✅ WebSocket real-time communication / WebSocket 实时通信 (WebSocket real-time communication)
- ✅ File upload/download / 文件上传/下载 (file upload/download)
- ✅ Request/response interceptors / 请求/响应拦截器 (request/response interceptors)
- ✅ Intelligent cache system / 智能缓存系统 (intelligent cache system)
- ✅ Exception handling mechanism / 异常处理机制 (exception handling mechanism)
- ✅ Concurrency control / 并发控制 (concurrency control)
- ✅ Request retry / 请求重试 (request retry)
- ✅ Timeout control / 超时控制 (timeout control)
- ✅ Request priority / 请求优先级 (request priority)

### Advanced Features / 高级特性 (Advanced Features)
- 🔄 Automatic retry mechanism / 自动重试机制 (automatic retry mechanism)
- 📦 Intelligent cache strategies / 智能缓存策略 (intelligent cache strategies)
- 🔐 Authentication and authorization / 认证和授权 (authentication and authorization)
- 📊 Performance monitoring / 性能监控 (performance monitoring)
- 🚨 Error recovery / 错误恢复 (error recovery)
- 🔄 Data synchronization / 数据同步 (data synchronization)
- 📱 Offline support / 离线支持 (offline support)
- 🎯 Request deduplication / 请求去重 (request deduplication)
- 📈 Statistical analysis / 统计分析 (statistical analysis)
- 🛡️ Security protection / 安全防护 (security protection)

## 🎯 Use Cases / 使用场景 (Use Cases)

### 1. Simple Applications / 简单应用 (Simple Applications)
- Basic API calls / 基础的 API 调用 (basic API calls)
- Simple data retrieval / 简单的数据获取 (simple data retrieval)
- Basic error handling / 基本的错误处理 (basic error handling)

**Recommended Examples / 推荐示例 (Recommended Examples)**: `01_basic_demo.dart`

### 2. Medium Applications / 中型应用 (Medium Applications)
- User authentication system / 用户认证系统 (user authentication system)
- File management functionality / 文件管理功能 (file management functionality)
- Cache optimization / 缓存优化 (cache optimization)
- Error recovery / 错误恢复 (error recovery)

**Recommended Examples / 推荐示例 (Recommended Examples)**: `02_advanced_demo.dart`, `04_interceptors_demo.dart`, `06_cache_demo.dart`

### 3. Large Applications / 大型应用 (Large Applications)
- High-concurrency processing / 高并发处理 (high-concurrency processing)
- Real-time communication / 实时通信 (real-time communication)
- Complex business logic / 复杂的业务逻辑 (complex business logic)
- Performance optimization / 性能优化 (performance optimization)

**Recommended Examples / 推荐示例 (Recommended Examples)**: `07_concurrent_demo.dart`, `08_websocket_demo.dart`, `10_comprehensive_demo.dart`

### 4. Enterprise Applications / 企业级应用 (Enterprise Applications)
- Microservice architecture / 微服务架构 (microservice architecture)
- Data synchronization / 数据同步 (data synchronization)
- Monitoring and analysis / 监控和分析 (monitoring and analysis)
- Security and compliance / 安全和合规 (security and compliance)

**Recommended Examples / 推荐示例 (Recommended Examples)**: `09_graphql_demo.dart`, `10_comprehensive_demo.dart`

## 📖 Learning Path / 学习路径 (Learning Path)

### Beginner Path / 初学者路径 (Beginner Path)
1. `01_basic_demo.dart` - Understand basic concepts / 了解基础概念 (understand basic concepts)
2. `03_file_operations_demo.dart` - Learn file operations / 学习文件操作 (learn file operations)
3. `05_exception_handling_demo.dart` - Master error handling / 掌握错误处理 (master error handling)

### Advanced Path / 进阶路径 (Advanced Path)
1. `02_advanced_demo.dart` - Advanced features / 高级功能 (advanced features)
2. `04_interceptors_demo.dart` - Interceptor system / 拦截器系统 (interceptor system)
3. `06_cache_demo.dart` - Cache mechanism / 缓存机制 (cache mechanism)

### Expert Path / 专家路径 (Expert Path)
1. `07_concurrent_demo.dart` - Concurrency processing / 并发处理 (concurrency processing)
2. `08_websocket_demo.dart` - Real-time communication / 实时通信 (real-time communication)
3. `09_graphql_demo.dart` - GraphQL
4. `10_comprehensive_demo.dart` - Comprehensive application / 综合应用 (comprehensive application)

## 🔧 Configuration Guide / 配置说明 (Configuration Guide)

### Basic Configuration / 基础配置 (Basic Configuration)
```dart
await UnifiedNetworkFramework.instance.initialize(
  baseUrl: 'https://api.example.com',
  config: {
    'enableLogging': true,
    'enableCache': true,
    'defaultTimeout': 30000,
  },
);
```

### Advanced Configuration / 高级配置 (Advanced Configuration)
```dart
await UnifiedNetworkFramework.instance.initialize(
  baseUrl: 'https://api.example.com',
  config: {
    'enableLogging': true,
    'enableCache': true,
    'maxConcurrentRequests': 10,
    'defaultTimeout': 30000,
    'retryCount': 3,
    'retryDelay': 1000,
    'cacheMaxSize': 100 * 1024 * 1024, // 100MB
    'enableGzip': true,
    'enableHttp2': true,
  },
);
```

## 🐛 Debugging Tips / 调试技巧 (Debugging Tips)

### Enable Detailed Logging / 启用详细日志 (Enable Detailed Logging)
```dart
// Enable logging during initialization / 在初始化时启用日志 (enable logging during initialization)
config['enableLogging'] = true;
config['logLevel'] = 'debug';
```

### Performance Monitoring / 性能监控 (Performance Monitoring)
```dart
// Add performance monitoring interceptor / 添加性能监控拦截器 (add performance monitoring interceptor)
framework.addGlobalInterceptor(PerformanceInterceptor());
```

### Error Tracking / 错误追踪 (Error Tracking)
```dart
// Register global error handler / 注册全局错误处理器 (register global error handler)
UnifiedExceptionHandler.instance.registerGlobalHandler((error, request) {
  print('Global Error: $error');
  return true;
});
```

## 📊 Performance Optimization Recommendations / 性能优化建议 (Performance Optimization Recommendations)

### 1. Cache Strategy / 缓存策略 (Cache Strategy)
- Enable cache for frequently accessed data / 为频繁访问的数据启用缓存 (enable cache for frequently accessed data)
- Set reasonable cache expiration time / 设置合理的缓存过期时间 (set reasonable cache expiration time)
- Use memory cache to improve response speed / 使用内存缓存提高响应速度 (use memory cache to improve response speed)

### 2. Concurrency Control / 并发控制 (Concurrency Control)
- Limit the number of concurrent requests / 限制同时进行的请求数量 (limit the number of concurrent requests)
- Use request queue management / 使用请求队列管理 (use request queue management)
- Implement request deduplication / 实现请求去重 (implement request deduplication)

### 3. Network Optimization / 网络优化 (Network Optimization)
- Enable GZIP compression / 启用 GZIP 压缩 (enable GZIP compression)
- Use HTTP/2 / 使用 HTTP/2 (use HTTP/2)
- Set reasonable timeout values / 合理设置超时时间 (set reasonable timeout values)

### 4. Error Handling / 错误处理 (Error Handling)
- Implement intelligent retry / 实现智能重试 (implement intelligent retry)
- Provide fallback solutions / 提供降级方案 (provide fallback solutions)
- Record detailed error information / 记录详细的错误信息 (record detailed error information)

## 🤝 Contributing Guide / 贡献指南 (Contributing Guide)

If you want to contribute to the example code, please follow these steps: / 如果您想为示例代码做出贡献，请遵循以下步骤 (if you want to contribute to the example code, please follow these steps)：

1. Fork the project / Fork 项目 (fork the project)
2. Create feature branch / 创建功能分支 (create feature branch)
3. Add new examples or improve existing examples / 添加新的示例或改进现有示例 (add new examples or improve existing examples)
4. Ensure code quality and test coverage / 确保代码质量和测试覆盖率 (ensure code quality and test coverage)
5. Submit Pull Request / 提交 Pull Request (submit pull request)

## 📞 Support and Feedback / 支持和反馈 (Support and Feedback)

If you encounter problems or have suggestions for improvement during use, please: / 如果您在使用过程中遇到问题或有改进建议，请 (if you encounter problems or have suggestions for improvement during use, please)：

1. Check existing example code / 查看现有的示例代码 (check existing example code)
2. Read framework documentation / 阅读框架文档 (read framework documentation)
3. Submit Issue or Pull Request / 提交 Issue 或 Pull Request (submit issue or pull request)
4. Contact maintenance team / 联系维护团队 (contact maintenance team)

## 📄 License / 许可证 (License)

This example code follows the MIT License. For details, please refer to the LICENSE file. / 本示例代码遵循 MIT 许可证，详情请参阅 LICENSE 文件 (this example code follows the MIT License, for details please refer to the LICENSE file)。

---

**Note**: These examples are for demonstration purposes only. Please adjust according to specific requirements in actual use. / **注意**: 这些示例仅用于演示目的，实际使用时请根据具体需求进行调整。

**Happy Coding! 🎉**