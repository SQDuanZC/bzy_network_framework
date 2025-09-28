import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 平台工具类
/// 提供跨平台的文件系统操作和平台检测功能
class PlatformUtils {
  /// 获取当前平台类型
  static PlatformType get currentPlatform {
    if (kIsWeb) {
      return PlatformType.web;
    } else if (Platform.isIOS) {
      return PlatformType.ios;
    } else if (Platform.isAndroid) {
      return PlatformType.android;
    } else if (Platform.isMacOS) {
      return PlatformType.macos;
    } else if (Platform.isWindows) {
      return PlatformType.windows;
    } else if (Platform.isLinux) {
      return PlatformType.linux;
    } else {
      return PlatformType.unknown;
    }
  }

  /// 获取平台名称
  static String get platformName {
    switch (currentPlatform) {
      case PlatformType.ios:
        return 'iOS';
      case PlatformType.android:
        return 'Android';
      case PlatformType.web:
        return 'Web';
      case PlatformType.macos:
        return 'macOS';
      case PlatformType.windows:
        return 'Windows';
      case PlatformType.linux:
        return 'Linux';
      case PlatformType.unknown:
        return 'Unknown';
    }
  }

  /// 是否为移动平台
  static bool get isMobile => currentPlatform == PlatformType.ios || currentPlatform == PlatformType.android;

  /// 是否为桌面平台
  static bool get isDesktop => currentPlatform == PlatformType.macos || 
                               currentPlatform == PlatformType.windows || 
                               currentPlatform == PlatformType.linux;

  /// 是否为Web平台
  static bool get isWeb => currentPlatform == PlatformType.web;

  /// 获取平台特定的主目录
  static String? _getHomeDirectory() {
    return Platform.environment['HOME'] ?? 
           Platform.environment['USERPROFILE'] ??
           (Platform.environment['HOMEDRIVE'] != null && Platform.environment['HOMEPATH'] != null
           ? '${Platform.environment['HOMEDRIVE']}${Platform.environment['HOMEPATH']}'
           : null);
  }

  /// 安全创建目录
  static Future<Directory?> _createDirectorySafely(String path) async {
    try {
      final directory = Directory(normalizePath(path));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      // 检查目录是否可写
      if (await isDirectoryWritable(directory)) {
        return directory;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('创建目录失败: $path, 错误: $e');
      }
      return null;
    }
  }

  /// 获取平台特定的缓存目录
  static Future<Directory?> getCacheDirectory() async {
    try {
      if (kIsWeb) {
        // Web平台使用浏览器存储，返回null表示使用内存缓存
        return null;
      }

      Directory? cacheDir;
      
      try {
        // 使用 path_provider 获取平台特定的缓存目录
        cacheDir = await getApplicationCacheDirectory();
        final networkCacheDir = Directory('${cacheDir.path}/network_cache');
        return networkCacheDir;
      } catch (e) {
        if (kDebugMode) {
          print('path_provider 获取缓存目录失败，使用 fallback: $e');
        }
        
        // Fallback to manual platform detection
        String? cachePath;
        
        switch (currentPlatform) {
          case PlatformType.ios:
          case PlatformType.macos:
            // iOS/macOS: ~/Library/Caches/
            final homeDir = _getHomeDirectory();
            if (homeDir != null) {
              cachePath = '$homeDir/Library/Caches/network_cache';
            }
            break;
          case PlatformType.android:
            // Android: 使用临时目录作为fallback
            final tempDir = Directory.systemTemp;
            cachePath = '${tempDir.path}/cache/network_cache';
            break;
          case PlatformType.windows:
            // Windows: %LOCALAPPDATA%\cache\ 或 %TEMP%\cache\
            final localAppData = Platform.environment['LOCALAPPDATA'] ?? 
                                Platform.environment['TEMP'];
            if (localAppData != null) {
              cachePath = '$localAppData\\cache\\network_cache';
            }
            break;
          case PlatformType.linux:
            // Linux: ~/.cache/
            final homeDir = _getHomeDirectory();
            if (homeDir != null) {
              cachePath = '$homeDir/.cache/network_cache';
            }
            break;
          case PlatformType.web:
          case PlatformType.unknown:
            return null;
        }

        if (cachePath != null) {
          return Directory(normalizePath(cachePath));
        }
        
        // Final fallback to system temp directory
        final tempDir = Directory.systemTemp;
        return Directory('${tempDir.path}/network_cache');
      }
    } catch (e) {
      if (kDebugMode) {
        print('获取缓存目录失败: $e');
      }
      // Final fallback to system temp directory
      try {
        final tempDir = Directory.systemTemp;
        return Directory('${tempDir.path}/network_cache');
      } catch (fallbackError) {
        return null;
      }
    }
  }

  /// 获取平台特定的文档目录
  static Future<Directory?> getDocumentsDirectory() async {
    try {
      if (kIsWeb) {
        return null;
      }

      Directory? documentsDir;
      
      try {
        // 使用 path_provider 获取平台特定的文档目录
        documentsDir = await getApplicationDocumentsDirectory();
        final networkDocumentsDir = Directory('${documentsDir.path}/network_documents');
        return networkDocumentsDir;
      } catch (e) {
        if (kDebugMode) {
          print('path_provider 获取文档目录失败，使用 fallback: $e');
        }
        
        // Fallback to manual platform detection
        String? documentsPath;

        switch (currentPlatform) {
          case PlatformType.ios:
          case PlatformType.macos:
          case PlatformType.linux:
            // iOS/macOS/Linux: ~/Documents/
            final homeDir = _getHomeDirectory();
            if (homeDir != null) {
              documentsPath = '$homeDir/Documents/network_documents';
            }
            break;
          case PlatformType.android:
            // Android: 使用临时目录作为fallback
            final tempDir = Directory.systemTemp;
            documentsPath = '${tempDir.path}/documents/network_documents';
            break;
          case PlatformType.windows:
            // Windows: %USERPROFILE%\Documents\
            final userProfile = _getHomeDirectory();
            if (userProfile != null) {
              documentsPath = '$userProfile\\Documents\\network_documents';
            }
            break;
          case PlatformType.web:
          case PlatformType.unknown:
            return null;
        }

        if (documentsPath != null) {
          return Directory(normalizePath(documentsPath));
        }

        // Final fallback to system temp directory
        final tempDir = Directory.systemTemp;
        return Directory('${tempDir.path}/documents/network_documents');
      }
    } catch (e) {
      if (kDebugMode) {
        print('获取文档目录失败: $e');
      }
      // Final fallback to system temp directory
      try {
        final tempDir = Directory.systemTemp;
        return Directory('${tempDir.path}/documents/network_documents');
      } catch (fallbackError) {
        return null;
      }
    }
  }

  /// 检查目录是否可写
  static Future<bool> isDirectoryWritable(Directory directory) async {
    try {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final testFile = File('${directory.path}/.write_test');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取目录大小（字节）
  static Future<int> getDirectorySize(Directory directory) async {
    try {
      if (!await directory.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// 清理目录
  static Future<bool> cleanDirectory(Directory directory) async {
    try {
      if (!await directory.exists()) {
        return true;
      }

      await for (final entity in directory.list()) {
        await entity.delete(recursive: true);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取可用磁盘空间（字节）
  static Future<int> getAvailableDiskSpace(Directory directory) async {
    try {
      if (kIsWeb) {
        // Web平台无法获取磁盘空间，返回一个合理的默认值
        return 100 * 1024 * 1024; // 100MB
      }

      final stat = await directory.stat();
      // 注意：Dart的FileStat不直接提供可用空间信息
      // 这里返回一个估算值，实际项目中可能需要使用平台特定的插件
      return 1024 * 1024 * 1024; // 1GB 估算值
    } catch (e) {
      return 0;
    }
  }

  /// 创建平台特定的缓存目录结构
  static Future<Map<String, Directory?>> createPlatformCacheStructure() async {
    final result = <String, Directory?>{};
    
    try {
      final baseDir = await getCacheDirectory();
      if (baseDir == null) {
        return result;
      }

      // 创建基础缓存目录
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }
      result['base'] = baseDir;

      // 创建子目录
      final subDirs = ['images', 'data', 'temp', 'logs'];
      for (final subDirName in subDirs) {
        final subDir = Directory('${baseDir.path}/$subDirName');
        if (!await subDir.exists()) {
          await subDir.create(recursive: true);
        }
        result[subDirName] = subDir;
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('创建平台缓存目录结构失败: $e');
      }
      return result;
    }
  }

  /// 获取带权限检查的缓存目录
  static Future<Directory?> getCacheDirectoryWithPermissionCheck() async {
    final cacheDir = await getCacheDirectory();
    if (cacheDir == null) return null;
    
    return await _createDirectorySafely(cacheDir.path);
  }

  /// 获取带权限检查的文档目录
  static Future<Directory?> getDocumentsDirectoryWithPermissionCheck() async {
    final documentsDir = await getDocumentsDirectory();
    if (documentsDir == null) return null;
    
    return await _createDirectorySafely(documentsDir.path);
  }

  /// 获取平台特定的路径分隔符
  static String get pathSeparator {
    if (kIsWeb) {
      return '/';
    }
    return Platform.pathSeparator;
  }

  /// 标准化路径
  static String normalizePath(String path) {
    if (kIsWeb) {
      return path.replaceAll('\\', '/');
    }
    return path;
  }
}

/// 平台类型枚举
enum PlatformType {
  ios,
  android,
  web,
  macos,
  windows,
  linux,
  unknown,
}

/// 平台存储信息
class PlatformStorageInfo {
  final PlatformType platform;
  final String platformName;
  final Directory? cacheDirectory;
  final Directory? documentsDirectory;
  final bool isCacheWritable;
  final bool isDocumentsWritable;
  final int availableSpace;
  final Map<String, Directory?> cacheStructure;

  PlatformStorageInfo({
    required this.platform,
    required this.platformName,
    this.cacheDirectory,
    this.documentsDirectory,
    required this.isCacheWritable,
    required this.isDocumentsWritable,
    required this.availableSpace,
    required this.cacheStructure,
  });

  @override
  String toString() {
    return 'PlatformStorageInfo{\n'
        '  platform: $platformName,\n'
        '  cacheDirectory: ${cacheDirectory?.path},\n'
        '  documentsDirectory: ${documentsDirectory?.path},\n'
        '  isCacheWritable: $isCacheWritable,\n'
        '  isDocumentsWritable: $isDocumentsWritable,\n'
        '  availableSpace: ${(availableSpace / 1024 / 1024).toStringAsFixed(2)} MB,\n'
        '  cacheStructure: ${cacheStructure.keys.join(', ')}\n'
        '}';
  }
}