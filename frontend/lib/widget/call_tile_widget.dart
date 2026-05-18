import 'package:flutter/material.dart';
import 'package:frontend/core/constant/app_colors.dart';
import 'package:frontend/core/constant/app_images.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/theme/app_theme_colors.dart';
import 'package:frontend/model/call_item_model.dart';
import 'package:frontend/widget/image_widget.dart';
import 'package:frontend/widget/user_avatar_widget.dart';

class CallTileWidget extends StatelessWidget {
  const CallTileWidget({
    super.key,
    required this.contact,
    required this.callTime,
    this.isMissed = false,
    this.isVideoCall = false,
    this.onTap,
  });

  final CallItemModel contact;
  final String callTime;
  final bool isMissed;
  final bool isVideoCall;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;

    final callColor = isMissed ? Colors.red : Colors.green;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              UserAvatarWidget(
                initials: contact.initials,
                backgroundColor: contact.avatarColor,
                radius: 28,
                profilePicUrl: contact.profilePicUrl,
              ),

              const SizedBox(width: 18),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: AppStyle.circularMediumStyle.copyWith(
                        fontSize: 20,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        ImageWidget(
                          isMissed ? AppImages.missedCall : AppImages.calls,
                          color: isMissed ? Colors.red : AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          callTime,
                          style: AppStyle.circularMediumStyle.copyWith(
                            fontSize: 15,
                            color: AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Row(
                children: [
                  ImageWidget(AppImages.call, color: AppColors.grey),
                  SizedBox(width: 12),
                  ImageWidget(AppImages.video, color: AppColors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
