import 'package:flutter/material.dart';

class CallItemModel {
  const CallItemModel({
    required this.name,
    required this.callTime,
    required this.initials,
    required this.avatarColor,
    required this.imagePath,
    this.profilePicUrl,
    this.userId,
    this.isMissed = false,
    this.isVideoCall = false,
    this.isIncoming = false,
  });

  final String name;
  final String callTime;
  final String initials;
  final Color avatarColor;
  final String? profilePicUrl;
  final String? userId;
  final String? imagePath;

  final bool isMissed;
  final bool isVideoCall;
  final bool isIncoming;
}
