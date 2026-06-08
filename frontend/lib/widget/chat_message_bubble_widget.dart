import 'package:flutter/material.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/model/chat_message_model.dart';
import 'package:frontend/provider/core_provider.dart';

class ChatMessageBubbleWidget extends StatelessWidget {
  const ChatMessageBubbleWidget({
    super.key,
    required this.message,
    this.onLongPress,
    this.isTranslating = false,
  });

  final ChatMessageModel message;
  final VoidCallback? onLongPress;
  final bool isTranslating;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;
    final bubbleColor = message.isMe
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.38);
    final textColor = message.isMe
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    switch (message.type) {
      case ChatMessageType.text:
        return GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text ?? '',
                  style: AppStyle.circularTextStyle(
                    size: 16,
                    weight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                if (isTranslating ||
                    (message.translatedText ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: message.isMe
                          ? Colors.white.withValues(alpha: 0.14)
                          : colorScheme.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.translate_rounded,
                              size: 15,
                              color: message.isMe
                                  ? colorScheme.onPrimary.withValues(
                                      alpha: 0.82,
                                    )
                                  : colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isTranslating
                                  ? 'AI translation'
                                  : message.translationLanguage ??
                                        'Translation',
                              style: AppStyle.circularTextStyle(
                                size: 12,
                                weight: FontWeight.w800,
                                color: message.isMe
                                    ? colorScheme.onPrimary.withValues(
                                        alpha: 0.82,
                                      )
                                    : colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (isTranslating)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Translating...',
                                style: AppStyle.circularTextStyle(
                                  size: 14,
                                  weight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            message.translatedText!,
                            style: AppStyle.circularTextStyle(
                              size: 15,
                              weight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      case ChatMessageType.voice:
        return Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: message.isMe
                      ? Colors.white.withValues(alpha: 0.92)
                      : colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 30,
                  color: message.isMe ? colorScheme.primary : Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              ...List.generate(
                18,
                (index) => Container(
                  width: 4,
                  height: 10 + (index % 5) * 4,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: index > 11
                        ? textColor.withValues(alpha: 0.35)
                        : textColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(
                message.voiceDuration ?? '00:16',
                style: AppStyle.circularTextStyle(
                  size: 16,
                  weight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        );
      case ChatMessageType.image:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: palette.messageSheet.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < message.imageUrls.take(2).length; i++)
                    Padding(
                      padding: EdgeInsets.only(right: i == 0 ? 8 : 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          _normalizedUrl(message.imageUrls[i]),
                          width: 142,
                          height: 142,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                ],
              ),
              if ((message.text ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    message.text!,
                    style: AppStyle.circularTextStyle(
                      size: 15,
                      weight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
    }
  }

  String _normalizedUrl(String value) {
    final cleaned = value.trim();
    final uri = Uri.tryParse(cleaned);
    if (uri != null && uri.hasScheme) {
      return cleaned;
    }

    final baseUri = Uri.parse(apiBaseUrl);
    final normalizedPath = cleaned.startsWith('/') ? cleaned : '/$cleaned';
    return baseUri.replace(path: normalizedPath).toString();
  }
}
