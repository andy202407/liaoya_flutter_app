import 'user_model.dart';

class ConversationModel {
  final int id;
  final int type; // 1=私聊, 2=群聊, 3=公众号
  final int? friendId;
  final int? targetId;
  final String lastMessage;
  final DateTime? lastTime;
  final int unreadCount;
  final bool pinned;
  final bool muted;
  final UserModel? friend;
  final GroupInfo? group;

  ConversationModel({
    required this.id,
    required this.type,
    this.friendId,
    this.targetId,
    this.lastMessage = '',
    this.lastTime,
    this.unreadCount = 0,
    this.pinned = false,
    this.muted = false,
    this.friend,
    this.group,
  });

  bool get isGroup => type == 2;
  bool get isPrivate => type == 1;

  String get displayName {
    if (isGroup) return group?.name ?? '群聊';
    return friend?.nickname ?? friend?.username ?? '用户';
  }

  String? get displayAvatar {
    if (isGroup) return group?.avatar;
    return friend?.avatar;
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as int,
      type: json['type'] as int? ?? 1,
      friendId: json['friend_id'] as int?,
      targetId: json['target_id'] as int?,
      lastMessage: json['last_message'] as String? ?? '',
      lastTime: json['last_time'] != null ? DateTime.tryParse(json['last_time']) : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      pinned: json['pinned'] as bool? ?? false,
      muted: json['muted'] as bool? ?? false,
      friend: json['friend'] != null ? UserModel.fromJson(json['friend']) : null,
      group: json['group'] != null ? GroupInfo.fromJson(json['group']) : null,
    );
  }
}

class GroupInfo {
  final int id;
  final String name;
  final String? avatar;
  final String? description;
  final int? ownerId;

  GroupInfo({required this.id, required this.name, this.avatar, this.description, this.ownerId});

  factory GroupInfo.fromJson(Map<String, dynamic> json) {
    return GroupInfo(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String?,
      description: json['description'] as String?,
      ownerId: json['owner_id'] as int?,
    );
  }
}
