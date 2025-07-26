#!/usr/bin/env dart

/// BZY 网络框架发布准备脚本
/// 
/// 此脚本用于准备 BZY 网络框架的发布包
/// 包括代码检查、测试运行、文档生成等

import 'dart:io';
import 'dart:convert';

void main(List<String> args) async {
  print('🚀 开始准备 BZY 网络框架发布包...');
  
  final releaseHelper = BzyReleaseHelper();
  
  try {
    // 1. 检查环境
    await releaseHelper.checkEnvironment();
    
    // 2. 运行代码分析
    await releaseHelper.runAnalysis();
    
    // 3. 运行测试
    await releaseHelper.runTests();
    
    // 4. 检查版本号
    await releaseHelper.checkVersion();
    
    // 5. 生成文档
    await releaseHelper.generateDocs();
    
    // 6. 创建发布包
    await releaseHelper.createReleasePackage();
    
    print('✅ BZY 网络框架发布包准备完成！');
    print('📦 发布包位置: ./release/bzy_network_framework.tar.gz');
    print('📚 使用说明: ./release/README.md');
    
  } catch (e) {
    print('❌ 发布准备失败: $e');
    exit(1);
  }
}

class BzyReleaseHelper {
  static const String frameworkName = 'BZY Network Framework';
  static const String packageName = 'bzy_network_framework';
  
  /// 检查环境
  Future<void> checkEnvironment() async {
    print('\n🔍 检查环境...');
    
    // 检查 Flutter 版本
    final flutterResult = await Process.run('flutter', ['--version']);
    if (flutterResult.exitCode != 0) {
      throw Exception('Flutter 未安装或版本不兼容');
    }
    
    // 检查 Dart 版本
    final dartResult = await Process.run('dart', ['--version']);
    if (dartResult.exitCode != 0) {
      throw Exception('Dart 未安装或版本不兼容');
    }
    
    print('✅ 环境检查通过');
  }
  
  /// 运行代码分析
  Future<void> runAnalysis() async {
    print('\n📊 运行代码分析...');
    
    final result = await Process.run('dart', ['analyze', '.']);
    if (result.exitCode != 0) {
      print('⚠️  代码分析发现问题:');
      print(result.stdout);
      print(result.stderr);
      
      // 询问是否继续
      stdout.write('是否继续发布? (y/N): ');
      final input = stdin.readLineSync();
      if (input?.toLowerCase() != 'y') {
        throw Exception('用户取消发布');
      }
    } else {
      print('✅ 代码分析通过');
    }
  }
  
  /// 运行测试
  Future<void> runTests() async {
    print('\n🧪 运行测试...');
    
    final result = await Process.run('flutter', ['test']);
    if (result.exitCode != 0) {
      print('❌ 测试失败:');
      print(result.stdout);
      print(result.stderr);
      throw Exception('测试未通过');
    }
    
    print('✅ 所有测试通过');
  }
  
  /// 检查版本号
  Future<void> checkVersion() async {
    print('\n🏷️  检查版本号...');
    
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      throw Exception('pubspec.yaml 文件不存在');
    }
    
    final content = await pubspecFile.readAsString();
    final versionMatch = RegExp(r'version:\s*([\d\.]+)').firstMatch(content);
    
    if (versionMatch == null) {
      throw Exception('无法找到版本号');
    }
    
    final version = versionMatch.group(1)!;
    print('📋 当前版本: $version');
    
    // 检查 CHANGELOG.md 是否包含当前版本
    final changelogFile = File('CHANGELOG.md');
    if (changelogFile.existsSync()) {
      final changelogContent = await changelogFile.readAsString();
      if (!changelogContent.contains('[$version]')) {
        print('⚠️  CHANGELOG.md 中未找到版本 $version 的更新记录');
      }
    }
    
    print('✅ 版本检查完成');
  }
  
  /// 生成文档
  Future<void> generateDocs() async {
    print('\n📚 生成文档...');
    
    // 生成 API 文档
    final docResult = await Process.run('dart', ['doc', '.']);
    if (docResult.exitCode != 0) {
      print('⚠️  API 文档生成失败，但继续发布');
    }
    
    // 创建发布说明
    await _createReleaseNotes();
    
    print('✅ 文档生成完成');
  }
  
  /// 创建发布包
  Future<void> createReleasePackage() async {
    print('\n📦 创建发布包...');
    
    // 创建发布目录
    final releaseDir = Directory('release');
    if (releaseDir.existsSync()) {
      await releaseDir.delete(recursive: true);
    }
    await releaseDir.create();
    
    // 复制必要文件
    final filesToCopy = [
      'pubspec.yaml',
      'README.md',
      'CHANGELOG.md',
      'LICENSE',
      'lib/',
      'test/',
      'example/',
      'docs/',
    ];
    
    for (final file in filesToCopy) {
      final source = File(file);
      final sourceDir = Directory(file);
      
      if (source.existsSync()) {
        await source.copy('release/$file');
      } else if (sourceDir.existsSync()) {
        await _copyDirectory(sourceDir, Directory('release/$file'));
      }
    }
    
    // 创建压缩包
    final tarResult = await Process.run('tar', [
      '-czf',
      'release/$packageName.tar.gz',
      '-C',
      'release',
      '.',
    ]);
    
    if (tarResult.exitCode != 0) {
      print('⚠️  压缩包创建失败，但文件已准备完成');
    }
    
    print('✅ 发布包创建完成');
  }
  
  /// 创建发布说明
  Future<void> _createReleaseNotes() async {
    final releaseNotes = '''
# $frameworkName 发布说明

## 📦 包信息
- **包名**: $packageName
- **版本**: 请查看 pubspec.yaml
- **发布时间**: ${DateTime.now().toIso8601String()}

## 🚀 安装方式

### 方式一：从 pub.dev 安装
```yaml
dependencies:
  $packageName: ^1.0.0
```

### 方式二：从源码安装
```yaml
dependencies:
  $packageName:
    git:
      url: https://github.com/your-org/$packageName.git
      ref: main
```

## 📚 快速开始

```dart
import 'package:$packageName/$packageName.dart';

void main() async {
  // 初始化 BZY 网络框架
  await UnifiedNetworkFramework.initialize(
    baseUrl: 'https://api.example.com',
    enableLogging: true,
    enableCache: true,
  );
  
  // 创建请求
  final request = GetUserRequest('123');
  final response = await UnifiedNetworkFramework.instance.execute(request);
  
  if (response.success) {
    print('用户信息: \${response.data}');
  }
}
```

## 📖 文档链接

- [完整文档](./docs/README.md)
- [快速开始](./docs/QUICK_START_GUIDE.md)
- [API 参考](./docs/API_REFERENCE.md)
- [最佳实践](./docs/BEST_PRACTICES.md)

## 🐛 问题反馈

如果您在使用过程中遇到问题，请通过以下方式反馈：

- GitHub Issues: https://github.com/your-org/$packageName/issues
- 邮箱: support@bzy.com

## 📄 许可证

本项目采用 MIT 许可证，详见 [LICENSE](./LICENSE) 文件。

---

**BZY 团队** ❤️ **Flutter 社区**
''';
    
    await File('release/RELEASE_NOTES.md').writeAsString(releaseNotes);
  }
  
  /// 复制目录
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    
    await for (final entity in source.list(recursive: false)) {
      if (entity is File) {
        final newFile = File('${destination.path}/${entity.uri.pathSegments.last}');
        await entity.copy(newFile.path);
      } else if (entity is Directory) {
        final newDir = Directory('${destination.path}/${entity.uri.pathSegments.last}');
        await _copyDirectory(entity, newDir);
      }
    }
  }
}