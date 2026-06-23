import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';

/// Penyimpanan token & user di secure storage (§3.1, §7).
/// iOS → Keychain · Android → EncryptedSharedPreferences. BUKAN plaintext.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions:
                  IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  static const _kToken = 'field.token';
  static const _kIssuedAt = 'field.token_issued_at';
  static const _kUser = 'field.user';

  String? _cachedToken;

  Future<void> save({required String token, required AppUser user}) async {
    _cachedToken = token;
    await _storage.write(key: _kToken, value: token);
    await _storage.write(
        key: _kIssuedAt, value: DateTime.now().toUtc().toIso8601String());
    await _storage.write(key: _kUser, value: jsonEncode(user.toJson()));
  }

  Future<String?> readToken() async {
    _cachedToken ??= await _storage.read(key: _kToken);
    return _cachedToken;
  }

  /// Versi sinkron untuk interceptor (token sudah di-cache setelah login/boot).
  String? get cachedToken => _cachedToken;

  Future<AppUser?> readUser() async {
    final raw = await _storage.read(key: _kUser);
    if (raw == null) return null;
    return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// true jika token sudah melewati TTL 12 jam (proaktif logout).
  Future<bool> isExpired(Duration ttl) async {
    final iso = await _storage.read(key: _kIssuedAt);
    if (iso == null) return true;
    final issued = DateTime.tryParse(iso);
    if (issued == null) return true;
    return DateTime.now().toUtc().difference(issued) >= ttl;
  }

  Future<void> clear() async {
    _cachedToken = null;
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kIssuedAt);
    await _storage.delete(key: _kUser);
  }
}
