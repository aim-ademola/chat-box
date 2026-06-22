import 'dart:convert';

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
const Duration _readMediaLifetime = Duration(minutes: 10);

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

  Future<Response?> groupDetails(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({
        'status': false,
        'message': 'Unauthorized',
      });
    }

    final groupId = ctx.req.param('groupId')?.trim();
    if (groupId == null || groupId.isEmpty) {
      return res.status(400).json({
        'status': false,
        'message': 'Group id is required',
      });
    }

    final group = await Conversation().find(groupId);
    if (group == null || !_isGroupConversation(group)) {
      return res.status(404).json({
        'status': false,
        'message': 'Group not found',
      });
    }

    if (!_conversationMembers(group).contains(user.id)) {
      return res.status(403).json({
        'status': false,
        'message': 'You are not a member of this group',
      });
    }

    return res.json({
      'status': true,
      'data': await _groupDetailsMap(group, currentUserId: user.id),
    });
  }

  Future<Response?> updateGroup(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({
        'status': false,
        'message': 'Unauthorized',
      });
    }

    final group = await _editableGroup(ctx, user.id);
    if (group == null) {
      return res.status(404).json({
        'status': false,
        'message': 'Group not found',
      });
    }

    final hasUpload = await ctx.req.hasFile('profile_pic');
    final data = hasUpload
        ? Map<String, dynamic>.from(await ctx.req.form())
        : await ctx.req.json();
    final updateData = <String, dynamic>{};
    final title = data['title']?.toString().trim();

    if (title != null && title.isNotEmpty) {
      updateData['title'] = title;
    }

    if (hasUpload) {
      final file = await ctx.req.file('profile_pic');
      if (file != null) {
        final existingUrl = group.profilePicUrl.trim();
        updateData['profilePicUrl'] = existingUrl.isEmpty
            ? await Storage.create(file, subdirectory: 'groups')
            : await Storage.update(
                existingUrl,
                file,
                subdirectory: 'groups',
              );
      }
    }

    if (updateData.isNotEmpty) {
      await group.update(data: updateData);
    }

    final updated = await Conversation().find(group.id);
    return res.json({
      'status': true,
      'data': await _groupDetailsMap(updated ?? group, currentUserId: user.id),
    });
  }

  Future<Response?> addGroupMembers(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({
        'status': false,
        'message': 'Unauthorized',
      });
    }

    final group = await _editableGroup(ctx, user.id);
    if (group == null) {
      return res.status(404).json({
        'status': false,
        'message': 'Group not found',
      });
    }

    final body = await ctx.req.json();
    final rawMemberIds = body['memberIds'];
    final nextMembers = <String>{
      ..._conversationMembers(group),
      if (rawMemberIds is List)
        ...rawMemberIds
            .map((memberId) => memberId.toString().trim())
            .where((memberId) => memberId.isNotEmpty),
    }.toList()
      ..sort();

    await group.update(data: {'memberIds': nextMembers.join(',')});
    final updated = await Conversation().find(group.id);
    return res.json({
      'status': true,
      'data': await _groupDetailsMap(updated ?? group, currentUserId: user.id),
    });
  }

  Future<Response?> removeGroupMember(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({
        'status': false,
        'message': 'Unauthorized',
      });
    }

    final group = await _editableGroup(ctx, user.id);
    if (group == null) {
      return res.status(404).json({
        'status': false,
        'message': 'Group not found',
      });
    }

    final memberId = ctx.req.param('memberId')?.trim();
    if (memberId == null || memberId.isEmpty) {
      return res.status(400).json({
        'status': false,
        'message': 'Member id is required',
      });
    }

    final members = _conversationMembers(group)
        .where((currentMemberId) => currentMemberId != memberId)
        .toList()
      ..sort();

    if (members.length < 2) {
      return res.status(400).json({
        'status': false,
        'message': 'A group needs at least two members',
      });
    }

    await group.update(data: {'memberIds': members.join(',')});
    final updated = await Conversation().find(group.id);
    return res.json({
      'status': true,
      'data': await _groupDetailsMap(updated ?? group, currentUserId: user.id),
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

    final rawMessages = await ChatMessage()
        .where('conversationId', roomId)
        .withRelation('sender')
        .orderBy('sentAt', asc: true)
        .limit(100)
        .get();
    final messages = rawMessages.where((message) => !_isExpired(message));

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
        final latestMessage = await _lastVisibleMessageFor(conversation);

        summaries.add(
          _RecentChatSummary(
            conversationId: conversation.id,
            peer: {
              'id': conversation.id,
              'name': conversation.title.trim().isEmpty
                  ? 'Group chat'
                  : conversation.title,
              'bio': '${_conversationMembers(conversation).length} members',
              'profilePicUrl': conversation.profilePicUrl,
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
      final latestMessage = await _lastVisibleMessageFor(conversation);

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
      final normalizedMessageType = messageType.isEmpty ? 'text' : messageType;
      final normalizedContent = normalizedMessageType == 'poll'
          ? _normalizedPollContent(content)
          : content;
      if (normalizedMessageType == 'poll' && normalizedContent == null) {
        socket.emit('chat:error', {
          'message': 'Poll needs a question and at least two options',
        });
        return;
      }
      final recipientId = isGroup ? null : data['recipientId']?.toString();
      final sentAt = DateTime.now().toIso8601String();
      final targetConversationId = isGroup
          ? conversationId
          : (conversation?.id ?? normalizedConversationId ?? conversationId);

      final created = await ChatMessage().create({
        'conversationId': targetConversationId,
        'senderId': user.id.toString(),
        'recipientId': recipientId,
        'content': normalizedContent ?? content,
        'messageType': normalizedMessageType,
        'sentAt': sentAt,
        'readAt': '',
        'expiresAt': '',
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
              'unreadCount': await _unreadCount(
                conversationId: conversationKey,
                userId: memberId,
              ),
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
      'expiresAt': '',
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

  Future<Response?> votePoll(Context ctx) async {
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
    final messageId = ctx.req.param('messageId')?.trim();
    if (roomId == null ||
        roomId.isEmpty ||
        messageId == null ||
        messageId.isEmpty) {
      return res.status(400).json({
        'status': false,
        'message': 'Poll message id is required',
      });
    }

    final body = await ctx.req.json();
    final optionIndex = int.tryParse(body['optionIndex']?.toString() ?? '');
    if (optionIndex == null || optionIndex < 0) {
      return res.status(400).json({
        'status': false,
        'message': 'Choose a poll option',
      });
    }

    final message = await ChatMessage().find(messageId);
    if (message == null ||
        message.conversationId != roomId ||
        message.messageType != 'poll') {
      return res.status(404).json({
        'status': false,
        'message': 'Poll not found',
      });
    }

    if (!await _canAccessMessage(message, user.id)) {
      return res.status(403).json({
        'status': false,
        'message': 'You are not a member of this chat',
      });
    }

    final poll = _pollContent(message.content);
    final options = poll['options'];
    if (options is! List || optionIndex >= options.length) {
      return res.status(400).json({
        'status': false,
        'message': 'Invalid poll option',
      });
    }

    final votes = poll['votes'] is Map
        ? Map<String, dynamic>.from(poll['votes'] as Map)
        : <String, dynamic>{};

    for (final key in votes.keys.toList()) {
      final voters = votes[key] is List
          ? (votes[key] as List).map((item) => item.toString()).toList()
          : <String>[];
      voters.remove(user.id);
      votes[key] = voters;
    }

    final selectedKey = optionIndex.toString();
    final selectedVoters = votes[selectedKey] is List
        ? (votes[selectedKey] as List).map((item) => item.toString()).toSet()
        : <String>{};
    selectedVoters.add(user.id);
    votes[selectedKey] = selectedVoters.toList()..sort();
    poll['votes'] = votes;

    await message.update(data: {'content': jsonEncode(poll)});
    final updated = await ChatMessage().withRelation('sender').find(message.id);
    if (updated == null) {
      return res.status(500).json({
        'status': false,
        'message': 'Poll could not be updated',
      });
    }

    final updatedMap = updated.toMap()
      ..remove('created_at')
      ..remove('updated_at');

    WebSocketManager().emitToPathRoom(
      '/chat/rooms/$roomId',
      roomId,
      'chat:poll_updated',
      updatedMap,
    );

    return res.json({
      'status': true,
      'data': updatedMap,
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

  Map<String, dynamic> _pollContent(String? content) {
    if (content == null || content.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

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
    final conversation = await Conversation().find(conversationId);
    final isGroup = conversation != null && _isGroupConversation(conversation);

    final query = ChatMessage().where('conversationId', conversationId);
    if (!isGroup) {
      query.where('recipientId', userId);
    }

    final messages = await query.get();

    return messages.where((message) {
      if (_isExpired(message)) {
        return false;
      }

      if (isGroup) {
        if (message.senderId == userId) {
          return false;
        }
      }

      final readAt = message.readAt?.trim() ?? '';
      return readAt.isEmpty;
    }).length;
  }

  Future<Map<String, dynamic>?> _markConversationRead({
    required String conversationId,
    required String readerId,
  }) async {
    final messages =
        await ChatMessage().where('conversationId', conversationId).get();

    final readAt = DateTime.now().toIso8601String();
    final readMessageIds = <String>[];
    final senderIds = <String>{};

    for (final message in messages) {
      if (_isExpired(message)) {
        continue;
      }

      final recipientId = message.recipientId?.trim() ?? '';
      final senderId = message.senderId?.trim();
      final shouldMarkRead = recipientId == readerId ||
          (recipientId.isEmpty && senderId != null && senderId != readerId);
      if (!shouldMarkRead) {
        continue;
      }

      final currentReadAt = message.readAt?.trim() ?? '';
      if (currentReadAt.isNotEmpty) {
        continue;
      }

      final updateData = <String, dynamic>{'readAt': readAt};
      if (_expiresAfterRead(message)) {
        updateData['expiresAt'] =
            DateTime.now().add(_readMediaLifetime).toIso8601String();
      }

      await message.update(data: updateData);

      final messageId = message.id?.toString();
      if (messageId != null && messageId.isNotEmpty) {
        readMessageIds.add(messageId);
      }

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

  Future<bool> _canAccessMessage(ChatMessage message, String userId) async {
    final conversationId = message.conversationId?.trim();
    if (conversationId == null || conversationId.isEmpty) {
      return false;
    }

    final conversation = await Conversation().find(conversationId);
    if (conversation != null) {
      if (_isGroupConversation(conversation)) {
        return _conversationMembers(conversation).contains(userId);
      }

      return conversation.userId == userId || conversation.friendId == userId;
    }

    final senderId = message.senderId?.trim();
    final recipientId = message.recipientId?.trim();
    if (senderId == userId || recipientId == userId) {
      return true;
    }

    final directIds = conversationId.split('__').map((id) => id.trim());
    return directIds.contains(userId);
  }

  Future<Conversation?> _editableGroup(Context ctx, String userId) async {
    final groupId = ctx.req.param('groupId')?.trim();
    if (groupId == null || groupId.isEmpty) {
      return null;
    }

    final group = await Conversation().find(groupId);
    if (group == null || !_isGroupConversation(group)) {
      return null;
    }

    final members = _conversationMembers(group);
    if (!members.contains(userId)) {
      return null;
    }

    return group;
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

  Future<ChatMessage?> _lastVisibleMessageFor(Conversation conversation) async {
    final lastMessage = await _lastMessageFor(conversation);
    if (lastMessage != null && !_isExpired(lastMessage)) {
      return lastMessage;
    }

    final messages = await ChatMessage()
        .where('conversationId', conversation.id)
        .orderBy('sentAt', asc: false)
        .limit(25)
        .get();

    for (final message in messages) {
      if (!_isExpired(message)) {
        return message;
      }
    }

    return null;
  }

  bool _expiresAfterRead(ChatMessage message) {
    switch (message.messageType?.trim().toLowerCase()) {
      case 'image':
      case 'video':
      case 'voice':
      case 'poll':
        return true;
      default:
        return false;
    }
  }

  bool _isExpired(ChatMessage message) {
    final rawExpiresAt = message.expiresAt?.trim();
    if (rawExpiresAt == null || rawExpiresAt.isEmpty) {
      return false;
    }

    final expiresAt = DateTime.tryParse(rawExpiresAt);
    if (expiresAt == null) {
      return false;
    }

    return DateTime.now().isAfter(expiresAt);
  }

  String? _normalizedPollContent(String content) {
    final poll = _pollContent(content);
    final question = poll['question']?.toString().trim() ?? '';
    final options = poll['options'] is List
        ? (poll['options'] as List)
            .map((option) => option.toString().trim())
            .where((option) => option.isNotEmpty)
            .toList()
        : <String>[];

    if (question.isEmpty || options.length < 2) {
      return null;
    }

    final normalizedOptions =
        options.length > 6 ? options.take(6).toList() : options;
    return jsonEncode({
      'question': question,
      'options': normalizedOptions,
      'votes': <String, List<String>>{},
    });
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
        'profilePicUrl': conversation.profilePicUrl,
        'presence': 'group',
        'isGroup': true,
        'memberIds': _conversationMembers(conversation),
      },
      'lastMessage': _systemLastMessage(conversation, currentUserId),
      'unreadCount': 0,
      'sentAt': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _groupDetailsMap(
    Conversation conversation, {
    required String currentUserId,
  }) async {
    final memberIds = _conversationMembers(conversation);
    final members = <Map<String, dynamic>>[];

    for (final memberId in memberIds) {
      final member = await User().find(memberId);
      if (member != null) {
        members.add(member.toMap());
      }
    }

    return {
      ..._groupConversationMap(conversation, currentUserId: currentUserId),
      'id': conversation.id,
      'title':
          conversation.title.trim().isEmpty ? 'Group chat' : conversation.title,
      'profilePicUrl': conversation.profilePicUrl,
      'memberIds': memberIds,
      'members': members,
      'createdBy': conversation.createdBy,
      'isOwner': conversation.createdBy == currentUserId,
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
