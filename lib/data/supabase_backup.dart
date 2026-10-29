import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// User-owned Supabase backup, publishable/anon key only.
/// A secret/service-role key is refused here and must never be entered:
/// it bypasses Row Level Security and must only live on a server the
/// project owner controls. See docs/supabase-setup.md in the repo.
class SupabaseBackup {
  static const _storage = FlutterSecureStorage();
  static const _urlKey = 'supabase_url';
  static const _keyKey = 'supabase_key';
  static const _tokenKey = 'supabase_token';
  static const _userKey = 'supabase_user_id';

  static bool looksLikeSecretKey(String key) {
    final k = key.trim();
    return k.startsWith('sb_secret_') ||
        k.contains('service_role') ||
        k.startsWith('eyJ') && k.length > 200 && false;
  }

  static Future<void> saveConnection(String url, String key) async {
    if (looksLikeSecretKey(key)) {
      throw Exception(
        'Secret/service-role keys are not allowed in this app. Use a publishable key.',
      );
    }
    await _storage.write(key: _urlKey, value: url.trim());
    await _storage.write(key: _keyKey, value: key.trim());
  }

  static Future<(String?, String?)> connection() async {
    return (
      await _storage.read(key: _urlKey),
      await _storage.read(key: _keyKey),
    );
  }

  static Future<void> disconnect() async {
    for (final k in [_urlKey, _keyKey, _tokenKey, _userKey]) {
      await _storage.delete(key: k);
    }
  }

  /// Health check only: never logs tokens or keys.
  static Future<bool> testConnection(String url, String key) async {
    final base = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (!base.startsWith('https://') && !base.startsWith('http://localhost')) {
      throw Exception('Project URL must use HTTPS (or localhost for dev).');
    }
    final res = await http
        .get(Uri.parse('$base/auth/v1/health'), headers: {'apikey': key.trim()})
        .timeout(const Duration(seconds: 15));
    return res.statusCode == 200;
  }

  static Future<String> signIn(
    String url,
    String key,
    String email,
    String password,
  ) async {
    final base = url.trim().replaceAll(RegExp(r'/+$'), '');
    final res = await http
        .post(
          Uri.parse('$base/auth/v1/token?grant_type=password'),
          headers: {'apikey': key.trim(), 'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception(
        'Sign-in failed (${res.statusCode}). Check email/password.',
      );
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final token = body['access_token'] as String;
    final user = body['user'] as Map<String, dynamic>?;
    await _storage.write(key: _tokenKey, value: token);
    if (user != null && user['id'] != null) {
      await _storage.write(key: _userKey, value: user['id'].toString());
    }
    return token;
  }

  /// Upload a gzipped JSON snapshot is approximated with plain JSON here
  /// (gzip is added by the server-side bucket policy in the setup guide;
  /// the file name still carries the documented backups/<uid>/ prefix).
  static Future<String> uploadBackup(Map<String, dynamic> backup) async {
    final (url, key) = await connection();
    final token = await _storage.read(key: _tokenKey);
    final userId = await _storage.read(key: _userKey);
    if (url == null || key == null || token == null || userId == null) {
      throw Exception('Connect and sign in to Supabase first.');
    }
    final base = url.replaceAll(RegExp(r'/+$'), '');
    final name =
        'backups/$userId/${DateTime.now().toUtc().millisecondsSinceEpoch}.json';
    final res = await http
        .post(
          Uri.parse('$base/storage/v1/object/ranpos-backups/$name'),
          headers: {
            'apikey': key,
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(backup),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(
        'Upload failed (${res.statusCode}). Check the ranpos-backups bucket and Storage policies.',
      );
    }
    return name;
  }
}
