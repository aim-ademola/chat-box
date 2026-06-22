import 'package:flutter/material.dart';

class CallItemModel {
  const CallItemModel({
    this.id,
    this.conversationId,
    required this.name,
    required this.callTime,
    required this.initials,
    required this.avatarColor,
    this.imagePath,
    this.profilePicUrl,
    this.userId,
    this.status,
    this.callType,
    this.durationSeconds,
    this.isMissed = false,
    this.isVideoCall = false,
    this.isIncoming = false,
    this.recordingUrl,
    this.transcript,
  });

  final String? id;
  final String? conversationId;
  final String name;
  final String callTime;
  final String initials;
  final Color avatarColor;
  final String? profilePicUrl;
  final String? userId;
  final String? imagePath;
  final String? status;
  final String? callType;
  final int? durationSeconds;
  final String? recordingUrl;
  final String? transcript;

  final bool isMissed;
  final bool isVideoCall;
  final bool isIncoming;

  factory CallItemModel.fromMap(Map<String, dynamic> map) {
    final peer = map['peer'] is Map
        ? Map<String, dynamic>.from(map['peer'] as Map)
        : <String, dynamic>{};
    final peerName = peer['name']?.toString() ?? 'Unknown';
    final status = map['status']?.toString() ?? '';
    final callType = map['callType']?.toString() ?? 'audio';
    final isOutgoing = map['isOutgoing'] == true;

    return CallItemModel(
      id: map['id']?.toString(),
      conversationId: map['conversationId']?.toString(),
      name: peerName,
      callTime: _formatCallTime(map['startedAt']?.toString()),
      initials: _initials(peerName),
      avatarColor: _avatarColor(peer['id']?.toString() ?? peerName),
      profilePicUrl: peer['profilePicUrl']?.toString(),
      userId: peer['id']?.toString(),
      status: status,
      callType: callType,
      durationSeconds: int.tryParse(map['durationSeconds']?.toString() ?? ''),
      isMissed: status == 'missed' || status == 'rejected',
      isVideoCall: callType == 'video',
      isIncoming: !isOutgoing,
      recordingUrl: map['recordingUrl']?.toString(),
      transcript: map['transcript']?.toString(),
    );
  }

  static String _formatCallTime(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    if (parsed == null) {
      return 'Unknown time';
    }

    final now = DateTime.now();
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = parsed.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$minute $period';

    if (_sameDay(parsed, now)) {
      return 'Today, $time';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (_sameDay(parsed, yesterday)) {
      return 'Yesterday, $time';
    }

    return '${parsed.month}/${parsed.day}/${parsed.year}, $time';
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();

    final initials = parts.map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? 'U' : initials;
  }

  static Color _avatarColor(String seed) {
    const palette = [
      Colors.blue,
      Colors.orange,
      Colors.pink,
      Colors.grey,
      Colors.brown,
      Colors.teal,
    ];

    return palette[seed.hashCode.abs() % palette.length];
  }
}
