// src/routes/app_routes.dart
import 'package:flint_dart/flint_dart.dart';
import 'ai_routes.dart';
import 'auth_routes.dart';
import 'chat_routes.dart';
import 'status_routes.dart';
import 'user_routes.dart';

/// Main route group for the entire app
class AppRoutes extends RouteGroup {
  @override
  String get prefix => ''; // root

  @override
  List<Middleware> get middlewares => []; // optional global middlewares

  @override
  void register(Flint app) {
    // Home route
    app.get('/', (Context ctx) async => ctx.res?.view('welcome'));

    // Auth routes
    app.routes(AuthRoutes());

    // User routes with optional middleware
    app.routes(
      UserRoutes(),
      children: [],
    );

    app.routes(ChatRoutes());
    app.routes(AiRoutes());
    app.routes(StatusRoutes());
  }
}
