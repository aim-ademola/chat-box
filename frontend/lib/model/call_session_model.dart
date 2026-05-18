class CallSessionModel {
  const CallSessionModel({
    required this.id,
    this.conversationId,
    required this.channelName,
    required this.callType,
    required this.status,
    required this.agoraAppId,
    required this.agoraToken,
    required this.agoraUid,
    required this.peerName,
    this.peerId,
    this.peerProfilePicUrl,
    this.isOutgoing = true,
  });

  final String id;
  final String? conversationId;
  final String channelName;
  final String callType;
  final String status;
  final String agoraAppId;
  final String agoraToken;
  final int agoraUid;
  final String peerName;
  final String? peerId;
  final String? peerProfilePicUrl;
  final bool isOutgoing;

  bool get isVideoCall => callType == 'video';

  factory CallSessionModel.fromMap(Map<String, dynamic> map) {
    final peer = map['peer'] is Map
        ? Map<String, dynamic>.from(map['peer'] as Map)
        : <String, dynamic>{};

    return CallSessionModel(
      id: map['id']?.toString() ?? '',
      conversationId: map['conversationId']?.toString(),
      channelName: map['channelName']?.toString() ?? '',
      callType: map['callType']?.toString() == 'video' ? 'video' : 'audio',
      status: map['status']?.toString() ?? 'ringing',
      agoraAppId: map['agoraAppId']?.toString() ?? '',
      agoraToken: map['agoraToken']?.toString() ?? '',
      agoraUid: int.tryParse(map['agoraUid']?.toString() ?? '') ?? 0,
      peerName: peer['name']?.toString() ?? 'Unknown',
      peerId: peer['id']?.toString(),
      peerProfilePicUrl: peer['profilePicUrl']?.toString(),
      isOutgoing: map['isOutgoing'] == true,
    );
  }

  CallSessionModel copyWith({String? peerName, String? peerProfilePicUrl}) {
    return CallSessionModel(
      id: id,
      conversationId: conversationId,
      channelName: channelName,
      callType: callType,
      status: status,
      agoraAppId: agoraAppId,
      agoraToken: agoraToken,
      agoraUid: agoraUid,
      peerName: peerName ?? this.peerName,
      peerId: peerId,
      peerProfilePicUrl: peerProfilePicUrl ?? this.peerProfilePicUrl,
      isOutgoing: isOutgoing,
    );
  }
}
