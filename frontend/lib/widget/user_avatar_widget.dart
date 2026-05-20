import 'package:flutter/material.dart';
import 'package:frontend/provider/core_provider.dart';
import 'package:frontend/widget/profile_avatar_widget.dart';

class UserAvatarWidget extends StatelessWidget {
  const UserAvatarWidget({
    super.key,
    required this.initials,
    required this.backgroundColor,
    required this.radius,
    this.profilePicUrl,
    this.isGroup = false,
  });

  final String initials;
  final Color backgroundColor;
  final double radius;
  final String? profilePicUrl;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _normalizedImageUrl(profilePicUrl);
    final fallback = ProfileAvatarWidget(
      initials: initials,
      backgroundColor: backgroundColor,
      radius: radius,
      isGroup: isGroup,
      profilePicUrl: '',
    );

    if (imageUrl == null) {
      return fallback;
    }

    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      ),
    );
  }

  String? _normalizedImageUrl(String? value) {
    final cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(cleaned);
    if (uri != null && uri.hasScheme) {
      return cleaned;
    }

    final baseUri = Uri.parse(apiBaseUrl);
    final normalizedPath = cleaned.startsWith('/') ? cleaned : '/$cleaned';
    return baseUri.replace(path: normalizedPath).toString();
  }
}
