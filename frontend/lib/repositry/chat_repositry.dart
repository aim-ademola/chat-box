import 'dart:convert';
import 'dart:io';

import 'package:flint_client/flint_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/model/chat_message_model.dart';
import 'package:frontend/provider/core_provider.dart';
import 'package:frontend/repositry/auth_repositry.dart';
import 'package:frontend/services/local_database_service.dart';

class ChatRepositry {
  ChatRepositry({
    required this.client,
    required this.authRepository,
    required this.localDatabase,
  });

  final FlintClient client;
  final AuthRepositry authRepository;
  final LocalDatabaseService localDatabase;

  String buildConversationId({
    required String currentUserId,
    String? peerId,
    required String fallbackKey,
  }) {
    final cleanedCurrentUserId = currentUserId.trim();
    final cleanedPeerId = peerId?.trim();

    if (cleanedCurrentUserId.isNotEmpty &&
        cleanedPeerId != null &&
        cleanedPeerId.isNotEmpty) {
      final ids = [cleanedCurrentUserId, cleanedPeerId]..sort();
      return ids.join('__');
    }

    final slug = fallbackKey
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return 'demo_${slug.isEmpty ? 'chat' : slug}';
  }

  Future<List<ChatMessageModel>> getHistory({
    required String roomId,
    required String currentUserId,
  }) async {
    try {
      final headers = await authRepository.authHeaders();
      final res = await client.get(
        '/chat/rooms/$roomId/messages',
        headers: headers,
      );
      res.throwIfError();

      final responseData = res.data;
      final rawMessages = responseData is Map
          ? responseData['data'] as List<dynamic>? ?? const []
          : const [];
      final messages = rawMessages
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      await localDatabase.saveChatMessages(roomId, messages);

      return messages
          .map(
            (item) =>
                ChatMessageModel.fromMap(item, currentUserId: currentUserId),
          )
          .toList();
    } catch (_) {
      final cachedMessages = await localDatabase.getChatMessages(roomId);
      return cachedMessages
          .map(
            (item) =>
                ChatMessageModel.fromMap(item, currentUserId: currentUserId),
          )
          .toList();
    }
  }

  Future<List<Map<String, dynamic>>> getRecentChats() async {
    final headers = await authRepository.authHeaders();

    final res = await client.get(
      '/chat/recent',
      headers: headers,
      cacheConfig: CacheConfig(maxAge: Duration.zero),
    );
    res.throwIfError();

    final responseData = res.data;

    final rawChats = responseData is Map
        ? responseData['data'] as List<dynamic>? ?? const []
        : const [];

    return rawChats
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createGroup({
    required String title,
    required List<String> memberIds,
  }) async {
    final headers = await authRepository.authHeaders();
    final res = await client.post(
      '/chat/groups',
      headers: headers,
      body: {'title': title, 'memberIds': memberIds},
    );
    res.throwIfError();

    final responseData = res.data;
    final data = responseData is Map ? responseData['data'] : null;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getGroupDetails(String groupId) async {
    final headers = await authRepository.authHeaders();
    final res = await client.get(
      '/chat/groups/$groupId',
      headers: headers,
      cacheConfig: CacheConfig(maxAge: Duration.zero),
    );
    res.throwIfError();

    final responseData = res.data;
    final data = responseData is Map ? responseData['data'] : null;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateGroup({
    required String groupId,
    String? title,
    File? profilePic,
  }) async {
    final headers = await authRepository.authHeaders();
    final res = await client.post(
      '/chat/groups/$groupId',
      headers: headers,
      files: profilePic == null ? null : {'profile_pic': profilePic},
      body: {'title': ?title},
    );
    res.throwIfError();

    final responseData = res.data;
    final data = responseData is Map ? responseData['data'] : null;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> addGroupMembers({
    required String groupId,
    required List<String> memberIds,
  }) async {
    final headers = await authRepository.authHeaders();
    final res = await client.post(
      '/chat/groups/$groupId/members',
      headers: headers,
      body: {'memberIds': memberIds},
    );
    res.throwIfError();

    final responseData = res.data;
    final data = responseData is Map ? responseData['data'] : null;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> removeGroupMember({
    required String groupId,
    required String memberId,
  }) async {
    final headers = await authRepository.authHeaders();
    final res = await client.post(
      '/chat/groups/$groupId/members/$memberId/remove',
      headers: headers,
    );
    res.throwIfError();

    final responseData = res.data;
    final data = responseData is Map ? responseData['data'] : null;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Future<ChatMessageModel> sendMedia({
    required String roomId,
    required String currentUserId,
    required File file,
    String? recipientId,
    String caption = '',
    String messageType = 'image',
  }) async {
    final headers = await authRepository.authHeaders();
    final body = {'messageType': messageType, 'caption': caption};
    if (recipientId != null) {
      body['recipientId'] = recipientId;
    }

    final res = await client.post(
      '/chat/rooms/$roomId/media',
      headers: headers,
      files: {'file': file},
      body: body,
    );
    res.throwIfError();

    final responseData = res.data;
    final data = responseData is Map ? responseData['data'] : null;
    if (data is! Map) {
      throw const FormatException('Invalid media message response');
    }

    final message = ChatMessageModel.fromMap(
      Map<String, dynamic>.from(data),
      currentUserId: currentUserId,
    );
    await cacheMessage(roomId: roomId, message: message);
    return message;
  }

  Future<ChatMessageModel> votePoll({
    required String roomId,
    required String messageId,
    required int optionIndex,
    required String currentUserId,
  }) async {
    final headers = await authRepository.authHeaders();
    final res = await client.post(
      '/chat/rooms/$roomId/polls/$messageId/vote',
      headers: headers,
      body: {'optionIndex': optionIndex},
    );
    res.throwIfError();

    final responseData = res.data;
    final data = responseData is Map ? responseData['data'] : null;
    if (data is! Map) {
      throw const FormatException('Invalid poll vote response');
    }

    final message = ChatMessageModel.fromMap(
      Map<String, dynamic>.from(data),
      currentUserId: currentUserId,
    );
    await cacheMessage(roomId: roomId, message: message);
    return message;
  }

  Future<void> cacheMessage({
    required String roomId,
    required ChatMessageModel message,
  }) async {
    await localDatabase.saveChatMessage(
      roomId,
      _cachePayloadFromMessage(message),
    );
  }

  Future<void> markCachedMessagesRead({
    required String roomId,
    required Set<String> messageIds,
    required String readAt,
  }) async {
    await localDatabase.markChatMessagesRead(roomId, messageIds, readAt);
  }

  Future<FlintWebSocketClient> createSocket(String roomId) async {
    final headers = await authRepository.authHeaders();
    return client.ws('/chat/rooms/$roomId', headers: headers);
  }

  Future<FlintWebSocketClient> handShackSocket() async {
    final headers = await authRepository.authHeaders();
    return client.ws('/chat/connect', headers: headers);
  }
}

final chatRepositryProvider = Provider<ChatRepositry>((ref) {
  final client = ref.read(flintCLient);
  final authRepository = ref.read(authRepositryProvider);
  final localDatabase = ref.read(localDatabaseProvider);
  return ChatRepositry(
    client: client,
    authRepository: authRepository,
    localDatabase: localDatabase,
  );
});

Map<String, dynamic> _cachePayloadFromMessage(ChatMessageModel message) {
  final map = message.toMap();
  map['messageType'] = message.type.name;
  map['pollVotes'] = message.pollVotes.map(
    (key, value) => MapEntry(key.toString(), value),
  );

  switch (message.type) {
    case ChatMessageType.image:
      map['content'] = message.imageUrls.isNotEmpty
          ? message.imageUrls.first
          : message.mediaUrl;
      map['caption'] = message.text;
      break;
    case ChatMessageType.video:
    case ChatMessageType.voice:
      map['content'] = message.mediaUrl ?? message.text;
      break;
    case ChatMessageType.poll:
      map['content'] = jsonEncode({
        'question': message.pollQuestion ?? message.text ?? '',
        'options': message.pollOptions,
        'votes': message.pollVotes.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      });
      break;
    case ChatMessageType.text:
      map['content'] = message.text;
      break;
  }

  return map;
}
