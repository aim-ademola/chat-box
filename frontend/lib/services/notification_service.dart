import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static const String chatChannelKey = 'chat_messages';
  static const String callChannelKey = 'incoming_calls';

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
      NotificationChannel(
        channelKey: callChannelKey,
        channelName: 'Incoming calls',
        channelDescription: 'Ringing alerts for incoming audio and video calls',
        defaultColor: const Color(0xFF2D8C80),
        ledColor: Colors.white,
        importance: NotificationImportance.Max,
        channelShowBadge: true,
        playSound: true,
        defaultRingtoneType: DefaultRingtoneType.Ringtone,
        enableVibration: true,
        locked: true,
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

  static Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    required bool isVideoCall,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _notificationId(callId),
        channelKey: callChannelKey,
        title: callerName,
        body: isVideoCall ? 'Incoming video call' : 'Incoming audio call',
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Call,
        wakeUpScreen: true,
        fullScreenIntent: true,
        locked: true,
        autoDismissible: false,
        payload: {'callId': callId},
      ),
    );
  }

  static Future<void> cancelIncomingCall(String callId) {
    return AwesomeNotifications().cancel(_notificationId(callId));
  }

  static Future<void> cancelIncomingCalls() {
    return AwesomeNotifications().cancelNotificationsByChannelKey(
      callChannelKey,
    );
  }

  static int _notificationId(String value) {
    return value.hashCode.abs() % 2147483647;
  }
}
