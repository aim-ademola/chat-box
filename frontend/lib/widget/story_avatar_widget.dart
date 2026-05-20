import 'package:flutter/material.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/model/story_item_model.dart';
import 'package:frontend/widget/user_avatar_widget.dart';

class StoryAvatarWidget extends StatelessWidget {
  const StoryAvatarWidget({
    super.key,
    required this.item,
    this.onTap,
    this.onAddTap,
  });

  final StoryItemModel item;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppThemeColors>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        width: 112,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item.isMine
                          ? palette.storyRingMuted
                          : item.ringColor,
                      width: 2.2,
                    ),
                  ),
                  child: UserAvatarWidget(
                    initials: item.initials,
                    backgroundColor: item.backgroundColor,
                    radius: 38,
                    profilePicUrl: item.profilePicUrl,
                  ),
                ),
                if (item.isMine)
                  Positioned(
                    right: -2,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onAddTap ?? onTap,
                      child: Container(
                        width: 31,
                        height: 31,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: palette.headerBackground,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.add,
                          size: 20,
                          color: palette.headerBackground,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyle.circularTextStyle(
                size: 15,
                weight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
