import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/model/chat_message_model.dart';
import 'package:frontend/model/message_item_model.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/repositry/chat_repositry.dart';

class RecentChatsNotifier extends AsyncNotifier<List<MessageItemModel>> {
  static const _avatarPalette = [
    Color(0xFFF3A4B1),
    Color(0xFFFFC94D),
    Color(0xFFF8F4ED),
    Color(0xFFE0D9D3),
    Color(0xFFD7E0F4),
    Color(0xFFDCE7F8),
  ];

  @override
  Future<List<MessageItemModel>> build() async {
    final currentUser = await ref.watch(authProvider.future);
    if (currentUser == null) {
      return const [];
    }

    final chatRepository = ref.read(chatRepositryProvider);
    final recentChats = await chatRepository.getRecentChats();

    return recentChats
        .map((summary) => _toMessageItem(summary, currentUser.id))
        .whereType<MessageItemModel>()
        .toList();
  }

  Future get() async {
    final currentUser = await ref.watch(authProvider.future);
    if (currentUser == null) {
      return const [];
    }

    final chatRepository = ref.read(chatRepositryProvider);
    final recentChats = await chatRepository.getRecentChats();

    var value = recentChats
        .map((summary) => _toMessageItem(summary, currentUser.id))
        .whereType<MessageItemModel>()
        .toList();

    state = AsyncValue.data(value);
  }

  MessageItemModel? _toMessageItem(
    Map<String, dynamic> summary,
    String currentUserId,
  ) {
    final peer = summary['peer'] is Map
        ? Map<String, dynamic>.from(summary['peer'] as Map)
        : <String, dynamic>{};
    final lastMessageMap = summary['lastMessage'] is Map
        ? Map<String, dynamic>.from(summary['lastMessage'] as Map)
        : <String, dynamic>{};

    if (peer.isEmpty || lastMessageMap.isEmpty) {
      return null;
    }

    final lastMessage = ChatMessageModel.fromMap(
      lastMessageMap,
      currentUserId: currentUserId,
    );
    final peerId = peer['id']?.toString() ?? '';
    final peerName = peer['name']?.toString() ?? 'Unknown';
    final isGroup =
        peer['isGroup'] == true ||
        peer['presence']?.toString().trim().toLowerCase() == 'group';
    final memberCount = peer['memberIds'] is List
        ? (peer['memberIds'] as List).length
        : int.tryParse(
                RegExp(r'\d+').stringMatch(peer['bio']?.toString() ?? '') ?? '',
              ) ??
              0;

    return MessageItemModel(
      name: peerName,
      message: _previewText(lastMessage),
      time: lastMessage.time,
      initials: _initials(peerName),
      avatarColor: _avatarColor(peerId.isEmpty ? peerName : peerId),
      statusColor: isGroup
          ? const Color(0xFF24786D)
          : _presenceStatusColor(peer['presence']),
      profilePicUrl: peer['profilePicUrl']?.toString(),
      userId: isGroup || peerId.isEmpty ? null : peerId,
      conversationId: summary['conversationId']?.toString(),
      unreadCount: int.tryParse(summary['unreadCount']?.toString() ?? '') ?? 0,
      isGroup: isGroup,
      memberCount: memberCount,
    );
  }

  String _previewText(ChatMessageModel message) {
    final text = message.text?.trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }

    switch (message.type) {
      case ChatMessageType.image:
        return 'Photo';
      case ChatMessageType.voice:
        return 'Voice message';
      case ChatMessageType.text:
        return 'Message';
    }
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();

    final initials = parts.map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? 'U' : initials;
  }

  Color _avatarColor(String seed) {
    return _avatarPalette[seed.hashCode.abs() % _avatarPalette.length];
  }

  Color _presenceStatusColor(dynamic rawPresence) {
    switch (rawPresence?.toString().trim().toLowerCase()) {
      case 'online':
        return const Color(0xFF1EDB76);
      case 'away':
        return const Color(0xFFFFC94D);
      default:
        return const Color(0xFFBEC4C3);
    }
  }
}

final recentChatsProvider =
    AsyncNotifierProvider<RecentChatsNotifier, List<MessageItemModel>>(
      RecentChatsNotifier.new,
    );
