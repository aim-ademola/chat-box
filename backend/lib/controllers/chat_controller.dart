import 'package:backend/helper/auth_helper.dart';
import 'package:backend/models/conversation.dart';
import 'package:backend/models/chat_message.dart';
import 'package:backend/models/user_model.dart';
import 'package:flint_dart/flint_dart.dart';

const String _userSocketPath = '/chat/connect';
const String _presenceRoom = 'presence';
final Map<String, int> _presenceConnections = {};
final Map<String, String> _presenceStates = {};

class ChatController {
  Future<Response?> history(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({
        'status': false,
        'message': 'Unauthorized',
      });
    }

    final roomId = ctx.req.param('roomId');
    if (roomId == null || roomId.trim().isEmpty) {
      return res.status(400).json({
        'status': false,
        'message': 'Room id is required',
      });
    }

    final messages = await ChatMessage()
        .where('conversationId', roomId)
        .withRelation('sender')
        .orderBy('sentAt', asc: true)
        .limit(100)
        .get();

    await _markConversationRead(
      conversationId: roomId,
      readerId: user.id,
    );

    return res.json({
      'status': true,
      'data': messages.map((message) => message.toMap()).toList(),
    });
  }

  Future<Response?> recent(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({
        'status': false,
        'message': 'Unauthorized',
      });
    }

    final summaries = <_RecentChatSummary>[];

    final userCon = await Conversation().where("userId", user.id).get();
    final friendCon = await Conversation().where("friendId", user.id).get();
    final conversations = [...userCon, ...friendCon];
    print(conversations);
    for (var conversation in conversations) {
      print(conversation);
      final peerId = conversation.userId == user.id
          ? conversation.friendId
          : conversation.userId;

      final peer = await User().find(peerId);
      final lastMessageId = conversation.lastMessageId.trim();
      final latestMessage = lastMessageId.isEmpty
          ? null
          : await ChatMessage().find(lastMessageId);

      if (latestMessage == null) {
        continue;
      }

      summaries.add(
        _RecentChatSummary(
          conversationId: conversation.id,
          peer: {
            'id': peer?.id.toString(),
            'name': peer?.name,
            'bio': peer?.bio,
            'profilePicUrl': peer?.profilePicUrl,
            'presence': _presenceFor(peer?.id.toString()),
          },
          lastMessage: {
            'id': latestMessage.id?.toString(),
            'conversationId': latestMessage.conversationId,
            'senderId': latestMessage.senderId,
            'recipientId': latestMessage.recipientId,
            'content': latestMessage.content,
            'messageType': latestMessage.messageType,
            'sentAt': latestMessage.sentAt,
            'readAt': latestMessage.readAt,
          },
          unreadCount: await _unreadCount(
            conversationId: conversation.id,
            userId: user.id,
          ),
          sentAt: _sentAtValue(latestMessage),
        ),
      );
    }

    summaries.sort((a, b) => b.sentAt.compareTo(a.sentAt));

    return res.json({
      'status': true,
      'data': summaries.map((summary) => summary.toMap()).toList(),
    });
  }

  Future handShack(Context ctx) async {
    final socket = ctx.socket;
    if (socket == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      socket.emit('chat:error', {
        'message': 'Unauthorized',
      });
      return null;
    }

    final userRoom = _userRoom(user.id);
    socket.join(userRoom);
    socket.join(_presenceRoom);
    _markUserOnline(user.id);
    socket.emit('chat:notifications:ready', {
      'userId': user.id,
      'room': userRoom,
      'presence': _presenceStates,
    });
    _emitPresence(user.id, 'online');

    socket.on('presence:set', (dynamic payload) {
      final data = _asMap(payload);
      final status = _normalizePresence(data['status']);
      _presenceStates[user.id] = status;
      _emitPresence(user.id, status);
    });

    socket.onClose(() {
      socket.leave(userRoom);
      socket.leave(_presenceRoom);
      final status = _markUserDisconnected(user.id);
      if (status == 'offline') {
        _emitPresence(user.id, status);
      }
    });
  }

  Future<Object?> connect(Context ctx) async {
    final socket = ctx.socket;
    if (socket == null) return null;

    final roomId = ctx.req.param('roomId');
    final user = await ctx.req.authUser;

    if (roomId == null || roomId.trim().isEmpty || user == null) {
      socket.emit('chat:error', {
        'message': 'Unauthorized',
      });
      return null;
    }

    final conversationId = roomId.trim();
    socket.join(conversationId);
    socket.emit('chat:ready', {
      'roomId': conversationId,
      'userId': user.id.toString(),
    });

    final readPayload = await _markConversationRead(
      conversationId: conversationId,
      readerId: user.id,
    );
    if (readPayload != null) {
      socket.emitToRoom(
        conversationId,
        'chat:read',
        readPayload,
        includeSelf: true,
      );
    }

    socket.on('ping', (_) {
      socket.emit('pong', {
        'roomId': conversationId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    socket.on('chat:send', (dynamic payload) async {
      final data = _asMap(payload);
      final content = (data['content'] ?? data['text'] ?? '').toString().trim();
      Conversation? conversation;

      final cleanedCurrentUserId = user.id.trim();
      final cleanedPeerId = data['recipientId']?.toString().trim();
      final normalizedConversationId = _conversationIdFor(
        cleanedCurrentUserId,
        cleanedPeerId,
      );

      if (cleanedCurrentUserId.isNotEmpty &&
          cleanedPeerId != null &&
          cleanedPeerId.isNotEmpty) {
        conversation = await Conversation().upsert(uniqueBy: [
          "id"
        ], data: {
          "id": normalizedConversationId,
          "userId": cleanedCurrentUserId,
          "friendId": cleanedPeerId,
          "lastSenderId": cleanedCurrentUserId
        }, excludeUpdatedData: [
          'userId',
          "friendId"
        ]);
      }

      if (content.isEmpty) {
        socket.emit('chat:error', {
          'message': 'Message cannot be empty',
        });
        return;
      }

      final messageType =
          (data['messageType'] ?? data['type'] ?? 'text').toString().trim();
      final recipientId = data['recipientId']?.toString();
      final sentAt = DateTime.now().toIso8601String();

      final created = await ChatMessage().create({
        'conversationId':
            conversation?.id ?? normalizedConversationId ?? conversationId,
        'senderId': user.id.toString(),
        'recipientId': recipientId,
        'content': content,
        'messageType': messageType.isEmpty ? 'text' : messageType,
        'sentAt': sentAt,
        'readAt': '',
      });

      if (created == null) {
        socket.emit('chat:error', {
          'message': 'Message could not be saved',
        });
        return;
      }

      if (recipientId != null && recipientId.trim().isNotEmpty) {
        conversation?.update(data: {"lastMessageId": created.id});
      }

      final stored =
          await ChatMessage().withRelation('sender').find(created.id);

      if (stored == null) {
        return;
      }

      var storedMap = stored.toMap();
      storedMap.remove("created_at");
      storedMap.remove("updated_at");

      socket.emitToRoom(
        conversationId,
        'chat:message',
        storedMap,
        includeSelf: true,
      );

      final conversationKey =
          (conversation?.id ?? normalizedConversationId ?? conversationId)
              .trim();
      final senderNotificationPayload = {
        'conversationId': conversationKey,
        'message': storedMap,
        'unreadCount': 0,
      };

      _emitToUser(
        cleanedCurrentUserId,
        'messageReceived',
        senderNotificationPayload,
      );

      if (recipientId != null && recipientId.trim().isNotEmpty) {
        final cleanedRecipientId = recipientId.trim();
        final recipientNotificationPayload = {
          'conversationId': conversationKey,
          'message': storedMap,
          'unreadCount': await _unreadCount(
            conversationId: conversationKey,
            userId: cleanedRecipientId,
          ),
        };

        _emitToUser(
          cleanedRecipientId,
          'messageReceived',
          recipientNotificationPayload,
        );
      }
    });

    socket.onClose(() {
      socket.leave(conversationId);
    });

    return null;
  }

  Map<String, dynamic> _asMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }

    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }

    return <String, dynamic>{};
  }

  String _userRoom(String userId) => 'user:$userId';

  void _markUserOnline(String userId) {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return;

    _presenceConnections[cleanedUserId] =
        (_presenceConnections[cleanedUserId] ?? 0) + 1;
    _presenceStates[cleanedUserId] = 'online';
  }

  String _markUserDisconnected(String userId) {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return 'offline';

    final nextCount = (_presenceConnections[cleanedUserId] ?? 1) - 1;
    if (nextCount > 0) {
      _presenceConnections[cleanedUserId] = nextCount;
      return _presenceStates[cleanedUserId] ?? 'online';
    }

    _presenceConnections.remove(cleanedUserId);
    _presenceStates[cleanedUserId] = 'offline';
    return 'offline';
  }

  String _presenceFor(String? userId) {
    final cleanedUserId = userId?.trim();
    if (cleanedUserId == null || cleanedUserId.isEmpty) {
      return 'offline';
    }

    return _presenceStates[cleanedUserId] ?? 'offline';
  }

  String _normalizePresence(dynamic rawStatus) {
    final status = rawStatus?.toString().trim().toLowerCase();
    if (status == 'online' || status == 'away') {
      return status!;
    }

    return 'offline';
  }

  void _emitPresence(String userId, String status) {
    WebSocketManager().emitToPathRoom(
      _userSocketPath,
      _presenceRoom,
      'presence:update',
      {
        'userId': userId,
        'status': status,
      },
    );
  }

  void _emitToUser(String userId, String event, Map<String, dynamic> data) {
    WebSocketManager().emitToPathRoom(
      _userSocketPath,
      _userRoom(userId),
      event,
      data,
    );
  }

  Future<int> _unreadCount({
    required String conversationId,
    required String userId,
  }) async {
    final messages = await ChatMessage()
        .where('conversationId', conversationId)
        .where('recipientId', userId)
        .get();

    return messages.where((message) {
      final readAt = message.readAt?.trim() ?? '';
      return readAt.isEmpty;
    }).length;
  }

  Future<Map<String, dynamic>?> _markConversationRead({
    required String conversationId,
    required String readerId,
  }) async {
    final messages = await ChatMessage()
        .where('conversationId', conversationId)
        .where('recipientId', readerId)
        .get();

    final readAt = DateTime.now().toIso8601String();
    final readMessageIds = <String>[];
    final senderIds = <String>{};

    for (final message in messages) {
      final currentReadAt = message.readAt?.trim() ?? '';
      if (currentReadAt.isNotEmpty) {
        continue;
      }

      await message.update(data: {'readAt': readAt});

      final messageId = message.id?.toString();
      if (messageId != null && messageId.isNotEmpty) {
        readMessageIds.add(messageId);
      }

      final senderId = message.senderId?.trim();
      if (senderId != null && senderId.isNotEmpty) {
        senderIds.add(senderId);
      }
    }

    if (readMessageIds.isEmpty) {
      return null;
    }

    final payload = {
      'conversationId': conversationId,
      'readerId': readerId,
      'readAt': readAt,
      'messageIds': readMessageIds,
    };

    _emitToUser(readerId, 'chat:read', payload);

    for (final senderId in senderIds) {
      _emitToUser(senderId, 'chat:read', payload);
    }

    return payload;
  }

  String? _conversationIdFor(String userId, String? friendId) {
    final cleanedUserId = userId.trim();
    final cleanedFriendId = friendId?.trim();

    if (cleanedUserId.isEmpty ||
        cleanedFriendId == null ||
        cleanedFriendId.isEmpty) {
      return null;
    }

    final ids = [cleanedUserId, cleanedFriendId]..sort();
    return ids.join('__');
  }

  DateTime _sentAtValue(ChatMessage message) {
    final rawSentAt = message.sentAt?.trim();
    if (rawSentAt != null && rawSentAt.isNotEmpty) {
      final parsed = DateTime.tryParse(rawSentAt);
      if (parsed != null) {
        return parsed;
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _RecentChatSummary {
  _RecentChatSummary({
    required this.conversationId,
    required this.peer,
    required this.lastMessage,
    required this.unreadCount,
    required this.sentAt,
  });

  final String conversationId;
  final Map<String, dynamic> peer;
  final Map<String, dynamic> lastMessage;
  final int unreadCount;
  final DateTime sentAt;

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'peer': peer,
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
      'sentAt': sentAt.toIso8601String(),
    };
  }
}
