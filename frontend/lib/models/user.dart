import 'dart:convert';

class User {
  final int id;
  final String email;
  final String name;
  final String role;
  final bool isActive;
  final String? avatarUrl;
  final String? fcmToken;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.isActive = true,
    this.avatarUrl,
    this.fcmToken,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int,
      email: map['email'] as String,
      name: map['name'] as String,
      role: map['role'] as String,
      isActive: map['is_active'] as bool? ?? true,
      avatarUrl: map['avatar_url'] as String?,
      fcmToken: map['fcm_token'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
    );
  }

  factory User.fromJson(String source) => User.fromMap(json.decode(source) as Map<String, dynamic>);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'is_active': isActive,
      'avatar_url': avatarUrl,
      'fcm_token': fcmToken,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  String toJson() => json.encode(toMap());

  User copyWith({
    int? id,
    String? email,
    String? name,
    String? role,
    bool? isActive,
    String? avatarUrl,
    String? fcmToken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, name: $name, role: $role)';
  }

  bool get isAdmin => role == 'admin';
  bool get isStaff => role == 'staff';
  bool get isPatient => role == 'patient';
}