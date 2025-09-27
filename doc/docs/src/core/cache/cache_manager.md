# 缓存管理器 (CacheManager) 文档

## 概述
`CacheManager` 是网络框架的高性能缓存管理系统，提供内存缓存、磁盘缓存、缓存策略、过期管理、标签系统等全面的缓存解决方案。

## 文件位置
```
lib/src/core/cache/cache_manager.dart
```

## 核心特性

### 1. 双层缓存架构
- **内存缓存**: 快速访问，适合热点数据
- **磁盘缓存**: 持久化存储，适合大量数据

### 2. 智能缓存策略
- **LRU**: 最近最少使用淘汰策略
- **TTL**: 基于时间的过期策略
- **Size-based**: 基于大小的容量管理

### 3. 标签系统
- 支持缓存项标签管理
- 批量操作和清理
- 灵活的分组管理

### 4. 数据压缩
- 自动GZip压缩
- 减少存储空间占用
- 提高I/O效率

### 5. 并发安全
- 线程安全的操作
- 细粒度锁控制
- 高并发性能优化

## 主要组件

### CacheEntry 缓存条目类
```dart
class CacheEntry {
  final String key;                    // 缓存键
  final dynamic data;                  // 缓存数据
  final DateTime createdAt;            // 创建时间
  final DateTime? expiresAt;           // 过期时间
  final Set<String> tags;              // 标签集合
  final int size;                      // 数据大小
  final Map<String, dynamic> metadata; // 元数据
  
  bool get isExpired;                  // 是否过期
  Duration get age;                    // 缓存年龄
}
```

### CacheConfig 缓存配置类
```dart
class CacheConfig {
  final int maxMemorySize;             // 最大内存缓存大小
  final int maxDiskSize;               // 最大磁盘缓存大小
  final Duration defaultTTL;           // 默认TTL
  final bool enableCompression;        // 启用压缩
  final bool enableDiskCache;          // 启用磁盘缓存
  final Duration cleanupInterval;      // 清理间隔
  final double compressionThreshold;   // 压缩阈值
}
```

### CacheStatistics 缓存统计类
```dart
class CacheStatistics {
  int memoryHits;          // 内存命中次数
  int memoryMisses;        // 内存未命中次数
  int diskHits;            // 磁盘命中次数
  int diskMisses;          // 磁盘未命中次数
  int totalWrites;         // 总写入次数
  int totalReads;          // 总读取次数
  int totalEvictions;      // 总淘汰次数
  int currentMemorySize;   // 当前内存使用
  int currentDiskSize;     // 当前磁盘使用
  
  double get memoryHitRate;  // 内存命中率
  double get diskHitRate;    // 磁盘命中率
  double get overallHitRate; // 总体命中率
}
```

## 核心方法

### 1. get() - 获取缓存
```dart
Future<T?> get<T>(
  String key, {
  bool updateAccessTime = true,
  bool checkDisk = true,
}) async
```

**功能**：
- 优先从内存缓存获取
- 内存未命中时从磁盘获取
- 自动更新访问时间
- 返回强类型数据

### 2. set() - 设置缓存
```dart
Future<void> set<T>(
  String key,
  T data, {
  Duration? ttl,
  Set<String>? tags,
  bool toDisk = true,
  Map<String, dynamic>? metadata,
}) async
```

**功能**：
- 同时写入内存和磁盘缓存
- 支持自定义TTL
- 支持标签管理
- 自动数据压缩

### 3. remove() - 删除缓存
```dart
Future<bool> remove(String key) async
```

**功能**：
- 从内存和磁盘同时删除
- 清理相关标签映射
- 更新统计信息

### 4. clear() - 清空缓存
```dart
Future<void> clear({
  bool memoryOnly = false,
  bool diskOnly = false,
}) async
```

**功能**：
- 清空指定类型的缓存
- 重置统计信息
- 清理所有映射关系

### 5. clearByTag() - 按标签清理
```dart
Future<void> clearByTag(String tag) async
```

**功能**：
- 删除指定标签的所有缓存项
- 批量清理操作
- 维护标签映射一致性

## 缓存策略

### 1. LRU淘汰策略
```dart
// 当缓存满时，淘汰最近最少使用的项
void _evictLRU() {
  final oldestKey = _findLeastRecentlyUsed();
  _removeFromMemory(oldestKey);
}
```

### 2. TTL过期策略
```dart
// 检查缓存项是否过期
bool _isExpired(CacheEntry entry) {
  return entry.expiresAt != null && 
         DateTime.now().isAfter(entry.expiresAt!);
}
```

### 3. 大小限制策略
```dart
// 检查缓存大小限制
bool _exceedsMemoryLimit() {
  return _currentMemorySize > _config.maxMemorySize;
}
```

## 标签系统

### 标签管理
```dart
// 为缓存项添加标签
await CacheManager.instance.set(
  'user_123',
  userData,
  tags: {'user', 'profile', 'active'},
);

// 按标签批量清理
await CacheManager.instance.clearByTag('user');
```

### 标签查询
```dart
// 获取标签下的所有键
Set<String> getKeysByTag(String tag) {
  return _tagToKeys[tag] ?? {};
}

// 获取键的所有标签
Set<String> getTagsByKey(String key) {
  return _keyToTags[key] ?? {};
}
```

## 数据压缩

### 压缩策略
```dart
// 自动压缩大于阈值的数据
if (dataSize > _config.compressionThreshold) {
  compressedData = _gzipEncoder.encode(utf8.encode(jsonData));
}
```

### 解压缩
```dart
// 自动检测和解压缩数据
if (_isCompressed(data)) {
  decompressedData = _gzipDecoder.decodeBytes(data);
}
```

## 使用示例

### 基本缓存操作
```dart
// 设置缓存
await CacheManager.instance.set(
  'user_profile_123',
  userProfile,
  ttl: Duration(hours: 1),
  tags: {'user', 'profile'},
);

// 获取缓存
final cachedProfile = await CacheManager.instance.get<UserProfile>('user_profile_123');
if (cachedProfile != null) {
  // 使用缓存数据
  displayProfile(cachedProfile);
} else {
  // 缓存未命中，从网络获取
  final profile = await fetchUserProfile(123);
  await CacheManager.instance.set('user_profile_123', profile);
}
```

### 标签管理
```dart
// 缓存多个用户数据
for (final user in users) {
  await CacheManager.instance.set(
    'user_${user.id}',
    user,
    tags: {'user', 'list_page', user.department},
  );
}

// 清理特定部门的用户缓存
await CacheManager.instance.clearByTag('engineering');

// 清理列表页相关缓存
await CacheManager.instance.clearByTag('list_page');
```

### 配置管理
```dart
// 更新缓存配置
await CacheManager.instance.updateConfig(CacheConfig(
  maxMemorySize: 50 * 1024 * 1024,  // 50MB
  maxDiskSize: 200 * 1024 * 1024,   // 200MB
  defaultTTL: Duration(hours: 2),
  enableCompression: true,
  compressionThreshold: 1024,        // 1KB
));
```

### 统计监控
```dart
// 获取缓存统计
final stats = CacheManager.instance.statistics;
print('内存命中率: ${(stats.memoryHitRate * 100).toStringAsFixed(2)}%');
print('磁盘命中率: ${(stats.diskHitRate * 100).toStringAsFixed(2)}%');
print('总体命中率: ${(stats.overallHitRate * 100).toStringAsFixed(2)}%');
print('内存使用: ${stats.currentMemorySize} bytes');
print('磁盘使用: ${stats.currentDiskSize} bytes');
```

### 高级用法
```dart
// 预加载缓存
await CacheManager.instance.preload({
  'config': await fetchAppConfig(),
  'user_preferences': await fetchUserPreferences(),
}, ttl: Duration(days: 1));

// 缓存预热
await CacheManager.instance.warmup([
  'frequently_used_data_1',
  'frequently_used_data_2',
]);

// 缓存同步
await CacheManager.instance.sync();
```

## 性能优化

### 1. 内存优化
- 智能的LRU淘汰策略
- 内存使用监控和限制
- 及时清理过期数据

### 2. I/O优化
- 异步磁盘操作
- 批量I/O操作
- 数据压缩减少I/O

### 3. 并发优化
- 细粒度锁控制
- 读写分离
- 无锁数据结构

## 错误处理

### 1. 磁盘I/O错误
```dart
try {
  await _writeToDisk(key, data);
} catch (e) {
  // 降级到仅内存缓存
  _writeToMemoryOnly(key, data);
}
```

### 2. 数据损坏
```dart
try {
  final data = await _readFromDisk(key);
  return _deserialize(data);
} catch (e) {
  // 删除损坏的缓存项
  await _removeFromDisk(key);
  return null;
}
```

### 3. 内存不足
```dart
if (_isMemoryPressure()) {
  // 强制清理过期项
  await _forceCleanup();
  // 降低缓存大小限制
  _reduceMemoryLimit();
}
```

## 设计模式

### 1. 单例模式
确保全局唯一的缓存管理器实例。

### 2. 策略模式
不同的缓存策略（LRU、TTL等）可以灵活切换。

### 3. 装饰器模式
压缩、加密等功能作为装饰器添加。

### 4. 观察者模式
缓存事件的监听和通知。

## 注意事项

1. **内存管理**: 合理设置内存缓存大小避免OOM
2. **磁盘空间**: 监控磁盘缓存使用避免空间不足
3. **数据一致性**: 确保内存和磁盘缓存的一致性
4. **并发安全**: 多线程环境下的安全访问
5. **错误恢复**: 处理磁盘I/O错误和数据损坏
6. **性能监控**: 定期检查缓存命中率和性能指标
7. **清理策略**: 及时清理过期和无用的缓存数据