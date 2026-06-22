import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
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
    if (token == null || await _tokens.isExpired(const Duration(hours: 12))) {
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
        lockoutSeconds = _parseLockout(e.message);
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

  int _parseLockout(String message) {
    final m = RegExp(r'(\d+)\s*detik').firstMatch(message);
    return m != null ? int.tryParse(m.group(1)!) ?? 0 : 0;
  }
}
