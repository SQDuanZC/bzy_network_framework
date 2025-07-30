import 'package:bzy_network_framework/bzy_network_framework.dart';

/// 示例请求类 - 用于演示和测试

/// 简单的用户模型
class UserModel {
  final String id;
  final String name;
  final String email;
  
  UserModel({required this.id, required this.name, required this.email});
  
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
    );
  }
}

/// 获取用户信息请求
class GetUserProfileRequest extends BaseNetworkRequest<UserModel> {
  final String userId;

  GetUserProfileRequest({required this.userId});

  @override
  String get path => '/users/$userId';

  @override
  HttpMethod get method => HttpMethod.get;

  @override
  UserModel parseResponse(dynamic data) {
    return UserModel.fromJson(data);
  }
}

/// 更新用户信息请求
class UpdateUserProfileRequest extends BaseNetworkRequest<UserModel> {
  final String userId;
  final Map<String, dynamic> userData;

  UpdateUserProfileRequest({required this.userId, required this.userData});

  @override
  String get path => '/users/$userId';

  @override
  HttpMethod get method => HttpMethod.put;



  @override
  UserModel parseResponse(dynamic data) {
    return UserModel.fromJson(data);
  }
}

/// 获取用户列表请求
class GetUsersListRequest extends BaseNetworkRequest<List<UserModel>> {
  final int page;
  final int pageSize;

  GetUsersListRequest({required this.page, required this.pageSize});

  @override
  String get path => '/users';

  @override
  HttpMethod get method => HttpMethod.get;

  @override
  Map<String, dynamic>? get queryParameters => {
    'page': page,
    'pageSize': pageSize,
  };

  @override
  List<UserModel> parseResponse(dynamic data) {
    final List<dynamic> userList = data['users'] ?? [];
    return userList.map((json) => UserModel.fromJson(json)).toList();
  }
}

/// 上传用户头像请求
class UploadUserAvatarRequest extends BaseNetworkRequest<Map<String, dynamic>> {
  final String userId;
  final String filePath;

  UploadUserAvatarRequest({required this.userId, required this.filePath});

  @override
  String get path => '/users/$userId/avatar';

  @override
  HttpMethod get method => HttpMethod.post;

  @override
  Map<String, dynamic> parseResponse(dynamic data) {
    return data as Map<String, dynamic>;
  }
}

/// 下载文件响应模型
class DownloadResponse {
  final String filePath;
  final int fileSize;
  final bool success;

  DownloadResponse({
    required this.filePath,
    required this.fileSize,
    required this.success,
  });
}

/// 下载文件请求
class DownloadFileRequest extends DownloadRequest<DownloadResponse> {
  final String fileUrl;
  final String saveDirectory;

  DownloadFileRequest({
    required this.fileUrl,
    required this.saveDirectory,
  });

  @override
  String get path => fileUrl;

  @override
  String get savePath => saveDirectory;

  @override
  DownloadResponse parseResponse(dynamic data) {
    return DownloadResponse(
      filePath: data['filePath'] ?? '',
      fileSize: data['fileSize'] ?? 0,
      success: data['success'] ?? false,
    );
  }
}