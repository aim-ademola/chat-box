import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/model/status_item_model.dart';
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
                      widget.statuses.length,
                      (index) => Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(
                            right: index == widget.statuses.length - 1 ? 0 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: index <= _currentIndex
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
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
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.statuses.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final status = widget.statuses[index];
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
                          if (status.url != null && status.url!.isNotEmpty) ...[
                            if (status.type == 'video')
                              _VideoStatusTile(url: status.url!)
                            else
                              ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.network(
                                  status.url ?? "",
                                  height: 260,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            const SizedBox(height: 24),
                          ],
                          Text(
                            status.content ?? 'No caption',
                            textAlign: TextAlign.center,
                            style: AppStyle.circularTextStyle(
                              size: 24,
                              weight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
