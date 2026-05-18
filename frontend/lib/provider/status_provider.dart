import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/model/story_item_model.dart';
import 'package:frontend/repositry/auth_repositry.dart';
import 'package:frontend/provider/core_provider.dart';
import 'package:frontend/repositry/status_repositry.dart';

class StatusNotifier extends AsyncNotifier<List<StoryItemModel>> {
  @override
  Future<List<StoryItemModel>> build() async {
    return fetchStatuses();
  }

  Future<List<StoryItemModel>> fetchStatuses() async {
    final repository = ref.read(statusRepositoryProvider);
    final statuses = await repository.getAll();
    state = AsyncValue.data(statuses);
    return statuses;
  }

  Future<StoryItemModel> uploadStatus({
    required String content,
    required String type,
    File? file,
  }) async {
    final previous = state.asData?.value ?? <StoryItemModel>[];
    state = const AsyncValue.loading();
    final repository = ref.read(statusRepositoryProvider);
    final created = await repository.create(
      content: content,
      type: type,
      file: file,
    );

    final next = <StoryItemModel>[created, ...previous];
    state = AsyncValue.data(next);
    return created;
  }

  Future<List<StoryItemModel>> fetchStatusesByUser(String userId) async {
    final repository = ref.read(statusRepositoryProvider);
    return repository.getByUser(userId);
  }
}

final statusRepositoryProvider = Provider<StatusRepositry>((ref) {
  final client = ref.read(flintCLient);
  final authRepository = ref.read(authRepositryProvider);
  return StatusRepositry(client: client, authRepository: authRepository);
});

final statusProvider =
    AsyncNotifierProvider<StatusNotifier, List<StoryItemModel>>(
      StatusNotifier.new,
    );
