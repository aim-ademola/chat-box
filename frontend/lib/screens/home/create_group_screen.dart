import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/model/message_item_model.dart';
import 'package:frontend/model/user_model.dart';
import 'package:frontend/provider/contacts_provider.dart';
import 'package:frontend/provider/recent_chat_provider.dart';
import 'package:frontend/repositry/chat_repositry.dart';
import 'package:frontend/screens/home/chat_detail.dart';
import 'package:frontend/widget/user_avatar_widget.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  static const _avatarPalette = [
    Color(0xFFF3A4B1),
    Color(0xFFFFC94D),
    Color(0xFFD7E0F4),
    Color(0xFFD9E8E5),
    Color(0xFFC8C5F7),
  ];

  final TextEditingController _nameController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup(List<UserModel> users) async {
    final title = _nameController.text.trim();
    if (title.isEmpty) {
      _showSnackBar('Add a group name first.');
      return;
    }

    if (_selectedUserIds.length < 2) {
      _showSnackBar('Choose at least two people.');
      return;
    }

    setState(() {
      _creating = true;
    });

    try {
      final summary = await ref
          .read(chatRepositryProvider)
          .createGroup(title: title, memberIds: _selectedUserIds.toList());
      ref.invalidate(recentChatsProvider);

      if (!mounted) return;

      final item = _messageItemFromSummary(summary, title);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ChatDetailScreen(contact: item)),
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  MessageItemModel _messageItemFromSummary(
    Map<String, dynamic> summary,
    String fallbackTitle,
  ) {
    final peer = summary['peer'] is Map
        ? Map<String, dynamic>.from(summary['peer'] as Map)
        : <String, dynamic>{};
    final memberIds = peer['memberIds'] is List
        ? List<dynamic>.from(peer['memberIds'] as List)
        : const <dynamic>[];
    final name = peer['name']?.toString().trim();
    final displayName = name == null || name.isEmpty ? fallbackTitle : name;

    return MessageItemModel(
      name: displayName,
      message: 'Group created',
      time: 'Just now',
      initials: _initials(displayName),
      avatarColor: const Color(0xFFD9E8E5),
      statusColor: const Color(0xFF24786D),
      conversationId: summary['conversationId']?.toString(),
      profilePicUrl: peer['profilePicUrl']?.toString(),
      isGroup: true,
      memberCount: memberIds.length,
      memberIds: memberIds.map((memberId) => memberId.toString()).toList(),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    final initials = parts.map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? 'G' : initials;
  }

  Color _avatarColor(String seed) {
    return _avatarPalette[seed.hashCode.abs() % _avatarPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;
    final contactsState = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: palette.headerBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(52, 52),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      'New Group',
                      textAlign: TextAlign.center,
                      style: AppStyle.circularTextStyle(
                        size: 16,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 52),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                decoration: BoxDecoration(
                  color: palette.messageSheet,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(42),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 74,
                      height: 6,
                      decoration: BoxDecoration(
                        color: palette.handle,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Group name',
                          hintStyle: AppStyle.circularTextStyle(
                            size: 16,
                            weight: FontWeight.w500,
                            color: palette.secondaryText,
                          ),
                          border: InputBorder.none,
                          icon: Icon(
                            Icons.groups_2_outlined,
                            color: colorScheme.primary,
                          ),
                        ),
                        style: AppStyle.circularTextStyle(
                          size: 17,
                          weight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Text(
                          'Add members',
                          style: AppStyle.circularTextStyle(
                            size: 22,
                            weight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_selectedUserIds.length} selected',
                          style: AppStyle.circularTextStyle(
                            size: 14,
                            weight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: contactsState.when(
                        data: (users) {
                          if (users.isEmpty) {
                            return Center(
                              child: Text(
                                'No contacts available.',
                                style: AppStyle.circularTextStyle(
                                  color: palette.secondaryText,
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final isSelected = _selectedUserIds.contains(
                                user.id,
                              );

                              return _SelectableMemberTile(
                                user: user,
                                isSelected: isSelected,
                                avatarColor: _avatarColor(user.id),
                                initials: _initials(user.name),
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedUserIds.remove(user.id);
                                    } else {
                                      _selectedUserIds.add(user.id);
                                    }
                                  });
                                },
                              );
                            },
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 18),
                            itemCount: users.length,
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stackTrace) => Center(
                          child: Text(
                            error.toString(),
                            textAlign: TextAlign.center,
                            style: AppStyle.circularTextStyle(
                              color: palette.secondaryText,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: contactsState.when(
                        data: (users) => FilledButton.icon(
                          onPressed: _creating
                              ? null
                              : () => _createGroup(users),
                          icon: _creating
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Create Group'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: 'circular',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (error, stackTrace) => const SizedBox.shrink(),
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
}

class _SelectableMemberTile extends StatelessWidget {
  const _SelectableMemberTile({
    required this.user,
    required this.isSelected,
    required this.avatarColor,
    required this.initials,
    required this.onTap,
  });

  final UserModel user;
  final bool isSelected;
  final Color avatarColor;
  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              UserAvatarWidget(
                initials: initials,
                backgroundColor: avatarColor,
                radius: 28,
                profilePicUrl: user.profilePicUrl,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: AppStyle.circularTextStyle(
                        size: 18,
                        weight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      user.bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyle.circularTextStyle(
                        size: 14,
                        weight: FontWeight.w500,
                        color: palette.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : palette.secondaryText.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        size: 19,
                        color: colorScheme.onPrimary,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
