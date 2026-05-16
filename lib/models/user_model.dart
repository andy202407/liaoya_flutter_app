class UserModel {
  final int id;
  final String username;
  final String nickname;
  final String? avatar;
  final String? avatarFrame;
  final int role;
  final String? greeting;
  final DateTime? lastSeen;

  UserModel({
    required this.id,
    required this.username,
    required this.nickname,
    this.avatar,
    this.avatarFrame,
    this.role = 0,
    this.greeting,
    this.lastSeen,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatar: json['avatar'] as String?,
      avatarFrame: json['avatar_frame'] as String?,
      role: json['role'] as int? ?? 0,
      greeting: json['greeting_message'] as String?,
      lastSeen: json['last_seen'] != null ? DateTime.tryParse(json['last_seen']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'nickname': nickname,
    'avatar': avatar,
    'avatar_frame': avatarFrame,
    'role': role,
    'greeting_message': greeting,
    'last_seen': lastSeen?.toIso8601String(),
  };
}
