import 'package:flutter/material.dart';
import 'package:frontend/model/status_item_model.dart';

class StoryItemModel {
  StoryItemModel({
    required this.name,
    required this.initials,
    required this.backgroundColor,
    required this.ringColor,
    this.profilePicUrl,
    this.userId,
    this.isMine = false,
    this.statuses,
  });
  List<StatusItemModel>? statuses;
  final String name;
  final String initials;
  final Color backgroundColor;
  final Color ringColor;
  final String? profilePicUrl;
  final String? userId;
  final bool isMine;
}
