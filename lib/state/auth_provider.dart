import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../core/config.dart';
import '../core/token_store.dart';
import '../data/auth_repository.dart';
import '../models/user.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._auth, this._tokens);

  final AuthRepository _auth;
  final TokenStore _tokens;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;
  bool busy = false;
  String? error;

  /// Sisa detik rate-limit login (untuk countdown UI, §3.1).
  int lockoutSeconds = 0;

  Future<void> bootstrap() async {
    final token = await _tokens.readToken();
    if (token == null || await _tokens.isExpired(ApiConfig.tokenTtl)) {
      await _tokens.clear();
      status = AuthStatus.signedOut;
    } else {
      user = await _tokens.readUser();
      status = user != null ? AuthStatus.signedIn : AuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    busy = true;
    error = null;
    lockoutSeconds = 0;
    notifyListeners();
    try {
      user = await _auth.login(email.trim(), password);
      status = AuthStatus.signedIn;
      return true;
    } on ApiException catch (e) {
      error = e.message;
      if (e.isUnprocessable) {
        lockoutSeconds = parseLockoutSeconds(e.message);
      }
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    busy = true;
    notifyListeners();
    await _auth.logout();
    user = null;
    status = AuthStatus.signedOut;
    busy = false;
    notifyListeners();
  }

  /// Dipicu interceptor saat 401.
  Future<void> forceSignOut() async {
    await _tokens.clear();
    user = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  void tickLockout() {
    if (lockoutSeconds > 0) {
      lockoutSeconds--;
      notifyListeners();
    }
  }

  /// Ekstrak sisa detik rate-limit dari pesan server (§3.1). Toleran terhadap
  /// variasi: "60 detik", "tunggu 60 dtk", "2 menit", "60s".
  static int parseLockoutSeconds(String message) {
    final m = message.toLowerCase();
    final menit = RegExp(r'(\d+)\s*menit').firstMatch(m);
    if (menit != null) return (int.tryParse(menit.group(1)!) ?? 0) * 60;
    final detik =
        RegExp(r'(\d+)\s*(?:detik|dtk|sec(?:ond)?s?|s)\b').firstMatch(m);
    if (detik != null) return int.tryParse(detik.group(1)!) ?? 0;
    return 0;
  }
}
