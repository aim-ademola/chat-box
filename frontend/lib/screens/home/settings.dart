import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_images.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/extention/build_context_ext.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/screens/home/profile.dart';
import 'package:frontend/widget/app_button.dart';
import 'package:frontend/model/settings_item_model.dart';
import 'package:frontend/widget/settings_tile_widget.dart';
import 'package:frontend/widget/user_avatar_widget.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final List<SettingsItemModel> settingsItems = [
    SettingsItemModel(
      title: "Account",
      subtitle: "Privacy, security",
      imagePath: AppImages.keys,
      onTap: () {},
    ),

    SettingsItemModel(
      title: "Chat",
      subtitle: "Chat history, theme, wallpapers",
      imagePath: AppImages.messages,
      onTap: () {},
    ),
    SettingsItemModel(
      title: "Notifications",
      subtitle: "Messages, group and others",
      imagePath: AppImages.notificationss,
      onTap: () {},
    ),

    SettingsItemModel(
      title: "Storage and data",
      subtitle: "Network usage, storage usage",
      imagePath: AppImages.data,
      onTap: () {},
    ),
    SettingsItemModel(
      title: "Help",
      subtitle: "FAQs & contact support",
      imagePath: AppImages.help,
      onTap: () {},
    ),
    SettingsItemModel(
      title: "Invite a friend",
      subtitle: "",
      imagePath: AppImages.users,
      onTap: () {},
    ),
  ];

  @override
  Widget build(BuildContext context) {
    var authUser = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final user = authUser.value;
    final displayName = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'ChatBox User';
    final bio = user?.bio.trim().isNotEmpty == true
        ? user!.bio.trim()
        : 'Hey, I am using ChatBox';
    final initials = _initials(displayName);

    return DecoratedBox(
      decoration: BoxDecoration(color: context.palette.headerBackground),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.arrow_back_rounded, color: Colors.white),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Settings",
                        style: AppStyle.circularMediumStyle.copyWith(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),

            const SizedBox(height: 60),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.palette.messageSheet,
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
                child: ListView(
                  padding: const EdgeInsets.all(16),
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
                    const SizedBox(height: 40),

                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => Profile()),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 10,
                        ),
                        child: Row(
                          children: [
                            UserAvatarWidget(
                              initials: initials,
                              backgroundColor: Color(0xFFC8C5F7),
                              radius: 28,
                              profilePicUrl: user?.profilePicUrl,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    authUser.isLoading
                                        ? 'Loading...'
                                        : displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppStyle.circularMediumStyle
                                        .copyWith(
                                          fontSize: 16,
                                          color: colorScheme.onSurface,
                                        ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    bio,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppStyle.circularMediumStyle
                                        .copyWith(
                                          fontSize: 13,
                                          color: context.palette.secondaryText,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.qr_code,
                              color: context.palette.secondaryText,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    ...settingsItems.map(
                      (item) => SettingsTileWidget(item: item),
                    ),

                    SizedBox(height: 20),

                    AppButton(
                      backgroundColor: authUser.isLoading
                          ? context.palette.badge
                          : context.palette.badge,
                      label: authUser.isLoading
                          ? "logging out....."
                          : "Log Out",
                      onTap: () async {
                        await ref.read(authProvider.notifier).logout();

                        if (!context.mounted) return;
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          "login",
                          (_) => false,
                        );
                      },
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
