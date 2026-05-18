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
    var item = res.data["data"];
    return StoryItemModel(
      name: item["name"],
      profilePicUrl: item["profilePicUrl"],
      initials: item["name"]
          .toString()
          .split(" ")
          .map((e) => e[1].toUpperCase())
          .join(),
      backgroundColor: Colors.black,
      ringColor: Colors.black,

      statuses: (item["statuses"])
          .map((e) => StatusItemModel.fromMap(e))
          .toList(),
    );
  }

  Future<List<StoryItemModel>> getAll() async {
    print("get here");
    final headers = await authRepository.authHeaders();
    final res = await client.get("/status", headers: headers);
    res.throwIfError();

    var data;
    try {
      data = (res.data['data'] as List<dynamic>)
          .map(
            (item) => StoryItemModel(
              name: item["name"],
              profilePicUrl: item["profilePicUrl"],
              initials: item["name"]
                  .toString()
                  .split(" ")
                  .map((e) => e[1].toUpperCase())
                  .join(),
              backgroundColor: Colors.black,
              ringColor: Colors.black,

              statuses: List<Map<String, dynamic>>.from(
                item['statuses'],
              ).map((e) => StatusItemModel.fromMap(e)).toList(),
            ),
          )
          .toList();
    } catch (e) {
      print(e);
    }

    print("this is the Model ${data}");

    return data;
  }

  Future<List<StoryItemModel>> getByUser(String userId) async {
    final headers = await authRepository.authHeaders();
    final res = await client.get("/status/user/$userId", headers: headers);
    res.throwIfError();
    return (res.data['data'] as List<dynamic>)
        .map(
          (item) => StoryItemModel(
            name: item["name"],
            profilePicUrl: item["profilePicUrl"],
            initials: item["name"]
                .toString()
                .split(" ")
                .map((e) => e[1].toUpperCase())
                .join(),
            backgroundColor: Colors.black,
            ringColor: Colors.black,

            statuses: (item["statuses"])
                .map((e) => StatusItemModel.fromMap(e))
                .toList(),
          ),
        )
        .toList();
  }
}
