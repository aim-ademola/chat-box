import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/extention/build_context_ext.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/widget/profile_info_widget.dart';
import 'package:frontend/widget/user_avatar_widget.dart';

class Profile extends ConsumerWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final displayName = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'ChatBox User';
    final bio = user?.bio.trim().isNotEmpty == true
        ? user!.bio.trim()
        : 'Hey, I am using ChatBox';
    final email = user?.email.trim().isNotEmpty == true
        ? user!.email.trim()
        : 'No email available';
    final initials = _initials(displayName);

    return DecoratedBox(
      decoration: BoxDecoration(color: context.palette.headerBackground),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            UserAvatarWidget(
              initials: initials,
              backgroundColor: Color(0xFFFFC746),
              radius: 42,
              profilePicUrl: user?.profilePicUrl,
            ),

            const SizedBox(height: 8),

            Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyle.carosLargeStyle.copyWith(
                fontSize: 16,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyle.circularSmallStyle.copyWith(
                fontSize: 13,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.palette.messageSheet,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
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
                child: ListView(
                  children: [
                    Center(
                      child: Container(
                        width: 76,
                        height: 6,
                        decoration: BoxDecoration(
                          color: context.palette.handle,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),

                    ProfileInfoTileWidget(
                      title: "Display Name",
                      value: displayName,
                    ),

                    SizedBox(height: 15),

                    ProfileInfoTileWidget(title: "Email Address", value: email),

                    SizedBox(height: 15),

                    ProfileInfoTileWidget(title: "Bio", value: bio),

                    SizedBox(height: 15),

                    ProfileInfoTileWidget(
                      title: "User ID",
                      value: user?.id ?? 'Unavailable',
                    ),

                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
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
