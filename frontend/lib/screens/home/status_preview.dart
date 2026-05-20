import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/model/status_item_model.dart';
import 'package:frontend/provider/core_provider.dart';
import 'package:frontend/widget/user_avatar_widget.dart';

class StatusPreviewScreen extends ConsumerStatefulWidget {
  const StatusPreviewScreen({
    super.key,
    required this.userName,
    required this.userInitials,
    required this.userProfilePicUrl,
    required this.statuses,
  });

  final String userName;
  final String userInitials;
  final String userProfilePicUrl;
  final List<StatusItemModel> statuses;

  @override
  ConsumerState<StatusPreviewScreen> createState() =>
      _StatusPreviewScreenState();
}

class _StatusPreviewScreenState extends ConsumerState<StatusPreviewScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _hasStatuses => widget.statuses.isNotEmpty;

  void _goToStatus(int index) {
    if (!_hasStatuses || index < 0 || index >= widget.statuses.length) {
      return;
    }

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _goNext() {
    if (!_hasStatuses) {
      return;
    }

    if (_currentIndex >= widget.statuses.length - 1) {
      Navigator.pop(context);
      return;
    }

    _goToStatus(_currentIndex + 1);
  }

  void _goPrevious() {
    if (_currentIndex == 0) {
      return;
    }

    _goToStatus(_currentIndex - 1);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                children: [
                  Row(
                    children: List.generate(
                      widget.statuses.isEmpty ? 1 : widget.statuses.length,
                      (index) {
                        final isActive =
                            widget.statuses.isEmpty || index <= _currentIndex;
                        final isLast =
                            widget.statuses.isEmpty ||
                            index == widget.statuses.length - 1;

                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: EdgeInsets.only(right: isLast ? 0 : 6),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      UserAvatarWidget(
                        initials: widget.userInitials,
                        backgroundColor: const Color(0xFFFFC94D),
                        radius: 24,
                        profilePicUrl: widget.userProfilePicUrl,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.userName,
                          style: AppStyle.circularTextStyle(
                            size: 16,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _hasStatuses
                  ? Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: widget.statuses.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return _StatusPage(
                              status: widget.statuses[index],
                              colorScheme: colorScheme,
                            );
                          },
                        ),
                        Positioned.fill(
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: _goPrevious,
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: _goNext,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 16,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: IconButton.filledTonal(
                              onPressed: _currentIndex == 0
                                  ? null
                                  : _goPrevious,
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 16,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: IconButton.filledTonal(
                              onPressed: _goNext,
                              icon: Icon(
                                _currentIndex == widget.statuses.length - 1
                                    ? Icons.check_rounded
                                    : Icons.chevron_right_rounded,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 24,
                          bottom: 28,
                          child: FilledButton.icon(
                            onPressed: _goNext,
                            icon: Icon(
                              _currentIndex == widget.statuses.length - 1
                                  ? Icons.check_rounded
                                  : Icons.chevron_right_rounded,
                            ),
                            label: Text(
                              _currentIndex == widget.statuses.length - 1
                                  ? 'Done'
                                  : 'Next',
                            ),
                          ),
                        ),
                      ],
                    )
                  : _EmptyStatusView(colorScheme: colorScheme),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPage extends StatelessWidget {
  const _StatusPage({required this.status, required this.colorScheme});

  final StatusItemModel status;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final type = (status.type ?? 'text').trim().toLowerCase();
    final hasCaption = status.content?.trim().isNotEmpty == true;
    final mediaUrl = _normalizedMediaUrl(status.url);
    final hasMedia = mediaUrl != null;
    final showImage = hasMedia && type == 'image';
    final showVideo = hasMedia && type == 'video';
    final showUnknownMedia =
        hasMedia && type != 'text' && !showImage && !showVideo;
    final showCaption = hasCaption && (type == 'text' || hasMedia);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withValues(alpha: 0.92),
              const Color(0xFF103A35),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showVideo) ...[
              _VideoStatusTile(url: mediaUrl),
              if (showCaption) const SizedBox(height: 24),
            ] else if (showImage || showUnknownMedia) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.network(
                  mediaUrl,
                  height: 320,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _BrokenMediaTile(url: mediaUrl),
                ),
              ),
              if (showCaption) const SizedBox(height: 24),
            ],
            if (showCaption)
              Text(
                status.content!.trim(),
                textAlign: TextAlign.center,
                style: AppStyle.circularTextStyle(
                  size: type == 'text' && !hasMedia ? 28 : 20,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.35,
                ),
              )
            else if (!showImage && !showVideo && !showUnknownMedia)
              Text(
                'No status content',
                textAlign: TextAlign.center,
                style: AppStyle.circularTextStyle(
                  size: 22,
                  weight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.8),
                  height: 1.35,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _normalizedMediaUrl(String? value) {
    final cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(cleaned);
    if (uri != null && uri.hasScheme) {
      return cleaned;
    }

    var path = cleaned.replaceAll('\\', '/');
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    if (!path.startsWith('public/')) {
      path = path.startsWith('status/')
          ? 'public/$path'
          : 'public/status/$path';
    }

    return Uri.parse(apiBaseUrl).replace(path: '/$path').toString();
  }
}

class _EmptyStatusView extends StatelessWidget {
  const _EmptyStatusView({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'No status available',
          textAlign: TextAlign.center,
          style: AppStyle.circularTextStyle(
            size: 22,
            weight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ),
    );
  }
}

class _BrokenMediaTile extends StatelessWidget {
  const _BrokenMediaTile({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            color: Colors.white,
            size: 54,
          ),
          const SizedBox(height: 12),
          Text(
            'Could not load media',
            textAlign: TextAlign.center,
            style: AppStyle.circularTextStyle(
              size: 17,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppStyle.circularTextStyle(
              size: 12,
              weight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoStatusTile extends StatelessWidget {
  const _VideoStatusTile({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.play_circle_outline_rounded,
            color: Colors.white,
            size: 62,
          ),
          const SizedBox(height: 12),
          Text(
            'Video status',
            style: AppStyle.circularTextStyle(
              size: 18,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppStyle.circularTextStyle(
                size: 12,
                weight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
