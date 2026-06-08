import 'dart:convert';

enum ChatMessageType { text, voice, image, video, poll }

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
    this.mediaUrl,
    this.showSender = false,
    this.senderName,
    this.senderProfilePicUrl,
    this.sentAt,
    this.readAt,
    this.expiresAt,
    this.translatedText,
    this.translationLanguage,
    this.pollQuestion,
    this.pollOptions = const [],
    this.pollVotes = const {},
    this.pollMyOptionIndex,
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
  final String? mediaUrl;
  final bool showSender;
  final String? senderName;
  final String? senderProfilePicUrl;
  final String? sentAt;
  final String? readAt;
  final String? expiresAt;
  final String? translatedText;
  final String? translationLanguage;
  final String? pollQuestion;
  final List<String> pollOptions;
  final Map<int, List<String>> pollVotes;
  final int? pollMyOptionIndex;

  int get pollTotalVotes {
    final voters = <String>{};
    for (final optionVotes in pollVotes.values) {
      voters.addAll(optionVotes);
    }
    return voters.length;
  }

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
    String? mediaUrl,
    bool? showSender,
    String? senderName,
    String? senderProfilePicUrl,
    String? sentAt,
    String? readAt,
    String? expiresAt,
    String? translatedText,
    String? translationLanguage,
    String? pollQuestion,
    List<String>? pollOptions,
    Map<int, List<String>>? pollVotes,
    int? pollMyOptionIndex,
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
      mediaUrl: mediaUrl ?? this.mediaUrl,
      showSender: showSender ?? this.showSender,
      senderName: senderName ?? this.senderName,
      senderProfilePicUrl: senderProfilePicUrl ?? this.senderProfilePicUrl,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
      expiresAt: expiresAt ?? this.expiresAt,
      translatedText: translatedText ?? this.translatedText,
      translationLanguage: translationLanguage ?? this.translationLanguage,
      pollQuestion: pollQuestion ?? this.pollQuestion,
      pollOptions: pollOptions ?? this.pollOptions,
      pollVotes: pollVotes ?? this.pollVotes,
      pollMyOptionIndex: pollMyOptionIndex ?? this.pollMyOptionIndex,
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
    final expiresAt =
        map['expiresAt']?.toString() ?? map['expires_at']?.toString();
    final type = _parseType(map['messageType'] ?? map['type']);
    final senderName =
        sender['name']?.toString() ?? map['senderName']?.toString();
    final senderProfilePicUrl =
        sender['profilePicUrl']?.toString() ??
        map['senderProfilePicUrl']?.toString();

    final content =
        map['content']?.toString() ??
        map['text']?.toString() ??
        map['mediaUrl']?.toString();
    final imageUrls = _asStringList(map['imageUrls']);
    final poll = type == ChatMessageType.poll
        ? _pollContent(content, currentUserId)
        : const _ParsedPoll();

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
          : type == ChatMessageType.poll
          ? poll.question
          : content,
      voiceDuration: map['voiceDuration']?.toString(),
      imageUrls:
          type == ChatMessageType.image && imageUrls.isEmpty && content != null
          ? [content]
          : imageUrls,
      mediaUrl: type == ChatMessageType.video || type == ChatMessageType.voice
          ? content
          : null,
      senderName: senderName,
      senderProfilePicUrl: senderProfilePicUrl,
      sentAt: sentAt,
      readAt: readAt,
      expiresAt: expiresAt,
      translatedText: map['translatedText']?.toString(),
      translationLanguage: map['translationLanguage']?.toString(),
      pollQuestion: poll.question,
      pollOptions: poll.options,
      pollVotes: poll.votes,
      pollMyOptionIndex: poll.myOptionIndex,
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
      'mediaUrl': mediaUrl,
      'showSender': showSender,
      'senderName': senderName,
      'senderProfilePicUrl': senderProfilePicUrl,
      'sentAt': sentAt,
      'readAt': readAt,
      'expiresAt': expiresAt,
      'translatedText': translatedText,
      'translationLanguage': translationLanguage,
      'pollQuestion': pollQuestion,
      'pollOptions': pollOptions,
      'pollVotes': pollVotes,
      'pollMyOptionIndex': pollMyOptionIndex,
    };
  }

  static ChatMessageType _parseType(dynamic rawType) {
    final value = rawType?.toString().toLowerCase().trim() ?? 'text';
    switch (value) {
      case 'voice':
        return ChatMessageType.voice;
      case 'image':
        return ChatMessageType.image;
      case 'video':
        return ChatMessageType.video;
      case 'poll':
        return ChatMessageType.poll;
      default:
        return ChatMessageType.text;
    }
  }

  static _ParsedPoll _pollContent(String? content, String currentUserId) {
    if (content == null || content.trim().isEmpty) {
      return const _ParsedPoll();
    }

    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map) {
        return const _ParsedPoll();
      }

      final map = Map<String, dynamic>.from(decoded);
      final options = map['options'] is List
          ? (map['options'] as List)
                .map((option) => option.toString())
                .where((option) => option.trim().isNotEmpty)
                .toList()
          : const <String>[];
      final rawVotes = map['votes'] is Map
          ? Map<String, dynamic>.from(map['votes'] as Map)
          : <String, dynamic>{};
      final votes = <int, List<String>>{};
      int? myOptionIndex;

      for (final entry in rawVotes.entries) {
        final index = int.tryParse(entry.key.toString());
        if (index == null) {
          continue;
        }

        final voters = entry.value is List
            ? (entry.value as List).map((item) => item.toString()).toList()
            : <String>[];
        votes[index] = voters;
        if (voters.contains(currentUserId)) {
          myOptionIndex = index;
        }
      }

      return _ParsedPoll(
        question: map['question']?.toString(),
        options: options,
        votes: votes,
        myOptionIndex: myOptionIndex,
      );
    } catch (_) {
      return const _ParsedPoll();
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

class _ParsedPoll {
  const _ParsedPoll({
    this.question,
    this.options = const [],
    this.votes = const {},
    this.myOptionIndex,
  });

  final String? question;
  final List<String> options;
  final Map<int, List<String>> votes;
  final int? myOptionIndex;
}
