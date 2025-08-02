import 'base_network_request.dart';

/// Batch request class
class BatchRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final List<BaseNetworkRequest> requests;

  BatchRequest(this.requests);

  @override
  String get path => '/batch'; // Dummy path, won't be used directly

  @override
  HttpMethod get method => HttpMethod.post; // Dummy method

  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    // Return the combined data as-is for batch requests
    if (data is Map<String, dynamic>) {
      return data;
    }
    // If data is not a Map, wrap it in a results structure
    return {
      'results': data is List ? data : [data],
      'success': true,
    };
  }
}

/// Simple API request for testing
class SimpleApiRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final int id;

  SimpleApiRequest({required this.id});

  @override
  String get path => '/posts/$id';

  @override
  HttpMethod get method => HttpMethod.get;

  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}
