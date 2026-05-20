import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/model/user_model.dart';
import 'package:frontend/repositry/auth_repositry.dart';

class AuthProvider extends AsyncNotifier<UserModel?> {
  @override
  build() async {
    final repo = ref.read(authRepositryProvider);
    final token = await repo.getToken();

    if (token == null || token.isEmpty) {
      return null;
    }

    final data = await repo.me(token: token);
    if (data == null) return null;
    return UserModel.fromMap(data['data']);
  }

  Future login({required String email, required String password}) async {
    final repo = ref.read(authRepositryProvider);
    state = AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      var data = await repo.login(email: email, password: password);
      return UserModel.fromMap(data["data"]['user']);
    });
  }

  Future register({
    required String name,
    required String email,
    required String password,
  }) async {
    final repo = ref.read(authRepositryProvider);

    state = AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      var data = await repo.register(
        name: name,
        email: email,
        password: password,
      );
      return UserModel.fromMap(data["data"]);
    });
  }

  Future me() async {
    final repo = ref.read(authRepositryProvider);
    var token = await repo.getToken();

    if (token == null || token.isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }

    state = AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      var data = await repo.me(token: token);
      return UserModel.fromMap(data["data"]);
    });
  }

  Future logout() async {
    final repo = ref.read(authRepositryProvider);
    state = AsyncValue.loading();
    await repo.logout();
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthProvider, UserModel?>(
  AuthProvider.new,
);
