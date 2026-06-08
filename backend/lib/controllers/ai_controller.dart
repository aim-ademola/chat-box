import 'package:backend/helper/auth_helper.dart';
import 'package:backend/models/chat_message.dart';
import 'package:backend/models/conversation.dart';
import 'package:backend/services/ai_service.dart';
import 'package:flint_dart/flint_dart.dart';

class AiController {
  AiController({AiService? aiService}) : _aiService = aiService ?? AiService();

  final AiService _aiService;

  Future<Response?> chatSummary(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({
        'status': false,
        'message': 'Unauthorized',
      });
    }

    final conversationId = ctx.req.param('conversationId');
    if (conversationId == null || conversationId.trim().isEmpty) {
      return res.status(400).json({
        'status': false,
        'message': 'Conversation id is required',
      });
    }

    final cleanConversationId = conversationId.trim();
    final canAccess =
        await _canAccessConversation(cleanConversationId, user.id);

    if (!canAccess) {
      return res.status(403).json({
        'status': false,
        'message': 'You cannot summarize this conversation',
      });
    }

    final messages = await ChatMessage()
        .where('conversationId', cleanConversationId)
        .withRelation('sender')
        .orderBy('sentAt', asc: true)
        .limit(150)
        .get();

    final provider = ctx.req.queryParam('provider');
    final summary = await _aiService.summarizeChat(
      messages: messages,
      currentUserId: user.id,
      provider: provider,
    );

    return res.json({
      'status': true,
      'data': {
        'conversationId': cleanConversationId,
        ...summary,
      },
    });
  }

  Future<Response?> chatAsk(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({
        'status': false,
        'message': 'Unauthorized',
      });
    }

    final conversationId = ctx.req.param('conversationId');
    if (conversationId == null || conversationId.trim().isEmpty) {
      return res.status(400).json({
        'status': false,
        'message': 'Conversation id is required',
      });
    }

    final body = await ctx.req.json();
    final question = body['question']?.toString().trim() ?? '';
    final provider = body['provider']?.toString().trim();
    if (question.isEmpty) {
      return res.status(400).json({
        'status': false,
        'message': 'Question is required',
      });
    }

    final cleanConversationId = conversationId.trim();
    final canAccess =
        await _canAccessConversation(cleanConversationId, user.id);

    if (!canAccess) {
      return res.status(403).json({
        'status': false,
        'message': 'You cannot ask about this conversation',
      });
    }

    final messages = await _conversationMessages(cleanConversationId);
    final answer = await _aiService.answerChatQuestion(
      messages: messages,
      currentUserId: user.id,
      question: question,
      provider: provider,
    );

    return res.json({
      'status': true,
      'data': {
        'conversationId': cleanConversationId,
        'question': question,
        ...answer,
      },
    });
  }

  Future<Response?> translateMessage(Context ctx) async {
    final res = ctx.res;
    if (res == null) return null;

    final user = await ctx.req.authUser;
    if (user == null) {
      return res.status(401).json({
        'status': false,
        'message': 'Unauthorized',
      });
    }

    final conversationId = ctx.req.param('conversationId');
    if (conversationId == null || conversationId.trim().isEmpty) {
      return res.status(400).json({
        'status': false,
        'message': 'Conversation id is required',
      });
    }

    final body = await ctx.req.json();
    final text = body['text']?.toString() ?? '';
    final language = body['language']?.toString().trim() ?? '';
    final provider = body['provider']?.toString().trim();

    if (text.trim().isEmpty) {
      return res.status(400).json({
        'status': false,
        'message': 'Message text is required',
      });
    }

    if (language.isEmpty) {
      return res.status(400).json({
        'status': false,
        'message': 'Target language is required',
      });
    }

    final cleanConversationId = conversationId.trim();
    final canAccess =
        await _canAccessConversation(cleanConversationId, user.id);

    if (!canAccess) {
      return res.status(403).json({
        'status': false,
        'message': 'You cannot translate this conversation',
      });
    }

    final translation = await _aiService.translateText(
      text: text,
      targetLanguage: language,
      provider: provider,
    );

    return res.json({
      'status': true,
      'data': {
        'conversationId': cleanConversationId,
        ...translation,
      },
    });
  }

  Future<List<ChatMessage>> _conversationMessages(
    String conversationId,
  ) async {
    return ChatMessage()
        .where('conversationId', conversationId)
        .withRelation('sender')
        .orderBy('sentAt', asc: true)
        .limit(150)
        .get();
  }

  Future<bool> _canAccessConversation(
    String conversationId,
    String currentUserId,
  ) async {
    final conversation = await Conversation().find(conversationId);
    if (conversation != null) {
      if (_isGroupConversation(conversation)) {
        return _conversationMembers(conversation).contains(currentUserId);
      }

      return conversation.userId == currentUserId ||
          conversation.friendId == currentUserId;
    }

    final messages = await ChatMessage()
        .where('conversationId', conversationId)
        .limit(20)
        .get();

    if (messages.isEmpty) {
      final ids = conversationId.split('__').map((id) => id.trim()).toList();
      return ids.contains(currentUserId);
    }

    return messages.any(
      (message) =>
          message.senderId == currentUserId ||
          message.recipientId == currentUserId,
    );
  }

  bool _isGroupConversation(Conversation conversation) {
    return conversation.type.trim().toLowerCase() == 'group';
  }

  List<String> _conversationMembers(Conversation conversation) {
    return conversation.memberIds
        .split(',')
        .map((memberId) => memberId.trim())
        .where((memberId) => memberId.isNotEmpty)
        .toSet()
        .toList();
  }
}
