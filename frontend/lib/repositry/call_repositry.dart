import 'dart:io';
import 'package:flint_client/flint_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/model/call_item_model.dart';
import 'package:frontend/model/call_session_model.dart';
import 'package:frontend/provider/core_provider.dart';
import 'package:frontend/repositry/auth_repositry.dart';

class CallRepositry {
  CallRepositry({required this.client, required this.authRepository});

  final FlintClient client;
  final AuthRepositry authRepository;

  Future<CallSessionModel> createCall({
    required String recipientId,
    required String callType,
    String? conversationId,
  }) async {
    final headers = await authRepository.authHeaders();
    final res = await client.post(
      '/calls',
      headers: headers,
      body: {
        'recipientId': recipientId,
        if (conversationId != null && conversationId.trim().isNotEmpty)
          'conversationId': conversationId.trim(),
        'callType': callType == 'video' ? 'video' : 'audio',
      },
    );
    res.throwIfError();

    return CallSessionModel.fromMap(_responseData(res.data));
  }

  Future<CallSessionModel> endCall(String callId) async {
    final headers = await authRepository.authHeaders();
    final res = await client.post('/calls/$callId/end', headers: headers);
    res.throwIfError();

    return CallSessionModel.fromMap(_responseData(res.data));
  }

  Future<CallSessionModel> acceptCall(String callId) async {
    final headers = await authRepository.authHeaders();
    final res = await client.post('/calls/$callId/accept', headers: headers);
    res.throwIfError();

    return CallSessionModel.fromMap(_responseData(res.data));
  }

  Future<CallSessionModel> rejectCall(String callId) async {
    final headers = await authRepository.authHeaders();
    final res = await client.post('/calls/$callId/reject', headers: headers);
    res.throwIfError();

    return CallSessionModel.fromMap(_responseData(res.data));
  }

  Future<List<CallItemModel>> getRecentCalls() async {
    final headers = await authRepository.authHeaders();
    final res = await client.get(
      '/calls/recent',
      headers: headers,
      cacheConfig: CacheConfig(maxAge: Duration.zero),
    );
    res.throwIfError();

    final responseData = res.data;
    final rawCalls = responseData is Map
        ? responseData['data'] as List<dynamic>? ?? const []
        : const [];

    return rawCalls
        .whereType<Map>()
        .map((item) => CallItemModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<CallSessionModel> uploadCallRecording({
    required String callId,
    required File file,
  }) async {
    final headers = await authRepository.authHeaders();
    final res = await client.post(
      '/calls/$callId/recording',
      headers: headers,
      files: {'file': file},
    );
    res.throwIfError();

    return CallSessionModel.fromMap(_responseData(res.data));
  }

  Map<String, dynamic> _responseData(dynamic responseData) {
    final rawData = responseData is Map ? responseData['data'] : null;
    return rawData is Map ? Map<String, dynamic>.from(rawData) : {};
  }
}

final callRepositryProvider = Provider<CallRepositry>((ref) {
  final client = ref.read(flintCLient);
  final authRepository = ref.read(authRepositryProvider);
  return CallRepositry(client: client, authRepository: authRepository);
});
