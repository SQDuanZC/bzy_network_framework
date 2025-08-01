import 'package:flutter_test/flutter_test.dart';
import 'package:bzy_network_framework/bzy_network_framework.dart';
import 'dart:io';

/// Data Processing and Priority Examples
/// Demonstrates the priority logic of data and queryParameters and data processing functionality
void main() {
  group('Data Processing and Priority Examples', () {
    setUpAll(() async {
      // Initialize network framework
      await UnifiedNetworkFramework.instance.initialize(
        baseUrl: 'https://jsonplaceholder.typicode.com',
      );
    });

    test('GET Request: queryParameters Priority Test', () async {
      print('=== GET Request: queryParameters Priority Test ===');
      
      final request = GetRequestWithPriority();
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('GET request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('GET request failed: $e');
      }
    });

    test('POST Request: data Priority Test', () async {
      print('=== POST Request: data Priority Test ===');
      
      final request = PostRequestWithPriority();
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('POST request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('POST request failed: $e');
      }
    });

    test('PUT Request: data Priority Test', () async {
      print('=== PUT Request: data Priority Test ===');
      
      final request = PutRequestWithPriority();
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('PUT request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('PUT request failed: $e');
      }
    });

    test('PATCH Request: data Priority Test', () async {
      print('=== PATCH Request: data Priority Test ===');
      
      final request = PatchRequestWithPriority();
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('PATCH request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('PATCH request failed: $e');
      }
    });

    test('DELETE Request: queryParameters Priority Test', () async {
      print('=== DELETE Request: queryParameters Priority Test ===');
      
      final request = DeleteRequestWithPriority();
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('DELETE request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('DELETE request failed: $e');
      }
    });

    test('File Upload: data and queryParameters Compatibility Test', () async {
      print('=== File Upload: data and queryParameters Compatibility Test ===');
      
      final request = FileUploadWithMixedData();
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('File upload successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('File upload failed: $e');
      }
    });

    test('Complex Data Structure Processing', () async {
      print('=== Complex Data Structure Processing ===');
      
      final request = ComplexDataRequest();
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('Complex data request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('Complex data request failed: $e');
      }
    });

    test('Data Transformation and Validation', () async {
      print('=== Data Transformation and Validation ===');
      
      final request = DataTransformRequest();
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('Data transformation request successful: ${response.data}');
        expect(response.success, true);
        expect(response.data?['transformed'], true);
      } catch (e) {
        print('Data transformation request failed: $e');
      }
    });

    test('Unified queryParameters Usage', () async {
      print('=== Unified queryParameters Usage ===');
      
      final request = UnifiedQueryParametersRequest();
      final executor = NetworkExecutor.instance;
      
      try {
        final response = await NetworkExecutor.instance.execute(request);
        print('Unified parameters request successful: ${response.data}');
        expect(response.success, true);
      } catch (e) {
        print('Unified parameters request failed: $e');
      }
    });
  });
}

/// GET Request: queryParameters Priority Test
class GetRequestWithPriority extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  Map<String, dynamic>? get data => {
    'userId': 999, // This will be ignored in GET request
    'title': 'Data Title',
  };
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'userId': 1, // This will be used
    '_limit': 5,
    'source': 'queryParameters',
  };
  
  @override
  void onRequestStart() {
    print('GET request started - queryParameters priority');
    print('data: $data');
    print('queryParameters: $queryParameters');
  }
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    final list = data as List<dynamic>;
    return {
      'count': list.length,
      'items': list,
      'source': 'GET request uses queryParameters',
    };
  }
}

/// POST Request: data Priority Test
class PostRequestWithPriority extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts';
  
  @override
  HttpMethod get method => HttpMethod.post;
  
  @override
  Map<String, dynamic>? get data => {
    'title': 'Data Title', // This will be used
    'body': 'Data Body',
    'userId': 1,
    'source': 'data',
  };
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'title': 'Query Title', // This will be ignored
    'extra': 'queryParam',
  };
  
  @override
  void onRequestStart() {
    print('POST request started - data priority');
    print('data: $data');
    print('queryParameters: $queryParameters');
  }
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    final response = data as Map<String, dynamic>;
    response['processedBy'] = 'POST request uses data';
    return response;
  }
}

/// PUT Request: data Priority Test
class PutRequestWithPriority extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.put;
  
  @override
  Map<String, dynamic>? get data => {
    'id': 1,
    'title': 'Updated Data Title', // This will be used
    'body': 'Updated Data Body',
    'userId': 1,
    'source': 'data',
  };
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'title': 'Updated Query Title', // This will be ignored
    'version': '1.0',
  };
  
  @override
  void onRequestStart() {
    print('PUT request started - data priority');
    print('data: $data');
    print('queryParameters: $queryParameters');
  }
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    final response = data as Map<String, dynamic>;
    response['processedBy'] = 'PUT request uses data';
    return response;
  }
}

/// PATCH Request: data Priority Test
class PatchRequestWithPriority extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.patch;
  
  @override
  Map<String, dynamic>? get data => {
    'title': 'Patched Data Title', // This will be used
    'source': 'data',
  };
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'title': 'Patched Query Title', // This will be ignored
    'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
  };
  
  @override
  void onRequestStart() {
    print('PATCH request started - data priority');
    print('data: $data');
    print('queryParameters: $queryParameters');
  }
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    final response = data as Map<String, dynamic>;
    response['processedBy'] = 'PATCH request uses data';
    return response;
  }
}

/// DELETE Request: queryParameters Priority Test
class DeleteRequestWithPriority extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.delete;
  
  @override
  Map<String, dynamic>? get data => {
    'reason': 'Data Reason', // This will be ignored in DELETE request
    'source': 'data',
  };
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'reason': 'Query Reason', // This will be used
    'force': 'true',
    'source': 'queryParameters',
  };
  
  @override
  void onRequestStart() {
    print('DELETE request started - queryParameters priority');
    print('data: $data');
    print('queryParameters: $queryParameters');
  }
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return {
      'deleted': true,
      'processedBy': 'DELETE request uses queryParameters',
      'originalResponse': data,
    };
  }
}

/// File Upload: data and queryParameters Compatibility Test
class FileUploadWithMixedData extends UploadRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts';
  
  @override
  String get filePath => 'test.txt';
  
  @override
  Map<String, dynamic>? get data => {
    'title': 'File Upload Title',
    'description': 'File Upload Description',
    'category': 'image',
  };
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'upload_type': 'multipart',
    'compress': 'true',
  };
  
  @override
  Map<String, dynamic>? getFormData() {
    return {
      'file': 'Hello, World!'.codeUnits,
      'title': 'File Upload Title',
      'description': 'File Upload Description',
      'category': 'image',
    };
  }
  
  @override
  void onRequestStart() {
    print('File upload started - data and queryParameters compatibility');
    print('data: $data');
    print('queryParameters: $queryParameters');
    print('filePath: $filePath');
  }
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return {
      'uploaded': true,
      'processedBy': 'File upload compatible with data and queryParameters',
      'response': data,
    };
  }
}

/// Complex Data Structure Processing
class ComplexDataRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts';
  
  @override
  HttpMethod get method => HttpMethod.post;
  
  @override
  Map<String, dynamic>? get data => {
    'user': {
      'id': 1,
      'name': 'John Doe',
      'email': 'john@example.com',
      'profile': {
        'age': 30,
        'city': 'New York',
        'interests': ['coding', 'reading', 'travel'],
      },
    },
    'post': {
      'title': 'Complex Data Structure',
      'content': 'This is a complex data structure example',
      'tags': ['example', 'complex', 'data'],
      'metadata': {
        'created_at': DateTime.now().toIso8601String(),
        'version': '1.0',
        'settings': {
          'public': true,
          'comments_enabled': true,
          'notifications': {
            'email': true,
            'push': false,
          },
        },
      },
    },
    'attachments': [
      {
        'type': 'image',
        'url': 'https://example.com/image1.jpg',
        'size': 1024000,
      },
      {
        'type': 'document',
        'url': 'https://example.com/doc1.pdf',
        'size': 2048000,
      },
    ],
  };
  
  @override
  void onRequestStart() {
    print('Complex data structure request started');
    print('Data structure depth: ${_getDataDepth(data)}');
  }
  
  int _getDataDepth(dynamic obj, [int depth = 0]) {
    if (obj is Map) {
      int maxDepth = depth;
      for (final value in obj.values) {
        final childDepth = _getDataDepth(value, depth + 1);
        if (childDepth > maxDepth) maxDepth = childDepth;
      }
      return maxDepth;
    } else if (obj is List) {
      int maxDepth = depth;
      for (final item in obj) {
        final childDepth = _getDataDepth(item, depth + 1);
        if (childDepth > maxDepth) maxDepth = childDepth;
      }
      return maxDepth;
    }
    return depth;
  }
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return {
      'processed': true,
      'complexDataHandled': true,
      'response': data,
    };
  }
}

/// Data Transformation and Validation
class DataTransformRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts/1';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    final response = data as Map<String, dynamic>;
    
    // Data transformation
    final transformed = {
      'id': response['id'],
      'title': response['title']?.toString().toUpperCase(),
      'body': response['body']?.toString().trim(),
      'userId': response['userId'],
      'transformed': true,
      'transformedAt': DateTime.now().toIso8601String(),
      'originalLength': response['body']?.toString().length ?? 0,
      'wordCount': response['body']?.toString().split(' ').length ?? 0,
    };
    
    // Data validation
    _validateData(transformed);
    
    return transformed;
  }
  
  void _validateData(Map<String, dynamic> data) {
    if (data['id'] == null) {
      throw Exception('ID cannot be empty');
    }
    
    if (data['title'] == null || data['title'].toString().isEmpty) {
      throw Exception('Title cannot be empty');
    }
    
    if (data['originalLength'] == 0) {
      throw Exception('Content cannot be empty');
    }
    
    print('Data validation passed');
  }
}

/// Unified queryParameters Usage
class UnifiedQueryParametersRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  @override
  String get path => '/posts';
  
  @override
  HttpMethod get method => HttpMethod.get;
  
  @override
  Map<String, dynamic>? get queryParameters => {
    'userId': 1,
    '_limit': 3,
    '_sort': 'id',
    '_order': 'desc',
    'include_metadata': 'true',
    'format': 'json',
    'version': 'v1',
    'client': 'flutter_app',
    'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
  };
  
  @override
  void onRequestStart() {
    print('Unified queryParameters request started');
    print('Query parameters: $queryParameters');
  }
  
  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    final list = data as List<dynamic>;
    return {
      'unified': true,
      'queryParametersUsed': queryParameters,
      'resultCount': list.length,
      'results': list,
      'processedBy': 'Unified queryParameters processing',
    };
  }
}