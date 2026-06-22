/// Konstanta wajib dari kontrak API SIA-PDAM Field v1 (§0).
class ApiConfig {
  ApiConfig._();

  static const String baseUrlProd = 'https://pdamcore.web.id/api/v1/field';

  /// Ganti host dev sesuai lingkungan pengujian internal.
  static const String baseUrlDev = 'https://pdamcore.web.id/api/v1/field';

  /// Set `false` untuk menunjuk ke [baseUrlDev].
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
