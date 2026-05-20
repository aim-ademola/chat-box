import 'package:flint_client/flint_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/provider/core_provider.dart';
import 'package:frontend/services/local_database_service.dart';

class AuthRepositry {
  final FlintClient client;
  final FlutterSecureStorage storage;
  final LocalDatabaseService localDatabase;

  AuthRepositry({
    required this.client,
    required this.storage,
    required this.localDatabase,
  });
  Future<Map<String, String>> authHeaders({String? token}) async {
    final authToken = token ?? await getToken();
    if (authToken == null || authToken.isEmpty) {
      throw Exception('User is not authenticated');
    }

    return {'Authorization': 'Bearer $authToken'};
  }

  Future saveToken(String token) async {
    await storage.write(key: 'token', value: token);
  }

  Future<String?> getToken() async {
    return await storage.read(key: 'token');
  }

  Future register({
    required String name,
    required String email,
    required String password,
  }) async {
    var res = await client.post(
      '/auth/register',
      body: {'name': name, 'email': email, 'password': password},
    );
    if (res.isError) {
      return res.throwIfError();
    }
    return res.data;
  }

  Future login({required String email, required String password}) async {
    var res = await client.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    if (res.isError) {
      return res.throwIfError();
    }
    await saveToken(res.data['data']['token']);
    final rawUser = res.data['data']['user'];
    if (rawUser is Map) {
      await localDatabase.saveCurrentUser(Map<String, dynamic>.from(rawUser));
    }
    return res.data;
  }

  Future me({required String token}) async {
    var headers = await authHeaders(token: token);
    try {
      var res = await client.post('/auth/me', headers: headers);
      if (res.isError) {
        return null;
      }

      final responseData = res.data;
      final rawUser = responseData is Map ? responseData['data'] : null;
      if (rawUser is Map) {
        await localDatabase.saveCurrentUser(Map<String, dynamic>.from(rawUser));
      }

      return res.data;
    } catch (_) {
      final cachedUser = await localDatabase.getCurrentUser();
      if (cachedUser == null) return null;

      return {'status': true, 'data': cachedUser, 'source': 'sqlite'};
    }
  }

  Future logout() async {
    await storage.delete(key: 'token');
    await localDatabase.clearSession();
    return true;
  }
}

final authRepositryProvider = Provider((ref) {
  final client = ref.read(flintCLient);
  final storage = ref.watch(storageProvider);
  final localDatabase = ref.watch(localDatabaseProvider);
  return AuthRepositry(
    client: client,
    storage: storage,
    localDatabase: localDatabase,
  );
});
