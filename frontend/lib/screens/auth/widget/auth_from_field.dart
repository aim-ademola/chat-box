import 'package:flutter/material.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/theme/theme.dart';

class AuthFormField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final VoidCallback? onVisibilityToggle;
  final bool showVisibilityButton;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  const AuthFormField({
    super.key,
    required this.label,
    this.controller,
    this.obscureText = false,
    this.onVisibilityToggle,
    this.showVisibilityButton = false,
    this.icon,
    this.keyboardType,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;

    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(
          label,
          style: AppStyle.circularMediumStyle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: palette.secondaryText,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          style: AppStyle.circularTextStyle(
            size: 16,
            weight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.36,
            ),
            prefixIcon: icon == null
                ? null
                : Icon(icon, size: 22, color: colorScheme.primary),
            suffixIcon: !showVisibilityButton
                ? null
                : IconButton(
                    onPressed: onVisibilityToggle,
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: colorScheme.primary,
                    ),
                  ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}
