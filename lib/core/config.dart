/// Konstanta wajib dari kontrak API SIA-PDAM Field v1 (§0).
class ApiConfig {
  ApiConfig._();

  static const String baseUrlProd = 'https://pdamcore.web.id/api/v1/field';

  /// Host dev. Untuk emulator Android + `php artisan serve`, pakai
  /// `http://10.0.2.2:8000/api/v1/field` (10.0.2.2 = alias emulator ke localhost host),
  /// set [useProd] = false, dan aktifkan cleartext di debug manifest.
  static const String baseUrlDev = 'http://10.0.2.2:8000/api/v1/field';

  /// Set `false` untuk menunjuk ke [baseUrlDev] (pengujian lokal).
  static const bool useProd = true;

  static String get baseUrl => useProd ? baseUrlProd : baseUrlDev;

  /// Maksimal item per POST /readings/sync.
  static const int batchMax = 500;

  /// Foto maksimal 5 MB.
  static const int photoMaxBytes = 5 * 1024 * 1024;

  /// Format foto yang diterima server.
  static const List<String> photoMimes = <String>['image/jpeg', 'image/png'];

  /// TTL token (12 jam = satu shift). Hanya untuk info UI/proaktif logout.
  static const Duration tokenTtl = Duration(hours: 12);

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
