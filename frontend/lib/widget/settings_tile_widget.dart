import 'package:flutter/material.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/constant/app_colors.dart';
import 'package:frontend/widget/image_widget.dart';
import 'package:frontend/model/settings_item_model.dart';

class SettingsTileWidget extends StatelessWidget {
  final SettingsItemModel item;

  const SettingsTileWidget({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.isEnabled ? item.onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.lightBlueAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: ImageWidget(item.imagePath, width: 26, height: 26),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppStyle.circularMediumStyle.copyWith(
                          fontSize: 18,
                          color: item.isEnabled ? AppColors.black : Colors.grey,
                        ),
                      ),
                      if (item.subtitle != null) const SizedBox(height: 3),
                      if (item.subtitle != null)
                        Text(
                          item.subtitle!,
                          style: AppStyle.circularMediumStyle.copyWith(
                            fontSize: 14,
                            color: item.isEnabled
                                ? Colors.black54
                                : Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
