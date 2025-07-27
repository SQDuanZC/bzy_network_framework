import 'package:flutter/material.dart';

/// 用户数据模型
class UserModel {
  final String id;
  final String email;
  final String name;
  final String? avatar;
  final String? phone;
  final String? department;
  final String? position;
  final UserStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;
  
  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatar,
    this.phone,
    this.department,
    this.position,
    this.status = UserStatus.active,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });
  
  /// 从JSON创建用户模型
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
      phone: json['phone'] as String?,
      department: json['department'] as String?,
      position: json['position'] as String?,
      status: UserStatus.values.firstWhere(
        (status) => status.name == (json['status'] as String? ?? 'active'),
        orElse: () => UserStatus.active,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar': avatar,
      'phone': phone,
      'department': department,
      'position': position,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }
  
  /// 复制并修改部分属性
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? avatar,
    String? phone,
    String? department,
    String? position,
    UserStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      phone: phone ?? this.phone,
      department: department ?? this.department,
      position: position ?? this.position,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// 获取显示名称
  String get displayName {
    return name.isNotEmpty ? name : email.split('@').first;
  }
  
  /// 获取头像URL或默认头像
  String get avatarUrl {
    return avatar ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName)}&background=random';
  }
  
  /// 是否为活跃用户
  bool get isActive => status == UserStatus.active;
  
  /// 是否为管理员
  bool get isAdmin => position?.toLowerCase().contains('admin') == true || 
                     position?.toLowerCase().contains('manager') == true;
  
  /// 获取完整信息
  String get fullInfo {
    final parts = <String>[name];
    if (position != null) parts.add(position!);
    if (department != null) parts.add(department!);
    return parts.join(' - ');
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'UserModel{'
        'id: $id, '
        'name: $name, '
        'email: $email, '
        'status: ${status.name}'
        '}';
  }
}

/// 用户状态枚举
enum UserStatus {
  active,
  inactive,
  suspended,
  pending,
  deleted,
}

/// 用户状态扩展
extension UserStatusExtension on UserStatus {
  /// 获取状态显示名称
  String get displayName {
    switch (this) {
      case UserStatus.active:
        return '活跃';
      case UserStatus.inactive:
        return '非活跃';
      case UserStatus.suspended:
        return '已暂停';
      case UserStatus.pending:
        return '待审核';
      case UserStatus.deleted:
        return '已删除';
    }
  }
  
  /// 获取状态颜色
  String get colorHex {
    switch (this) {
      case UserStatus.active:
        return '#4CAF50'; // 绿色
      case UserStatus.inactive:
        return '#9E9E9E'; // 灰色
      case UserStatus.suspended:
        return '#FF9800'; // 橙色
      case UserStatus.pending:
        return '#2196F3'; // 蓝色
      case UserStatus.deleted:
        return '#F44336'; // 红色
    }
  }
  
  /// 获取状态颜色（Color对象）
  Color get statusColor {
    switch (this) {
      case UserStatus.active:
        return Colors.green;
      case UserStatus.inactive:
        return Colors.grey;
      case UserStatus.suspended:
        return Colors.orange;
      case UserStatus.pending:
        return Colors.blue;
      case UserStatus.deleted:
        return Colors.red;
    }
  }
  
  /// 是否可以执行操作
  bool get canPerformActions {
    return this == UserStatus.active || this == UserStatus.pending;
  }
}

/// 用户列表响应模型
class UserListResponse {
  final List<UserModel> users;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;
  
  const UserListResponse({
    required this.users,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });
  
  factory UserListResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> usersJson = json['users'] ?? json['data'] ?? [];
    final users = usersJson
        .map((userJson) => UserModel.fromJson(userJson as Map<String, dynamic>))
        .toList();
    
    return UserListResponse(
      users: users,
      total: json['total'] as int? ?? users.length,
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? users.length,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'users': users.map((user) => user.toJson()).toList(),
      'total': total,
      'page': page,
      'pageSize': pageSize,
      'hasMore': hasMore,
    };
  }
}

/// 用户搜索过滤器
class UserSearchFilter {
  final String? keyword;
  final String? department;
  final UserStatus? status;
  final String? position;
  final DateTime? createdAfter;
  final DateTime? createdBefore;
  
  const UserSearchFilter({
    this.keyword,
    this.department,
    this.status,
    this.position,
    this.createdAfter,
    this.createdBefore,
  });
  
  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    
    if (keyword != null && keyword!.isNotEmpty) {
      params['search'] = keyword;
    }
    if (department != null) {
      params['department'] = department;
    }
    if (status != null) {
      params['status'] = status!.name;
    }
    if (position != null) {
      params['position'] = position;
    }
    if (createdAfter != null) {
      params['createdAfter'] = createdAfter!.toIso8601String();
    }
    if (createdBefore != null) {
      params['createdBefore'] = createdBefore!.toIso8601String();
    }
    
    return params;
  }
  
  bool get isEmpty {
    return keyword == null &&
           department == null &&
           status == null &&
           position == null &&
           createdAfter == null &&
           createdBefore == null;
  }
}