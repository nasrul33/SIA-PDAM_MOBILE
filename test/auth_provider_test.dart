import 'package:flutter_test/flutter_test.dart';
import 'package:sia_pdam_field/state/auth_provider.dart';

void main() {
  group('AuthProvider.parseLockoutSeconds', () {
    test('format detik', () {
      expect(AuthProvider.parseLockoutSeconds('Coba lagi dalam 60 detik'), 60);
      expect(AuthProvider.parseLockoutSeconds('tunggu 5 dtk'), 5);
      expect(AuthProvider.parseLockoutSeconds('retry in 30s'), 30);
    });

    test('format menit dikonversi ke detik', () {
      expect(AuthProvider.parseLockoutSeconds('Tunggu 2 menit'), 120);
    });

    test('tanpa durasi → 0', () {
      expect(AuthProvider.parseLockoutSeconds('Kredensial salah.'), 0);
      expect(AuthProvider.parseLockoutSeconds(''), 0);
    });
  });
}
