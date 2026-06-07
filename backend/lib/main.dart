import 'package:flint_dart/flint_dart.dart';
import 'package:backend/routes/app_routes.dart';

void main() {
  final app = Flint(
    withDefaultMiddleware: false,
    autoConnectDb: true,
    enableSwaggerDocs: true,
  );

  app.use(LoggerMiddleware());

  app.use(StaticFileMiddleware());
  app.routes(AppRoutes());
  app.listen(port: 3001, hotReload: true);
}
