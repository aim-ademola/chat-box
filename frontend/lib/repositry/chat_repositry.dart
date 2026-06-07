import 'dart:io';

import 'package:flint_client/flint_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/model/chat_message_model.dart';
import 'package:frontend/provider/core_provider.dart';
import 'package:frontend/repositry/auth_repositry.dart';

class ChatRepositry {
  ChatRepositry({required this.client, required this.authRepository});

  final FlintClient client;
  final AuthRepositry authRepository;

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

    return rawMessages
        .map(
          (item) => ChatMessageModel.fromMap(
            Map<String, dynamic>.from(item as Map),
            currentUserId: currentUserId,
          ),
        )
        .toList();
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

    return ChatMessageModel.fromMap(
      Map<String, dynamic>.from(data),
      currentUserId: currentUserId,
    );
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
  return ChatRepositry(client: client, authRepository: authRepository);
});
