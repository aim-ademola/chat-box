import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_colors.dart';
import 'package:frontend/core/constant/app_images.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/extention/build_context_ext.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/screens/home/profile.dart';
import 'package:frontend/widget/app_button.dart';
import 'package:frontend/widget/profile_avatar_widget.dart';
import 'package:frontend/model/settings_item_model.dart';
import 'package:frontend/widget/settings_tile_widget.dart';

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
    final user = authUser.value;
    final displayName = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'ChatBox User';
    final bio = user?.bio.trim().isNotEmpty == true
        ? user!.bio.trim()
        : 'Hey, I am using ChatBox';
    final initials = _initials(displayName);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.arrow_back_rounded, color: AppColors.white),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Settings",
                        style: AppStyle.circularMediumStyle.copyWith(
                          fontSize: 16,
                          color: AppColors.white,
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
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(38)),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SizedBox(height: 40),

                    Row(
                      children: [
                        const SizedBox(width: 10),
                        ProfileAvatarWidget(
                          initials: initials,
                          backgroundColor: Color(0xFFC8C5F7),
                          radius: 28,
                          profilePicUrl: user?.profilePicUrl ?? "",
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Profile(),
                                    ),
                                  );
                                },
                                child: Text(
                                  authUser.isLoading
                                      ? 'Loading...'
                                      : displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppStyle.circularMediumStyle.copyWith(
                                    fontSize: 16,
                                    color: AppColors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                bio,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppStyle.circularMediumStyle.copyWith(
                                  fontSize: 13,
                                  color: AppColors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.qr_code),
                      ],
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
