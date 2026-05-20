import 'package:flint_client/flint_client.dart';
import 'package:frontend/services/local_database_service.dart';

class UserRepositry {
  UserRepositry({required this.client, required this.localDatabase});

  final FlintClient client;
  final LocalDatabaseService localDatabase;

  Future<List<dynamic>> getAllUsers() async {
    try {
      final res = await client.get('/users');
      res.throwIfError();
      final users = res.data['users'] as List<dynamic>;
      await localDatabase.saveContacts(
        users
            .whereType<Map>()
            .map((user) => Map<String, dynamic>.from(user))
            .toList(),
      );
      return users;
    } catch (_) {
      return localDatabase.getContacts();
    }
  }
}
