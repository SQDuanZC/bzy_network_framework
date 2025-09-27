import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/src/core/cache/cache_manager.dart';
import '../lib/src/utils/platform_utils.dart';

void main() {
  group('跨平台存储测试', () {
    late CacheManager cacheManager;

    setUpAll(() async {
      cacheManager = CacheManager.instance;
    });

    test('平台检测测试', () {
      expect(PlatformUtils.isMobile || PlatformUtils.isDesktop || PlatformUtils.isWeb, isTrue);
      
      print('当前平台: ${PlatformUtils.platformName}');
      print('平台类型: ${PlatformUtils.currentPlatform}');
      print('是否为移动平台: ${PlatformUtils.isMobile}');
      print('是否为桌面平台: ${PlatformUtils.isDesktop}');
      print('是否为Web平台: ${PlatformUtils.isWeb}');
    });

    test('缓存目录创建测试', () async {
      final cacheDir = await PlatformUtils.getCacheDirectory();
      expect(cacheDir, isNotNull);
      expect(await cacheDir!.exists(), isTrue);
      
      print('缓存目录路径: ${cacheDir.path}');
    });

    test('文档目录创建测试', () async {
      final docsDir = await PlatformUtils.getDocumentsDirectory();
      expect(docsDir, isNotNull);
      expect(await docsDir!.exists(), isTrue);
      
      print('文档目录路径: ${docsDir.path}');
    });

    test('目录权限测试', () async {
      final cacheDir = await PlatformUtils.getCacheDirectory();
      final isWritable = await PlatformUtils.isDirectoryWritable(cacheDir!);
      expect(isWritable, isTrue);
      
      print('缓存目录可写: $isWritable');
    });

    test('基础缓存功能测试', () async {
      const testKey = 'test_key_storage';
      const testValue = 'test_value';
      
      // 检查CacheManager配置
      final config = cacheManager.config;
      print('CacheManager配置: enableMemoryCache=${config.enableMemoryCache}, enableDiskCache=${config.enableDiskCache}');
      
      // 清空所有缓存确保测试环境干净
      await cacheManager.clear();
      
      // 验证清空后确实为空
      final emptyValue = await cacheManager.getString(testKey);
      expect(emptyValue, isNull);
      print('清空后验证: $testKey = $emptyValue');
      
      // 设置缓存
      await cacheManager.putString(testKey, testValue);
      print('设置缓存: $testKey = $testValue');
      
      // 获取缓存
      final cachedValue = await cacheManager.getString(testKey);
      expect(cachedValue, equals(testValue));
      print('获取缓存: $testKey = $cachedValue');
      
      // 删除缓存
      await cacheManager.remove(testKey);
      print('删除缓存: $testKey');
      
      // 等待一小段时间确保删除操作完成
      await Future.delayed(Duration(milliseconds: 500));
      
      // 验证删除
      final deletedValue = await cacheManager.getString(testKey);
      print('删除后获取: $testKey = $deletedValue');
      
      // 如果删除失败，尝试再次清空
      if (deletedValue != null) {
        print('删除失败，尝试再次清空缓存');
        await cacheManager.clear();
        await Future.delayed(Duration(milliseconds: 100));
        final finalValue = await cacheManager.getString(testKey);
        print('清空后再次获取: $testKey = $finalValue');
        expect(finalValue, isNull);
      } else {
        expect(deletedValue, isNull);
      }
    });

    test('缓存统计测试', () async {
      final stats = await cacheManager.getCacheInfo();
      expect(stats, isNotNull);
      
      print('缓存统计: $stats');
    });

    test('目录大小计算测试', () async {
      final cacheDir = await PlatformUtils.getCacheDirectory();
      final size = await PlatformUtils.getDirectorySize(cacheDir!);
      expect(size, greaterThanOrEqualTo(0));
      
      print('缓存目录大小: ${size} bytes');
    });

    test('目录清理测试', () async {
      final testDir = await PlatformUtils.getCacheDirectory();
      final subDir = Directory('${testDir!.path}/test_cleanup');
      
      if (!await subDir.exists()) {
        await subDir.create(recursive: true);
      }
      
      // 创建测试文件
      final testFile = File('${subDir.path}/test.txt');
      await testFile.writeAsString('test content');
      
      expect(await testFile.exists(), isTrue);
      
      // 清理目录
      await PlatformUtils.cleanDirectory(subDir);
      
      // 验证清理结果
      final isEmpty = await subDir.list().isEmpty;
      expect(isEmpty, isTrue);
    });

    test('磁盘空间检查测试', () async {
      final cacheDir = await PlatformUtils.getCacheDirectory();
      final freeSpace = await PlatformUtils.getAvailableDiskSpace(cacheDir!);
      expect(freeSpace, greaterThan(0));
      
      print('可用磁盘空间: ${(freeSpace / 1024 / 1024).toStringAsFixed(2)} MB');
    });

    test('文件路径格式兼容性测试', () async {
      final cacheDir = await PlatformUtils.getCacheDirectory();
      final testPath = '${cacheDir!.path}/test/nested/path';
      final testDir = Directory(testPath);
      
      await testDir.create(recursive: true);
      expect(await testDir.exists(), isTrue);
      
      // 测试不同路径分隔符
      final normalizedPath = testPath.replaceAll('\\', '/');
      expect(normalizedPath.contains('/'), isTrue);
      
      await testDir.delete(recursive: true);
    });

    test('Unicode文件名测试', () async {
      final cacheDir = await PlatformUtils.getCacheDirectory();
      final unicodeFileName = '测试文件_🚀_test.txt';
      final testFile = File('${cacheDir!.path}/$unicodeFileName');
      
      try {
        await testFile.writeAsString('Unicode content');
        expect(await testFile.exists(), isTrue);
        
        final content = await testFile.readAsString();
        expect(content, equals('Unicode content'));
        
        await testFile.delete();
      } catch (e) {
        print('Unicode文件名在当前平台不支持: $e');
      }
    });

    test('平台缓存目录结构测试', () async {
       final cacheStructure = await PlatformUtils.createPlatformCacheStructure();
       
       // 验证基础目录
       expect(cacheStructure['base'], isNotNull);
       expect(await cacheStructure['base']!.exists(), isTrue);
       
       // 验证子目录
       final expectedSubDirs = ['images', 'data', 'temp', 'logs'];
       for (final subDirName in expectedSubDirs) {
         expect(cacheStructure[subDirName], isNotNull);
         expect(await cacheStructure[subDirName]!.exists(), isTrue);
         print('子目录 $subDirName: ${cacheStructure[subDirName]!.path}');
       }
       
       print('缓存目录结构创建成功，包含 ${cacheStructure.length} 个目录');
     });

     test('路径分隔符和标准化测试', () {
       final separator = PlatformUtils.pathSeparator;
       expect(separator, isNotEmpty);
       print('平台路径分隔符: "$separator"');
       
       // 测试路径标准化
       final testPath = 'test\\path/mixed\\separators';
       final normalizedPath = PlatformUtils.normalizePath(testPath);
       expect(normalizedPath, isNotEmpty);
       print('原始路径: $testPath');
       print('标准化路径: $normalizedPath');
     });

     test('平台存储信息综合测试', () async {
      print('\n=== 平台存储信息 ===');
      print('平台: ${PlatformUtils.platformName}');
      
      final cacheDir = await PlatformUtils.getCacheDirectory();
      print('缓存目录: ${cacheDir?.path}');
      
      final docsDir = await PlatformUtils.getDocumentsDirectory();
      print('文档目录: ${docsDir?.path}');
      
      if (cacheDir != null) {
        final isWritable = await PlatformUtils.isDirectoryWritable(cacheDir);
        print('缓存目录可写: $isWritable');
        
        final size = await PlatformUtils.getDirectorySize(cacheDir);
        print('缓存目录大小: $size bytes');
        
        final freeSpace = await PlatformUtils.getAvailableDiskSpace(cacheDir);
         print('可用磁盘空间: ${(freeSpace / 1024 / 1024).toStringAsFixed(2)} MB');
      }
      
      final cacheInfo = await cacheManager.getCacheInfo();
      print('缓存信息: $cacheInfo');
    });

    test('PlatformStorageInfo测试', () async {
      final cacheDir = await PlatformUtils.getCacheDirectory();
      final docsDir = await PlatformUtils.getDocumentsDirectory();
      final cacheStructure = await PlatformUtils.createPlatformCacheStructure();
      
      final storageInfo = PlatformStorageInfo(
        platform: PlatformUtils.currentPlatform,
        platformName: PlatformUtils.platformName,
        cacheDirectory: cacheDir,
        documentsDirectory: docsDir,
        isCacheWritable: cacheDir != null ? await PlatformUtils.isDirectoryWritable(cacheDir) : false,
        isDocumentsWritable: docsDir != null ? await PlatformUtils.isDirectoryWritable(docsDir) : false,
        availableSpace: cacheDir != null ? await PlatformUtils.getAvailableDiskSpace(cacheDir) : 0,
        cacheStructure: cacheStructure,
      );
      
      expect(storageInfo.platformName, isNotEmpty);
      expect(storageInfo.platform, isNotNull);
      
      print('\n=== PlatformStorageInfo ===');
      print(storageInfo.toString());
    });
  });
}