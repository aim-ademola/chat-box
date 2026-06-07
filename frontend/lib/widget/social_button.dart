import 'package:flutter/material.dart';
import 'package:frontend/core/constant/app_colors.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/widget/image_widget.dart';

class SocialBotton extends StatelessWidget {
  final String iconPath;
  final Color boderColor;
  final Color? color;
  const SocialBotton({
    super.key,
    required this.iconPath,
    this.boderColor = AppColors.white,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: palette.messageSheet,
        border: Border.all(color: boderColor.withValues(alpha: 0.18)),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: ImageWidget(
        iconPath,
        color: color == AppColors.black ? colorScheme.onSurface : color,
      ),
    );
  }
}
