import 'base_network_request.dart';
import '../model/user_model.dart';

/// 获取用户信息请求
class GetUserProfileRequest extends GetRequest<UserModel> {
  final String userId;
  
  GetUserProfileRequest({required this.userId});
  
  @override
  String get path => '/api/users/$userId';
  
  @override
  bool get enableCache => true;
  
  @override
  int get cacheDuration => 600; // 10分钟缓存
  
  @override
  UserModel parseResponse(dynamic data) {
    return UserModel.fromJson(data as Map<String, dynamic>);
  }
}

/// 更新用户信息请求
class UpdateUserProfileRequest extends PutRequest<UserModel> {
  final String userId;
  final Map<String, dynamic> userData;
  
  UpdateUserProfileRequest({
    required this.userId,
    required this.userData,
  });
  
  @override
  String get path => '/api/users/$userId';
  
  @override
  dynamic get data => userData;
  
  @override
  bool get enableCache => false; // 更新操作不缓存
  
  @override
  UserModel parseResponse(dynamic data) {
    return UserModel.fromJson(data as Map<String, dynamic>);
  }
}

/// 获取用户列表请求（分页）
class GetUsersListRequest extends PagedRequest<List<UserModel>> {
  final String? searchKeyword;
  final String? department;
  
  GetUsersListRequest({
    required super.page,
    super.pageSize = 20,
    this.searchKeyword,
    this.department,
  });
  
  @override
  String get path => '/api/users';
  
  @override
  Map<String, dynamic>? getExtraParams() {
    final params = <String, dynamic>{};
    if (searchKeyword != null) params['search'] = searchKeyword;
    if (department != null) params['department'] = department;
    return params.isNotEmpty ? params : null;
  }
  
  @override
  bool get enableCache => true;
  
  @override
  int get cacheDuration => 300; // 5分钟缓存
  
  @override
  List<UserModel> parseResponse(dynamic data) {
    final List<dynamic> users = data['users'] ?? data['data'] ?? [];
    return users.map((user) => UserModel.fromJson(user as Map<String, dynamic>)).toList();
  }
}

/// 用户登录请求
class UserLoginRequest extends PostRequest<LoginResponse> {
  final String email;
  final String password;
  
  UserLoginRequest({
    required this.email,
    required this.password,
  });
  
  @override
  String get path => '/api/auth/login';
  
  @override
  dynamic get data => {
    'email': email,
    'password': password,
  };
  
  @override
  bool get requiresAuth => false; // 登录请求不需要认证
  
  @override
  bool get enableCache => false; // 登录不缓存
  
  @override
  int get timeout => 10000; // 10秒超时
  
  @override
  LoginResponse parseResponse(dynamic data) {
    return LoginResponse.fromJson(data as Map<String, dynamic>);
  }
}

/// 用户头像上传请求
class UploadUserAvatarRequest extends UploadRequest<UploadResponse> {
  final String userId;
  final String avatarPath;
  
  UploadUserAvatarRequest({
    required this.userId,
    required this.avatarPath,
  });
  
  @override
  String get path => '/api/users/$userId/avatar';
  
  @override
  String get filePath => avatarPath;
  
  @override
  String get fileFieldName => 'avatar';
  
  @override
  Map<String, dynamic>? getFormData() => {
    'userId': userId,
  };
  
  @override
  int get timeout => 30000; // 30秒超时
  
  @override
  RequestPriority get priority => RequestPriority.high;
  
  @override
  UploadResponse parseResponse(dynamic data) {
    return UploadResponse.fromJson(data as Map<String, dynamic>);
  }
}

/// 删除用户请求
class DeleteUserRequest extends DeleteRequest<bool> {
  final String userId;
  
  DeleteUserRequest({required this.userId});
  
  @override
  String get path => '/api/users/$userId';
  
  @override
  RequestPriority get priority => RequestPriority.high;
  
  @override
  bool parseResponse(dynamic data) {
    return data['success'] == true || data == true;
  }
}

/// 批量获取用户信息请求
class BatchGetUsersRequest extends PostRequest<List<UserModel>> {
  final List<String> userIds;
  
  BatchGetUsersRequest({required this.userIds});
  
  @override
  String get path => '/api/users/batch';
  
  @override
  dynamic get data => {
    'userIds': userIds,
  };
  
  @override
  bool get enableCache => true;
  
  @override
  int get cacheDuration => 300;
  
  @override
  String? get cacheKey => 'batch_users_${userIds.join('_')}';
  
  @override
  List<UserModel> parseResponse(dynamic data) {
    final List<dynamic> users = data['users'] ?? data['data'] ?? [];
    return users.map((user) => UserModel.fromJson(user as Map<String, dynamic>)).toList();
  }
}

/// 登录响应模型
class LoginResponse {
  final String token;
  final UserModel user;
  final DateTime expiresAt;
  
  LoginResponse({
    required this.token,
    required this.user,
    required this.expiresAt,
  });
  
  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user': user.toJson(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}

/// 上传响应模型
class UploadResponse {
  final String url;
  final String fileName;
  final int fileSize;
  final String fileType;
  
  UploadResponse({
    required this.url,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
  });
  
  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      url: json['url'] as String,
      fileName: json['fileName'] as String,
      fileSize: json['fileSize'] as int,
      fileType: json['fileType'] as String,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileType': fileType,
    };
  }
}