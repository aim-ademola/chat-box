import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_images.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/extention/build_context_ext.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/model/message_item_model.dart';
import 'package:frontend/model/story_item_model.dart';
import 'package:frontend/provider/recent_chat_provider.dart';
import 'package:frontend/provider/status_provider.dart';
import 'package:frontend/screens/home/chat_detail.dart';
import 'package:frontend/screens/home/status_preview.dart';
import 'package:frontend/screens/home/upload_status.dart';
import 'package:frontend/widget/circle_icon_button_widget.dart';
import 'package:frontend/widget/message_tile_widget.dart';
import 'package:frontend/widget/profile_avatar_widget.dart';
import 'package:frontend/widget/story_avatar_widget.dart';

var _myStory = StoryItemModel(
  name: 'My status',
  initials: 'ME',
  backgroundColor: Color(0xFFD9E8E5),
  ringColor: Color(0xFF5CB6AA),
  isMine: true,
);

class MessageScreen extends ConsumerStatefulWidget {
  const MessageScreen({super.key});

  @override
  ConsumerState<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends ConsumerState<MessageScreen> {
  Future<void> _openUploadStatus() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UploadStatusScreen()),
    );
    if (mounted) {
      await ref.read(statusProvider.notifier).fetchStatuses();
    }
  }

  Future<void> _openChat(MessageItemModel message) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatDetailScreen(contact: message)),
    );
    if (mounted) {
      ref.invalidate(recentChatsProvider);
    }
  }

  Future<void> _openStatusPreview(StoryItemModel story) async {
    if (story.userId == null) {
      return;
    }

    final statuses = await ref
        .read(statusProvider.notifier)
        .fetchStatusesByUser(story.userId!);

    if (!mounted || statuses.isEmpty) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusPreviewScreen(
          userName: story.name,
          userInitials: story.initials,
          userProfilePicUrl: story.profilePicUrl ?? '',
          statuses: story.statuses ?? [],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusesState = ref.watch(statusProvider);
    final recentChatsState = ref.watch(recentChatsProvider);

    return DecoratedBox(
      decoration: BoxDecoration(color: context.palette.headerBackground),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
              child: Row(
                children: [
                  CircleIconButtonWidget(
                    icon: AppImages.search,
                    borderColor: context.palette.searchBorder,
                  ),
                  Expanded(
                    child: Text(
                      'Home',
                      textAlign: TextAlign.center,
                      style: AppStyle.circularTextStyle(
                        size: 28,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      print("Hello iam started");
                      await ref.watch(statusProvider.notifier).fetchStatuses();
                      print("Am done");
                    },
                    child: const ProfileAvatarWidget(
                      initials: 'AM',
                      backgroundColor: Color(0xFFC8C5F7),
                      radius: 28,
                      profilePicUrl: '',
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 168,
              child: statusesState.when(
                data: (statuses) {
                  final stories = <StoryItemModel>[_myStory, ...statuses];
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final story = stories[index];
                      return StoryAvatarWidget(
                        item: story,
                        onTap: story.isMine
                            ? _openUploadStatus
                            : () => _openStatusPreview(story),
                        onAddTap: story.isMine ? _openUploadStatus : null,
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 20),
                    itemCount: stories.length,
                  );
                },
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                  scrollDirection: Axis.horizontal,
                  children: [
                    StoryAvatarWidget(
                      item: _myStory,
                      onTap: _openUploadStatus,
                      onAddTap: _openUploadStatus,
                    ),
                  ],
                ),
                error: (error, stackTrace) => ListView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                  scrollDirection: Axis.horizontal,
                  children: [
                    StoryAvatarWidget(
                      item: _myStory,
                      onTap: _openUploadStatus,
                      onAddTap: _openUploadStatus,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.palette.messageSheet,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(42),
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
                        color: context.palette.handle,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Expanded(
                      child: recentChatsState.when(
                        data: (messages) {
                          if (messages.isEmpty) {
                            return _buildEmptyChatState(
                              colorScheme,
                              context.palette,
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              return MessageTileWidget(
                                item: message,
                                onTap: () => _openChat(message),
                              );
                            },
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 28),
                            itemCount: messages.length,
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stackTrace) => Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              error.toString(),
                              textAlign: TextAlign.center,
                              style: AppStyle.circularTextStyle(
                                size: 15,
                                weight: FontWeight.w500,
                                color: context.palette.secondaryText,
                              ),
                            ),
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

  Widget _buildEmptyChatState(ColorScheme colorScheme, AppThemeColors palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 54,
              color: palette.secondaryText,
            ),
            const SizedBox(height: 16),
            Text(
              'No recent conversations yet',
              textAlign: TextAlign.center,
              style: AppStyle.circularTextStyle(
                size: 20,
                weight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message from Contacts to see the latest chat here.',
              textAlign: TextAlign.center,
              style: AppStyle.circularTextStyle(
                size: 15,
                weight: FontWeight.w500,
                color: palette.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
