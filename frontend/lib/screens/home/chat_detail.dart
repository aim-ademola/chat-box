import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flint_client/flint_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/core/theme/theme.dart';
import 'package:frontend/model/ai_summary_model.dart';
import 'package:frontend/model/chat_message_model.dart';
import 'package:frontend/model/message_item_model.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/presence_provider.dart';
import 'package:frontend/provider/recent_chat_provider.dart';
import 'package:frontend/repositry/ai_repositry.dart';
import 'package:frontend/repositry/call_repositry.dart';
import 'package:frontend/repositry/chat_repositry.dart';
import 'package:frontend/screens/home/active_call_screen.dart';
import 'package:frontend/screens/home/group_info_screen.dart';
import 'package:frontend/widget/chat_thread_item_widget.dart';
import 'package:frontend/widget/ai_conversation_sheet.dart';
import 'package:frontend/widget/user_avatar_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({super.key, required this.contact});

  final MessageItemModel contact;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final List<ChatMessageModel> _messages = [];
  final Set<String> _translatingMessageKeys = {};
  final Set<String> _transcribingMessageKeys = {};
  Timer? _readTickTimer;

  FlintWebSocketClient? _socket;
  WebSocketConnectionState _socketState = WebSocketConnectionState.disconnected;
  String? _roomId;
  String? _currentUserId;
  bool _loading = true;
  bool _isRecording = false;
  String? _historyError;
  String? _fatalError;
  AiSummaryModel? _aiSummary;
  String? _moodLabel;
  String? _moodEmoji;
  String? _moodExplanation;
  bool _loadingMood = false;

  static const List<_TranslationLanguage> _translationLanguages = [
    _TranslationLanguage('English', 'EN'),
    _TranslationLanguage('Spanish', 'ES'),
    _TranslationLanguage('French', 'FR'),
    _TranslationLanguage('Arabic', 'AR'),
    _TranslationLanguage('Portuguese', 'PT'),
    _TranslationLanguage('German', 'DE'),
    _TranslationLanguage('Hindi', 'HI'),
    _TranslationLanguage('Yoruba', 'YO'),
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _socket?.dispose();
    _readTickTimer?.cancel();
    _audioRecorder.dispose();
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

      final roomId =
          widget.contact.isGroup &&
              widget.contact.conversationId?.trim().isNotEmpty == true
          ? widget.contact.conversationId!.trim()
          : chatRepository.buildConversationId(
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
      ref.invalidate(recentChatsProvider);

      await _connectSocket(chatRepository, roomId);
      _startReadTick();
      _fetchMood();
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

    socket.on('state_change', (dynamic state) {
      if (!mounted) return;
      if (state is WebSocketConnectionState) {
        setState(() {
          _socketState = state;
        });
      }
    });

    socket.on('connect', (_) {
      if (!mounted) return;
      setState(() {
        _socketState = WebSocketConnectionState.connected;
      });
    });

    socket.on('disconnect', (_) {
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

      _appendMessage(message);
      if (!message.isMe) {
        _markOpenConversationRead();
      }
      _scrollToBottom();
      _fetchMood();
    });

    socket.on('chat:poll_updated', (dynamic data) {
      final currentUserId = _currentUserId;
      if (!mounted || currentUserId == null) return;

      final message = ChatMessageModel.fromMap(
        _asMap(data),
        currentUserId: currentUserId,
      );
      _replaceMessage(message);
    });

    socket.on('chat:read', (dynamic data) {
      final payload = _asMap(data);
      final ids = payload['messageIds'] is List
          ? (payload['messageIds'] as List)
                .map((item) => item.toString())
                .toSet()
          : <String>{};
      final readAt = payload['readAt']?.toString();

      if (!mounted || ids.isEmpty || readAt == null || readAt.isEmpty) {
        return;
      }

      setState(() {
        for (var i = 0; i < _messages.length; i++) {
          final message = _messages[i];
          if (message.id != null && ids.contains(message.id)) {
            _messages[i] = message.copyWith(readAt: readAt);
          }
        }
      });

      final roomId = _roomId;
      if (roomId != null) {
        unawaited(
          ref
              .read(chatRepositryProvider)
              .markCachedMessagesRead(
                roomId: roomId,
                messageIds: ids,
                readAt: readAt,
              ),
        );
      }
    });

    await socket.connect();
    _markOpenConversationRead();
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

  void _markOpenConversationRead() {
    final socket = _socket;
    final roomId = _roomId;
    if (socket == null || roomId == null) {
      return;
    }

    socket.emit('chat:mark_read', {'conversationId': roomId});
    ref.invalidate(recentChatsProvider);
  }

  void _startReadTick() {
    _readTickTimer?.cancel();
    _readTickTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      _markOpenConversationRead();
      await _refreshHistoryForExpiry();
    });
  }

  Future<void> _refreshHistoryForExpiry() async {
    final roomId = _roomId;
    final currentUserId = _currentUserId;
    if (roomId == null || currentUserId == null || !mounted) {
      return;
    }

    try {
      final history = await ref
          .read(chatRepositryProvider)
          .getHistory(roomId: roomId, currentUserId: currentUserId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(_decorateConversation(history));
      });
    } catch (_) {}
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
      if (!widget.contact.isGroup) 'recipientId': widget.contact.userId,
      'content': text,
      'messageType': 'text',
    });
  }

  Future<void> _pickAndSendImage() async {
    await _pickAndSendMedia(messageType: 'image');
  }

  Future<void> _pickAndSendVideo() async {
    await _pickAndSendMedia(messageType: 'video');
  }

  Future<void> _pickAndSendMedia({required String messageType}) async {
    final roomId = _roomId;
    final currentUserId = _currentUserId;
    if (roomId == null || currentUserId == null) {
      _showSnackBar('Chat is still loading.');
      return;
    }

    final picked = messageType == 'video'
        ? await _imagePicker.pickVideo(source: ImageSource.gallery)
        : await _imagePicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 82,
          );
    if (picked == null) {
      return;
    }

    try {
      final message = await ref
          .read(chatRepositryProvider)
          .sendMedia(
            roomId: roomId,
            currentUserId: currentUserId,
            file: File(picked.path),
            recipientId: widget.contact.isGroup ? null : widget.contact.userId,
            messageType: messageType,
          );
      if (!mounted) return;
      _appendMessage(message);
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Could not send the media.');
    }
  }

  Future<void> _openComposerActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _ComposerActionSheet(),
    );

    switch (action) {
      case 'photo':
        await _pickAndSendImage();
        break;
      case 'video':
        await _pickAndSendVideo();
        break;
      case 'poll':
        await _openCreatePollSheet();
        break;
    }
  }

  Future<void> _openCreatePollSheet() async {
    final poll = await showModalBottomSheet<_PollDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _CreatePollSheet(),
    );

    if (poll == null) {
      return;
    }

    _sendPoll(poll);
  }

  void _sendPoll(_PollDraft poll) {
    final socket = _socket;
    final roomId = _roomId;
    if (socket == null || roomId == null) {
      _showSnackBar('Chat is still connecting.');
      return;
    }

    socket.emit('chat:send', {
      'conversationId': roomId,
      if (!widget.contact.isGroup) 'recipientId': widget.contact.userId,
      'content': jsonEncode({
        'question': poll.question,
        'options': poll.options,
        'votes': <String, List<String>>{},
      }),
      'messageType': 'poll',
    });
  }

  Future<void> _votePoll(ChatMessageModel message, int optionIndex) async {
    final roomId = _roomId;
    final currentUserId = _currentUserId;
    final messageId = message.id;
    if (roomId == null || currentUserId == null || messageId == null) {
      _showSnackBar('Poll is still syncing.');
      return;
    }

    try {
      final updated = await ref
          .read(chatRepositryProvider)
          .votePoll(
            roomId: roomId,
            messageId: messageId,
            optionIndex: optionIndex,
            currentUserId: currentUserId,
          );
      if (!mounted) return;
      _replaceMessage(updated);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Could not vote on this poll.');
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      await _stopAndSendVoiceRecording();
      return;
    }

    await _startVoiceRecording();
  }

  Future<void> _startVoiceRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      _showSnackBar('Microphone permission is needed to record voice notes.');
      return;
    }

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}${Platform.pathSeparator}chatbox_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    if (!mounted) return;
    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _stopAndSendVoiceRecording() async {
    final path = await _audioRecorder.stop();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
    });

    if (path == null || path.trim().isEmpty) {
      _showSnackBar('Recording could not be saved.');
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      _showSnackBar('Recording file was not found.');
      return;
    }

    await _sendRecordedVoice(file);
  }

  Future<void> _sendRecordedVoice(File file) async {
    final roomId = _roomId;
    final currentUserId = _currentUserId;
    if (roomId == null || currentUserId == null) {
      _showSnackBar('Chat is still loading.');
      return;
    }

    try {
      final message = await ref
          .read(chatRepositryProvider)
          .sendMedia(
            roomId: roomId,
            currentUserId: currentUserId,
            file: file,
            recipientId: widget.contact.isGroup ? null : widget.contact.userId,
            messageType: 'voice',
          );
      if (!mounted) return;
      _appendMessage(message);
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Could not send the voice note.');
    }
  }

  Future<void> _startAudioCall() async {
    await _startCall('audio');
  }

  Future<void> _startVideoCall() async {
    await _startCall('video');
  }

  Future<void> _startCall(String callType) async {
    final recipientId = widget.contact.isGroup ? _roomId : widget.contact.userId;
    final roomId = _roomId;

    if (recipientId == null || recipientId.trim().isEmpty) {
      _showSnackBar(
        widget.contact.isGroup
            ? 'Chat is still loading.'
            : 'This contact cannot receive calls yet.',
      );
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
      final displaySession = session.copyWith(
        peerName: widget.contact.name,
        peerProfilePicUrl: widget.contact.profilePicUrl,
      );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveCallScreen(session: displaySession),
        ),
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
          isGroup: widget.contact.isGroup,
          initialSummary: _aiSummary,
          onSummaryLoaded: (summary) {
            if (!mounted) return;
            setState(() {
              _aiSummary = summary;
            });
          },
        ),
      ),
    );
  }

  Future<void> _openGroupInfo() async {
    if (!widget.contact.isGroup) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupInfoScreen(group: widget.contact)),
    );

    if (mounted) {
      ref.invalidate(recentChatsProvider);
    }
  }

  Future<void> _openMessageActions(ChatMessageModel message) async {
    if (message.type == ChatMessageType.voice) {
      await _openVoiceMessageActions(message);
      return;
    }

    final text = message.text?.trim();
    if (text == null || text.isEmpty) {
      return;
    }

    final language = await showModalBottomSheet<_TranslationLanguage>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _MessageTranslationSheet(
        message: message,
        languages: _translationLanguages,
      ),
    );

    if (language == null) {
      return;
    }

    await _translateMessage(message, language);
  }

  Future<void> _openVoiceMessageActions(ChatMessageModel message) async {
    final canTranscribe =
        message.id?.trim().isNotEmpty == true &&
        message.mediaUrl?.trim().isNotEmpty == true;
    if (!canTranscribe) {
      _showSnackBar('This voice message is still syncing.');
      return;
    }

    final shouldTranscribe = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _VoiceTranscriptionSheet(),
    );

    if (shouldTranscribe != true) {
      return;
    }

    await _transcribeVoiceMessage(message);
  }

  Future<void> _transcribeVoiceMessage(ChatMessageModel message) async {
    final roomId = _roomId;
    final messageId = message.id?.trim();
    if (roomId == null || messageId == null || messageId.isEmpty) {
      _showSnackBar('This voice message is still syncing.');
      return;
    }

    final key = _messageKey(message);
    if (_transcribingMessageKeys.contains(key)) {
      return;
    }

    setState(() {
      _transcribingMessageKeys.add(key);
    });

    try {
      final transcription = await ref
          .read(aiRepositryProvider)
          .transcribeVoiceMessage(
            conversationId: roomId,
            messageId: messageId,
            provider: 'gemini',
          );

      if (!mounted) return;
      _updateTranscribedMessage(key: key, transcriptionText: transcription);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Could not transcribe this voice message.');
    } finally {
      if (mounted) {
        setState(() {
          _transcribingMessageKeys.remove(key);
        });
      }
    }
  }

  Future<void> _translateMessage(
    ChatMessageModel message,
    _TranslationLanguage language,
  ) async {
    final roomId = _roomId;
    final text = message.text?.trim();
    if (roomId == null || text == null || text.isEmpty) {
      _showSnackBar('This message cannot be translated.');
      return;
    }

    final key = _messageKey(message);
    if (_translatingMessageKeys.contains(key)) {
      return;
    }

    setState(() {
      _translatingMessageKeys.add(key);
    });

    try {
      final translated = await ref
          .read(aiRepositryProvider)
          .translateMessage(
            conversationId: roomId,
            text: text,
            language: language.name,
            provider: 'gemini',
          );

      if (!mounted) return;
      _updateTranslatedMessage(
        key: key,
        translatedText: translated,
        language: language.name,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Could not translate this message.');
    } finally {
      if (mounted) {
        setState(() {
          _translatingMessageKeys.remove(key);
        });
      }
    }
  }

  Future<void> _fetchMood() async {
    if (widget.contact.isGroup || _roomId == null) return;
    
    setState(() {
      _loadingMood = true;
    });

    try {
      final res = await ref.read(aiRepositryProvider).getChatMood(
        conversationId: _roomId!,
        provider: 'gemini',
      );
      if (!mounted) return;
      setState(() {
        _moodLabel = res['mood']?.toString();
        _moodEmoji = res['emoji']?.toString();
        _moodExplanation = res['explanation']?.toString();
        _loadingMood = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMood = false;
      });
    }
  }

  void _showMoodExplanation() {
    final explanation = _moodExplanation ?? 'No explanation available.';
    showDialog<void>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Text(_moodEmoji ?? '😐'),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${widget.contact.name}\'s Mood',
                  style: AppStyle.circularTextStyle(
                    size: 20,
                    weight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Mood: $_moodLabel',
                style: AppStyle.circularTextStyle(
                  size: 16,
                  weight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                explanation,
                style: AppStyle.circularTextStyle(
                  size: 14,
                  weight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _updateTranslatedMessage({
    required String key,
    required String translatedText,
    required String language,
  }) {
    ChatMessageModel? updatedMessage;
    setState(() {
      for (var i = 0; i < _messages.length; i++) {
        if (_messageKey(_messages[i]) == key) {
          updatedMessage = _messages[i].copyWith(
            translatedText: translatedText,
            translationLanguage: language,
          );
          _messages[i] = updatedMessage!;
          break;
        }
      }
    });

    final message = updatedMessage;
    if (message != null) {
      _cacheMessage(message);
    }
  }

  void _updateTranscribedMessage({
    required String key,
    required String transcriptionText,
  }) {
    ChatMessageModel? updatedMessage;
    setState(() {
      for (var i = 0; i < _messages.length; i++) {
        if (_messageKey(_messages[i]) == key) {
          updatedMessage = _messages[i].copyWith(
            transcriptionText: transcriptionText,
          );
          _messages[i] = updatedMessage!;
          break;
        }
      }
    });

    final message = updatedMessage;
    if (message != null) {
      _cacheMessage(message);
    }
  }

  String _messageKey(ChatMessageModel message) {
    final id = message.id?.trim();
    if (id != null && id.isNotEmpty) {
      return id;
    }

    return [
      message.conversationId ?? '',
      message.senderId ?? '',
      message.sentAt ?? '',
      message.text ?? '',
    ].join('|');
  }

  String get _statusLabel {
    if (_fatalError != null) {
      return 'Unavailable';
    }

    if (widget.contact.isGroup) {
      final count = widget.contact.memberCount;
      return count > 0 ? '$count members' : 'Group chat';
    }

    if (widget.contact.userId == null) {
      switch (_socketState) {
        case WebSocketConnectionState.connecting:
          return 'Connecting...';
        case WebSocketConnectionState.connected:
          return 'Demo room';
        case WebSocketConnectionState.reconnecting:
          return 'Reconnecting...';
        case WebSocketConnectionState.disconnected:
          return 'Offline';
      }
    }

    final presence =
        ref.watch(presenceProvider)[widget.contact.userId] ??
        parsePresence(null);
    return presenceLabel(presence);
  }

  Color _statusColor(AppThemeColors palette) {
    if (widget.contact.isGroup) {
      return palette.online;
    }

    if (widget.contact.userId == null) {
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

    final presence =
        ref.watch(presenceProvider)[widget.contact.userId] ??
        parsePresence(null);
    return presenceColor(palette, presence);
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

  void _appendMessage(ChatMessageModel message) {
    if (!mounted) {
      return;
    }

    final messageId = message.id;
    if (messageId != null &&
        _messages.any((existing) => existing.id == messageId)) {
      return;
    }

    setState(() {
      _messages.add(_decorateIncomingMessage(message));
    });
    _cacheMessage(message);
  }

  void _replaceMessage(ChatMessageModel message) {
    if (!mounted) {
      return;
    }

    final messageId = message.id;
    if (messageId == null || messageId.isEmpty) {
      return;
    }

    setState(() {
      for (var i = 0; i < _messages.length; i++) {
        if (_messages[i].id == messageId) {
          _messages[i] = _decorateMessage(
            message,
            i == 0 ? null : _messages[i - 1],
          );
          return;
        }
      }

      _messages.add(_decorateIncomingMessage(message));
    });
    _cacheMessage(message);
  }

  void _cacheMessage(ChatMessageModel message) {
    final roomId = _roomId;
    if (roomId == null || roomId.trim().isEmpty) {
      return;
    }

    unawaited(
      ref
          .read(chatRepositryProvider)
          .cacheMessage(roomId: roomId, message: message),
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
          ChatThreadItemWidget(
            contact: widget.contact,
            message: message,
            isTranslating: _translatingMessageKeys.contains(
              _messageKey(message),
            ),
            isTranscribing: _transcribingMessageKeys.contains(
              _messageKey(message),
            ),
            onMessageLongPress:
                message.type == ChatMessageType.text ||
                    message.type == ChatMessageType.voice
                ? () => _openMessageActions(message)
                : null,
            onPollVote: message.type == ChatMessageType.poll
                ? (optionIndex) => _votePoll(message, optionIndex)
                : null,
          ),
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
          IconButton(
            tooltip: 'Attach',
            onPressed: _openComposerActions,
            icon: Icon(
              Icons.attach_file_rounded,
              size: 30,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 6),
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
          IconButton(
            tooltip: _isRecording ? 'Stop recording' : 'Record voice note',
            onPressed: _toggleVoiceRecording,
            style: IconButton.styleFrom(
              backgroundColor: _isRecording
                  ? colorScheme.error.withValues(alpha: 0.14)
                  : Colors.transparent,
            ),
            icon: Icon(
              _isRecording ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
              size: 32,
              color: _isRecording ? colorScheme.error : colorScheme.onSurface,
            ),
          ),
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
                            size: 16,
                            weight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Text(
                              _statusLabel,
                              style: AppStyle.circularTextStyle(
                                size: 14,
                                weight: FontWeight.w500,
                                color: palette.secondaryText,
                              ),
                            ),
                            if (!widget.contact.isGroup && (_moodLabel != null || _loadingMood)) ...[
                              Text(
                                '•',
                                style: AppStyle.circularTextStyle(
                                  size: 14,
                                  weight: FontWeight.w500,
                                  color: palette.secondaryText,
                                ),
                              ),
                              _loadingMood
                                  ? const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                      ),
                                    )
                                  : GestureDetector(
                                      onTap: _showMoodExplanation,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Mood: $_moodLabel $_moodEmoji',
                                          style: AppStyle.circularTextStyle(
                                            size: 11,
                                            weight: FontWeight.w700,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                            ],
                          ],
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
                    // If visual elements look better side by side:
                  ),
                  if (widget.contact.isGroup)
                    _buildHeaderIcon(
                      icon: Icons.info_outline_rounded,
                      tooltip: 'Group info',
                      onPressed: _openGroupInfo,
                      color: colorScheme.onSurface,
                    ),
                  _buildHeaderIcon(
                    icon: Icons.auto_awesome_rounded,
                    tooltip: 'AI assistant',
                    onPressed: _openAiSheet,
                    color: colorScheme.primary,
                  ),
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

class _TranslationLanguage {
  const _TranslationLanguage(this.name, this.shortCode);

  final String name;
  final String shortCode;
}

class _MessageTranslationSheet extends StatelessWidget {
  const _MessageTranslationSheet({
    required this.message,
    required this.languages,
  });

  final ChatMessageModel message;
  final List<_TranslationLanguage> languages;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;
    final preview = (message.text ?? '').trim();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: palette.handle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.translate_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Translate message',
                        style: AppStyle.circularTextStyle(
                          size: 21,
                          weight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a language for this bubble.',
                        style: AppStyle.circularTextStyle(
                          size: 14,
                          weight: FontWeight.w500,
                          color: palette.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.36,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                preview.length > 140
                    ? '${preview.substring(0, 140)}...'
                    : preview,
                style: AppStyle.circularTextStyle(
                  size: 14,
                  weight: FontWeight.w600,
                  color: colorScheme.onSurface,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final language in languages)
                  ActionChip(
                    onPressed: () => Navigator.pop(context, language),
                    avatar: CircleAvatar(
                      radius: 13,
                      backgroundColor: colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: Text(
                        language.shortCode,
                        style: AppStyle.circularTextStyle(
                          size: 9,
                          weight: FontWeight.w900,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    label: Text(language.name),
                    labelStyle: AppStyle.circularTextStyle(
                      size: 14,
                      weight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    backgroundColor: palette.messageSheet,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceTranscriptionSheet extends StatelessWidget {
  const _VoiceTranscriptionSheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: palette.handle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice to text',
                        style: AppStyle.circularTextStyle(
                          size: 22,
                          weight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use AI to write out this voice message.',
                        style: AppStyle.circularTextStyle(
                          size: 13,
                          weight: FontWeight.w600,
                          color: palette.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Transcribe'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
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

class _ComposerActionSheet extends StatelessWidget {
  const _ComposerActionSheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: palette.handle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Add to chat',
              style: AppStyle.circularTextStyle(
                size: 24,
                weight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _ComposerActionTile(
              icon: Icons.image_outlined,
              title: 'Send photo',
              subtitle: 'Share an image from your gallery',
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            const SizedBox(height: 12),
            _ComposerActionTile(
              icon: Icons.video_library_outlined,
              title: 'Send video',
              subtitle: 'Share a video from your gallery',
              onTap: () => Navigator.pop(context, 'video'),
            ),
            const SizedBox(height: 12),
            _ComposerActionTile(
              icon: Icons.poll_outlined,
              title: 'Create poll',
              subtitle: 'Ask a question with multiple options',
              onTap: () => Navigator.pop(context, 'poll'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerActionTile extends StatelessWidget {
  const _ComposerActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppStyle.circularTextStyle(
                        size: 16,
                        weight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppStyle.circularTextStyle(
                        size: 13,
                        weight: FontWeight.w500,
                        color: palette.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class _PollDraft {
  const _PollDraft({required this.question, required this.options});

  final String question;
  final List<String> options;
}

class _CreatePollSheet extends StatefulWidget {
  const _CreatePollSheet();

  @override
  State<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<_CreatePollSheet> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 6) {
      return;
    }

    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) {
      return;
    }

    setState(() {
      _optionControllers.removeAt(index).dispose();
    });
  }

  void _createPoll() {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((controller) => controller.text.trim())
        .where((option) => option.isNotEmpty)
        .toList();

    if (question.isEmpty || options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a question and at least two options.'),
        ),
      );
      return;
    }

    Navigator.pop(context, _PollDraft(question: question, options: options));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>()!;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          12,
          22,
          22 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: palette.handle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Create poll',
                style: AppStyle.circularTextStyle(
                  size: 24,
                  weight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _questionController,
                decoration: _pollInputDecoration(
                  context,
                  label: 'Question',
                  icon: Icons.help_outline_rounded,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _optionControllers.length; i++) ...[
                TextField(
                  controller: _optionControllers[i],
                  decoration: _pollInputDecoration(
                    context,
                    label: 'Option ${i + 1}',
                    icon: Icons.radio_button_unchecked_rounded,
                    suffixIcon: _optionControllers.length <= 2
                        ? null
                        : IconButton(
                            onPressed: () => _removeOption(i),
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_optionControllers.length < 6)
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add option'),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _createPoll,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send poll'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _pollInputDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: colorScheme.primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
    );
  }
}
