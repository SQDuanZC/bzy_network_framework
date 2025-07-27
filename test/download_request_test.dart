import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:bzy_network_framework/bzy_network_framework.dart';
import 'dart:io';
import 'dart:typed_data';

void main() {
  group('DownloadRequest Tests', () {
    late UnifiedNetworkFramework framework;
    late Directory tempDir;
    
    setUpAll(() async {
      framework = UnifiedNetworkFramework.instance;
      await framework.initialize(
        baseUrl: 'https://httpbin.org',
        config: {
          'connectTimeout': 30000,
          'receiveTimeout': 30000,
          'sendTimeout': 30000,
        },
      );
      
      // 创建临时目录用于测试
      tempDir = await Directory.systemTemp.createTemp('download_test_');
    });
    
    tearDownAll(() async {
      // 清理临时目录
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    
    test('should download file successfully', () async {
      final downloadPath = '${tempDir.path}/test_download.json';
      
      final request = TestDownloadRequest(
        fileUrl: '/json',
        localPath: downloadPath,
      );
      
      final response = await framework.execute<TestDownloadResponse>(request);
      
      expect(response.success, true);
      expect(response.data?.success, true);
      expect(response.data?.filePath, downloadPath);
      
      // 验证文件是否存在
      final downloadedFile = File(downloadPath);
      expect(await downloadedFile.exists(), true);
      
      // 验证文件内容不为空
      final fileSize = await downloadedFile.length();
      expect(fileSize, greaterThan(0));
    });
    
    test('should handle download progress', () async {
      final downloadPath = '${tempDir.path}/test_progress.json';
      int progressCallCount = 0;
      int lastReceived = 0;
      int lastTotal = 0;
      
      final request = TestDownloadRequest(
        fileUrl: '/json',
        localPath: downloadPath,
        progressCallback: (received, total) {
          progressCallCount++;
          lastReceived = received;
          lastTotal = total;
        },
      );
      
      final response = await framework.execute<TestDownloadResponse>(request);
      
      expect(response.success, true);
      expect(progressCallCount, greaterThan(0));
      expect(lastReceived, greaterThan(0));
      expect(lastTotal, greaterThan(0));
    });
    
    test('should handle file already exists', () async {
      final downloadPath = '${tempDir.path}/existing_file.json';
      
      // 先创建一个文件
      final existingFile = File(downloadPath);
      await existingFile.writeAsString('existing content');
      
      final request = TestDownloadRequest(
        fileUrl: '/json',
        localPath: downloadPath,
        overwriteExisting: false,
      );
      
      final response = await framework.execute<TestDownloadResponse>(request);
      
      expect(response.success, false);
      expect(response.statusCode, 409);
      expect(response.errorCode, 'FILE_EXISTS');
    });
    
    test('should overwrite existing file when allowed', () async {
      final downloadPath = '${tempDir.path}/overwrite_file.json';
      
      // 先创建一个文件
      final existingFile = File(downloadPath);
      await existingFile.writeAsString('existing content');
      final originalSize = await existingFile.length();
      
      final request = TestDownloadRequest(
        fileUrl: '/json',
        localPath: downloadPath,
        overwriteExisting: true,
      );
      
      final response = await framework.execute<TestDownloadResponse>(request);
      
      expect(response.success, true);
      
      // 验证文件被覆盖
      final newSize = await existingFile.length();
      expect(newSize, isNot(equals(originalSize)));
    });
    
    test('should handle download error', () async {
      final downloadPath = '${tempDir.path}/error_download.json';
      
      final request = TestDownloadRequest(
        fileUrl: '/status/404', // 404错误
        localPath: downloadPath,
      );
      
      final response = await framework.execute<TestDownloadResponse>(request);
      
      expect(response.success, false);
      expect(response.statusCode, 404);
    });
    
    test('should create directory if not exists', () async {
      final nestedPath = '${tempDir.path}/nested/deep/directory/test_file.json';
      
      final request = TestDownloadRequest(
        fileUrl: '/json',
        localPath: nestedPath,
      );
      
      final response = await framework.execute<TestDownloadResponse>(request);
      
      expect(response.success, true);
      
      // 验证嵌套目录被创建
      final downloadedFile = File(nestedPath);
      expect(await downloadedFile.exists(), true);
    });
  });
}

/// 测试用的下载请求类
class TestDownloadRequest extends DownloadRequest<TestDownloadResponse> {
  final String fileUrl;
  final String localPath;
  final void Function(int received, int total)? progressCallback;
  final bool _overwriteExisting;
  
  TestDownloadRequest({
    required this.fileUrl,
    required this.localPath,
    this.progressCallback,
    bool overwriteExisting = true,
  }) : _overwriteExisting = overwriteExisting;
  
  @override
  String get path => fileUrl;
  
  @override
  String get savePath => localPath;
  
  @override
  void Function(int received, int total)? get onProgress => progressCallback;
  
  @override
  bool get overwriteExisting => _overwriteExisting;
  
  @override
  TestDownloadResponse parseResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      return TestDownloadResponse(
        filePath: data['filePath'] as String,
        fileSize: data['fileSize'] as int,
        success: data['success'] as bool,
      );
    }
    return TestDownloadResponse(
      filePath: savePath,
      fileSize: 0,
      success: false,
    );
  }
  
  @override
  void Function(String filePath)? get onDownloadComplete => (filePath) {
    print('测试下载完成: $filePath');
  };
  
  @override
  void Function(String error)? get onDownloadError => (error) {
    print('测试下载失败: $error');
  };
}

/// 测试用的下载响应类
class TestDownloadResponse {
  final String filePath;
  final int fileSize;
  final bool success;
  
  TestDownloadResponse({
    required this.filePath,
    required this.fileSize,
    required this.success,
  });
}