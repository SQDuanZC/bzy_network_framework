import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';
import '../../model/response_wrapper.dart';

/// 缓存管理器
/// 支持内存缓存、磁盘缓存、缓存策略、过期管理
class CacheManager {
  static CacheManager? _instance;
  
  // 内存缓存
  final Map<String, CacheEntry> _memoryCache = {};
  
  // 标签到缓存键的映射
  final Map<String, Set<String>> _tagToKeys = {};
  
  // 缓存键到标签的映射
  final Map<String, Set<String>> _keyToTags = {};
  
  // 缓存配置
  late CacheConfig _config;
  
  // 缓存目录
  Directory? _cacheDirectory;
  
  // 缓存清理定时器
  Timer? _cleanupTimer;
  
  // 缓存统计
  final CacheStatistics _statistics = CacheStatistics();
  
  // 磁盘I/O队列
  final List<Future<void>> _diskIOQueue = [];
  
  // 压缩器
  final GZipEncoder _gzipEncoder = GZipEncoder();
  final GZipDecoder _gzipDecoder = GZipDecoder();
  
  // 并发锁
  final Lock _diskOperationLock = Lock();
  
  // 私有构造函数
  CacheManager._() {
    _config = CacheConfig();
    _initializeCache();
  }
  
  /// 获取单例实例
  static CacheManager get instance {
    _instance ??= CacheManager._();
    return _instance!;
  }
  
  /// 缓存配置
  CacheConfig get config => _config;
  
  /// 缓存统计
  CacheStatistics get statistics => _statistics;
  
  /// 初始化缓存
  Future<void> _initializeCache() async {
    try {
      // 初始化缓存目录
      await _initializeCacheDirectory();
      
      // 启动定期清理
      _startPeriodicCleanup();
      
      // 缓存管理器初始化完成
    } catch (e, stackTrace) {
      // 使用适当的日志记录而不是注释
      if (kDebugMode) {
        debugPrint('缓存管理器初始化失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      }
      rethrow; // 重新抛出异常以便上层处理
    }
  }
  
  /// 初始化缓存目录
  Future<void> _initializeCacheDirectory() async {
    try {
      // 使用系统临时目录作为缓存目录
      final tempDir = Directory.systemTemp;
      _cacheDirectory = Directory('${tempDir.path}/network_cache');
      
      if (!await _cacheDirectory!.exists()) {
        await _cacheDirectory!.create(recursive: true);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('创建缓存目录失败: $e');
        debugPrint('堆栈跟踪: $stackTrace');
      }
      // 不重新抛出，允许框架在没有磁盘缓存的情况下继续运行
    }
  }
  
  /// 启动定期清理
  void _startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_config.cleanupInterval, (timer) {
      _performCleanup();
    });
  }
  
  /// 获取缓存
  Future<BaseResponse<T>?> get<T>(
    String key, {
    T Function(dynamic)? fromJson,
  }) async {
    try {
      _statistics.totalRequests++;
      
      // 先检查内存缓存
      final memoryEntry = _memoryCache[key];
      if (memoryEntry != null && !memoryEntry.isExpired) {
        _statistics.memoryHits++;
        return _deserializeResponse<T>(memoryEntry.data, fromJson);
      }
      
      // 检查磁盘缓存
      if (_config.enableDiskCache) {
        final diskEntry = await _getDiskCache(key);
        if (diskEntry != null && !diskEntry.isExpired) {
          _statistics.diskHits++;
          
          // 将磁盘缓存加载到内存
          if (_config.enableMemoryCache) {
            _memoryCache[key] = diskEntry;
          }
          
          return _deserializeResponse<T>(diskEntry.data, fromJson);
        }
      }
      
      _statistics.misses++;
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('获取缓存失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      }
      // 记录错误但不影响统计，因为CacheStatistics可能没有errors字段
      return null;
    }
  }
  
  /// 设置缓存
  Future<void> set<T>(
    String key,
    BaseResponse<T> response, {
    Duration? expiry,
    CachePriority priority = CachePriority.normal,
    Set<String> tags = const {},
    bool? enableCompression,
    bool? enableEncryption,
  }) async {
    try {
      final effectiveExpiry = expiry ?? _config.defaultExpiry;
      final expiryTime = DateTime.now().add(effectiveExpiry);
      
      final serializedData = _serializeResponse(response);
      final shouldCompress = enableCompression ?? _shouldCompress(jsonEncode(serializedData));
      final shouldEncrypt = enableEncryption ?? _config.enableEncryption;
      
      final entry = CacheEntry(
        key: key,
        data: serializedData,
        expiryTime: expiryTime,
        priority: priority,
        size: _calculateSize(serializedData),
        accessCount: 0,
        lastAccessed: DateTime.now(),
        tags: tags,
        isCompressed: shouldCompress,
        isEncrypted: shouldEncrypt,
      );
      
      // 添加标签映射
      if (_config.enableTagManagement && tags.isNotEmpty) {
        for (final tag in tags) {
          await addTag(key, tag);
        }
      }
      
      // 内存缓存
      if (_config.enableMemoryCache) {
        await _setMemoryCache(key, entry);
      }
      
      // 磁盘缓存
      if (_config.enableDiskCache) {
        await _setDiskCache(key, entry);
      }
      
      _statistics.totalSets++;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('设置缓存失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      }
      // 不重新抛出，缓存失败不应该影响主要业务流程
    }
  }
  
  /// 设置内存缓存
  Future<void> _setMemoryCache(String key, CacheEntry entry) async {
    // 检查内存限制
    if (_getMemoryCacheSize() + entry.size > _config.maxMemorySize) {
      await _evictMemoryCache(entry.size);
    }
    
    _memoryCache[key] = entry;
  }
  
  /// 设置磁盘缓存
  Future<void> _setDiskCache(String key, CacheEntry entry) async {
    if (_cacheDirectory == null) return;
    
    if (_config.enableAsyncDiskIO) {
      // 异步磁盘I/O
      final future = _setDiskCacheSync(key, entry);
      _diskIOQueue.add(future);
      
      // 清理已完成的任务（简化处理）
      if (_diskIOQueue.length > 100) {
        _diskIOQueue.clear();
      }
    } else {
      await _setDiskCacheSync(key, entry);
    }
  }
  
  /// 同步设置磁盘缓存
  Future<void> _setDiskCacheSync(String key, CacheEntry entry) async {
    try {
      final file = File('${_cacheDirectory!.path}/${_hashKey(key)}.cache');
      
      var dataToWrite = jsonEncode(entry.data);
      
      // 加密处理
      if (entry.isEncrypted) {
        dataToWrite = _encryptData(dataToWrite);
      }
      
      final cacheData = {
        'key': key,
        'data': dataToWrite,
        'expiryTime': entry.expiryTime.millisecondsSinceEpoch,
        'priority': entry.priority.index,
        'size': entry.size,
        'accessCount': entry.accessCount,
        'lastAccessed': entry.lastAccessed.millisecondsSinceEpoch,
        'tags': entry.tags.toList(),
        'isCompressed': entry.isCompressed,
        'isEncrypted': entry.isEncrypted,
      };
      
      var finalData = jsonEncode(cacheData);
      
      // 压缩处理
      if (entry.isCompressed) {
        final compressedData = _compressData(finalData);
        await file.writeAsBytes(compressedData);
      } else {
        // 使用缓冲写入优化性能
        final sink = file.openWrite();
        sink.write(finalData);
        await sink.close();
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('写入磁盘缓存失败: $e');
        debugPrint('堆栈跟踪: $stackTrace');
      }
      // 磁盘写入失败不应该影响主要流程
    }
  }
  
  /// 获取磁盘缓存
  Future<CacheEntry?> _getDiskCache(String key) async {
    if (_cacheDirectory == null) return null;
    
    // 使用锁确保并发安全
    return await _diskOperationLock.synchronized(() async {
      try {
        final file = File('${_cacheDirectory!.path}/${_hashKey(key)}.cache');
        if (!await file.exists()) return null;
        
        // 检查文件权限和完整性
        final stat = await file.stat();
        if (stat.size == 0) {
          // 空文件，删除并返回null
          await file.delete().catchError((_) => file);
          return null;
        }
        
        // 读取文件内容
        String content;
        final fileSize = stat.size;
        
        if (fileSize > _config.diskIOBufferSize) {
          // 大文件使用流式读取，增加超时控制
          final stream = file.openRead();
          final bytes = await stream
              .timeout(const Duration(seconds: 30))
              .fold<List<int>>(<int>[], (previous, element) => previous..addAll(element));
          
          // 验证数据完整性
          if (bytes.isEmpty) {
            await file.delete().catchError((_) => file);
            return null;
          }
          
          // 尝试解压缩
          try {
            content = _decompressData(Uint8List.fromList(bytes));
          } catch (e) {
            // 如果解压失败，尝试直接解码
            try {
              content = utf8.decode(bytes);
            } catch (decodeError) {
              // 文件损坏，删除并返回null
              await file.delete().catchError((_) => file);
              return null;
            }
          }
        } else {
          // 小文件直接读取，增加超时控制
          try {
            final bytes = await file.readAsBytes()
                .timeout(const Duration(seconds: 10));
            
            if (bytes.isEmpty) {
              await file.delete().catchError((_) => file);
              return null;
            }
            
            content = _decompressData(bytes);
          } catch (e) {
            // 如果解压失败，尝试直接读取字符串
            try {
              content = await file.readAsString()
                  .timeout(const Duration(seconds: 10));
              
              if (content.isEmpty) {
                await file.delete().catchError((_) => file);
                return null;
              }
            } catch (readError) {
              // 文件损坏，删除并返回null
              await file.delete().catchError((_) => file);
              return null;
            }
          }
        }
        
        // 解析JSON数据
        Map<String, dynamic> cacheData;
        try {
          cacheData = jsonDecode(content) as Map<String, dynamic>;
        } catch (e) {
          // JSON解析失败，文件损坏
          await file.delete().catchError((_) => file);
          return null;
        }
        
        // 验证必要字段
        if (!cacheData.containsKey('key') || !cacheData.containsKey('data')) {
          await file.delete().catchError((_) => file);
          return null;
        }
        
        // 处理数据解密
        var entryData = cacheData['data'];
        final isEncrypted = cacheData['isEncrypted'] as bool? ?? false;
        
        if (isEncrypted && entryData is String) {
          try {
            entryData = _decryptData(entryData);
            entryData = jsonDecode(entryData);
          } catch (e) {
            // 解密失败，可能是密钥不匹配或数据损坏
            if (kDebugMode) {
              debugPrint('缓存解密失败: $e');
            }
            await file.delete().catchError((_) => file);
            return null;
          }
        }
        
        final tags = (cacheData['tags'] as List<dynamic>?)?.cast<String>().toSet() ?? <String>{};
        
        // 验证时间戳
        final expiryTime = cacheData['expiryTime'] as int? ?? 0;
        final lastAccessed = cacheData['lastAccessed'] as int? ?? 0;
        
        if (expiryTime < 0 || lastAccessed < 0) {
          await file.delete().catchError((_) => file);
          return null;
        }
        
        // 验证优先级
        final priorityIndex = cacheData['priority'] as int? ?? 0;
        if (priorityIndex < 0 || priorityIndex >= CachePriority.values.length) {
          await file.delete().catchError((_) => file);
          return null;
        }
        
        return CacheEntry(
          key: cacheData['key'] as String? ?? '',
          data: entryData ?? {},
          expiryTime: DateTime.fromMillisecondsSinceEpoch(expiryTime),
          priority: CachePriority.values[priorityIndex],
          size: cacheData['size'] as int? ?? 0,
          accessCount: cacheData['accessCount'] as int? ?? 0,
          lastAccessed: DateTime.fromMillisecondsSinceEpoch(lastAccessed),
          tags: tags,
          isCompressed: cacheData['isCompressed'] as bool? ?? false,
          isEncrypted: cacheData['isEncrypted'] as bool? ?? false,
        );
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('读取磁盘缓存失败: $e');
          debugPrint('堆栈跟踪: $stackTrace');
        }
        
        // 尝试删除损坏的缓存文件
        try {
          final file = File('${_cacheDirectory!.path}/${_hashKey(key)}.cache');
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // 忽略删除失败
        }
        
        return null;
      }
    });
  }
  
  /// 删除缓存
  Future<void> remove(String key) async {
    // 获取要删除的条目的标签
    final tags = getTagsByKey(key);
    
    // 删除内存缓存
    _memoryCache.remove(key);
    
    // 清理标签映射
    if (_config.enableTagManagement && tags.isNotEmpty) {
      // 创建副本避免并发修改
      final tagsCopy = Set<String>.from(tags);
      for (final tag in tagsCopy) {
        await removeTag(key, tag);
      }
    }
    
    // 删除磁盘缓存
    if (_cacheDirectory != null) {
      try {
        final file = File('${_cacheDirectory!.path}/${_hashKey(key)}.cache');
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('删除磁盘缓存失败: $e');
        debugPrint('堆栈跟踪: $stackTrace');
        }
        // 删除失败不影响主要流程
      }
    }
  }
  
  /// 清空所有缓存
  Future<void> clear() async {
    // 清空内存缓存
    _memoryCache.clear();
    
    // 清空标签映射
    if (_config.enableTagManagement) {
      _tagToKeys.clear();
      _keyToTags.clear();
    }
    
    // 清空磁盘缓存
    if (_cacheDirectory != null) {
      try {
        if (await _cacheDirectory!.exists()) {
          await _cacheDirectory!.delete(recursive: true);
          await _cacheDirectory!.create(recursive: true);
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('清空磁盘缓存失败: $e');
        debugPrint('堆栈跟踪: $stackTrace');
        }
        // 清空失败不影响主要流程
      }
    }
    
    // 等待所有磁盘I/O操作完成
    if (_config.enableAsyncDiskIO && _diskIOQueue.isNotEmpty) {
      try {
        await Future.wait(_diskIOQueue);
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('等待磁盘I/O操作完成失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
        }
        // 忽略已完成的Future错误
      }
      _diskIOQueue.clear();
    }
    
    // 重置统计
    _statistics.reset();
  }
  
  /// 执行清理
  Future<void> _performCleanup() async {
    await _cleanupExpiredEntries();
    await _cleanupLRUEntries();
  }
  
  /// 清理过期条目
  Future<void> _cleanupExpiredEntries() async {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    // 清理内存中的过期条目
    _memoryCache.forEach((key, entry) {
      if (entry.expiryTime.isBefore(now)) {
        expiredKeys.add(key);
      }
    });
    
    for (final key in expiredKeys) {
      await remove(key);
    }
    
    // 清理磁盘中的过期条目
    if (_cacheDirectory != null && await _cacheDirectory!.exists()) {
      try {
        final files = await _cacheDirectory!.list().toList();
        for (final file in files) {
          if (file is File && file.path.endsWith('.cache')) {
            try {
              final content = await file.readAsString();
              final cacheData = jsonDecode(content) as Map<String, dynamic>;
              final expiryTime = DateTime.fromMillisecondsSinceEpoch(cacheData['expiryTime'] as int);
              
              if (expiryTime.isBefore(now)) {
                await file.delete();
              }
            } catch (e) {
              // 如果文件损坏，直接删除
              await file.delete();
            }
          }
        }
      } catch (e) {
        // 清理磁盘过期缓存失败: $e
      }
    }
  }
  
  /// 清理LRU条目
  Future<void> _cleanupLRUEntries() async {
    if (_getMemoryCacheSize() <= _config.maxMemorySize) return;
    
    // 按最后访问时间排序
    final entries = _memoryCache.entries.toList();
    entries.sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));
    
    // 删除最久未使用的条目
    var currentSize = _getMemoryCacheSize();
    for (final entry in entries) {
      if (currentSize <= _config.maxMemorySize * 0.8) break;
      
      _memoryCache.remove(entry.key);
      currentSize -= entry.value.size;
    }
  }
  
  /// 内存缓存驱逐
  Future<void> _evictMemoryCache(int requiredSize) async {
    var currentSize = _getMemoryCacheSize();
    final targetSize = _config.maxMemorySize - requiredSize;
    
    if (currentSize <= targetSize) return;
    
    // 按优先级和访问时间排序
    final entries = _memoryCache.entries.toList();
    entries.sort((a, b) {
      final priorityCompare = a.value.priority.index.compareTo(b.value.priority.index);
      if (priorityCompare != 0) return priorityCompare;
      return a.value.lastAccessed.compareTo(b.value.lastAccessed);
    });
    
    // 删除低优先级和最久未使用的条目
    for (final entry in entries) {
      if (currentSize <= targetSize) break;
      
      _memoryCache.remove(entry.key);
      currentSize -= entry.value.size;
    }
  }
  
  /// 获取内存缓存大小
  int _getMemoryCacheSize() {
    return _memoryCache.values.fold(0, (sum, entry) => sum + entry.size);
  }
  
  /// 计算数据大小
  int _calculateSize(dynamic data) {
    try {
      return utf8.encode(jsonEncode(data)).length;
    } catch (e) {
      return 1024; // 默认1KB
    }
  }
  
  /// 哈希键
  String _hashKey(String key) {
    // 使用简单的哈希算法替代md5
    return key.hashCode.abs().toString();
  }
  
  /// 序列化响应
  Map<String, dynamic> _serializeResponse<T>(BaseResponse<T> response) {
    return {
      'success': response.success,
      'data': response.data,
      'message': response.message,
      'code': response.code,
      'timestamp': response.timestamp ?? DateTime.now().millisecondsSinceEpoch,
    };
  }
  
  /// 反序列化响应
  BaseResponse<T> _deserializeResponse<T>(
    Map<String, dynamic> data,
    T Function(dynamic)? fromJson,
  ) {
    final responseData = data['data'];
    final parsedData = fromJson != null && responseData != null
        ? fromJson(responseData)
        : responseData;
    
    return BaseResponse<T>(
      success: data['success'] as bool? ?? false,
      data: parsedData,
      message: data['message'] as String? ?? '',
      code: data['code'] as int? ?? 0,
      timestamp: data['timestamp'] as int?,
    );
  }
  
  /// 更新配置
  void updateConfig(CacheConfig config) {
    _config = config;
    
    // 重启定期清理
    _startPeriodicCleanup();
  }
  
  /// 获取缓存信息
  Map<String, dynamic> getCacheInfo() {
    final compressedEntries = _memoryCache.values.where((e) => e.isCompressed).length;
    final encryptedEntries = _memoryCache.values.where((e) => e.isEncrypted).length;
    final totalTags = _tagToKeys.length;
    final avgTagsPerEntry = _memoryCache.isNotEmpty ? _keyToTags.length / _memoryCache.length : 0.0;
    
    return {
      'memoryEntries': _memoryCache.length,
      'memorySize': _getMemoryCacheSize(),
      'maxMemorySize': _config.maxMemorySize,
      'statistics': _statistics.toMap(),
      'compression': {
        'enabled': _config.enableCompression,
        'threshold': _config.compressionThreshold,
        'compressedEntries': compressedEntries,
        'compressionRatio': _memoryCache.isNotEmpty ? compressedEntries / _memoryCache.length : 0.0,
      },
      'encryption': {
        'enabled': _config.enableEncryption,
        'encryptedEntries': encryptedEntries,
        'encryptionRatio': _memoryCache.isNotEmpty ? encryptedEntries / _memoryCache.length : 0.0,
      },
      'tagManagement': {
        'enabled': _config.enableTagManagement,
        'totalTags': totalTags,
        'taggedEntries': _keyToTags.length,
        'avgTagsPerEntry': avgTagsPerEntry,
      },
      'diskIO': {
        'asyncEnabled': _config.enableAsyncDiskIO,
        'bufferSize': _config.diskIOBufferSize,
        'pendingOperations': _diskIOQueue.length,
      },
    };
  }
  
  /// 销毁缓存管理器
  Future<void> dispose() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    
    // 等待所有磁盘I/O操作完成
    while (_diskIOQueue.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    
    // 清理内存缓存
    _memoryCache.clear();
    _tagToKeys.clear();
    _keyToTags.clear();
    
    // 重置统计信息
    _statistics.reset();
  }
  
  // ==================== 压缩功能 ====================
  
  /// 压缩数据
  Uint8List _compressData(String data) {
    final bytes = utf8.encode(data);
    final compressed = _gzipEncoder.encode(bytes);
    return Uint8List.fromList(compressed ?? bytes);
  }
  
  /// 解压数据
  String _decompressData(Uint8List compressedData) {
    final decompressed = _gzipDecoder.decodeBytes(compressedData);
    return utf8.decode(decompressed);
  }
  
  /// 判断是否需要压缩
  bool _shouldCompress(String data) {
    return _config.enableCompression && 
           utf8.encode(data).length >= _config.compressionThreshold;
  }
  
  // ==================== 加密功能 ====================
  
  /// 加密数据
  String _encryptData(String data) {
    if (!_config.enableEncryption || _config.encryptionKey == null) {
      return data;
    }
    
    // 简单的XOR加密（生产环境应使用更强的加密算法）
    final key = _config.encryptionKey!;
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(data);
    final encryptedBytes = <int>[];
    
    for (int i = 0; i < dataBytes.length; i++) {
      encryptedBytes.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return base64.encode(encryptedBytes);
  }
  
  /// 解密数据
  String _decryptData(String encryptedData) {
    if (!_config.enableEncryption || _config.encryptionKey == null) {
      return encryptedData;
    }
    
    try {
      final key = _config.encryptionKey!;
      final keyBytes = utf8.encode(key);
      final encryptedBytes = base64.decode(encryptedData);
      final decryptedBytes = <int>[];
      
      for (int i = 0; i < encryptedBytes.length; i++) {
        decryptedBytes.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
      }
      
      return utf8.decode(decryptedBytes);
    } catch (e) {
      return encryptedData; // 解密失败，返回原数据
    }
  }
  
  // ==================== 标签管理功能 ====================
  
  /// 添加标签
  Future<void> addTag(String cacheKey, String tag) async {
    if (!_config.enableTagManagement) return;
    
    // 更新标签到键的映射
    _tagToKeys.putIfAbsent(tag, () => <String>{}).add(cacheKey);
    
    // 更新键到标签的映射
    _keyToTags.putIfAbsent(cacheKey, () => <String>{}).add(tag);
    
    // 更新内存缓存中的条目
    final entry = _memoryCache[cacheKey];
    if (entry != null) {
      _memoryCache[cacheKey] = entry.copyWithTags({tag});
    }
  }
  
  /// 移除标签
  Future<void> removeTag(String cacheKey, String tag) async {
    if (!_config.enableTagManagement) return;
    
    // 从标签到键的映射中移除
    _tagToKeys[tag]?.remove(cacheKey);
    if (_tagToKeys[tag]?.isEmpty == true) {
      _tagToKeys.remove(tag);
    }
    
    // 从键到标签的映射中移除
    _keyToTags[cacheKey]?.remove(tag);
    if (_keyToTags[cacheKey]?.isEmpty == true) {
      _keyToTags.remove(cacheKey);
    }
  }
  
  /// 根据标签清除缓存
  Future<void> clearByTag(String tag) async {
    if (!_config.enableTagManagement) return;
    
    final keys = _tagToKeys[tag];
    if (keys != null) {
      // 创建副本避免并发修改
      final keysCopy = Set<String>.from(keys);
      for (final key in keysCopy) {
        await remove(key);
      }
    }
  }
  
  /// 根据多个标签清除缓存
  Future<void> clearByTags(List<String> tags) async {
    if (!_config.enableTagManagement) return;
    
    final keysToRemove = <String>{};
    for (final tag in tags) {
      final keys = _tagToKeys[tag];
      if (keys != null) {
        keysToRemove.addAll(keys);
      }
    }
    
    // 创建副本避免并发修改
    final keysCopy = Set<String>.from(keysToRemove);
    for (final key in keysCopy) {
      await remove(key);
    }
  }
  
  /// 获取标签下的所有缓存键
  Set<String> getKeysByTag(String tag) {
    return _tagToKeys[tag] ?? <String>{};
  }
  
  /// 获取缓存键的所有标签
  Set<String> getTagsByKey(String key) {
    return _keyToTags[key] ?? <String>{};
  }
  
  /// 记录标签命中统计
  void recordTagHit(String tag) {
    // 可以在这里添加标签级别的统计
  }
  
  /// 记录端点命中统计
  void recordEndpointHit(String endpoint) {
    // 可以在这里添加端点级别的统计
  }
}

/// 缓存条目
class CacheEntry {
  final String key;
  final Map<String, dynamic> data;
  final DateTime expiryTime;
  final CachePriority priority;
  final int size;
  final Set<String> tags;
  final bool isCompressed;
  final bool isEncrypted;
  int accessCount;
  DateTime lastAccessed;
  
  CacheEntry({
    required this.key,
    required this.data,
    required this.expiryTime,
    required this.priority,
    required this.size,
    required this.accessCount,
    required this.lastAccessed,
    this.tags = const {},
    this.isCompressed = false,
    this.isEncrypted = false,
  });
  
  /// 是否过期
  bool get isExpired => DateTime.now().isAfter(expiryTime);
  
  /// 访问条目
  void access() {
    accessCount++;
    lastAccessed = DateTime.now();
  }
  
  /// 复制条目并添加标签
  CacheEntry copyWithTags(Set<String> newTags) {
    return CacheEntry(
      key: key,
      data: data,
      expiryTime: expiryTime,
      priority: priority,
      size: size,
      accessCount: accessCount,
      lastAccessed: lastAccessed,
      tags: {...tags, ...newTags},
      isCompressed: isCompressed,
      isEncrypted: isEncrypted,
    );
  }
}

/// 缓存优先级
enum CachePriority {
  low,
  normal,
  high,
  critical,
}

/// 缓存配置
class CacheConfig {
  /// 是否启用内存缓存
  bool enableMemoryCache;
  
  /// 是否启用磁盘缓存
  bool enableDiskCache;
  
  /// 最大内存缓存大小（字节）
  int maxMemorySize;
  
  /// 最大磁盘缓存大小（字节）
  int maxDiskSize;
  
  /// 默认过期时间
  Duration defaultExpiry;
  
  /// 清理间隔
  Duration cleanupInterval;
  
  /// 是否启用压缩
  bool enableCompression;
  
  /// 压缩阈值（字节）
  int compressionThreshold;
  
  /// 是否启用加密
  bool enableEncryption;
  
  /// 加密密钥
  String? encryptionKey;
  
  /// 是否启用标签管理
  bool enableTagManagement;
  
  /// 磁盘I/O缓冲区大小
  int diskIOBufferSize;
  
  /// 是否启用异步磁盘操作
  bool enableAsyncDiskIO;
  
  CacheConfig({
    this.enableMemoryCache = true,
    this.enableDiskCache = true,
    this.maxMemorySize = 50 * 1024 * 1024, // 50MB
    this.maxDiskSize = 200 * 1024 * 1024, // 200MB
    this.defaultExpiry = const Duration(hours: 1),
    this.cleanupInterval = const Duration(minutes: 30),
    this.enableCompression = true,
    this.compressionThreshold = 1024, // 1KB
    this.enableEncryption = false,
    this.encryptionKey,
    this.enableTagManagement = true,
    this.diskIOBufferSize = 8192, // 8KB
    this.enableAsyncDiskIO = true,
  });
}

/// 缓存统计
class CacheStatistics {
  int totalRequests = 0;
  int memoryHits = 0;
  int diskHits = 0;
  int misses = 0;
  int totalSets = 0;
  
  /// 内存命中率
  double get memoryHitRate => totalRequests > 0 ? memoryHits / totalRequests : 0.0;
  
  /// 磁盘命中率
  double get diskHitRate => totalRequests > 0 ? diskHits / totalRequests : 0.0;
  
  /// 总命中率
  double get totalHitRate => totalRequests > 0 ? (memoryHits + diskHits) / totalRequests : 0.0;
  
  /// 未命中率
  double get missRate => totalRequests > 0 ? misses / totalRequests : 0.0;
  
  /// 重置统计
  void reset() {
    totalRequests = 0;
    memoryHits = 0;
    diskHits = 0;
    misses = 0;
    totalSets = 0;
  }
  
  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'totalRequests': totalRequests,
      'memoryHits': memoryHits,
      'diskHits': diskHits,
      'misses': misses,
      'totalSets': totalSets,
      'memoryHitRate': memoryHitRate,
      'diskHitRate': diskHitRate,
      'totalHitRate': totalHitRate,
      'missRate': missRate,
    };
  }
}