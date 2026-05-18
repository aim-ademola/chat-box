import 'package:backend/models/chat_message.dart';

class AiService {
  Map<String, dynamic> summarizeChat({
    required List<ChatMessage> messages,
    required String currentUserId,
  }) {
    final generatedAt = DateTime.now().toIso8601String();

    if (messages.isEmpty) {
      return {
        'summary': 'No messages are available to summarize yet.',
        'messageCount': 0,
        'openQuestions': <Map<String, dynamic>>[],
        'importantMessages': <Map<String, dynamic>>[],
        'meetingSuggestions': <Map<String, dynamic>>[],
        'generatedAt': generatedAt,
        'source': 'local',
      };
    }

    final visibleMessages = messages
        .where((message) => (message.content ?? '').trim().isNotEmpty)
        .toList();
    final latestMessages = visibleMessages.length > 4
        ? visibleMessages.sublist(visibleMessages.length - 4)
        : visibleMessages;
    final openQuestions = _openQuestions(visibleMessages, currentUserId);
    final importantMessages = _importantMessages(visibleMessages);
    final meetingSuggestions = _meetingSuggestions(visibleMessages);

    return {
      'summary': _summaryText(visibleMessages),
      'messageCount': messages.length,
      'openQuestions': openQuestions,
      'importantMessages': importantMessages,
      'meetingSuggestions': meetingSuggestions,
      'latestMessages': latestMessages.map(_messagePreview).toList(),
      'generatedAt': generatedAt,
      'source': 'local',
    };
  }

  String _summaryText(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      return 'No readable text messages are available in this chat yet.';
    }

    final first = messages.first;
    final latest = messages.last;
    final senderNames = <String>{};

    for (final message in messages) {
      senderNames.add(_senderName(message));
    }

    final participantText = senderNames.take(3).join(', ');
    final latestText = (latest.content ?? '').trim();
    final latestPreview = latestText.length > 120
        ? '${latestText.substring(0, 120)}...'
        : latestText;

    return 'This conversation has ${messages.length} readable message(s)'
        '${participantText.isEmpty ? '' : ' between $participantText'}. '
        'It started around ${_timeLabel(first.sentAt)} and the latest update is: '
        '"$latestPreview"';
  }

  List<Map<String, dynamic>> _openQuestions(
    List<ChatMessage> messages,
    String currentUserId,
  ) {
    final questions = <Map<String, dynamic>>[];

    for (final message in messages.reversed) {
      final content = (message.content ?? '').trim();
      final senderId = message.senderId?.trim();
      if (content.contains('?') && senderId != currentUserId) {
        questions.add(_messagePreview(message));
      }

      if (questions.length == 5) {
        break;
      }
    }

    return questions.reversed.toList();
  }

  List<Map<String, dynamic>> _importantMessages(List<ChatMessage> messages) {
    final important = <Map<String, dynamic>>[];
    const keywords = [
      'urgent',
      'important',
      'deadline',
      'today',
      'tomorrow',
      'asap',
      'please',
      'remind',
      'meeting',
      'call',
    ];

    for (final message in messages.reversed) {
      final content = (message.content ?? '').toLowerCase();
      final isImportant = keywords.any(content.contains);
      if (isImportant) {
        important.add(_messagePreview(message));
      }

      if (important.length == 5) {
        break;
      }
    }

    return important.reversed.toList();
  }

  List<Map<String, dynamic>> _meetingSuggestions(List<ChatMessage> messages) {
    final suggestions = <Map<String, dynamic>>[];
    const keywords = [
      'meet',
      'meeting',
      'schedule',
      'appointment',
      'call tomorrow',
      'call today',
    ];

    for (final message in messages.reversed) {
      final content = (message.content ?? '').toLowerCase();
      final hasMeetingSignal = keywords.any(content.contains);
      if (hasMeetingSignal) {
        suggestions.add({
          'title': 'Possible meeting from chat',
          'sourceMessage': _messagePreview(message),
          'confidence': 'low',
        });
      }

      if (suggestions.length == 3) {
        break;
      }
    }

    return suggestions.reversed.toList();
  }

  Map<String, dynamic> _messagePreview(ChatMessage message) {
    return {
      'id': message.id?.toString(),
      'senderId': message.senderId,
      'senderName': _senderName(message),
      'content': message.content,
      'sentAt': message.sentAt,
    };
  }

  String _senderName(ChatMessage message) {
    final sender = message.sender;
    final name = sender?.name.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final senderId = message.senderId?.trim() ?? '';
    return senderId.isEmpty ? 'Someone' : 'User $senderId';
  }

  String _timeLabel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'an unknown time';
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }

    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = parsed.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
