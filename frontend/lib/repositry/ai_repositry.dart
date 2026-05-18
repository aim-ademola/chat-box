import 'package:flint_client/flint_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/model/ai_summary_model.dart';
import 'package:frontend/provider/core_provider.dart';
import 'package:frontend/repositry/auth_repositry.dart';

class AiRepositry {
  AiRepositry({required this.client, required this.authRepository});

  final FlintClient client;
  final AuthRepositry authRepository;

  Future<AiSummaryModel> getChatSummary({
    required String conversationId,
  }) async {
    final headers = await authRepository.authHeaders();
    final res = await client.get(
      '/ai/chats/$conversationId/summary',
      headers: headers,
      cacheConfig: CacheConfig(maxAge: Duration.zero),
    );
    res.throwIfError();

    final responseData = res.data;
    final rawData = responseData is Map ? responseData['data'] : null;
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    return AiSummaryModel.fromMap(data);
  }

  Future<String> askChat({
    required String conversationId,
    required String question,
  }) async {
    final headers = await authRepository.authHeaders();
    final res = await client.post(
      '/ai/chats/$conversationId/ask',
      headers: headers,
      body: {'question': question},
    );
    res.throwIfError();

    final responseData = res.data;
    final rawData = responseData is Map ? responseData['data'] : null;
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    return data['answer']?.toString() ?? 'No answer available.';
  }
}

final aiRepositryProvider = Provider<AiRepositry>((ref) {
  final client = ref.read(flintCLient);
  final authRepository = ref.read(authRepositryProvider);
  return AiRepositry(client: client, authRepository: authRepository);
});
