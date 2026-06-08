import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/model/message_item_model.dart';
import 'package:frontend/model/user_model.dart';
import 'package:frontend/provider/contacts_provider.dart';
import 'package:frontend/provider/recent_chat_provider.dart';
import 'package:frontend/repositry/chat_repositry.dart';
import 'package:frontend/widget/user_avatar_widget.dart';
import 'package:image_picker/image_picker.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  const GroupInfoScreen({super.key, required this.group});

  final MessageItemModel group;

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  static const _avatarPalette = [
    Color(0xFFF3A4B1),
    Color(0xFFFFC94D),
    Color(0xFFD7E0F4),
    Color(0xFFD9E8E5),
    Color(0xFFC8C5F7),
  ];

  final TextEditingController _titleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? _groupData;
  bool _loading = true;
  bool _saving = false;
  File? _pickedPhoto;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.group.name;
    _loadGroup();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadGroup() async {
    final groupId = widget.group.conversationId;
    if (groupId == null || groupId.isEmpty) {
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      final data = await ref
          .read(chatRepositryProvider)
          .getGroupDetails(groupId);
      if (!mounted) return;
      setState(() {
        _groupData = data;
        _titleController.text = data['title']?.toString() ?? widget.group.name;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      _showSnackBar('Could not load group info.');
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _pickedPhoto = File(picked.path);
    });
  }

  Future<void> _saveGroup() async {
    final groupId = widget.group.conversationId;
    if (groupId == null || groupId.isEmpty) {
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnackBar('Group name cannot be empty.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final data = await ref
          .read(chatRepositryProvider)
          .updateGroup(
            groupId: groupId,
            title: title,
            profilePic: _pickedPhoto,
          );
      ref.invalidate(recentChatsProvider);
      if (!mounted) return;
      setState(() {
        _groupData = data;
        _pickedPhoto = null;
        _saving = false;
      });
      _showSnackBar('Group updated.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      _showSnackBar('Could not update group.');
    }
  }

  Future<void> _openAddMembersSheet() async {
    final groupId = widget.group.conversationId;
    if (groupId == null || groupId.isEmpty) {
      return;
    }

    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AddMembersSheet(existingMemberIds: _memberIds),
    );

    if (selected == null || selected.isEmpty) {
      return;
    }

    try {
      final data = await ref
          .read(chatRepositryProvider)
          .addGroupMembers(groupId: groupId, memberIds: selected);
      ref.invalidate(recentChatsProvider);
      if (!mounted) return;
      setState(() {
        _groupData = data;
      });
      _showSnackBar('Members added.');
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Could not add members.');
    }
  }

  Future<void> _removeMember(UserModel member) async {
    final groupId = widget.group.conversationId;
    if (groupId == null || groupId.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('Remove ${member.name} from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final data = await ref
          .read(chatRepositryProvider)
          .removeGroupMember(groupId: groupId, memberId: member.id);
      ref.invalidate(recentChatsProvider);
      if (!mounted) return;
      setState(() {
        _groupData = data;
      });
      _showSnackBar('Member removed.');
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Could not remove member.');
    }
  }

  List<UserModel> get _members {
    final rawMembers = _groupData?['members'];
    if (rawMembers is! List) {
      return const [];
    }

    return rawMembers
        .whereType<Map>()
        .map((member) => UserModel.fromMap(Map<String, dynamic>.from(member)))
        .toList();
  }

  List<String> get _memberIds {
    final rawMemberIds = _groupData?['memberIds'];
    if (rawMemberIds is! List) {
      return widget.group.memberIds;
    }

    return rawMemberIds.map((memberId) => memberId.toString()).toList();
  }

  String get _groupName =>
      _groupData?['title']?.toString().trim().isNotEmpty == true
      ? _groupData!['title'].toString()
      : widget.group.name;

  String? get _groupPhoto =>
      _groupData?['profilePicUrl']?.toString().trim().isNotEmpty == true
      ? _groupData!['profilePicUrl'].toString()
      : widget.group.profilePicUrl;

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

    return Scaffold(
      backgroundColor: palette.headerBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      'Group Info',
                      textAlign: TextAlign.center,
                      style: AppStyle.circularTextStyle(
                        size: 16,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
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
                ),
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: colorScheme.primary,
                        ),
                      )
                    : ListView(
                        children: [
                          Center(
                            child: Container(
                              width: 74,
                              height: 6,
                              decoration: BoxDecoration(
                                color: palette.handle,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _pickedPhoto == null
                                    ? UserAvatarWidget(
                                        initials: _initials(_groupName),
                                        backgroundColor: const Color(
                                          0xFFD9E8E5,
                                        ),
                                        radius: 48,
                                        profilePicUrl: _groupPhoto,
                                        isGroup: true,
                                      )
                                    : ClipOval(
                                        child: Image.file(
                                          _pickedPhoto!,
                                          width: 96,
                                          height: 96,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: IconButton.filled(
                                    onPressed: _pickPhoto,
                                    icon: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),
                          _GroupSection(
                            title: 'Group details',
                            child: Column(
                              children: [
                                TextField(
                                  controller: _titleController,
                                  decoration: InputDecoration(
                                    labelText: 'Group name',
                                    prefixIcon: Icon(
                                      Icons.groups_2_outlined,
                                      color: colorScheme.primary,
                                    ),
                                    filled: true,
                                    fillColor: colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.35),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _saving ? null : _saveGroup,
                                    icon: _saving
                                        ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: colorScheme.onPrimary,
                                            ),
                                          )
                                        : const Icon(Icons.save_rounded),
                                    label: const Text('Save changes'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          _GroupSection(
                            title: '${_members.length} members',
                            trailing: TextButton.icon(
                              onPressed: _openAddMembersSheet,
                              icon: const Icon(Icons.person_add_alt_rounded),
                              label: const Text('Add'),
                            ),
                            child: Column(
                              children: [
                                for (final member in _members) ...[
                                  _MemberTile(
                                    member: member,
                                    initials: _initials(member.name),
                                    avatarColor: _avatarColor(member.id),
                                    onRemove: _members.length <= 2
                                        ? null
                                        : () => _removeMember(member),
                                  ),
                                  if (member != _members.last)
                                    const Divider(height: 24),
                                ],
                              ],
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

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppStyle.circularTextStyle(
                  size: 20,
                  weight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.initials,
    required this.avatarColor,
    this.onRemove,
  });

  final UserModel member;
  final String initials;
  final Color avatarColor;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;

    return Row(
      children: [
        UserAvatarWidget(
          initials: initials,
          backgroundColor: avatarColor,
          radius: 26,
          profilePicUrl: member.profilePicUrl,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.name,
                style: AppStyle.circularTextStyle(
                  size: 17,
                  weight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                member.bio,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyle.circularTextStyle(
                  size: 13,
                  weight: FontWeight.w500,
                  color: palette.secondaryText,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Remove member',
          onPressed: onRemove,
          icon: Icon(
            Icons.person_remove_outlined,
            color: onRemove == null ? palette.inactiveIcon : colorScheme.error,
          ),
        ),
      ],
    );
  }
}

class _AddMembersSheet extends ConsumerStatefulWidget {
  const _AddMembersSheet({required this.existingMemberIds});

  final List<String> existingMemberIds;

  @override
  ConsumerState<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends ConsumerState<_AddMembersSheet> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;
    final contactsState = ref.watch(contactsProvider);

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: palette.handle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add members',
                      style: AppStyle.circularTextStyle(
                        size: 24,
                        weight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selectedIds.toList()),
                    child: const Text('Done'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: contactsState.when(
                  data: (users) {
                    final available = users
                        .where(
                          (user) => !widget.existingMemberIds.contains(user.id),
                        )
                        .toList();
                    if (available.isEmpty) {
                      return Center(
                        child: Text(
                          'Everyone in your contacts is already here.',
                          textAlign: TextAlign.center,
                          style: AppStyle.circularTextStyle(
                            color: palette.secondaryText,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemBuilder: (context, index) {
                        final user = available[index];
                        final selected = _selectedIds.contains(user.id);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: UserAvatarWidget(
                            initials: _initials(user.name),
                            backgroundColor: const Color(0xFFD9E8E5),
                            radius: 25,
                            profilePicUrl: user.profilePicUrl,
                          ),
                          title: Text(user.name),
                          subtitle: Text(
                            user.bio,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Checkbox(
                            value: selected,
                            onChanged: (_) {
                              setState(() {
                                if (selected) {
                                  _selectedIds.remove(user.id);
                                } else {
                                  _selectedIds.add(user.id);
                                }
                              });
                            },
                          ),
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedIds.remove(user.id);
                              } else {
                                _selectedIds.add(user.id);
                              }
                            });
                          },
                        );
                      },
                      separatorBuilder: (context, index) =>
                          const Divider(height: 18),
                      itemCount: available.length,
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) =>
                      Center(child: Text(error.toString())),
                ),
              ),
            ],
          ),
        ),
      ),
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
