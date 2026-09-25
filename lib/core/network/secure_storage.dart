import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds exactly one thing: this backend's opaque session token (see
/// backend/README.md). The app never has a GitHub token, a Gemini key, or
/// any other secret to store — this is intentionally a one-purpose class
/// rather than a general key-value store, so it's obvious at a glance that
/// nothing sensitive-beyond-this is accumulating here over time.
class SecureSessionStorage {
  SecureSessionStorage._();
  static final SecureSessionStorage instance = SecureSessionStorage._();

  static const _sessionTokenKey = 'git_manager.session_token';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> readSessionToken() => _storage.read(key: _sessionTokenKey);

  Future<void> writeSessionToken(String token) => _storage.write(key: _sessionTokenKey, value: token);

  Future<void> clear() => _storage.delete(key: _sessionTokenKey);
}
