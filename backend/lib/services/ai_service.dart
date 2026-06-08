import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:backend/models/chat_message.dart';
import 'package:flint_dart/flint_dart.dart';

class AiService {
  Future<Map<String, dynamic>> summarizeChat({
    required List<ChatMessage> messages,
    required String currentUserId,
    String? provider,
  }) async {
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

    final selectedProvider = _cleanProvider(provider);
    final visibleMessages = messages
        .where((message) => (message.content ?? '').trim().isNotEmpty)
        .toList();
    final latestMessages = visibleMessages.length > 4
        ? visibleMessages.sublist(visibleMessages.length - 4)
        : visibleMessages;
    final openQuestions = _openQuestions(visibleMessages, currentUserId);
    final importantMessages = _importantMessages(visibleMessages);
    final meetingSuggestions = _meetingSuggestions(visibleMessages);
    final localSummary = _summaryText(visibleMessages);

    if (selectedProvider != 'local') {
      final aiSummary = await _generateText(
        provider: selectedProvider,
        prompt: _summaryPrompt(visibleMessages),
      );

      if (aiSummary != null && aiSummary.trim().isNotEmpty) {
        return {
          'summary': aiSummary.trim(),
          'messageCount': messages.length,
          'openQuestions': openQuestions,
          'importantMessages': importantMessages,
          'meetingSuggestions': meetingSuggestions,
          'latestMessages': latestMessages.map(_messagePreview).toList(),
          'generatedAt': generatedAt,
          'source': selectedProvider,
        };
      }
    }

    return {
      'summary': localSummary,
      'messageCount': messages.length,
      'openQuestions': openQuestions,
      'importantMessages': importantMessages,
      'meetingSuggestions': meetingSuggestions,
      'latestMessages': latestMessages.map(_messagePreview).toList(),
      'generatedAt': generatedAt,
      'source': 'local',
    };
  }

  Future<Map<String, dynamic>> answerChatQuestion({
    required List<ChatMessage> messages,
    required String currentUserId,
    required String question,
    String? provider,
  }) async {
    final cleanQuestion = question.trim();
    final visibleMessages = messages
        .where((message) => (message.content ?? '').trim().isNotEmpty)
        .toList();

    if (cleanQuestion.isEmpty) {
      return {
        'answer': 'Ask me something about this conversation.',
        'generatedAt': DateTime.now().toIso8601String(),
        'source': 'local',
      };
    }

    if (visibleMessages.isEmpty) {
      return {
        'answer': 'There are no readable messages in this chat yet.',
        'generatedAt': DateTime.now().toIso8601String(),
        'source': 'local',
      };
    }

    final selectedProvider = _cleanProvider(provider);
    final isReplyDraftRequest = _asksForReplyDraft(cleanQuestion);
    if (selectedProvider != 'local') {
      final aiAnswer = await _generateText(
        provider: selectedProvider,
        prompt: isReplyDraftRequest
            ? _replyPrompt(
                messages: visibleMessages,
                currentUserId: currentUserId,
                request: cleanQuestion,
              )
            : _questionPrompt(
                messages: visibleMessages,
                currentUserId: currentUserId,
                question: cleanQuestion,
              ),
      );

      if (aiAnswer != null && aiAnswer.trim().isNotEmpty) {
        return {
          'answer': aiAnswer.trim(),
          'generatedAt': DateTime.now().toIso8601String(),
          'source': selectedProvider,
        };
      }
    }

    final lowerQuestion = cleanQuestion.toLowerCase();
    if (isReplyDraftRequest) {
      return _answer(_localReplyDraft(visibleMessages, currentUserId));
    }

    if (_asksAboutReply(lowerQuestion)) {
      final questions = _openQuestions(visibleMessages, currentUserId);
      if (questions.isEmpty) {
        return _answer(
          'I do not see any unanswered direct questions from the other person in the recent chat.',
        );
      }

      final text = questions
          .map((item) => '- ${item['senderName']}: ${item['content']}')
          .join('\n');
      return _answer(
          'These look like messages you may need to reply to:\n$text');
    }

    if (_asksAboutMeeting(lowerQuestion)) {
      final meetings = _meetingSuggestions(visibleMessages);
      if (meetings.isEmpty) {
        return _answer(
          'I do not see a clear meeting suggestion in the recent chat.',
        );
      }

      final text = meetings.map((item) {
        final source = item['sourceMessage'] as Map<String, dynamic>;
        return '- ${source['senderName']}: ${source['content']}';
      }).join('\n');
      return _answer('These messages may relate to a meeting:\n$text');
    }

    if (_asksAboutImportant(lowerQuestion)) {
      final important = _importantMessages(visibleMessages);
      if (important.isEmpty) {
        return _answer(
          'I do not see urgent or high-priority messages in the recent chat.',
        );
      }

      final text = important
          .map((item) => '- ${item['senderName']}: ${item['content']}')
          .join('\n');
      return _answer('These messages look important:\n$text');
    }

    return _answer(
      '${_summaryText(visibleMessages)}\n\nBased on your question, I would focus on the latest messages and any direct requests in this chat.',
    );
  }

  Future<Map<String, dynamic>> translateText({
    required String text,
    required String targetLanguage,
    String? provider,
  }) async {
    final cleanText = text.trim();
    final cleanLanguage = targetLanguage.trim();
    final generatedAt = DateTime.now().toIso8601String();

    if (cleanText.isEmpty) {
      return {
        'translatedText': '',
        'targetLanguage': cleanLanguage,
        'generatedAt': generatedAt,
        'source': 'local',
      };
    }

    if (cleanLanguage.isEmpty) {
      return {
        'translatedText': cleanText,
        'targetLanguage': '',
        'generatedAt': generatedAt,
        'source': 'local',
      };
    }

    final selectedProvider = _cleanProvider(provider);
    if (selectedProvider != 'local') {
      final translated = await _generateText(
        provider: selectedProvider,
        prompt: _translationPrompt(
          text: cleanText,
          targetLanguage: cleanLanguage,
        ),
      );

      if (translated != null && translated.trim().isNotEmpty) {
        return {
          'translatedText': translated.trim(),
          'targetLanguage': cleanLanguage,
          'generatedAt': generatedAt,
          'source': selectedProvider,
        };
      }
    }

    return {
      'translatedText': cleanText,
      'targetLanguage': cleanLanguage,
      'generatedAt': generatedAt,
      'source': 'local',
    };
  }

  Future<Map<String, dynamic>> transcribeAudio({
    required String mediaUrl,
    String? provider,
  }) async {
    final cleanMediaUrl = mediaUrl.trim();
    final generatedAt = DateTime.now().toIso8601String();

    if (cleanMediaUrl.isEmpty) {
      return {
        'transcription': '',
        'generatedAt': generatedAt,
        'source': 'local',
      };
    }

    final selectedProvider = _cleanProvider(provider);
    if (selectedProvider != 'local') {
      final audio = await _loadAudioBytes(cleanMediaUrl);
      if (audio != null && audio.bytes.isNotEmpty) {
        final transcription = switch (selectedProvider) {
          'openai' => await _transcribeOpenAi(audio),
          'gemini' => await _transcribeGemini(audio),
          _ => null,
        };

        if (transcription != null && transcription.trim().isNotEmpty) {
          return {
            'transcription': transcription.trim(),
            'generatedAt': generatedAt,
            'source': selectedProvider,
          };
        }
      }
    }

    return {
      'transcription':
          'AI transcription is not available yet. Configure an AI key and try again.',
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

  bool _asksAboutReply(String question) {
    return question.contains('reply') ||
        question.contains('answer') ||
        question.contains('respond') ||
        question.contains('forgot');
  }

  bool _asksForReplyDraft(String question) {
    final lower = question.toLowerCase();
    final wantsReply = lower.contains('reply') ||
        lower.contains('respond') ||
        lower.contains('answer') ||
        lower.contains('message back');
    final wantsGeneration = lower.contains('generate') ||
        lower.contains('write') ||
        lower.contains('draft') ||
        lower.contains('compose') ||
        lower.contains('create') ||
        lower.contains('what should i reply') ||
        lower.contains('help me reply');

    return wantsReply && wantsGeneration;
  }

  bool _asksAboutMeeting(String question) {
    return question.contains('meeting') ||
        question.contains('meet') ||
        question.contains('schedule') ||
        question.contains('appointment') ||
        question.contains('next call');
  }

  bool _asksAboutImportant(String question) {
    return question.contains('important') ||
        question.contains('urgent') ||
        question.contains('deadline') ||
        question.contains('priority');
  }

  Map<String, dynamic> _answer(String text) {
    return {
      'answer': text,
      'generatedAt': DateTime.now().toIso8601String(),
      'source': 'local',
    };
  }

  String _cleanProvider(String? provider) {
    final requested =
        (provider ?? FlintEnv.get('AI_PROVIDER', 'local')).trim().toLowerCase();

    if (requested == 'gemini' || requested == 'openai') {
      return requested;
    }

    return 'local';
  }

  Future<String?> _generateText({
    required String provider,
    required String prompt,
  }) async {
    try {
      switch (provider) {
        case 'gemini':
          return await _generateGemini(prompt);
        case 'openai':
          return await _generateOpenAi(prompt);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<String?> _generateGemini(String prompt) async {
    final apiKey = FlintEnv.get('GEMINI_API_KEY', '').trim();
    if (apiKey.isEmpty) return null;

    final model = FlintEnv.get('GEMINI_MODEL', 'gemini-2.5-flash').trim();
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );

    final response = await _postJson(
      uri,
      headers: {'x-goog-api-key': apiKey},
      body: {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.3,
          'maxOutputTokens': 700,
        },
      },
    );

    final candidates = response['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;

    final content = candidates.first is Map
        ? Map<String, dynamic>.from(candidates.first as Map)['content']
        : null;
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) return null;

    return parts
        .whereType<Map>()
        .map((part) => part['text']?.toString() ?? '')
        .where((text) => text.trim().isNotEmpty)
        .join('\n')
        .trim();
  }

  Future<String?> _generateOpenAi(String prompt) async {
    final apiKey = FlintEnv.get('OPENAI_API_KEY', '').trim();
    if (apiKey.isEmpty) return null;

    final model = FlintEnv.get('OPENAI_MODEL', 'gpt-4.1-mini').trim();
    final response = await _postJson(
      Uri.parse('https://api.openai.com/v1/responses'),
      headers: {'Authorization': 'Bearer $apiKey'},
      body: {
        'model': model,
        'input': prompt,
        'temperature': 0.3,
        'max_output_tokens': 700,
      },
    );

    final outputText = response['output_text']?.toString();
    if (outputText != null && outputText.trim().isNotEmpty) {
      return outputText.trim();
    }

    final output = response['output'];
    if (output is! List) return null;

    final chunks = <String>[];
    for (final item in output.whereType<Map>()) {
      final content = item['content'];
      if (content is List) {
        for (final part in content.whereType<Map>()) {
          final text = part['text']?.toString();
          if (text != null && text.trim().isNotEmpty) {
            chunks.add(text.trim());
          }
        }
      }
    }

    return chunks.join('\n').trim();
  }

  Future<String?> _transcribeGemini(_AudioInput audio) async {
    final apiKey = FlintEnv.get('GEMINI_API_KEY', '').trim();
    if (apiKey.isEmpty) return null;

    final model = FlintEnv.get('GEMINI_MODEL', 'gemini-2.5-flash').trim();
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );

    final response = await _postJson(
      uri,
      headers: {'x-goog-api-key': apiKey},
      body: {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text':
                    'Transcribe this voice message. Return only the spoken words. If speech is unclear, keep it brief and say what is audible.',
              },
              {
                'inline_data': {
                  'mime_type': audio.mimeType,
                  'data': base64Encode(audio.bytes),
                },
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 700,
        },
      },
    );

    final candidates = response['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;

    final content = candidates.first is Map
        ? Map<String, dynamic>.from(candidates.first as Map)['content']
        : null;
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) return null;

    return parts
        .whereType<Map>()
        .map((part) => part['text']?.toString() ?? '')
        .where((text) => text.trim().isNotEmpty)
        .join('\n')
        .trim();
  }

  Future<String?> _transcribeOpenAi(_AudioInput audio) async {
    final apiKey = FlintEnv.get('OPENAI_API_KEY', '').trim();
    if (apiKey.isEmpty) return null;

    final model =
        FlintEnv.get('OPENAI_TRANSCRIPTION_MODEL', 'gpt-4o-mini-transcribe')
            .trim();
    final boundary =
        'chatbox-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(999999)}';
    final client = HttpClient();

    try {
      final request = await client.postUrl(
        Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
      );
      request.headers.set('Authorization', 'Bearer $apiKey');
      request.headers
          .set('Content-Type', 'multipart/form-data; boundary=$boundary');

      void addField(String name, String value) {
        request.write('--$boundary\r\n');
        request.write('Content-Disposition: form-data; name="$name"\r\n\r\n');
        request.write('$value\r\n');
      }

      addField('model', model);
      addField(
        'prompt',
        'This is a casual chat voice note. Transcribe only the spoken words.',
      );
      request.write('--$boundary\r\n');
      request.write(
        'Content-Disposition: form-data; name="file"; filename="${audio.fileName}"\r\n',
      );
      request.write('Content-Type: ${audio.mimeType}\r\n\r\n');
      request.add(audio.bytes);
      request.write('\r\n--$boundary--\r\n');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'AI transcription failed: ${response.statusCode} $responseBody');
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is Map) {
        return decoded['text']?.toString();
      }
    } finally {
      client.close(force: true);
    }

    return null;
  }

  Future<_AudioInput?> _loadAudioBytes(String mediaUrl) async {
    final uri = Uri.tryParse(mediaUrl);
    if (uri != null && uri.hasScheme) {
      return _downloadAudio(uri);
    }

    final path = mediaUrl.split('?').first.replaceAll('\\', '/');
    final candidates = [
      path,
      path.startsWith('/') ? path.substring(1) : path,
      path.startsWith('/public/') ? path.substring(1) : 'public/$path',
    ];

    for (final candidate in candidates) {
      final file = File(candidate);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return _AudioInput(
          bytes: bytes,
          mimeType: _mimeTypeFor(candidate),
          fileName: candidate.split('/').last,
        );
      }
    }

    return null;
  }

  Future<_AudioInput?> _downloadAudio(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final bytes = await response.fold<List<int>>(
        <int>[],
        (previous, chunk) => previous..addAll(chunk),
      );
      final path =
          uri.pathSegments.isEmpty ? 'voice.m4a' : uri.pathSegments.last;
      return _AudioInput(
        bytes: bytes,
        mimeType: response.headers.contentType?.mimeType ?? _mimeTypeFor(path),
        fileName: path,
      );
    } finally {
      client.close(force: true);
    }
  }

  String _mimeTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg') || lower.endsWith('.oga')) return 'audio/ogg';
    if (lower.endsWith('.webm')) return 'audio/webm';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.mp4')) return 'audio/mp4';
    return 'audio/mp4';
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      headers.forEach(request.headers.set);
      request.write(jsonEncode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'AI request failed: ${response.statusCode} $responseBody');
      }

      final decoded = jsonDecode(responseBody);
      return decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
    } finally {
      client.close(force: true);
    }
  }

  String _summaryPrompt(List<ChatMessage> messages) {
    return '''
Summarize this chat for the signed-in user.
Keep it concise and useful. Include decisions, unresolved questions, important messages, and possible meetings when relevant.

Conversation:
${_conversationText(messages)}
''';
  }

  String _questionPrompt({
    required List<ChatMessage> messages,
    required String currentUserId,
    required String question,
  }) {
    return '''
You are helping the signed-in user understand a chat conversation.
The signed-in user id is $currentUserId.
Answer the question using only the conversation. If the answer is not in the chat, say so briefly.

Question: $question

Conversation:
${_conversationText(messages)}
''';
  }

  String _replyPrompt({
    required List<ChatMessage> messages,
    required String currentUserId,
    required String request,
  }) {
    return '''
You are writing a chat reply for the signed-in user.
The signed-in user id is $currentUserId.

Task:
- Draft the exact message the signed-in user can send next.
- Reply to the other person's latest relevant message.
- Match the chat tone and keep it natural.
- Do not explain the conversation.
- Do not include labels like "Draft:" or quotation marks.
- If the user's request asks for a tone, follow it.
- If the conversation does not contain enough context, write a brief clarifying reply the user can send.

User request: $request

Conversation:
${_conversationText(messages)}
''';
  }

  String _translationPrompt({
    required String text,
    required String targetLanguage,
  }) {
    return '''
Translate this chat message into $targetLanguage.
Return only the translated message.
Keep names, links, emoji, punctuation, and chat tone natural.
Do not add explanations, labels, quotes, or markdown.

Message:
$text
''';
  }

  String _localReplyDraft(List<ChatMessage> messages, String currentUserId) {
    ChatMessage? latestIncoming;
    for (final message in messages.reversed) {
      final senderId = message.senderId?.trim();
      final content = (message.content ?? '').trim();
      if (senderId != null &&
          senderId.isNotEmpty &&
          senderId != currentUserId &&
          content.isNotEmpty) {
        latestIncoming = message;
        break;
      }
    }

    if (latestIncoming == null) {
      return 'I will check and get back to you soon.';
    }

    final content = (latestIncoming.content ?? '').trim();
    final lower = content.toLowerCase();

    if (content.contains('?')) {
      return 'Thanks for asking. Let me check and I will get back to you shortly.';
    }

    if (lower.contains('meeting') ||
        lower.contains('meet') ||
        lower.contains('call')) {
      return 'That works for me. What time is best for you?';
    }

    if (lower.contains('urgent') || lower.contains('asap')) {
      return 'Got it. I will look into this now and update you shortly.';
    }

    return 'Thanks for the update. I will get back to you soon.';
  }

  String _conversationText(List<ChatMessage> messages) {
    final latest = messages.length > 80
        ? messages.sublist(messages.length - 80)
        : messages;

    return latest.map((message) {
      final sender = _senderName(message);
      final time = message.sentAt ?? '';
      final content = (message.content ?? '').trim();
      return '[$time] $sender: $content';
    }).join('\n');
  }
}

class _AudioInput {
  const _AudioInput({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });

  final List<int> bytes;
  final String mimeType;
  final String fileName;
}
