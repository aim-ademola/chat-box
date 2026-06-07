import 'package:flint_client/flint_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://rosemarie-nonforming-lukas.ngrok-free.dev',
);

final flintCLient = Provider(
  (ref) => FlintClient(
    baseUrl: apiBaseUrl,
    onError: (error) {
      print(error.toMap());
    },
    defaultCacheConfig: CacheConfig(forceRefresh: true, maxAge: Duration.zero),
  ),
);

final storageProvider = Provider((ref) => FlutterSecureStorage());
