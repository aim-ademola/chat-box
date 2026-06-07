import 'package:backend/helper/auth_helper.dart';
import 'package:backend/models/conversation.dart';
import 'package:backend/models/chat_message.dart';
import 'package:backend/models/user_model.dart';
import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/storage.dart';

const String _userSocketPath = '/chat/connect';
const String _presenceRoom = 'presence';
final Map<String, int> _presenceConnections = {};
final Map<String, String> _presenceStates = {};

class ChatController {
  Future<Response?> createGroup(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({
        'status': false,
        'message': 'Unauthorized',
      });
    }

    final body = await ctx.req.json();
    final title = (body['title'] ?? '').toString().trim();
    final rawMemberIds = body['memberIds'];
    final memberIds = <String>{
      user.id.trim(),
      if (rawMemberIds is List)
        ...rawMemberIds
            .map((memberId) => memberId.toString().trim())
            .where((memberId) => memberId.isNotEmpty),
    }.toList()
      ..sort();

    if (title.isEmpty) {
      return res.status(400).json({
        'status': false,
        'message': 'Group name is required',
      });
    }

    if (memberIds.length < 3) {
      return res.status(400).json({
        'status': false,
        'message': 'Choose at least two people for a group',
      });
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final groupId = 'group_${user.id}_$now';
    final conversation = await Conversation().create({
      'id': groupId,
      'userId': user.id,
      'friendId': '',
      'type': 'group',
      'title': title,
      'memberIds': memberIds.join(','),
      'createdBy': user.id,
      'lastSenderId': user.id,
    });

    if (conversation == null) {
      return res.status(500).json({
        'status': false,
        'message': 'Group could not be created',
      });
    }

    return res.json({
      'status': true,
      'data': _groupConversationMap(conversation, currentUserId: user.id),
    });
  }

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

    if (!await _canAccessConversation(roomId.trim(), user.id)) {
      return res.status(403).json({
        'status': false,
        'message': 'You are not a member of this chat',
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
    final allConversations = await Conversation().get();
    final conversations = [
      ...userCon,
      ...friendCon,
      ...allConversations.where(
        (conversation) =>
            _isGroupConversation(conversation) &&
            _conversationMembers(conversation).contains(user.id),
      ),
    ];
    final seenConversationIds = <String>{};
    print(conversations);
    for (var conversation in conversations) {
      if (!seenConversationIds.add(conversation.id)) {
        continue;
      }
      print(conversation);
      if (_isGroupConversation(conversation)) {
        final latestMessage = await _lastMessageFor(conversation);

        summaries.add(
          _RecentChatSummary(
            conversationId: conversation.id,
            peer: {
              'id': conversation.id,
              'name': conversation.title.trim().isEmpty
                  ? 'Group chat'
                  : conversation.title,
              'bio': '${_conversationMembers(conversation).length} members',
              'profilePicUrl': '',
              'presence': 'group',
              'isGroup': true,
              'memberIds': _conversationMembers(conversation),
            },
            lastMessage: latestMessage == null
                ? _systemLastMessage(conversation, user.id)
                : {
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
            sentAt: latestMessage == null
                ? DateTime.fromMillisecondsSinceEpoch(0)
                : _sentAtValue(latestMessage),
          ),
        );
        continue;
      }

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
    if (!await _canAccessConversation(conversationId, user.id)) {
      socket.emit('chat:error', {
        'message': 'You are not a member of this chat',
      });
      return null;
    }

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

    socket.on('chat:mark_read', (dynamic payload) async {
      final data = _asMap(payload);
      final targetConversationId =
          (data['conversationId'] ?? conversationId).toString().trim();

      if (targetConversationId != conversationId) {
        return;
      }

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
      final activeConversation = await Conversation().find(conversationId);
      final isGroup = activeConversation != null &&
          _isGroupConversation(activeConversation);

      if (!isGroup &&
          cleanedCurrentUserId.isNotEmpty &&
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
      final recipientId = isGroup ? null : data['recipientId']?.toString();
      final sentAt = DateTime.now().toIso8601String();
      final targetConversationId = isGroup
          ? conversationId
          : (conversation?.id ?? normalizedConversationId ?? conversationId);

      final created = await ChatMessage().create({
        'conversationId': targetConversationId,
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

      if (isGroup) {
        await activeConversation.update(data: {
          'lastMessageId': created.id,
          'lastSenderId': cleanedCurrentUserId,
        });
      } else if (recipientId != null && recipientId.trim().isNotEmpty) {
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

      final conversationKey = targetConversationId.trim();
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

      if (isGroup) {
        for (final memberId in _conversationMembers(activeConversation)) {
          if (memberId == cleanedCurrentUserId) {
            continue;
          }

          _emitToUser(
            memberId,
            'messageReceived',
            {
              'conversationId': conversationKey,
              'message': storedMap,
              'unreadCount': 0,
            },
          );
        }
      } else if (recipientId != null && recipientId.trim().isNotEmpty) {
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

  Future<Response?> sendMedia(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({
        'status': false,
        'message': 'Unauthorized',
      });
    }

    final roomId = ctx.req.param('roomId')?.trim();
    if (roomId == null || roomId.isEmpty) {
      return res.status(400).json({
        'status': false,
        'message': 'Room id is required',
      });
    }

    if (!await _canAccessConversation(roomId, user.id)) {
      return res.status(403).json({
        'status': false,
        'message': 'You are not a member of this chat',
      });
    }

    if (!await ctx.req.hasFile('file')) {
      return res.status(400).json({
        'status': false,
        'message': 'Choose a media file first',
      });
    }

    final file = await ctx.req.file('file');
    if (file == null) {
      return res.status(400).json({
        'status': false,
        'message': 'Choose a media file first',
      });
    }

    final form = Map<String, dynamic>.from(await ctx.req.form());
    final messageType =
        (form['messageType'] ?? form['type'] ?? 'image').toString().trim();
    final caption = (form['caption'] ?? form['content'] ?? '').toString();
    final recipientId = form['recipientId']?.toString().trim();
    final url = await Storage.create(file, subdirectory: 'chat');
    final sentAt = DateTime.now().toIso8601String();
    final conversation = await Conversation().find(roomId);
    final isGroup = conversation != null && _isGroupConversation(conversation);

    final created = await ChatMessage().create({
      'conversationId': roomId,
      'senderId': user.id,
      'recipientId': isGroup ? null : recipientId,
      'content': url,
      'messageType': messageType.isEmpty ? 'image' : messageType,
      'sentAt': sentAt,
      'readAt': '',
    });

    if (created == null) {
      return res.status(500).json({
        'status': false,
        'message': 'Media message could not be saved',
      });
    }

    await conversation?.update(data: {
      'lastMessageId': created.id,
      'lastSenderId': user.id,
    });

    final stored = await ChatMessage().withRelation('sender').find(created.id);
    if (stored == null) {
      return res.status(500).json({
        'status': false,
        'message': 'Media message could not be loaded',
      });
    }

    final storedMap = stored.toMap()
      ..remove('created_at')
      ..remove('updated_at');
    if (caption.trim().isNotEmpty) {
      storedMap['caption'] = caption;
    }

    WebSocketManager().emitToPathRoom(
      '/chat/rooms/$roomId',
      roomId,
      'chat:message',
      storedMap,
    );

    final notifyMemberIds = isGroup
        ? _conversationMembers(conversation)
        : [
            user.id,
            if (recipientId != null && recipientId.isNotEmpty) recipientId
          ];

    for (final memberId in notifyMemberIds.toSet()) {
      _emitToUser(
        memberId,
        'messageReceived',
        {
          'conversationId': roomId,
          'message': storedMap,
          'unreadCount': memberId == user.id
              ? 0
              : await _unreadCount(conversationId: roomId, userId: memberId),
        },
      );
    }

    return res.json({
      'status': true,
      'data': storedMap,
    });
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

  bool _isGroupConversation(Conversation conversation) {
    return conversation.type.trim().toLowerCase() == 'group';
  }

  List<String> _conversationMembers(Conversation conversation) {
    return conversation.memberIds
        .split(',')
        .map((memberId) => memberId.trim())
        .where((memberId) => memberId.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<bool> _canAccessConversation(
    String conversationId,
    String userId,
  ) async {
    final conversation = await Conversation().find(conversationId);
    if (conversation == null) {
      return true;
    }

    if (_isGroupConversation(conversation)) {
      return _conversationMembers(conversation).contains(userId);
    }

    return conversation.userId == userId || conversation.friendId == userId;
  }

  Future<ChatMessage?> _lastMessageFor(Conversation conversation) async {
    final lastMessageId = conversation.lastMessageId.trim();
    if (lastMessageId.isNotEmpty) {
      return ChatMessage().find(lastMessageId);
    }

    final messages = await ChatMessage()
        .where('conversationId', conversation.id)
        .orderBy('sentAt', asc: false)
        .limit(1)
        .get();
    return messages.isEmpty ? null : messages.first;
  }

  Map<String, dynamic> _systemLastMessage(
    Conversation conversation,
    String userId,
  ) {
    return {
      'id': null,
      'conversationId': conversation.id,
      'senderId': userId,
      'recipientId': null,
      'content': 'Group created',
      'messageType': 'text',
      'sentAt': '',
      'readAt': '',
    };
  }

  Map<String, dynamic> _groupConversationMap(
    Conversation conversation, {
    required String currentUserId,
  }) {
    return {
      'conversationId': conversation.id,
      'peer': {
        'id': conversation.id,
        'name': conversation.title.trim().isEmpty
            ? 'Group chat'
            : conversation.title,
        'bio': '${_conversationMembers(conversation).length} members',
        'profilePicUrl': '',
        'presence': 'group',
        'isGroup': true,
        'memberIds': _conversationMembers(conversation),
      },
      'lastMessage': _systemLastMessage(conversation, currentUserId),
      'unreadCount': 0,
      'sentAt': DateTime.now().toIso8601String(),
    };
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
