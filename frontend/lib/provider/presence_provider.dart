import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/theme.dart';

enum UserPresence { online, away, offline }

class PresenceNotifier extends Notifier<Map<String, UserPresence>> {
  @override
  Map<String, UserPresence> build() => const {};

  void setPresence(String? userId, UserPresence presence) {
    final cleanedUserId = userId?.trim();
    if (cleanedUserId == null || cleanedUserId.isEmpty) {
      return;
    }

    state = {...state, cleanedUserId: presence};
  }

  void setMany(Map<String, UserPresence> presences) {
    state = {...state, ...presences};
  }
}

final presenceProvider =
    NotifierProvider<PresenceNotifier, Map<String, UserPresence>>(
      PresenceNotifier.new,
    );

UserPresence parsePresence(dynamic value) {
  switch (value?.toString().trim().toLowerCase()) {
    case 'online':
      return UserPresence.online;
    case 'away':
      return UserPresence.away;
    default:
      return UserPresence.offline;
  }
}

Color presenceColor(AppThemeColors palette, UserPresence presence) {
  switch (presence) {
    case UserPresence.online:
      return palette.online;
    case UserPresence.away:
      return const Color(0xFFFFC94D);
    case UserPresence.offline:
      return palette.offline;
  }
}

String presenceLabel(UserPresence presence) {
  switch (presence) {
    case UserPresence.online:
      return 'Online';
    case UserPresence.away:
      return 'Away';
    case UserPresence.offline:
      return 'Offline';
  }
}
