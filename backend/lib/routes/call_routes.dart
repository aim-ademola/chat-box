import 'package:backend/controllers/call_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';
import 'package:flint_dart/flint_dart.dart';

class CallRoutes extends RouteGroup {
  @override
  String get prefix => '/calls';

  @override
  void register(Flint app) {
    final controller = CallController();

    app.post('/', AuthMiddleware().handle(controller.create));
    app.get('/recent', AuthMiddleware().handle(controller.recent));
    app.get('/:id/token', AuthMiddleware().handle(controller.token));
    app.get('/:id', AuthMiddleware().handle(controller.show));
    app.post('/:id/accept', AuthMiddleware().handle(controller.accept));
    app.post('/:id/reject', AuthMiddleware().handle(controller.reject));
    app.post('/:id/end', AuthMiddleware().handle(controller.end));
    app.post('/:id/recording', AuthMiddleware().handle(controller.uploadRecording));
  }
}
