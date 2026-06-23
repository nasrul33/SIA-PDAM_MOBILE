import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/token_store.dart';
import '../models/user.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  /// POST /auth/login — publik, tanpa Authorization (§3.1).
  Future<AppUser> login(String email, String password) async {
    final body = await _api.postJson(
      '/auth/login',
      body: {'email': email, 'password': password},
      skipAuth: true,
    );

    final token = body['token'] as String?;
    final userJson = body['user'] as Map<String, dynamic>?;
    if (token == null || userJson == null) {
      throw ApiException(0, 'Respons login tidak valid.');
    }
    final user = AppUser.fromJson(userJson);

    // SoD: hanya petugas_meter / super_admin.
    if (!user.isReader) {
      throw ApiException(
          403, 'Akun ini tidak berhak mengakses aplikasi lapangan.');
    }

    await _tokens.save(token: token, user: user);
    return user;
  }

  /// POST /auth/logout — token dicabut server; bersihkan storage apa pun hasilnya.
  Future<void> logout() async {
    try {
      await _api.postJson('/auth/logout');
    } on ApiException {
      // Abaikan; token tetap kita hapus lokal.
    } finally {
      await _tokens.clear();
    }
  }

  Future<AppUser?> currentUser() => _tokens.readUser();
}
