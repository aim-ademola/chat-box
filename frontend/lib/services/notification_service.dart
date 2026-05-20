import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static const String chatChannelKey = 'chat_messages';

  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(null, [
      NotificationChannel(
        channelKey: chatChannelKey,
        channelName: 'Chat messages',
        channelDescription: 'Notifications for new chat messages',
        defaultColor: const Color(0xFF2D8C80),
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        channelShowBadge: true,
        playSound: true,
        enableVibration: true,
      ),
    ]);

    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications(
        channelKey: chatChannelKey,
      );
    }
  }

  static Future<void> showChatMessage({
    required String title,
    required String body,
    String? conversationId,
    int? unreadCount,
  }) async {
    final idSeed = conversationId == null || conversationId.isEmpty
        ? DateTime.now().millisecondsSinceEpoch
        : conversationId.hashCode;
    final payload = conversationId == null
        ? null
        : <String, String>{'conversationId': conversationId};

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: idSeed.abs() % 2147483647,
        channelKey: chatChannelKey,
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Messaging,
        category: NotificationCategory.Message,
        badge: unreadCount,
        payload: payload,
      ),
    );
  }
}
