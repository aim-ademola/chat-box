import 'package:backend/controllers/ai_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';
import 'package:flint_dart/flint_dart.dart';

class AiRoutes extends RouteGroup {
  @override
  String get prefix => '/ai';

  @override
  void register(Flint app) {
    final controller = AiController();

    app.get(
      '/chats/:conversationId/summary',
      AuthMiddleware().handle(controller.chatSummary),
    );
    app.post(
      '/chats/:conversationId/ask',
      AuthMiddleware().handle(controller.chatAsk),
    );
    app.post(
      '/chats/:conversationId/translate',
      AuthMiddleware().handle(controller.translateMessage),
    );
    app.post(
      '/chats/:conversationId/messages/:messageId/transcribe',
      AuthMiddleware().handle(controller.transcribeMessage),
    );
  }
}
