import 'package:flutter/material.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/model/chat_message_model.dart';
import 'package:frontend/provider/core_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

class ChatMessageBubbleWidget extends StatelessWidget {
  const ChatMessageBubbleWidget({
    super.key,
    required this.message,
    this.onLongPress,
    this.onPollVote,
    this.isTranslating = false,
    this.isTranscribing = false,
  });

  final ChatMessageModel message;
  final VoidCallback? onLongPress;
  final ValueChanged<int>? onPollVote;
  final bool isTranslating;
  final bool isTranscribing;

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
        return _VoiceMessageBubble(
          message: message,
          bubbleColor: bubbleColor,
          textColor: textColor,
          onLongPress: onLongPress,
          isTranscribing: isTranscribing,
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
      case ChatMessageType.video:
        return InkWell(
          onTap: () => _openVideoPlayer(context),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.messageSheet.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 34,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Video shared',
                        style: AppStyle.circularTextStyle(
                          size: 15,
                          weight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to open',
                        style: AppStyle.circularTextStyle(
                          size: 12,
                          weight: FontWeight.w600,
                          color: palette.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      case ChatMessageType.poll:
        final totalVotes = message.pollTotalVotes;
        return Container(
          constraints: const BoxConstraints(maxWidth: 330),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.poll_outlined, size: 19, color: textColor),
                  const SizedBox(width: 8),
                  Text(
                    'Poll',
                    style: AppStyle.circularTextStyle(
                      size: 13,
                      weight: FontWeight.w800,
                      color: textColor.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                message.pollQuestion ?? message.text ?? 'Poll',
                style: AppStyle.circularTextStyle(
                  size: 16,
                  weight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < message.pollOptions.length; i++) ...[
                _PollOptionTile(
                  label: message.pollOptions[i],
                  voteCount: message.pollVotes[i]?.length ?? 0,
                  totalVotes: totalVotes,
                  isSelected: message.pollMyOptionIndex == i,
                  isMine: message.isMe,
                  onTap: onPollVote == null ? null : () => onPollVote!(i),
                ),
                if (i != message.pollOptions.length - 1)
                  const SizedBox(height: 10),
              ],
              const SizedBox(height: 12),
              Text(
                '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
                style: AppStyle.circularTextStyle(
                  size: 12,
                  weight: FontWeight.w700,
                  color: textColor.withValues(alpha: 0.72),
                ),
              ),
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

  void _openVideoPlayer(BuildContext context) {
    final mediaUrl = message.mediaUrl?.trim();
    if (mediaUrl == null || mediaUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video is not available yet.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _VideoPlayerSheet(url: _normalizedUrl(mediaUrl)),
    );
  }
}

class _VoiceMessageBubble extends StatefulWidget {
  const _VoiceMessageBubble({
    required this.message,
    required this.bubbleColor,
    required this.textColor,
    required this.onLongPress,
    required this.isTranscribing,
  });

  final ChatMessageModel message;
  final Color bubbleColor;
  final Color textColor;
  final VoidCallback? onLongPress;
  final bool isTranscribing;

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  late final AudioPlayer _player;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _load();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final mediaUrl = widget.message.mediaUrl?.trim();
    if (mediaUrl == null || mediaUrl.isEmpty) {
      return;
    }

    try {
      await _player.setUrl(_normalizedUrl(mediaUrl));
      if (!mounted) return;
      setState(() {
        _ready = true;
      });
    } catch (_) {}
  }

  Future<void> _toggle() async {
    if (!_ready) {
      return;
    }

    if (_player.playing) {
      await _player.pause();
      return;
    }

    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }

    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        decoration: BoxDecoration(
          color: widget.bubbleColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<bool>(
                  stream: _player.playingStream,
                  initialData: false,
                  builder: (context, snapshot) {
                    final playing = snapshot.data ?? false;
                    return InkWell(
                      onTap: _toggle,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: widget.message.isMe
                              ? Colors.white.withValues(alpha: 0.92)
                              : colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 30,
                          color: widget.message.isMe
                              ? colorScheme.primary
                              : Colors.white,
                        ),
                      ),
                    );
                  },
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
                          ? widget.textColor.withValues(alpha: 0.35)
                          : widget.textColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Text(
                  'Voice',
                  style: AppStyle.circularTextStyle(
                    size: 16,
                    weight: FontWeight.w600,
                    color: widget.textColor,
                  ),
                ),
              ],
            ),
            if (widget.isTranscribing ||
                (widget.message.transcriptionText ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.message.isMe
                      ? Colors.white.withValues(alpha: 0.14)
                      : colorScheme.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: widget.isTranscribing
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: widget.textColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Transcribing...',
                            style: AppStyle.circularTextStyle(
                              size: 14,
                              weight: FontWeight.w700,
                              color: widget.textColor,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        widget.message.transcriptionText!,
                        style: AppStyle.circularTextStyle(
                          size: 15,
                          weight: FontWeight.w600,
                          color: widget.textColor,
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
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

class _VideoPlayerSheet extends StatefulWidget {
  const _VideoPlayerSheet({required this.url});

  final String url;

  @override
  State<_VideoPlayerSheet> createState() => _VideoPlayerSheetState();
}

class _VideoPlayerSheetState extends State<_VideoPlayerSheet> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() {
        _ready = true;
      });
      await _controller.play();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Video',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: _ready ? _controller.value.aspectRatio : 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _ready
                    ? VideoPlayer(_controller)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
            const SizedBox(height: 14),
            if (_ready)
              Row(
                children: [
                  IconButton.filled(
                    onPressed: () {
                      setState(() {
                        _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play();
                      });
                    },
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  Expanded(
                    child: VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.white,
                        bufferedColor: Colors.white38,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PollOptionTile extends StatelessWidget {
  const _PollOptionTile({
    required this.label,
    required this.voteCount,
    required this.totalVotes,
    required this.isSelected,
    required this.isMine,
    this.onTap,
  });

  final String label;
  final int voteCount;
  final int totalVotes;
  final bool isSelected;
  final bool isMine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percent = totalVotes == 0 ? 0.0 : voteCount / totalVotes;
    final foreground = isMine ? colorScheme.onPrimary : colorScheme.onSurface;
    final fillColor = isMine
        ? Colors.white.withValues(alpha: 0.18)
        : colorScheme.primary.withValues(alpha: 0.11);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 48,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: fillColor.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isMine ? Colors.white : colorScheme.primary)
                : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: percent.clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.18)
                      : colorScheme.primary.withValues(alpha: 0.16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: foreground,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyle.circularTextStyle(
                        size: 14,
                        weight: FontWeight.w800,
                        color: foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$voteCount',
                    style: AppStyle.circularTextStyle(
                      size: 13,
                      weight: FontWeight.w900,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
