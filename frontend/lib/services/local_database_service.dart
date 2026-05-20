import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class LocalDatabaseService {
  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;

    final dbPath = await getDatabasesPath();
    final database = await openDatabase(
      path.join(dbPath, 'chatbox.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE current_user (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            bio TEXT NOT NULL,
            profilePicUrl TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE contacts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            bio TEXT NOT NULL,
            profilePicUrl TEXT NOT NULL
          )
        ''');
      },
    );

    _database = database;
    return database;
  }

  Future<void> saveCurrentUser(Map<String, dynamic> user) async {
    final db = await database;
    await db.delete('current_user');
    await db.insert(
      'current_user',
      _userRow(user),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final db = await database;
    final rows = await db.query('current_user', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveContacts(List<Map<String, dynamic>> users) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('contacts');
    for (final user in users) {
      batch.insert(
        'contacts',
        _userRow(user),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getContacts() async {
    final db = await database;
    return db.query('contacts', orderBy: 'name COLLATE NOCASE ASC');
  }

  Future<void> clearSession() async {
    final db = await database;
    await db.delete('current_user');
  }

  Map<String, dynamic> _userRow(Map<String, dynamic> user) {
    return {
      'id': user['id']?.toString() ?? '',
      'name': user['name']?.toString() ?? 'ChatBox User',
      'email': user['email']?.toString() ?? '',
      'bio': user['bio']?.toString() ?? 'Hey, I am using ChatBox',
      'profilePicUrl': user['profilePicUrl']?.toString() ?? '',
    };
  }
}

final localDatabaseProvider = Provider((ref) => LocalDatabaseService());
