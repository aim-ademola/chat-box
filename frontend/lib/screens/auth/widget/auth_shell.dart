import 'package:flutter/material.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/theme/theme.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.highlight,
    required this.subtitle,
    required this.children,
    this.footer,
  });

  final String title;
  final String highlight;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;

    return Scaffold(
      backgroundColor: palette.headerBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 26),
                  RichText(
                    text: TextSpan(
                      style: AppStyle.circularTextStyle(
                        size: 34,
                        weight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.08,
                      ),
                      children: [
                        TextSpan(text: title),
                        TextSpan(
                          text: highlight,
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            decorationColor: colorScheme.primary,
                            decorationThickness: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    style: AppStyle.circularTextStyle(
                      size: 15,
                      weight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.74),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: palette.messageSheet,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(38),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 28,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    14,
                    24,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 74,
                        height: 6,
                        decoration: BoxDecoration(
                          color: palette.handle,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 28),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...children,
                            if (footer != null) ...[
                              const SizedBox(height: 20),
                              footer!,
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
