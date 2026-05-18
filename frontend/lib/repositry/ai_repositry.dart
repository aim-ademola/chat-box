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
    final data = responseData is Map
        ? Map<String, dynamic>.from(responseData['data'] as Map)
        : <String, dynamic>{};

    return AiSummaryModel.fromMap(data);
  }
}

final aiRepositryProvider = Provider<AiRepositry>((ref) {
  final client = ref.read(flintCLient);
  final authRepository = ref.read(authRepositryProvider);
  return AiRepositry(client: client, authRepository: authRepository);
});
