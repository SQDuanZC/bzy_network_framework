class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final dynamic originalError;
  final int retryCount;

  NetworkException({
    required this.message,
    this.statusCode,
    this.errorCode,
    this.originalError,
    this.retryCount = 0,
  });

  @override
  String toString() {
    return 'NetworkException: $message (statusCode: $statusCode, errorCode: $errorCode, retryCount: $retryCount)';
  }
}