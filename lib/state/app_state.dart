import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repository.dart';

final repoProvider = Provider<Repository>((_) => Repository());

/// Bump this after any mutation so FutureBuilder screens reload.
final refreshProvider = StateProvider<int>((_) => 0);

/// 'system' or a language code from L.supported.
final languageProvider = StateProvider<String>((_) => 'system');

/// Business settings loaded from SQLite, refreshed on bump.
final businessProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(refreshProvider);
  return ref.read(repoProvider).business();
});
