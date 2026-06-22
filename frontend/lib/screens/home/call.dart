import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_images.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/extention/build_context_ext.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/provider/call_provider.dart';
import 'package:frontend/provider/core_provider.dart';
import 'package:frontend/widget/call_tile_widget.dart';
import 'package:frontend/widget/circle_icon_button_widget.dart';
import 'package:just_audio/just_audio.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;
    final calls = ref.watch(recentCallsProvider);

    return Scaffold(
      backgroundColor: palette.headerBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  CircleIconButtonWidget(
                    icon: AppImages.search,
                    borderColor: palette.searchBorder,
                  ),

                  Expanded(
                    child: Center(
                      child: Text(
                        "Calls",
                        style: AppStyle.circularSmallStyle.copyWith(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: palette.searchBorder,
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_call,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: palette.messageSheet,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(38),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: context.isDarkMode ? 0.18 : 0.08,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 14, bottom: 8),
                      width: 76,
                      height: 6,
                      decoration: BoxDecoration(
                        color: palette.handle,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Recent",
                          style: AppStyle.circularMediumStyle.copyWith(
                            fontSize: 18,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Expanded(
                      child: calls.when(
                        data: (items) {
                          if (items.isEmpty) {
                            return Center(
                              child: Text(
                                'No recent calls',
                                style: AppStyle.circularMediumStyle.copyWith(
                                  color: palette.secondaryText,
                                  fontSize: 16,
                                ),
                              ),
                            );
                          }

                          return RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(recentCallsProvider);
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  Divider(color: palette.handle, indent: 70),
                              itemBuilder: (context, index) {
                                final call = items[index];

                                return CallTileWidget(
                                  contact: call,
                                  callTime: call.callTime,
                                  isMissed: call.isMissed,
                                  isVideoCall: call.isVideoCall,
                                  onTap: () => _showMeetingSummarySheet(context, call),
                                );
                              },
                            ),
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, _) => Center(
                          child: TextButton(
                            onPressed: () {
                              ref.invalidate(recentCallsProvider);
                            },
                            child: const Text('Retry loading calls'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMeetingSummarySheet(BuildContext context, CallItemModel call) {
    if (call.recordingUrl == null && call.transcript == null) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Meeting Overview'),
          content: Text(
            'This call with ${call.name} lasted ${call.durationSeconds ?? 0} seconds and was not recorded or summarized by AI.',
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: _MeetingSummarySheet(call: call),
      ),
    );
  }
}

class _MeetingSummarySheet extends StatefulWidget {
  const _MeetingSummarySheet({required this.call});

  final CallItemModel call;

  @override
  State<_MeetingSummarySheet> createState() => _MeetingSummarySheetState();
}

class _MeetingSummarySheetState extends State<_MeetingSummarySheet> {
  late final AudioPlayer _player;
  bool _ready = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    if (widget.call.recordingUrl != null && widget.call.recordingUrl!.isNotEmpty) {
      _loadAudio();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAudio() async {
    setState(() {
      _loading = true;
    });
    try {
      final url = _normalizedUrl(widget.call.recordingUrl!);
      await _player.setUrl(url);
      if (!mounted) return;
      setState(() {
        _ready = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
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

  Future<void> _togglePlay() async {
    if (!_ready) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meeting Summary',
                        style: AppStyle.circularTextStyle(
                          size: 22,
                          weight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Call with ${widget.call.name} • ${widget.call.callTime}',
                        style: AppStyle.circularTextStyle(
                          size: 13,
                          weight: FontWeight.w600,
                          color: palette.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.call.recordingUrl != null && widget.call.recordingUrl!.isNotEmpty) ...[
              Text(
                'Call Recording',
                style: AppStyle.circularTextStyle(
                  size: 15,
                  weight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    _loading
                        ? const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : StreamBuilder<bool>(
                            stream: _player.playingStream,
                            initialData: false,
                            builder: (context, snapshot) {
                              final playing = snapshot.data ?? false;
                              return IconButton.filled(
                                onPressed: _ready ? _togglePlay : null,
                                icon: Icon(
                                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                ),
                              );
                            },
                          ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: StreamBuilder<Duration>(
                        stream: _player.positionStream,
                        initialData: Duration.zero,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration = _player.duration ?? Duration.zero;
                          final progress = duration.inMilliseconds == 0
                              ? 0.0
                              : position.inMilliseconds / duration.inMilliseconds;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: colorScheme.outlineVariant,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position.inSeconds),
                                    style: AppStyle.circularTextStyle(
                                      size: 11,
                                      weight: FontWeight.w600,
                                      color: palette.secondaryText,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(duration.inSeconds),
                                    style: AppStyle.circularTextStyle(
                                      size: 11,
                                      weight: FontWeight.w600,
                                      color: palette.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              'AI Summary & Transcript',
              style: AppStyle.circularTextStyle(
                size: 15,
                weight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.call.transcript ?? 'No summary available.',
                    style: AppStyle.circularTextStyle(
                      size: 14,
                      weight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
