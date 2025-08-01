import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/bzy_network_framework.dart';
import 'dart:io';

/// File Operations Examples | 文件操作示例
/// Demonstrates file upload and download functionality | 演示文件上传和下载功能
void main() {
  group('File Operations Examples | 文件操作示例', () {
    setUpAll(() async {
      // Initialize network framework | 初始化网络框架
      await UnifiedNetworkFramework.instance.initialize(
        baseUrl: 'https://httpbin.org',
      );
    });

    test('Single File Upload Example | 单文件上传示例', () async {
      // Create test file | 创建测试文件
      final testFile = File('test_upload.txt');
      await testFile.writeAsString('This is a test file content');
      
      final request = SingleFileUploadRequest(file: testFile);
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('Single file upload successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('Single file upload failed: $e');
      } finally {
        // Clean up test file | 清理测试文件
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });

    test('Multiple File Upload Example | 多文件上传示例', () async {
      // Create multiple test files | 创建多个测试文件
      final file1 = File('test_upload_1.txt');
      final file2 = File('test_upload_2.txt');
      await file1.writeAsString('First test file');
      await file2.writeAsString('Second test file');
      
      final request = MultipleFileUploadRequest(files: [file1, file2]);
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('Multiple file upload successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('Multiple file upload failed: $e');
      } finally {
        // Clean up test files | 清理测试文件
        for (final file in [file1, file2]) {
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    });

    test('File Upload with Additional Data Example | 带额外数据的文件上传示例', () async {
      // Create test file | 创建测试文件
      final testFile = File('test_upload_with_data.txt');
      await testFile.writeAsString('File upload with additional data');
      
      final request = FileUploadWithDataRequest(
        file: testFile,
        title: 'Test Title',
        description: 'Test Description',
        category: 'test',
      );
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('File upload with additional data successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('File upload with additional data failed: $e');
      } finally {
        // Clean up test file | 清理测试文件
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });

    test('File Download Example | 文件下载示例', () async {
      final request = FileDownloadRequest(
        downloadUrl: '/base64/SFRUUEJJTiBpcyBhd2Vzb21l',
        savePath: 'downloaded_file.txt',
      );
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('File download successful: ${response.data}');
        expect(response.success, true);
        
        // Check if file exists | 检查文件是否存在
        final downloadedFile = File('downloaded_file.txt');
        if (await downloadedFile.exists()) {
          final content = await downloadedFile.readAsString();
          print('Downloaded file content: $content');
          await downloadedFile.delete(); // Clean up downloaded file | 清理下载的文件
        }
      } catch (e) {
        print('File download failed: $e');
      }
    });

    test('File Upload with Progress Monitoring Example | 带进度监听的文件上传示例', () async {
      // Create test file | 创建测试文件
      final testFile = File('test_progress_file.txt');
      await testFile.writeAsString('Test upload progress monitoring' * 1000); // Create larger file | 创建较大文件
      
      final request = FileUploadWithProgressRequest(file: testFile);
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('File upload with progress monitoring successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('File upload with progress monitoring failed: $e');
      } finally {
        // Clean up test file | 清理测试文件
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });
  });
}

/// Single file upload request | 单文件上传请求
class SingleFileUploadRequest extends UploadRequest<Map<String, dynamic>> {
  final File file;
  
  SingleFileUploadRequest({required this.file});
  
  @override
  String get path => '/post';
  
  @override
  String get filePath => file.path;
  
  @override
  Map<String, dynamic>? getFormData() {
    return {
      'file': file.path,
    };
  }
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// Multiple file upload request | 多文件上传请求
class MultipleFileUploadRequest extends UploadRequest<Map<String, dynamic>> {
  final List<File> files;
  
  MultipleFileUploadRequest({required this.files});
  
  @override
  String get path => '/post';
  
  @override
  String get filePath => files.isNotEmpty ? files.first.path : '';
  
  @override
  Map<String, dynamic>? getFormData() {
    return {
      for (int i = 0; i < files.length; i++)
        'file$i': files[i].path,
    };
  }
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// File upload request with additional data | 带额外数据的文件上传请求
class FileUploadWithDataRequest extends UploadRequest<Map<String, dynamic>> {
  final File file;
  final String title;
  final String description;
  final String category;
  
  FileUploadWithDataRequest({
    required this.file,
    required this.title,
    required this.description,
    required this.category,
  });
  
  @override
  String get path => '/post';
  
  @override
  String get filePath => file.path;
  
  @override
  Map<String, dynamic>? getFormData() {
    return {
      'file': file.path,
      'title': title,
      'description': description,
      'category': category,
    };
  }
  
  @override
  Map<String, dynamic>? get data => {
    'title': title,
    'description': description,
    'category': category,
  };
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// File download request | 文件下载请求
class FileDownloadRequest extends DownloadRequest<String> {
  final String downloadUrl;
  final String savePath;
  
  FileDownloadRequest({
    required this.downloadUrl,
    required this.savePath,
  });
  
  @override
  String get path => downloadUrl;
  
  @override
  String get saveFilePath => savePath;
  
  @override
  String parseResponse(dynamic data) {
    return 'File download completed: $savePath';
  }
}

/// File upload request with progress monitoring | 带进度监听的文件上传请求
class FileUploadWithProgressRequest extends UploadRequest<Map<String, dynamic>> {
  final File file;
  
  FileUploadWithProgressRequest({required this.file});
  
  @override
  String get path => '/post';
  
  @override
  String get filePath => file.path;
  
  @override
  Map<String, dynamic>? getFormData() {
    return {
      'file': file.path,
    };
  }
  
  @override
  void onUploadProgress(int sent, int total) {
    final progress = (sent / total * 100).toStringAsFixed(1);
    print('Upload progress: $progress% ($sent/$total bytes)');
  }
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}