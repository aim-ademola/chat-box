import 'package:flutter/material.dart';
import 'package:frontend/core/constant/app_colors.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/model/message_item_model.dart';
import 'package:frontend/model/user_model.dart';
import 'package:frontend/screens/home/chat_detail.dart';
import 'package:frontend/widget/profile_avatar_widget.dart';
import 'package:frontend/widget/profile_info_widget.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key, required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final displayName = user.name.trim().isEmpty
        ? 'ChatBox User'
        : user.name.trim();
    final bio = user.bio.trim().isEmpty
        ? 'Hey, I am using ChatBox'
        : user.bio.trim();
    final initials = _initials(displayName);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ProfileAvatarWidget(
              initials: initials,
              backgroundColor: const Color(0xFFC8C5F7),
              radius: 46,
              profilePicUrl: user.profilePicUrl,
            ),
            const SizedBox(height: 10),
            Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyle.carosLargeStyle.copyWith(
                fontSize: 18,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              bio,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyle.circularSmallStyle.copyWith(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                ),
                child: ListView(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openChat(context, initials),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Message'),
                    ),
                    const SizedBox(height: 24),
                    ProfileInfoTileWidget(
                      title: 'Display Name',
                      value: displayName,
                    ),
                    const SizedBox(height: 15),
                    ProfileInfoTileWidget(title: 'Email', value: user.email),
                    const SizedBox(height: 15),
                    ProfileInfoTileWidget(title: 'Bio', value: bio),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(BuildContext context, String initials) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          contact: MessageItemModel(
            name: user.name,
            message: user.bio,
            time: 'Active now',
            initials: initials,
            avatarColor: const Color(0xFFC8C5F7),
            statusColor: const Color(0xFF1EDB76),
            profilePicUrl: user.profilePicUrl,
            userId: user.id,
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

    final value = parts.map((part) => part[0].toUpperCase()).join();
    return value.isEmpty ? 'U' : value;
  }
}
