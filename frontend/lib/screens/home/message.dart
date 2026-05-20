import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_images.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/extention/build_context_ext.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/model/message_item_model.dart';
import 'package:frontend/model/story_item_model.dart';
import 'package:frontend/model/user_model.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/recent_chat_provider.dart';
import 'package:frontend/provider/status_provider.dart';
import 'package:frontend/screens/home/chat_detail.dart';
import 'package:frontend/screens/home/status_preview.dart';
import 'package:frontend/screens/home/upload_status.dart';
import 'package:frontend/widget/circle_icon_button_widget.dart';
import 'package:frontend/widget/message_tile_widget.dart';
import 'package:frontend/widget/story_avatar_widget.dart';
import 'package:frontend/widget/user_avatar_widget.dart';

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

  Future<void> _openMyStatus(UserModel? user) async {
    if (user == null || user.id.isEmpty) {
      return;
    }

    final statuses = await ref
        .read(statusProvider.notifier)
        .fetchStatusesByUser(user.id);

    if (!mounted) {
      return;
    }

    if (statuses.isEmpty || (statuses.first.statuses ?? []).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have not posted a status yet.')),
      );
      return;
    }

    final story = statuses.first;
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

  Future<void> _openStatusPreview(StoryItemModel story) async {
    if (story.userId == null) {
      return;
    }

    var previewStory = story;
    var statusItems = story.statuses ?? [];

    if (statusItems.isEmpty) {
      final statuses = await ref
          .read(statusProvider.notifier)
          .fetchStatusesByUser(story.userId!);

      if (statuses.isNotEmpty) {
        previewStory = statuses.first;
        statusItems = previewStory.statuses ?? [];
      }
    }

    if (!mounted || statusItems.isEmpty) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusPreviewScreen(
          userName: previewStory.name,
          userInitials: previewStory.initials,
          userProfilePicUrl: previewStory.profilePicUrl ?? '',
          statuses: statusItems,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider).value;
    final statusesState = ref.watch(statusProvider);
    final recentChatsState = ref.watch(recentChatsProvider);
    final myStory = _myStoryFor(user);

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
                        size: 16,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      await ref.read(authProvider.notifier).me();
                      await ref.read(statusProvider.notifier).fetchStatuses();
                    },
                    child: UserAvatarWidget(
                      initials: _initials(user?.name ?? ''),
                      backgroundColor: const Color(0xFFC8C5F7),
                      radius: 28,
                      profilePicUrl: user?.profilePicUrl,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 168,
              child: statusesState.when(
                data: (statuses) {
                  final stories = <StoryItemModel>[myStory, ...statuses];
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final story = stories[index];
                      return StoryAvatarWidget(
                        item: story,
                        onTap: story.isMine
                            ? () => _openMyStatus(user)
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
                      item: myStory,
                      onTap: () => _openMyStatus(user),
                      onAddTap: _openUploadStatus,
                    ),
                  ],
                ),
                error: (error, stackTrace) => ListView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                  scrollDirection: Axis.horizontal,
                  children: [
                    StoryAvatarWidget(
                      item: myStory,
                      onTap: () => _openMyStatus(user),
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

  StoryItemModel _myStoryFor(UserModel? user) {
    final displayName = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'My status';

    return StoryItemModel(
      name: 'My status',
      initials: _initials(displayName),
      backgroundColor: const Color(0xFFD9E8E5),
      ringColor: const Color(0xFF5CB6AA),
      profilePicUrl: user?.profilePicUrl,
      userId: user?.id,
      isMine: true,
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();

    final value = parts.map((part) => part[0].toUpperCase()).join();
    return value.isEmpty ? 'ME' : value;
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
