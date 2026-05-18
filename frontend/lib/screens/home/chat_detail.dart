import 'package:flint_client/flint_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/model/ai_summary_model.dart';
import 'package:frontend/model/chat_message_model.dart';
import 'package:frontend/model/message_item_model.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/repositry/call_repositry.dart';
import 'package:frontend/repositry/chat_repositry.dart';
import 'package:frontend/screens/home/active_call_screen.dart';
import 'package:frontend/widget/chat_thread_item_widget.dart';
import 'package:frontend/widget/ai_conversation_sheet.dart';
import 'package:frontend/widget/user_avatar_widget.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({super.key, required this.contact});

  final MessageItemModel contact;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessageModel> _messages = [];

  FlintWebSocketClient? _socket;
  WebSocketConnectionState _socketState = WebSocketConnectionState.disconnected;
  String? _roomId;
  String? _currentUserId;
  bool _loading = true;
  String? _historyError;
  String? _fatalError;
  String? _aiError;
  AiSummaryModel? _aiSummary;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _socket?.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap({bool reset = false}) async {
    if (reset) {
      _socket?.dispose();
      _socket = null;
      _messages.clear();
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _historyError = null;
        _fatalError = null;
        if (reset) {
          _roomId = null;
          _currentUserId = null;
          _socketState = WebSocketConnectionState.disconnected;
        }
      });
    }

    final chatRepository = ref.read(chatRepositryProvider);

    try {
      final currentUser = await ref.read(authProvider.future);
      if (!mounted) return;

      if (currentUser == null) {
        setState(() {
          _loading = false;
          _fatalError = 'Please sign in to chat.';
        });
        return;
      }

      final roomId = chatRepository.buildConversationId(
        currentUserId: currentUser.id,
        peerId: widget.contact.userId,
        fallbackKey: widget.contact.name,
      );

      List<ChatMessageModel> history = const [];
      String? historyError;

      try {
        history = await chatRepository.getHistory(
          roomId: roomId,
          currentUserId: currentUser.id,
        );
      } catch (_) {
        historyError = 'Could not load older messages.';
      }

      if (!mounted) return;

      setState(() {
        _currentUserId = currentUser.id;
        _roomId = roomId;
        _messages
          ..clear()
          ..addAll(_decorateConversation(history));
        _loading = false;
        _historyError = historyError;
      });
      _scrollToBottom();

      await _connectSocket(chatRepository, roomId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _fatalError = e.toString();
      });
    }
  }

  Future<void> _connectSocket(
    ChatRepositry chatRepository,
    String roomId,
  ) async {
    final socket = await chatRepository.createSocket(roomId);
    if (!mounted) {
      socket.dispose();
      return;
    }

    _socket = socket;

    socket.on("connecting", (dynamic state) {
      print("connecting");
    });
    socket.on('state_change', (dynamic state) {
      print(state);
      if (!mounted) return;
      if (state is WebSocketConnectionState) {
        setState(() {
          _socketState = state;
        });
      }
    });

    socket.on('connect', (_) {
      print("conectted");
      if (!mounted) return;
      setState(() {
        _socketState = WebSocketConnectionState.connected;
      });
    });

    socket.on('disconnect', (_) {
      print("disconnecting");
      if (!mounted) return;
      setState(() {
        if (_socketState != WebSocketConnectionState.reconnecting) {
          _socketState = WebSocketConnectionState.disconnected;
        }
      });
    });

    socket.on('reconnect_failed', (_) {
      if (!mounted) return;
      setState(() {
        _socketState = WebSocketConnectionState.disconnected;
      });
    });

    socket.on('chat:error', (dynamic data) {
      final message = _asMap(data)['message']?.toString() ?? 'Chat error';
      _showSnackBar(message);
    });

    socket.on('chat:message', (dynamic data) {
      final currentUserId = _currentUserId;
      if (!mounted || currentUserId == null) return;

      final message = ChatMessageModel.fromMap(
        _asMap(data),
        currentUserId: currentUserId,
      );

      setState(() {
        _messages.add(_decorateIncomingMessage(message));
      });
      _scrollToBottom();
    });

    await socket.connect();
  }

  List<ChatMessageModel> _decorateConversation(
    List<ChatMessageModel> messages,
  ) {
    final decorated = <ChatMessageModel>[];

    for (final message in messages) {
      decorated.add(
        _decorateMessage(message, decorated.isNotEmpty ? decorated.last : null),
      );
    }

    return decorated;
  }

  ChatMessageModel _decorateIncomingMessage(ChatMessageModel message) {
    return _decorateMessage(message, _messages.isEmpty ? null : _messages.last);
  }

  ChatMessageModel _decorateMessage(
    ChatMessageModel message,
    ChatMessageModel? previous,
  ) {
    final senderKey = message.senderId ?? message.senderName ?? '';
    final previousKey = previous?.senderId ?? previous?.senderName ?? '';

    final showSender =
        !message.isMe &&
        (previous == null || previous.isMe || previousKey != senderKey);

    return message.copyWith(showSender: showSender);
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) {
        return;
      }

      _scrollController.jumpTo(maxScroll);
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final socket = _socket;
    final roomId = _roomId;
    if (socket == null || roomId == null) {
      _showSnackBar('Chat is still connecting.');
      return;
    }

    _messageController.clear();
    socket.emit('chat:send', {
      'conversationId': roomId,
      'recipientId': widget.contact.userId,
      'content': text,
      'messageType': 'text',
    });
  }

  Future<void> _startAudioCall() async {
    await _startCall('audio');
  }

  Future<void> _startVideoCall() async {
    await _startCall('video');
  }

  Future<void> _startCall(String callType) async {
    final recipientId = widget.contact.userId;
    final roomId = _roomId;

    if (recipientId == null || recipientId.trim().isEmpty) {
      _showSnackBar('This contact cannot receive calls yet.');
      return;
    }

    if (roomId == null || roomId.trim().isEmpty) {
      _showSnackBar('Chat is still loading.');
      return;
    }

    try {
      final session = await ref
          .read(callRepositryProvider)
          .createCall(
            recipientId: recipientId,
            conversationId: roomId,
            callType: callType,
          );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ActiveCallScreen(session: session)),
      );
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Could not start the call.');
    }
  }

  Future<void> _openAiSheet() async {
    final roomId = _roomId;
    if (roomId == null || roomId.trim().isEmpty) {
      _showSnackBar('Chat is still loading.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: AiConversationSheet(
          conversationId: roomId,
          contactName: widget.contact.name,
          initialSummary: _aiSummary,
          onSummaryLoaded: (summary) {
            if (!mounted) return;
            setState(() {
              _aiSummary = summary;
              _aiError = null;
            });
          },
        ),
      ),
    );
  }

  String get _statusLabel {
    if (_fatalError != null) {
      return 'Unavailable';
    }

    switch (_socketState) {
      case WebSocketConnectionState.connecting:
        return 'Connecting...';
      case WebSocketConnectionState.connected:
        return widget.contact.userId == null ? 'Demo room' : 'Online';
      case WebSocketConnectionState.reconnecting:
        return 'Reconnecting...';
      case WebSocketConnectionState.disconnected:
        return 'Offline';
    }
  }

  Color _statusColor(AppThemeColors palette) {
    switch (_socketState) {
      case WebSocketConnectionState.connected:
        return palette.online;
      case WebSocketConnectionState.connecting:
      case WebSocketConnectionState.reconnecting:
        return palette.secondaryText;
      case WebSocketConnectionState.disconnected:
        return palette.offline;
    }
  }

  Widget _buildHistoryBanner(AppThemeColors palette) {
    if (_historyError == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: palette.badge.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _historyError!,
              style: AppStyle.circularTextStyle(
                size: 14,
                weight: FontWeight.w600,
                color: palette.secondaryText,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _bootstrap(reset: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSummaryPanel(ColorScheme colorScheme, AppThemeColors palette) {
    final summary = _aiSummary;
    final hasInsight = summary != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI chat summary',
                  style: AppStyle.circularTextStyle(
                    size: 15,
                    weight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openAiSheet,
                child: Text(hasInsight ? 'Ask' : 'Open'),
              ),
            ],
          ),
          if (_aiError != null) ...[
            const SizedBox(height: 8),
            Text(
              _aiError!,
              style: AppStyle.circularTextStyle(
                size: 13,
                weight: FontWeight.w600,
                color: palette.offline,
              ),
            ),
          ],
          if (summary != null) ...[
            const SizedBox(height: 8),
            Text(
              summary.summary,
              style: AppStyle.circularTextStyle(
                size: 14,
                weight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildAiChip(
                  colorScheme,
                  '${summary.messageCount} messages',
                  Icons.chat_bubble_outline_rounded,
                ),
                if (summary.openQuestions.isNotEmpty)
                  _buildAiChip(
                    colorScheme,
                    '${summary.openQuestions.length} need reply',
                    Icons.help_outline_rounded,
                  ),
                if (summary.meetingSuggestions.isNotEmpty)
                  _buildAiChip(
                    colorScheme,
                    '${summary.meetingSuggestions.length} possible meeting',
                    Icons.event_available_outlined,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiChip(ColorScheme colorScheme, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppStyle.circularTextStyle(
              size: 12,
              weight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 30, color: color),
    );
  }

  Widget _buildAiHeaderMenu(ColorScheme colorScheme) {
    return PopupMenuButton<String>(
      tooltip: 'AI tools',
      icon: Icon(
        Icons.auto_awesome_rounded,
        size: 28,
        color: colorScheme.primary,
      ),
      onSelected: (value) {
        switch (value) {
          case 'summary':
            _openAiSheet();
            break;
          case 'reply':
          case 'meeting':
            _openAiSheet();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'summary',
          child: Row(
            children: [
              Icon(Icons.notes_rounded, size: 20, color: colorScheme.primary),
              const SizedBox(width: 10),
              const Text('Summarize chat'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'reply',
          child: Row(
            children: [
              Icon(
                Icons.mark_chat_unread_outlined,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              const Text('Need reply'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'meeting',
          child: Row(
            children: [
              Icon(
                Icons.event_available_outlined,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              const Text('Possible meeting'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, AppThemeColors palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 54,
              color: palette.secondaryText,
            ),
            const SizedBox(height: 16),
            Text(
              'Start the conversation',
              textAlign: TextAlign.center,
              style: AppStyle.circularTextStyle(
                size: 20,
                weight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Messages you send here will be delivered through the websocket room.',
              textAlign: TextAlign.center,
              style: AppStyle.circularTextStyle(
                size: 15,
                weight: FontWeight.w500,
                color: palette.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ColorScheme colorScheme, AppThemeColors palette) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      children: [
        Align(
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.32,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Today',
              style: AppStyle.circularTextStyle(
                size: 16,
                weight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        for (final message in _messages) ...[
          ChatThreadItemWidget(contact: widget.contact, message: message),
          const SizedBox(height: 28),
        ],
      ],
    );
  }

  Widget _buildComposer(ColorScheme colorScheme, AppThemeColors palette) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      color: palette.messageSheet,
      child: Row(
        children: [
          Icon(
            Icons.attach_file_rounded,
            size: 32,
            color: colorScheme.onSurface,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.38,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Write your message',
                        hintStyle: AppStyle.circularTextStyle(
                          size: 16,
                          weight: FontWeight.w500,
                          color: palette.secondaryText,
                        ),
                        border: InputBorder.none,
                      ),
                      style: AppStyle.circularTextStyle(
                        size: 16,
                        weight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _messageController,
                    builder: (context, value, child) {
                      final canSend =
                          value.text.trim().isNotEmpty && _roomId != null;
                      return IconButton(
                        onPressed: canSend ? _sendMessage : null,
                        icon: Icon(
                          Icons.send_rounded,
                          color: canSend
                              ? colorScheme.primary
                              : palette.secondaryText,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Icon(Icons.mic_none_rounded, size: 32, color: colorScheme.onSurface),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;

    return Scaffold(
      backgroundColor: palette.messageSheet,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
              color: palette.messageSheet,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      size: 32,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatarWidget(
                        initials: widget.contact.initials,
                        backgroundColor: widget.contact.avatarColor,
                        radius: 28,
                        profilePicUrl: widget.contact.profilePicUrl,
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _statusColor(palette),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: palette.messageSheet,
                              width: 2.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.contact.name,
                          style: AppStyle.circularTextStyle(
                            size: 24,
                            weight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _statusLabel,
                          style: AppStyle.circularTextStyle(
                            size: 16,
                            weight: FontWeight.w500,
                            color: palette.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildHeaderIcon(
                    icon: Icons.call_outlined,
                    tooltip: 'Audio call',
                    onPressed: _startAudioCall,
                    color: colorScheme.onSurface,
                  ),
                  _buildHeaderIcon(
                    icon: Icons.videocam_outlined,
                    tooltip: 'Video call',
                    onPressed: _startVideoCall,
                    color: colorScheme.onSurface,
                  ),
                  _buildAiHeaderMenu(colorScheme),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: _fatalError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 54,
                                color: palette.secondaryText,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _fatalError!,
                                textAlign: TextAlign.center,
                                style: AppStyle.circularTextStyle(
                                  size: 16,
                                  weight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 18),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Go back'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          _buildAiSummaryPanel(colorScheme, palette),
                          const SizedBox(height: 12),
                          _buildHistoryBanner(palette),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _loading
                                ? Center(
                                    child: CircularProgressIndicator(
                                      color: colorScheme.primary,
                                    ),
                                  )
                                : _messages.isEmpty
                                ? _buildEmptyState(colorScheme, palette)
                                : _buildMessageList(colorScheme, palette),
                          ),
                        ],
                      ),
              ),
            ),
            if (_fatalError == null) _buildComposer(colorScheme, palette),
          ],
        ),
      ),
    );
  }
}
