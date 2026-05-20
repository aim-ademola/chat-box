import 'package:flutter/material.dart';
import 'package:frontend/core/constant/app_colors.dart';
import 'package:frontend/core/constant/app_style.dart';

class AuthFormField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final VoidCallback? onVisibilityToggle;
  final bool showVisibilityButton;
  const AuthFormField({
    super.key,
    required this.label,
    this.controller,
    this.obscureText = false,
    this.onVisibilityToggle,
    this.showVisibilityButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(
          label,
          style: AppStyle.circularMediumStyle.copyWith(
            fontSize: 18,
            color: AppColors.primary,
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            suffixIcon: !showVisibilityButton
                ? null
                : IconButton(
                    onPressed: onVisibilityToggle,
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.primary,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
