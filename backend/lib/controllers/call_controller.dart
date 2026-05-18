import 'package:backend/helper/auth_helper.dart';
import 'package:backend/models/call.dart';
import 'package:backend/models/user_model.dart';
import 'package:backend/services/agora_token_service.dart';
import 'package:flint_dart/flint_dart.dart';

class CallController {
  CallController({AgoraTokenService? tokenService})
      : _tokenService = tokenService ?? AgoraTokenService();

  final AgoraTokenService _tokenService;

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

    final startedAt = DateTime.now();
    final callerUid = _tokenService.uidForUser(user.id);
    final recipientUid = _tokenService.uidForUser(recipientId);
    final channelName =
        'call${callerUid}x${recipientUid}x${startedAt.millisecondsSinceEpoch}';

    final created = await Call().create({
      'conversationId': conversationId?.isEmpty == true ? null : conversationId,
      'channelName': channelName,
      'callerId': user.id,
      'recipientId': recipientId,
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
    final payload = _callPayload(call, currentUserId: user.id);

    WebSocketManager().emit(_userRoom(recipientId), 'call:incoming', {
      'call': _callPayload(call, currentUserId: recipientId),
      'caller': _userPayload(user),
    });

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
      'data': calls
          .map((call) => _callPayload(call, currentUserId: user.id))
          .toList(),
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

    if (!_canAccess(call, user.id)) {
      return res.status(403).json({'status': false, 'message': 'Forbidden'});
    }

    return res.json({
      'status': true,
      'data': _callPayload(call, currentUserId: user.id),
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

    if (!_canAccess(call, user.id)) {
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

    if (!_canAccess(call, user.id)) {
      return res.status(403).json({'status': false, 'message': 'Forbidden'});
    }

    if (status == 'accepted' && call.recipientId != user.id) {
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
    final payload = _callPayload(updatedCall, currentUserId: user.id);
    final otherUserId =
        call.callerId == user.id ? call.recipientId : call.callerId;

    WebSocketManager().emit(_userRoom(otherUserId), 'call:$status', {
      'call': _callPayload(updatedCall, currentUserId: otherUserId),
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

  Map<String, dynamic> _callPayload(Call call,
      {required String currentUserId}) {
    final peer = call.callerId == currentUserId ? call.recipient : call.caller;
    final peerId =
        call.callerId == currentUserId ? call.recipientId : call.callerId;

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
      'peer': {
        'id': peer?.id?.toString() ?? peerId,
        'name': _peerName(peer, peerId),
        'profilePicUrl': peer?.profilePicUrl,
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

  bool _canAccess(Call call, String userId) {
    return call.callerId == userId || call.recipientId == userId;
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

  String _userRoom(String userId) => 'user:$userId';
}
