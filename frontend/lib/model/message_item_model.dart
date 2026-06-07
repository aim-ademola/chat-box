import 'package:flutter/material.dart';

class MessageItemModel {
  const MessageItemModel({
    required this.name,
    required this.message,
    required this.time,
    required this.initials,
    required this.avatarColor,
    required this.statusColor,
    this.profilePicUrl,
    this.userId,
    this.conversationId,
    this.unreadCount = 0,
    this.isGroup = false,
    this.memberCount = 0,
  });

  final String name;
  final String message;
  final String time;
  final String initials;
  final Color avatarColor;
  final Color statusColor;
  final String? profilePicUrl;
  final String? userId;
  final String? conversationId;
  final int unreadCount;
  final bool isGroup;
  final int memberCount;

  MessageItemModel copyWith({
    String? name,
    String? message,
    String? time,
    String? initials,
    Color? avatarColor,
    Color? statusColor,
    String? profilePicUrl,
    String? userId,
    String? conversationId,
    int? unreadCount,
    bool? isGroup,
    int? memberCount,
  }) {
    return MessageItemModel(
      name: name ?? this.name,
      message: message ?? this.message,
      time: time ?? this.time,
      initials: initials ?? this.initials,
      avatarColor: avatarColor ?? this.avatarColor,
      statusColor: statusColor ?? this.statusColor,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      userId: userId ?? this.userId,
      conversationId: conversationId ?? this.conversationId,
      unreadCount: unreadCount ?? this.unreadCount,
      isGroup: isGroup ?? this.isGroup,
      memberCount: memberCount ?? this.memberCount,
    );
  }
}
