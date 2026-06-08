enum ChatMessageType { text, voice, image }

class ChatMessageModel {
  const ChatMessageModel({
    this.id,
    this.conversationId,
    this.senderId,
    this.recipientId,
    required this.type,
    required this.time,
    required this.isMe,
    this.text,
    this.voiceDuration,
    this.imageUrls = const [],
    this.showSender = false,
    this.senderName,
    this.senderProfilePicUrl,
    this.sentAt,
    this.readAt,
    this.translatedText,
    this.translationLanguage,
  });

  final String? id;
  final String? conversationId;
  final String? senderId;
  final String? recipientId;
  final ChatMessageType type;
  final String time;
  final bool isMe;
  final String? text;
  final String? voiceDuration;
  final List<String> imageUrls;
  final bool showSender;
  final String? senderName;
  final String? senderProfilePicUrl;
  final String? sentAt;
  final String? readAt;
  final String? translatedText;
  final String? translationLanguage;

  bool get isRead => readAt != null && readAt!.trim().isNotEmpty;

  ChatMessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? recipientId,
    ChatMessageType? type,
    String? time,
    bool? isMe,
    String? text,
    String? voiceDuration,
    List<String>? imageUrls,
    bool? showSender,
    String? senderName,
    String? senderProfilePicUrl,
    String? sentAt,
    String? readAt,
    String? translatedText,
    String? translationLanguage,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      type: type ?? this.type,
      time: time ?? this.time,
      isMe: isMe ?? this.isMe,
      text: text ?? this.text,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      imageUrls: imageUrls ?? this.imageUrls,
      showSender: showSender ?? this.showSender,
      senderName: senderName ?? this.senderName,
      senderProfilePicUrl: senderProfilePicUrl ?? this.senderProfilePicUrl,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
      translatedText: translatedText ?? this.translatedText,
      translationLanguage: translationLanguage ?? this.translationLanguage,
    );
  }

  factory ChatMessageModel.fromMap(
    Map<String, dynamic> map, {
    required String currentUserId,
  }) {
    final sender = map['sender'] is Map
        ? Map<String, dynamic>.from(map['sender'] as Map)
        : <String, dynamic>{};
    final senderId = map['senderId']?.toString();
    final recipientId = map['recipientId']?.toString();
    final sentAt =
        map['sentAt']?.toString() ??
        map['createdAt']?.toString() ??
        map['created_at']?.toString();
    final readAt = map['readAt']?.toString() ?? map['read_at']?.toString();
    final type = _parseType(map['messageType'] ?? map['type']);
    final senderName =
        sender['name']?.toString() ?? map['senderName']?.toString();
    final senderProfilePicUrl =
        sender['profilePicUrl']?.toString() ??
        map['senderProfilePicUrl']?.toString();

    final content = map['content']?.toString();
    final imageUrls = _asStringList(map['imageUrls']);

    return ChatMessageModel(
      id: map['id']?.toString(),
      conversationId: map['conversationId']?.toString(),
      senderId: senderId,
      recipientId: recipientId,
      type: type,
      time: _formatTime(sentAt),
      isMe: senderId != null && senderId == currentUserId,
      text: type == ChatMessageType.image
          ? map['caption']?.toString()
          : content,
      voiceDuration: map['voiceDuration']?.toString(),
      imageUrls:
          type == ChatMessageType.image && imageUrls.isEmpty && content != null
          ? [content]
          : imageUrls,
      senderName: senderName,
      senderProfilePicUrl: senderProfilePicUrl,
      sentAt: sentAt,
      readAt: readAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'recipientId': recipientId,
      'type': type.name,
      'time': time,
      'isMe': isMe,
      'text': text,
      'voiceDuration': voiceDuration,
      'imageUrls': imageUrls,
      'showSender': showSender,
      'senderName': senderName,
      'senderProfilePicUrl': senderProfilePicUrl,
      'sentAt': sentAt,
      'readAt': readAt,
      'translatedText': translatedText,
      'translationLanguage': translationLanguage,
    };
  }

  static ChatMessageType _parseType(dynamic rawType) {
    final value = rawType?.toString().toLowerCase().trim() ?? 'text';
    switch (value) {
      case 'voice':
        return ChatMessageType.voice;
      case 'image':
        return ChatMessageType.image;
      default:
        return ChatMessageType.text;
    }
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  static String _formatTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Just now';
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }

    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = parsed.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
