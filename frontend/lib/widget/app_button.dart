import 'package:flutter/material.dart';
import 'package:frontend/core/constant/app_colors.dart';
import 'package:frontend/core/constant/app_style.dart';

class AppButton extends StatelessWidget {
  final Color textColor;
  final Color backgroundColor;
  final String label;
  final VoidCallback onTap;
  const AppButton({
    super.key,
    this.textColor = AppColors.white,
    required this.backgroundColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontFamily: 'circular',
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(
          label,
          style: AppStyle.carosBoldStyle(context).copyWith(color: textColor),
        ),
      ),
    );
  }
}
