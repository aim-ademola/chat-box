import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/provider/auth_provider.dart';

class SplashProvider {
  SplashProvider(this.ref);

  final Ref ref;

  Future<String> getInitialRoute() async {
    await Future.delayed(const Duration(seconds: 1));

    try {
      final user = await ref.read(authProvider.future);
      return user == null ? 'onboarding' : 'home';
    } catch (_) {
      return 'onboarding';
    }
  }
}

final splashProvider = Provider((ref) => SplashProvider(ref));
