import 'package:flutter/material.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/model/chat_message_model.dart';
import 'package:frontend/model/message_item_model.dart';
import 'package:frontend/widget/chat_message_bubble_widget.dart';
import 'package:frontend/widget/user_avatar_widget.dart';

class ChatThreadItemWidget extends StatelessWidget {
  const ChatThreadItemWidget({
    super.key,
    required this.contact,
    required this.message,
    this.onMessageLongPress,
    this.onPollVote,
    this.isTranslating = false,
    this.isTranscribing = false,
  });

  final MessageItemModel contact;
  final ChatMessageModel message;
  final VoidCallback? onMessageLongPress;
  final ValueChanged<int>? onPollVote;
  final bool isTranslating;
  final bool isTranscribing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;

    if (message.isMe) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ChatMessageBubbleWidget(
            message: message,
            onLongPress: onMessageLongPress,
            onPollVote: onPollVote,
            isTranslating: isTranslating,
            isTranscribing: isTranscribing,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.time,
                  style: AppStyle.circularTextStyle(
                    size: 14,
                    weight: FontWeight.w500,
                    color: palette.secondaryText,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                  size: 17,
                  color: message.isRead
                      ? colorScheme.primary
                      : palette.secondaryText,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatarWidget(
          initials: contact.isGroup
              ? _initials(message.senderName ?? contact.name)
              : contact.initials,
          backgroundColor: contact.avatarColor,
          radius: 26,
          profilePicUrl: contact.isGroup
              ? message.senderProfilePicUrl
              : contact.profilePicUrl,
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.showSender) ...[
                Text(
                  contact.isGroup
                      ? (message.senderName ?? 'Group member')
                      : contact.name,
                  style: AppStyle.circularTextStyle(
                    size: 20,
                    weight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ChatMessageBubbleWidget(
                message: message,
                onLongPress: onMessageLongPress,
                onPollVote: onPollVote,
                isTranslating: isTranslating,
                isTranscribing: isTranscribing,
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  message.time,
                  style: AppStyle.circularTextStyle(
                    size: 14,
                    weight: FontWeight.w500,
                    color: palette.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    final initials = parts.map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? 'U' : initials;
  }
}
