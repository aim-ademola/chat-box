import 'package:backend/controllers/chat_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';
import 'package:flint_dart/flint_dart.dart';

class ChatRoutes extends RouteGroup {
  @override
  String get prefix => '/chat';

  @override
  void register(Flint app) {
    final controller = ChatController();

    app.get('/recent', AuthMiddleware().handle(controller.recent));
    app.post('/groups', AuthMiddleware().handle(controller.createGroup));
    app.get(
        '/rooms/:roomId/messages', AuthMiddleware().handle(controller.history));
    app.post(
        '/rooms/:roomId/media', AuthMiddleware().handle(controller.sendMedia));
    app.websocket('/rooms/:roomId', controller.connect);
    app.websocket('/connect', controller.handShack);
  }
}
