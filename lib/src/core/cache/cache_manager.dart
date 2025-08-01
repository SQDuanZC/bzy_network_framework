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
  final Lock _memoryOperationLock = Lock();
  
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
      final memoryEntry = await _memoryOperationLock.synchronized(() {
        return _memoryCache[key];
      });
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
            await _memoryOperationLock.synchronized(() async {
              _memoryCache[key] = diskEntry;
            });
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
    await _memoryOperationLock.synchronized(() async {
      // 检查内存限制
      final currentSize = _memoryCache.values.fold(0, (sum, entry) => sum + entry.size);
      
      // 如果当前条目已存在，先减去其大小
      final existingEntry = _memoryCache[key];
      final adjustedCurrentSize = existingEntry != null 
          ? currentSize - existingEntry.size 
          : currentSize;
      
      if (adjustedCurrentSize + entry.size > _config.maxMemorySize) {
        // 计算需要释放的空间
        final targetSize = (_config.maxMemorySize * 0.8).toInt(); // 保留20%缓冲
        final spaceNeeded = adjustedCurrentSize + entry.size - targetSize;
        
        if (spaceNeeded > 0) {
          final entries = _memoryCache.entries.toList();
          // 排序：优先级低的、访问时间早的优先淘汰
          entries.sort((a, b) {
            final priorityCompare = a.value.priority.index.compareTo(b.value.priority.index);
            if (priorityCompare != 0) return priorityCompare;
            return a.value.lastAccessed.compareTo(b.value.lastAccessed);
          });
          
          var freedSpace = 0;
          for (final e in entries) {
            if (freedSpace >= spaceNeeded) break;
            if (e.key == key) continue; // 跳过当前要设置的key
            
            _memoryCache.remove(e.key);
            freedSpace += e.value.size;
            
            // 清理标签映射
            final tags = _keyToTags[e.key];
            if (tags != null) {
              for (final tag in tags) {
                _tagToKeys[tag]?.remove(e.key);
                if (_tagToKeys[tag]?.isEmpty == true) {
                  _tagToKeys.remove(tag);
                }
              }
              _keyToTags.remove(e.key);
            }
          }
        }
      }
      
      _memoryCache[key] = entry;
    });
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
      var isEncrypted = entry.isEncrypted;
      
      // 加密处理 - 确保与entry.isEncrypted标记一致
      if (entry.isEncrypted && _config.enableEncryption && _config.encryptionKey != null) {
        try {
          dataToWrite = _encryptData(dataToWrite);
        } catch (e, stackTrace) {
          if (kDebugMode) {
            debugPrint('加密数据失败: $e');
            debugPrint('堆栈跟踪: $stackTrace');
          }
          // 加密失败时保持原数据，但需要更新加密标记
          isEncrypted = false;
        }
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
        'isEncrypted': isEncrypted,
      };
      
      var finalData = jsonEncode(cacheData);
      
      // 压缩处理 - 确保与entry.isCompressed标记一致
      if (entry.isCompressed) {
        try {
          final compressedData = _compressData(finalData);
          await file.writeAsBytes(compressedData);
        } catch (e, stackTrace) {
          if (kDebugMode) {
            debugPrint('压缩数据失败，使用原始数据: $e');
            debugPrint('堆栈跟踪: $stackTrace');
          }
          // 压缩失败时写入原始数据，但需要更新压缩标记
          final updatedCacheData = Map<String, dynamic>.from(cacheData);
          updatedCacheData['isCompressed'] = false;
          await file.writeAsString(jsonEncode(updatedCacheData));
        }
      } else {
        await file.writeAsString(finalData);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('写入磁盘缓存失败: $e');
        debugPrint('堆栈跟踪: $stackTrace');
      }
    }
  }
  

  

  

  
  /// 从文件读取缓存条目
  Future<CacheEntry?> _readCacheEntryFromFile(File file) async {
    try {
      final content = await file.readAsString();
      final data = jsonDecode(content);
      
      return CacheEntry(
        key: data['key'],
        data: data['data'],
        expiryTime: DateTime.fromMillisecondsSinceEpoch(data['expiryTime']),
        priority: CachePriority.values[data['priority']],
        size: data['size'],
        accessCount: data['accessCount'] ?? 0,
        lastAccessed: DateTime.fromMillisecondsSinceEpoch(data['lastAccessed'] ?? DateTime.now().millisecondsSinceEpoch),
        tags: Set<String>.from(data['tags'] ?? []),
        isCompressed: data['isCompressed'] ?? false,
        isEncrypted: data['isEncrypted'] ?? false,
      );
    } catch (e) {
      // 文件损坏，删除它
      await file.delete().catchError((_) => file);
      return null;
    }
  }
  
  /// 执行清理
  Future<void> _performCleanup() async {
    await _cleanupExpiredEntries();
  }
  
  /// 清理过期条目
  Future<void> _cleanupExpiredEntries() async {
    // 清理内存中的过期条目
    final expiredKeys = <String>[];
    await _memoryOperationLock.synchronized(() async {
      for (final entry in _memoryCache.entries) {
        if (entry.value.isExpired) {
          expiredKeys.add(entry.key);
        }
      }
    });
    
    for (final key in expiredKeys) {
      await remove(key);
    }
    
    // 清理磁盘中的过期条目
    if (_config.enableDiskCache && _cacheDirectory != null) {
      await _diskOperationLock.synchronized(() async {
        try {
          if (await _cacheDirectory!.exists()) {
            await for (final entity in _cacheDirectory!.list()) {
              if (entity is File && entity.path.endsWith('.cache')) {
                try {
                  final content = await entity.readAsString();
                  final cacheData = jsonDecode(content);
                  final expiryTime = DateTime.fromMillisecondsSinceEpoch(cacheData['expiryTime']);
                  
                  if (DateTime.now().isAfter(expiryTime)) {
                    await entity.delete();
                  }
                } catch (e) {
                  // 如果无法解析文件，删除它
                  await entity.delete();
                }
              }
            }
          }
        } catch (e, stackTrace) {
          if (kDebugMode) {
            debugPrint('清理磁盘缓存失败: $e');
            debugPrint('堆栈跟踪: $stackTrace');
          }
        }
      });
    }
  }
  
  /// 内存缓存淘汰策略
  Future<void> _evictMemoryCache() async {
    await _memoryOperationLock.synchronized(() async {
      final targetSize = (_config.maxMemorySize * 0.8).toInt();
      final entries = _memoryCache.entries.toList();
      
      // 按优先级和访问时间排序
      entries.sort((a, b) {
        final priorityCompare = a.value.priority.index.compareTo(b.value.priority.index);
        if (priorityCompare != 0) return priorityCompare;
        return a.value.lastAccessed.compareTo(b.value.lastAccessed);
      });
      
      var currentSize = _memoryCache.values.fold<int>(0, (sum, entry) => sum + entry.size);
      
      // 删除低优先级和最久未使用的条目
      for (final entry in entries) {
        if (currentSize <= targetSize) break;
        
        _memoryCache.remove(entry.key);
        currentSize -= entry.value.size;
        
        // 清理标签映射
        final tags = _keyToTags[entry.key];
        if (tags != null) {
          for (final tag in tags) {
            _tagToKeys[tag]?.remove(entry.key);
            if (_tagToKeys[tag]?.isEmpty == true) {
              _tagToKeys.remove(tag);
            }
          }
          _keyToTags.remove(entry.key);
        }
      }
    });
  }

  /// 计算数据大小
  int _calculateSize(Map<String, dynamic> data) {
    return utf8.encode(jsonEncode(data)).length;
  }

  /// 生成缓存键的哈希值
  String _hashKey(String key) {
    return key.hashCode.abs().toString();
  }

  /// 序列化响应
  Map<String, dynamic> _serializeResponse<T>(BaseResponse<T> response) {
    return {
      'success': response.success,
      'data': response.data,
      'message': response.message,
      'code': response.code,
      'timestamp': response.timestamp,
    };
  }

  /// 反序列化响应
  BaseResponse<T> _deserializeResponse<T>(
    Map<String, dynamic> data,
    T Function(dynamic)? fromJson,
  ) {
    return BaseResponse<T>(
      success: data['success'],
      data: fromJson != null && data['data'] != null ? fromJson(data['data']) : data['data'],
      message: data['message'],
      code: data['code'],
      timestamp: data['timestamp'] as int?,
    );
  }
  
  /// 获取缓存信息
  Future<Map<String, dynamic>> getCacheInfo() async {
    return await _memoryOperationLock.synchronized(() async {
      final memoryEntries = _memoryCache.length;
      final memorySize = _memoryCache.values.fold<int>(0, (sum, entry) => sum + entry.size);
      final compressedEntries = _memoryCache.values.where((e) => e.isCompressed).length;
      final encryptedEntries = _memoryCache.values.where((e) => e.isEncrypted).length;
      
      return {
        'memoryEntries': memoryEntries,
        'memorySize': memorySize,
        'compressedEntries': compressedEntries,
        'encryptedEntries': encryptedEntries,
        'totalTags': _tagToKeys.length,
        'tagMappings': _tagToKeys.map((k, v) => MapEntry(k, v.length)),
        'diskIOQueueLength': _diskIOQueue.length,
        'statistics': _statistics.toMap(),
      };
    });
  }
  
  /// 更新配置
  void updateConfig(CacheConfig newConfig) {
    _config = newConfig;
    
    // 重启定期清理
    _startPeriodicCleanup();
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
    
    try {
      // 简单的XOR加密（生产环境应使用更强的加密算法）
      final key = _config.encryptionKey!;
      final keyBytes = utf8.encode(key);
      final dataBytes = utf8.encode(data);
      final encryptedBytes = <int>[];
      
      for (int i = 0; i < dataBytes.length; i++) {
        encryptedBytes.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
      }
      
      return base64.encode(encryptedBytes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('加密数据失败: $e');
      }
      return data; // 加密失败，返回原数据
    }
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
      if (kDebugMode) {
        debugPrint('解密数据失败: $e');
      }
      return encryptedData; // 解密失败，返回原数据
    }
  }
  
  // ==================== 磁盘缓存读取 ====================
  
  /// 从磁盘获取缓存
  Future<CacheEntry?> _getDiskCache(String key) async {
    if (!_config.enableDiskCache || _cacheDirectory == null) return null;
    
    return await _diskOperationLock.synchronized(() async {
      try {
        final file = File('${_cacheDirectory!.path}/${_hashKey(key)}.cache');
        
        if (!await file.exists()) {
          return null;
        }
        
        // 检查文件权限和大小
        final stat = await file.stat();
        if (stat.size == 0) {
          await file.delete().catchError((_) => file);
          return null;
        }
        
        String content;
        
        // 根据文件大小选择读取策略
        if (stat.size > _config.diskIOBufferSize) {
          // 大文件使用RandomAccessFile分块读取
          final randomAccessFile = await file.open();
          try {
            final bytes = await randomAccessFile.read(stat.size);
            if (bytes.isEmpty) {
              await file.delete().catchError((_) => file);
              return null;
            }
            content = utf8.decode(bytes);
          } finally {
            await randomAccessFile.close();
          }
        } else {
          // 小文件直接读取，增加超时控制
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
        
        // 解析缓存数据
         Map<String, dynamic> cacheData;
         try {
           cacheData = jsonDecode(content) as Map<String, dynamic>;
         } catch (e) {
           // JSON解析失败，文件损坏
           await file.delete().catchError((_) => file);
           return null;
         }
         
         // 检查是否为压缩数据并解压
         final isCompressed = cacheData['isCompressed'] == true;
         if (isCompressed) {
           try {
             final compressedData = cacheData['data'] as String;
             final bytes = base64Decode(compressedData);
             final decompressed = _decompressData(bytes);
             cacheData['data'] = decompressed;
           } catch (e) {
             if (kDebugMode) {
               debugPrint('解压缩数据失败: $e');
             }
             await file.delete().catchError((_) => file);
             return null;
           }
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
            final decryptedData = _decryptData(entryData);
            entryData = jsonDecode(decryptedData);
          } catch (e) {
            // 解密失败，可能是密钥不匹配或数据损坏
            if (kDebugMode) {
              debugPrint('缓存解密失败: $e');
            }
            await file.delete().catchError((_) => file);
            return null;
          }
        } else if (!isEncrypted && entryData is String) {
          try {
            entryData = jsonDecode(entryData);
          } catch (e) {
            // JSON解析失败
            if (kDebugMode) {
              debugPrint('缓存数据解析失败: $e');
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
    Set<String> tags = {};
    
    // 删除内存缓存并获取标签
    await _memoryOperationLock.synchronized(() async {
      _memoryCache.remove(key);
      
      // 在同一个锁内获取并清理标签映射
      if (_config.enableTagManagement) {
        tags = Set<String>.from(_keyToTags[key] ?? {});
        
        // 清理标签映射
        for (final tag in tags) {
          _tagToKeys[tag]?.remove(key);
          if (_tagToKeys[tag]?.isEmpty == true) {
            _tagToKeys.remove(tag);
          }
        }
        _keyToTags.remove(key);
      }
    });
    
    // 删除磁盘缓存
    if (_config.enableDiskCache && _cacheDirectory != null) {
      await _diskOperationLock.synchronized(() async {
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
      });
    }
  }
  
  /// 清空所有缓存
  Future<void> clear() async {
    // 清空内存缓存和标签映射
    await _memoryOperationLock.synchronized(() async {
      _memoryCache.clear();
      
      // 在同一个锁内清空标签映射
      if (_config.enableTagManagement) {
        _tagToKeys.clear();
        _keyToTags.clear();
      }
    });
    
    // 清空磁盘缓存
    if (_config.enableDiskCache && _cacheDirectory != null) {
      await _diskOperationLock.synchronized(() async {
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
      });
    }
    
    // 等待所有磁盘I/O操作完成
    if (_config.enableAsyncDiskIO && _diskIOQueue.isNotEmpty) {
      try {
        await Future.wait(_diskIOQueue, eagerError: false);
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
  
  // ==================== 标签管理功能 ====================
  
  /// 添加标签
  Future<void> addTag(String cacheKey, String tag) async {
    if (!_config.enableTagManagement) return;
    
    await _memoryOperationLock.synchronized(() async {
      // 更新标签到键的映射
      _tagToKeys.putIfAbsent(tag, () => <String>{}).add(cacheKey);
      
      // 更新键到标签的映射
      _keyToTags.putIfAbsent(cacheKey, () => <String>{}).add(tag);
      
      // 更新内存缓存中的条目
      final entry = _memoryCache[cacheKey];
      if (entry != null) {
        _memoryCache[cacheKey] = entry.copyWithTags({tag});
      }
    });
  }
  
  /// 移除标签
  Future<void> removeTag(String cacheKey, String tag) async {
    if (!_config.enableTagManagement) return;
    
    await _memoryOperationLock.synchronized(() async {
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
    });
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

/// 缓存条目
class CacheEntry {
  final String key;
  final dynamic data;
  final DateTime expiryTime;
  final CachePriority priority;
  final int size;
  final int accessCount;
  final DateTime lastAccessed;
  final Set<String> tags;
  final bool isCompressed;
  final bool isEncrypted;

  CacheEntry({
    required this.key,
    required this.data,
    required this.expiryTime,
    required this.priority,
    required this.size,
    required this.accessCount,
    required this.lastAccessed,
    required this.tags,
    required this.isCompressed,
    required this.isEncrypted,
  });

  /// 是否已过期
  bool get isExpired => DateTime.now().isAfter(expiryTime);

  /// 复制并更新访问时间
  CacheEntry copyWithAccess() {
    return CacheEntry(
      key: key,
      data: data,
      expiryTime: expiryTime,
      priority: priority,
      size: size,
      accessCount: accessCount + 1,
      lastAccessed: DateTime.now(),
      tags: tags,
      isCompressed: isCompressed,
      isEncrypted: isEncrypted,
    );
  }

  /// 复制并添加标签
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

  /// 转换为Map用于序列化
  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'data': data,
      'expiryTime': expiryTime.millisecondsSinceEpoch,
      'priority': priority.index,
      'size': size,
      'accessCount': accessCount,
      'lastAccessed': lastAccessed.millisecondsSinceEpoch,
      'tags': tags.toList(),
      'isCompressed': isCompressed,
      'isEncrypted': isEncrypted,
    };
  }
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