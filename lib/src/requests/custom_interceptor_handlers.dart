import 'package:dio/dio.dart';

class CustomRequestInterceptorHandler extends RequestInterceptorHandler {
  final Function(RequestOptions) onNextCallback;
  final Function(DioException) onErrorCallback;

  CustomRequestInterceptorHandler({
    required this.onNextCallback,
    required this.onErrorCallback,
  });

  @override
  void next(RequestOptions requestOptions) {
    onNextCallback(requestOptions);
  }

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptors = true]) {
    onErrorCallback(error);
  }
}

class CustomResponseInterceptorHandler extends ResponseInterceptorHandler {
  final Function(Response) onNextCallback;
  final Function(DioException) onErrorCallback;

  CustomResponseInterceptorHandler({
    required this.onNextCallback,
    required this.onErrorCallback,
  });

  @override
  void next(Response response) {
    onNextCallback(response);
  }

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptors = true]) {
    onErrorCallback(error);
  }
}

class CustomErrorInterceptorHandler extends ErrorInterceptorHandler {
  final Function(DioException) onNextCallback;
  final Function(DioException) onErrorCallback;

  CustomErrorInterceptorHandler({
    required this.onNextCallback,
    required this.onErrorCallback,
  });

  @override
  void next(DioException err) {
    onNextCallback(err);
  }

  @override
  void reject(DioException error) {
    onErrorCallback(error);
  }
}