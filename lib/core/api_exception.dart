/// Eksepsi terstruktur untuk semua galat API (§2).
class ApiException implements Exception {
  ApiException(
    this.statusCode,
    this.message, {
    this.fieldErrors,
    this.isNetwork = false,
  });

  /// Kode HTTP; `0` bila galat jaringan/timeout (tidak sampai server).
  final int statusCode;

  /// Pesan ramah-pengguna (server `message` bila ada).
  final String message;

  /// Map validasi field untuk 422 (§2.1). `null` = galat aturan bisnis.
  final Map<String, dynamic>? fieldErrors;

  final bool isNetwork;

  /// 401 → token invalid/expired → wajib logout + redirect login.
  bool get isUnauthorized => statusCode == 401;

  /// 403 → tidak berhak; jangan retry.
  bool get isForbidden => statusCode == 403;

  /// 422 → validasi / aturan bisnis / rate-limit.
  bool get isUnprocessable => statusCode == 422;

  /// 5xx → boleh retry dengan backoff.
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
