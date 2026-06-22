import 'package:backend/helper/auth_helper.dart';
import 'package:backend/models/call.dart';
import 'package:backend/models/conversation.dart';
import 'package:backend/models/user_model.dart';
import 'package:backend/services/agora_token_service.dart';
import 'package:backend/services/ai_service.dart';
import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/storage.dart';

const String _userSocketPath = '/chat/connect';

class CallController {
  CallController({AgoraTokenService? tokenService, AiService? aiService})
      : _tokenService = tokenService ?? AgoraTokenService(),
        _aiService = aiService ?? AiService();

  final AgoraTokenService _tokenService;
  final AiService _aiService;

  Future<Response?> create(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({'status': false, 'message': 'Unauthorized'});
    }

    final body = await ctx.req.json();
    final recipientId = body['recipientId']?.toString().trim();
    final conversationId = body['conversationId']?.toString().trim();
    final callType = _cleanCallType(body['callType']?.toString());

    Conversation? conversation;
    bool isGroupCall = false;
    if (conversationId != null && conversationId.isNotEmpty) {
      conversation = await Conversation().find(conversationId);
      if (conversation != null && conversation.type.trim().toLowerCase() == 'group') {
        isGroupCall = true;
      }
    }

    if (!isGroupCall) {
      if (recipientId == null || recipientId.isEmpty) {
        return res.status(400).json({
          'status': false,
          'message': 'Recipient id is required',
        });
      }

      if (recipientId == user.id) {
        return res.status(400).json({
          'status': false,
          'message': 'You cannot call yourself',
        });
      }

      final recipient = await User().find(recipientId);
      if (recipient == null) {
        return res.status(404).json({
          'status': false,
          'message': 'Recipient was not found',
        });
      }
    }

    final startedAt = DateTime.now();
    final callerUid = _tokenService.uidForUser(user.id);
    final recipientUid = isGroupCall ? 0 : _tokenService.uidForUser(recipientId!);
    final channelName = isGroupCall
        ? 'call_group_${conversation!.id}_${startedAt.millisecondsSinceEpoch}'
        : 'call${callerUid}x${recipientUid}x${startedAt.millisecondsSinceEpoch}';

    final created = await Call().create({
      'conversationId': conversationId?.isEmpty == true ? null : conversationId,
      'channelName': channelName,
      'callerId': user.id,
      'recipientId': isGroupCall ? conversationId! : recipientId!,
      'callType': callType,
      'status': 'ringing',
      'startedAt': startedAt.toIso8601String(),
      'agoraUidCaller': callerUid.toString(),
      'agoraUidRecipient': recipientUid.toString(),
    });

    if (created == null) {
      return res.status(500).json({
        'status': false,
        'message': 'Call could not be created',
      });
    }

    final stored = await Call()
        .withRelation('caller')
        .withRelation('recipient')
        .find(created.id);
    final call = stored ?? created;
    final token = _tokenService.buildRtcToken(
      channelName: channelName,
      uid: callerUid,
    );
    final payload = await _callPayload(call, currentUserId: user.id);
    
    final recipientPayload = await _callPayload(
      call,
      currentUserId: isGroupCall ? conversationId! : recipientId!,
    );

    if (isGroupCall) {
      final memberIds = conversation!.memberIds
          .split(',')
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty && id != user.id)
          .toList();
      for (final memberId in memberIds) {
        _emitToUser(memberId, 'call:incoming', {
          'call': recipientPayload,
          'caller': _userPayload(user),
        });
      }
    } else {
      _emitToUser(recipientId!, 'call:incoming', {
        'call': recipientPayload,
        'caller': _userPayload(user),
      });
    }

    return res.json({
      'status': true,
      'data': {
        ...payload,
        'agoraAppId': _tokenService.appId,
        'agoraToken': token,
        'agoraUid': callerUid,
      },
    });
  }

  Future<Response?> accept(Context ctx) async {
    return _markCall(ctx, status: 'accepted');
  }

  Future<Response?> reject(Context ctx) async {
    return _markCall(ctx, status: 'rejected');
  }

  Future<Response?> end(Context ctx) async {
    return _markCall(ctx, status: 'ended');
  }

  Future<Response?> recent(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({'status': false, 'message': 'Unauthorized'});
    }

    final outgoing = await Call()
        .where('callerId', user.id)
        .withRelation('caller')
        .withRelation('recipient')
        .orderBy('startedAt', asc: false)
        .limit(50)
        .get();
    final incoming = await Call()
        .where('recipientId', user.id)
        .withRelation('caller')
        .withRelation('recipient')
        .orderBy('startedAt', asc: false)
        .limit(50)
        .get();

    final calls = [...outgoing, ...incoming];
    calls.sort(
        (a, b) => _dateValue(b.startedAt).compareTo(_dateValue(a.startedAt)));

    return res.json({
      'status': true,
      'data': await Future.wait(
        calls.map((call) => _callPayload(call, currentUserId: user.id)),
      ),
    });
  }

  Future<Response?> show(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({'status': false, 'message': 'Unauthorized'});
    }

    final call = await _callFromRequest(ctx);
    if (call == null) {
      return res
          .status(404)
          .json({'status': false, 'message': 'Call not found'});
    }

    if (!await _canAccess(call, user.id)) {
      return res.status(403).json({'status': false, 'message': 'Forbidden'});
    }

    return res.json({
      'status': true,
      'data': await _callPayload(call, currentUserId: user.id),
    });
  }

  Future<Response?> token(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({'status': false, 'message': 'Unauthorized'});
    }

    final call = await _callFromRequest(ctx);
    if (call == null) {
      return res
          .status(404)
          .json({'status': false, 'message': 'Call not found'});
    }

    if (!await _canAccess(call, user.id)) {
      return res.status(403).json({'status': false, 'message': 'Forbidden'});
    }

    final uid = _uidForCall(call, user.id);
    final token = _tokenService.buildRtcToken(
      channelName: call.channelName,
      uid: uid,
    );

    return res.json({
      'status': true,
      'data': {
        'callId': call.id?.toString(),
        'channelName': call.channelName,
        'agoraAppId': _tokenService.appId,
        'agoraToken': token,
        'agoraUid': uid,
      },
    });
  }

  Future<Response?> _markCall(Context ctx, {required String status}) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({'status': false, 'message': 'Unauthorized'});
    }

    final call = await _callFromRequest(ctx);
    if (call == null) {
      return res
          .status(404)
          .json({'status': false, 'message': 'Call not found'});
    }

    if (!await _canAccess(call, user.id)) {
      return res.status(403).json({'status': false, 'message': 'Forbidden'});
    }

    final conversation = call.conversationId != null ? await Conversation().find(call.conversationId!) : null;
    final isGroup = conversation != null && conversation.type.trim().toLowerCase() == 'group';
    if (status == 'accepted' && !isGroup && call.recipientId != user.id) {
      return res.status(403).json({
        'status': false,
        'message': 'Only the recipient can accept this call',
      });
    }

    final now = DateTime.now();
    final update = <String, dynamic>{'status': status};
    if (status == 'accepted') {
      update['acceptedAt'] = now.toIso8601String();
    }

    if (status == 'rejected' || status == 'ended') {
      update['endedAt'] = now.toIso8601String();
      update['durationSeconds'] = _durationSeconds(call, now).toString();
    }

    await call.update(data: update);
    final stored = await Call()
        .withRelation('caller')
        .withRelation('recipient')
        .find(call.id);
    final updatedCall = stored ?? call;
    final payload = await _callPayload(updatedCall, currentUserId: user.id);
    final otherUserId =
        call.callerId == user.id ? call.recipientId : call.callerId;
    final otherPayload = await _callPayload(
      updatedCall,
      currentUserId: otherUserId,
    );

    _emitToUser(otherUserId, 'call:$status', {
      'call': otherPayload,
    });

    final uid = _uidForCall(call, user.id);
    final token = _tokenService.buildRtcToken(
      channelName: call.channelName,
      uid: uid,
    );

    return res.json({
      'status': true,
      'data': {
        ...payload,
        'agoraAppId': _tokenService.appId,
        'agoraToken': token,
        'agoraUid': uid,
      },
    });
  }

  Future<Call?> _callFromRequest(Context ctx) async {
    final callId = ctx.req.param('id');
    if (callId == null || callId.trim().isEmpty) {
      return null;
    }

    return Call()
        .withRelation('caller')
        .withRelation('recipient')
        .find(callId.trim());
  }

  Future<Map<String, dynamic>> _callPayload(Call call,
      {required String currentUserId}) async {
    final relatedPeer =
        call.callerId == currentUserId ? call.recipient : call.caller;
    final peerId =
        call.callerId == currentUserId ? call.recipientId : call.callerId;
    final peer = await _peerForPayload(relatedPeer, peerId);

    Conversation? conversation;
    if (call.conversationId != null) {
      conversation = await Conversation().find(call.conversationId!);
    }
    final isGroup = conversation != null && conversation.type.trim().toLowerCase() == 'group';

    return {
      'id': call.id?.toString(),
      'conversationId': call.conversationId,
      'channelName': call.channelName,
      'callerId': call.callerId,
      'recipientId': call.recipientId,
      'callType': call.callType,
      'status': call.status,
      'startedAt': call.startedAt,
      'acceptedAt': call.acceptedAt,
      'endedAt': call.endedAt,
      'durationSeconds': call.durationSeconds,
      'isOutgoing': call.callerId == currentUserId,
      'recordingUrl': call.recordingUrl,
      'transcript': call.transcript,
      'peer': {
        'id': isGroup ? conversation.id : (peer?.id?.toString() ?? peerId),
        'name': isGroup ? conversation.title : _peerName(peer, peerId),
        'profilePicUrl': isGroup ? conversation.profilePicUrl : peer?.profilePicUrl,
      },
    };
  }

  Map<String, dynamic> _userPayload(User user) {
    return {
      'id': user.id?.toString(),
      'name': user.name,
      'profilePicUrl': user.profilePicUrl,
    };
  }

  Future<bool> _canAccess(Call call, String userId) async {
    if (call.callerId == userId || call.recipientId == userId) {
      return true;
    }
    if (call.conversationId != null) {
      final conversation = await Conversation().find(call.conversationId!);
      if (conversation != null && conversation.type.trim().toLowerCase() == 'group') {
        final members = conversation.memberIds
            .split(',')
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toList();
        return members.contains(userId);
      }
    }
    return false;
  }

  int _uidForCall(Call call, String userId) {
    final value =
        call.callerId == userId ? call.agoraUidCaller : call.agoraUidRecipient;
    final parsed = int.tryParse(value ?? '');
    return parsed ?? _tokenService.uidForUser(userId);
  }

  int _durationSeconds(Call call, DateTime endedAt) {
    final acceptedAt = DateTime.tryParse(call.acceptedAt ?? '');
    final startedAt = DateTime.tryParse(call.startedAt ?? '');
    final start = acceptedAt ?? startedAt;
    if (start == null) {
      return 0;
    }

    return endedAt.difference(start).inSeconds;
  }

  DateTime _dateValue(String? value) {
    return DateTime.tryParse(value ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _cleanCallType(String? value) {
    return value == 'video' ? 'video' : 'audio';
  }

  String _peerName(User? peer, String peerId) {
    final name = peer?.name.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    return 'User $peerId';
  }

  Future<User?> _peerForPayload(User? relatedPeer, String peerId) async {
    final relatedName = relatedPeer?.name.trim();
    if (relatedName != null && relatedName.isNotEmpty) {
      return relatedPeer;
    }

    if (peerId.trim().isEmpty) {
      return relatedPeer;
    }

    return await User().find(peerId.trim()) ?? relatedPeer;
  }

  String _userRoom(String userId) => 'user:$userId';

  void _emitToUser(String userId, String event, Map<String, dynamic> data) {
    WebSocketManager().emitToPathRoom(
      _userSocketPath,
      _userRoom(userId),
      event,
      data,
    );
  }

  Future<Response?> uploadRecording(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({'status': false, 'message': 'Unauthorized'});
    }

    final callId = ctx.req.param('id');
    if (callId == null || callId.trim().isEmpty) {
      return res.status(400).json({
        'status': false,
        'message': 'Call ID is required',
      });
    }

    final call = await Call().find(callId.trim());
    if (call == null) {
      return res.status(404).json({
        'status': false,
        'message': 'Call not found',
      });
    }

    if (!await _canAccess(call, user.id)) {
      return res.status(403).json({'status': false, 'message': 'Forbidden'});
    }

    if (!await ctx.req.hasFile('file')) {
      return res.status(400).json({
        'status': false,
        'message': 'No recording file uploaded',
      });
    }

    final file = await ctx.req.file('file');
    if (file == null) {
      return res.status(400).json({
        'status': false,
        'message': 'Invalid file',
      });
    }

    final url = await Storage.create(file, subdirectory: 'calls');
    
    // Perform AI transcription and summarization
    String transcriptText = 'Meeting recording transcript and summary could not be generated.';
    try {
      final transcriptionResult = await _aiService.transcribeAudio(
        mediaUrl: url,
        provider: 'gemini',
      );
      final rawTranscription = transcriptionResult['transcription']?.toString() ?? '';
      
      if (rawTranscription.isNotEmpty && !rawTranscription.contains('AI transcription is not available')) {
        final prompt = '''
You are summarizing a recorded call/meeting between two users.
Please provide a brief, professional meeting summary, highlighting key discussion points, decisions made, and follow-up tasks.
Format your response in a clean and readable format (markdown is fine, but keep it readable).

Meeting Transcription:
$rawTranscription
''';
        final summary = await _aiService.generateText(
          prompt: prompt,
          provider: 'gemini',
        );

        if (summary != null && summary.trim().isNotEmpty) {
          transcriptText = 'Meeting Summary:\n${summary.trim()}\n\nFull Transcription:\n$rawTranscription';
        } else {
          transcriptText = 'Full Transcription:\n$rawTranscription';
        }
      } else {
        transcriptText = 'Meeting recording uploaded successfully, but transcription is not available. Please verify your Gemini API key.';
      }
    } catch (e) {
      transcriptText = 'An error occurred during transcription: $e';
    }

    await call.update(data: {
      'recordingUrl': url,
      'transcript': transcriptText,
    });

    final updatedCall = await Call()
        .withRelation('caller')
        .withRelation('recipient')
        .find(call.id);

    return res.json({
      'status': true,
      'data': await _callPayload(updatedCall ?? call, currentUserId: user.id),
    });
  }
}
