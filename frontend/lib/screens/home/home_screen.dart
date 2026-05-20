import 'package:flint_client/flint_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_images.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/provider/home_provider.dart';
import 'package:frontend/provider/call_provider.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/presence_provider.dart';
import 'package:frontend/provider/recent_chat_provider.dart';
import 'package:frontend/repositry/chat_repositry.dart';
import 'package:frontend/model/call_session_model.dart';
import 'package:frontend/screens/home/call.dart';
import 'package:frontend/screens/home/contact.dart';
import 'package:frontend/screens/home/incoming_call_screen.dart';
import 'package:frontend/screens/home/message.dart';
import 'package:frontend/screens/home/settings.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/widget/image_widget.dart';

final List<Widget> listWidget = [
  const MessageScreen(),
  const CallScreen(),
  const ContactScreen(),
  const SettingsScreen(),
];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  FlintWebSocketClient? _socket;
  bool _showingIncomingCall = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => handShack(ref.read(chatRepositryProvider)));
  }

  @override
  void dispose() {
    _sendPresence(UserPresence.offline);
    WidgetsBinding.instance.removeObserver(this);
    _socket?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _sendPresence(UserPresence.online);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _sendPresence(UserPresence.away);
        break;
      case AppLifecycleState.detached:
        _sendPresence(UserPresence.offline);
        break;
    }
  }

  Future handShack(ChatRepositry chatRepository) async {
    _socket = await chatRepository.handShackSocket();

    _socket?.on("messageReceived", (data) async {
      debugPrint('chat notification: $data');
      ref.invalidate(recentChatsProvider);
      await _showMessageNotification(data);
    });

    _socket?.on('chat:read', (dynamic data) {
      debugPrint('chat read receipt: $data');
      ref.invalidate(recentChatsProvider);
    });

    _socket?.on('chat:error', (dynamic data) {
      debugPrint('chat notification error: $data');
    });

    _socket?.on('chat:notifications:ready', (dynamic data) {
      debugPrint('notification socket ready: $data');
      _applyPresenceSnapshot(data);
    });

    _socket?.on('connect', (_) {
      debugPrint('notification socket connected');
      _sendPresence(UserPresence.online);
    });

    _socket?.on('disconnect', (dynamic data) {
      debugPrint('notification socket disconnected: $data');
    });

    _socket?.on('presence:update', (dynamic data) {
      final payload = _asMap(data);
      ref
          .read(presenceProvider.notifier)
          .setPresence(
            payload['userId']?.toString(),
            parsePresence(payload['status']),
          );
    });

    _socket?.on('call:incoming', _handleIncomingCall);
    _socket?.on('call:ended', (_) {
      NotificationService.cancelIncomingCalls();
      ref.invalidate(recentCallsProvider);
    });
    _socket?.on('call:rejected', (_) {
      NotificationService.cancelIncomingCalls();
      ref.invalidate(recentCallsProvider);
    });
    _socket?.on('call:accepted', (_) {
      NotificationService.cancelIncomingCalls();
      ref.invalidate(recentCallsProvider);
    });

    await _socket?.connect();
  }

  void _sendPresence(UserPresence presence) {
    final status = presence.name;
    _socket?.emit('presence:set', {'status': status});
    final currentUser = ref.read(authProvider).value;
    ref.read(presenceProvider.notifier).setPresence(currentUser?.id, presence);
  }

  void _applyPresenceSnapshot(dynamic data) {
    final payload = _asMap(data);
    final rawPresence = payload['presence'];
    if (rawPresence is! Map) {
      return;
    }

    ref
        .read(presenceProvider.notifier)
        .setMany(
          rawPresence.map(
            (key, value) => MapEntry(key.toString(), parsePresence(value)),
          ),
        );
  }

  Future<void> _showMessageNotification(dynamic data) async {
    final payload = _asMap(data);
    final message = payload['message'] is Map
        ? Map<String, dynamic>.from(payload['message'] as Map)
        : <String, dynamic>{};
    if (message.isEmpty) return;

    final currentUser = ref.read(authProvider).value;
    final senderId = message['senderId']?.toString();
    if (currentUser != null && senderId == currentUser.id) {
      return;
    }

    final sender = message['sender'] is Map
        ? Map<String, dynamic>.from(message['sender'] as Map)
        : <String, dynamic>{};
    final senderName =
        sender['name']?.toString() ??
        message['senderName']?.toString() ??
        'New message';
    final body = _messagePreview(message);
    final unreadCount =
        int.tryParse(payload['unreadCount']?.toString() ?? '') ?? 1;

    await NotificationService.showChatMessage(
      title: senderName,
      body: body,
      conversationId: payload['conversationId']?.toString(),
      unreadCount: unreadCount,
    );
  }

  String _messagePreview(Map<String, dynamic> message) {
    final content = message['content']?.toString().trim();
    if (content != null && content.isNotEmpty) {
      return content;
    }

    final type = message['messageType']?.toString().toLowerCase().trim();
    if (type == 'image') return 'Sent a photo';
    if (type == 'voice') return 'Sent a voice message';
    return 'Sent a message';
  }

  Future<void> _handleIncomingCall(dynamic data) async {
    if (!mounted || _showingIncomingCall) return;

    final payload = _asMap(data);
    final callMap = payload['call'] is Map
        ? Map<String, dynamic>.from(payload['call'] as Map)
        : <String, dynamic>{};

    if (callMap.isEmpty) return;

    final call = CallSessionModel.fromMap(callMap);
    if (call.id.isEmpty) return;

    _showingIncomingCall = true;
    ref.invalidate(recentCallsProvider);
    await NotificationService.showIncomingCall(
      callId: call.id,
      callerName: call.peerName,
      isVideoCall: call.isVideoCall,
    );

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncomingCallScreen(call: call),
      ),
    );

    await NotificationService.cancelIncomingCall(call.id);
    _showingIncomingCall = false;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final homeProviderv = ref.watch(homeIndexProvider);
    final palette = Theme.of(context).extension<AppThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: listWidget[homeProviderv],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: homeProviderv,
        backgroundColor: Theme.of(
          context,
        ).bottomNavigationBarTheme.backgroundColor,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: palette.inactiveIcon,
        onTap: (index) {
          ref.read(homeIndexProvider.notifier).changeIndex(index);
        },
        items: [
          BottomNavigationBarItem(
            icon: ImageWidget(
              AppImages.homeMessage,
              color: homeProviderv == 0
                  ? colorScheme.primary
                  : palette.inactiveIcon,
            ),
            label: "Message",
          ),
          BottomNavigationBarItem(
            icon: ImageWidget(
              AppImages.call,
              color: homeProviderv == 1
                  ? colorScheme.primary
                  : palette.inactiveIcon,
            ),
            label: "Calls",
          ),
          BottomNavigationBarItem(
            icon: ImageWidget(
              AppImages.contact,
              color: homeProviderv == 2
                  ? colorScheme.primary
                  : palette.inactiveIcon,
            ),
            label: "Contacts",
          ),
          BottomNavigationBarItem(
            icon: ImageWidget(
              AppImages.settings,
              color: homeProviderv == 3
                  ? colorScheme.primary
                  : palette.inactiveIcon,
            ),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}
