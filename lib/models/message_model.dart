class MessageModel {
  final int id;
  final int fromId;
  final int? toId;
  final int? groupId;
  final String content;
  final String type; // text, image, video, audio, file, system
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? images;
  final String? videos;
  final String? quotedMessage;
  final bool recalled;
  final bool read;
  final bool edited;
  final DateTime? createdAt;
  final Map<String, dynamic>? fromUser;

  MessageModel({
    required this.id,
    required this.fromId,
    this.toId,
    this.groupId,
    required this.content,
    this.type = 'text',
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.images,
    this.videos,
    this.quotedMessage,
    this.recalled = false,
    this.read = false,
    this.edited = false,
    this.createdAt,
    this.fromUser,
  });

  bool get isImage => type == 'image' || type == 'images';
  bool get isVideo => type == 'video' || type == 'videos';
  bool get isAudio => type == 'audio';
  bool get isFile => type == 'file';
  bool get isSystem => type == 'system';

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as int? ?? 0,
      fromId: json['from_id'] as int? ?? json['from'] as int? ?? 0,
      toId: json['to_id'] as int? ?? json['to'] as int?,
      groupId: json['group_id'] as int?,
      content: json['content'] as String? ?? '',
      type: json['type'] as String? ?? json['message_type'] as String? ?? 'text',
      fileUrl: json['file_url'] as String?,
      fileName: json['file_name'] as String?,
      fileSize: json['file_size'] as int?,
      images: json['images'] as String?,
      videos: json['videos'] as String?,
      quotedMessage: json['quoted_message'] as String?,
      recalled: json['recalled'] as bool? ?? false,
      read: json['read'] as bool? ?? false,
      edited: json['edited'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : (json['timestamp'] != null ? DateTime.tryParse(json['timestamp']) : null),
      fromUser: json['from_user'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'from_id': fromId,
    'to_id': toId,
    'group_id': groupId,
    'content': content,
    'type': type,
    'file_url': fileUrl,
    'file_name': fileName,
    'file_size': fileSize,
    'images': images,
    'videos': videos,
    'quoted_message': quotedMessage,
    'recalled': recalled,
    'read': read,
    'edited': edited,
    'created_at': createdAt?.toIso8601String(),
    'from_user': fromUser,
  };
}
