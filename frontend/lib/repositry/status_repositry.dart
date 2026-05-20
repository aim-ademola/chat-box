import 'dart:io';
import 'package:flint_client/flint_client.dart';
import 'package:flutter/material.dart';
import 'package:frontend/model/status_item_model.dart';
import 'package:frontend/model/story_item_model.dart';
import 'package:frontend/repositry/auth_repositry.dart';

class StatusRepositry {
  final FlintClient client;
  final AuthRepositry authRepository;

  StatusRepositry({required this.client, required this.authRepository});

  String _safeString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  List<StatusItemModel> _statusesFrom(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map(
          (status) =>
              StatusItemModel.fromMap(Map<String, dynamic>.from(status)),
        )
        .toList();
  }

  StoryItemModel _storyFromUserMap(
    Map<String, dynamic> userMap, {
    List<StatusItemModel>? statuses,
  }) {
    final name = _safeString(userMap['name'], fallback: 'Unknown user');

    return StoryItemModel(
      name: name,
      userId: userMap['id']?.toString(),
      profilePicUrl: userMap['profilePicUrl']?.toString(),
      initials: _initialsFor(name),
      backgroundColor: Colors.black,
      ringColor: Colors.black,
      statuses: statuses ?? _statusesFrom(userMap['statuses']),
    );
  }

  StoryItemModel _storyFromCreatedStatus(Map<String, dynamic> statusMap) {
    final user = statusMap['user'];
    final userMap = user is Map
        ? Map<String, dynamic>.from(user)
        : <String, dynamic>{'id': statusMap['userId'], 'name': 'Unknown user'};

    return _storyFromUserMap(
      userMap,
      statuses: [StatusItemModel.fromMap(statusMap)],
    );
  }

  StoryItemModel _storyFromPayload(dynamic item) {
    if (item is! Map) {
      throw const FormatException('Invalid status response');
    }

    final map = Map<String, dynamic>.from(item);
    if (map.containsKey('statuses')) {
      return _storyFromUserMap(map);
    }

    return _storyFromCreatedStatus(map);
  }

  Future create({
    required String content,
    required String type,
    File? file,
  }) async {
    final headers = await authRepository.authHeaders();
    var res = await client.post(
      "/status",
      headers: headers,
      files: file == null ? null : {"file": file},
      body: {'type': type, "content": content},
    );

    if (res.isError) {
      res.throwIfError();
    }

    return _storyFromPayload(res.data["data"]);
  }

  Future<List<StoryItemModel>> getAll() async {
    final headers = await authRepository.authHeaders();
    final res = await client.get("/status", headers: headers);
    res.throwIfError();

    final items = res.data['data'];
    if (items is! List) {
      return [];
    }

    return items.map(_storyFromPayload).toList();
  }

  Future<List<StoryItemModel>> getByUser(String userId) async {
    final headers = await authRepository.authHeaders();
    final res = await client.get("/status/user/$userId", headers: headers);
    res.throwIfError();

    final items = res.data['data'];
    if (items is! List || items.isEmpty) {
      return [];
    }

    final statusMaps = items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (statusMaps.isEmpty) {
      return [];
    }

    final first = statusMaps.first;
    if (first.containsKey('statuses')) {
      return statusMaps.map(_storyFromPayload).toList();
    }

    final user = first['user'];
    if (user is Map) {
      return [
        _storyFromUserMap(
          Map<String, dynamic>.from(user),
          statuses: statusMaps.map(StatusItemModel.fromMap).toList(),
        ),
      ];
    }

    return [
      StoryItemModel(
        name: 'Status',
        userId: userId,
        initials: 'S',
        backgroundColor: Colors.black,
        ringColor: Colors.black,
        statuses: statusMaps.map(StatusItemModel.fromMap).toList(),
      ),
    ];
  }
}
