import 'dart:convert';

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
      version: 2,
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
        await _createChatMessagesTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createChatMessagesTable(db);
        }
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

  Future<void> saveChatMessages(
    String conversationId,
    List<Map<String, dynamic>> messages,
  ) async {
    if (conversationId.trim().isEmpty || messages.isEmpty) {
      return;
    }

    final db = await database;
    final batch = db.batch();
    for (final message in messages) {
      batch.insert(
        'chat_messages',
        _messageRow(conversationId, message),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    await deleteExpiredChatMessages();
  }

  Future<void> saveChatMessage(
    String conversationId,
    Map<String, dynamic> message,
  ) async {
    if (conversationId.trim().isEmpty) {
      return;
    }

    final db = await database;
    await db.insert(
      'chat_messages',
      _messageRow(conversationId, message),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await deleteExpiredChatMessages();
  }

  Future<List<Map<String, dynamic>>> getChatMessages(
    String conversationId,
  ) async {
    if (conversationId.trim().isEmpty) {
      return const [];
    }

    await deleteExpiredChatMessages();
    final db = await database;
    final rows = await db.query(
      'chat_messages',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
      orderBy: 'sentAt ASC, rowid ASC',
    );

    return rows
        .map((row) {
          final payload = row['payload'];
          if (payload is! String || payload.trim().isEmpty) {
            return <String, dynamic>{};
          }

          try {
            final decoded = jsonDecode(payload);
            return decoded is Map
                ? Map<String, dynamic>.from(decoded)
                : <String, dynamic>{};
          } catch (_) {
            return <String, dynamic>{};
          }
        })
        .where((message) => message.isNotEmpty)
        .toList();
  }

  Future<void> markChatMessagesRead(
    String conversationId,
    Set<String> messageIds,
    String readAt,
  ) async {
    if (conversationId.trim().isEmpty ||
        messageIds.isEmpty ||
        readAt.trim().isEmpty) {
      return;
    }

    final db = await database;
    final rows = await db.query(
      'chat_messages',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
    );
    final batch = db.batch();

    for (final row in rows) {
      final id = row['id']?.toString();
      if (id == null || !messageIds.contains(id)) {
        continue;
      }

      final payload = row['payload'];
      if (payload is! String) {
        continue;
      }

      try {
        final decoded = jsonDecode(payload);
        if (decoded is! Map) {
          continue;
        }

        final map = Map<String, dynamic>.from(decoded);
        map['readAt'] = readAt;
        batch.update(
          'chat_messages',
          {'readAt': readAt, 'payload': jsonEncode(map)},
          where: 'id = ?',
          whereArgs: [id],
        );
      } catch (_) {}
    }

    await batch.commit(noResult: true);
  }

  Future<void> deleteExpiredChatMessages() async {
    final db = await database;
    await db.delete(
      'chat_messages',
      where: 'expiresAt IS NOT NULL AND expiresAt != ? AND expiresAt <= ?',
      whereArgs: ['', DateTime.now().toUtc().toIso8601String()],
    );
  }

  Future<void> clearSession() async {
    final db = await database;
    await db.delete('current_user');
    await db.delete('chat_messages');
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

  static Future<void> _createChatMessagesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        id TEXT PRIMARY KEY,
        conversationId TEXT NOT NULL,
        senderId TEXT,
        recipientId TEXT,
        messageType TEXT NOT NULL,
        sentAt TEXT NOT NULL,
        readAt TEXT,
        expiresAt TEXT,
        payload TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_sent
      ON chat_messages (conversationId, sentAt)
    ''');
  }

  Map<String, dynamic> _messageRow(
    String conversationId,
    Map<String, dynamic> message,
  ) {
    final messageConversationId =
        message['conversationId']?.toString().trim().isNotEmpty == true
        ? message['conversationId'].toString()
        : conversationId;
    final sentAt =
        message['sentAt']?.toString() ??
        message['createdAt']?.toString() ??
        message['created_at']?.toString() ??
        DateTime.now().toUtc().toIso8601String();
    final id = message['id']?.toString().trim().isNotEmpty == true
        ? message['id'].toString()
        : [
            messageConversationId,
            message['senderId']?.toString() ?? '',
            sentAt,
            message['content']?.toString() ??
                message['text']?.toString() ??
                message['mediaUrl']?.toString() ??
                '',
          ].join('|');

    return {
      'id': id,
      'conversationId': messageConversationId,
      'senderId': message['senderId']?.toString(),
      'recipientId': message['recipientId']?.toString(),
      'messageType': (message['messageType'] ?? message['type'] ?? 'text')
          .toString(),
      'sentAt': sentAt,
      'readAt': message['readAt']?.toString() ?? message['read_at']?.toString(),
      'expiresAt':
          message['expiresAt']?.toString() ?? message['expires_at']?.toString(),
      'payload': jsonEncode(message),
    };
  }
}

final localDatabaseProvider = Provider((ref) => LocalDatabaseService());
