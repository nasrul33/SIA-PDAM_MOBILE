/// Hasil per-item dari POST /readings/sync (§4.3).
class SyncItemResult {
  SyncItemResult({
    required this.clientUuid,
    required this.status,
    this.readingId,
    this.consumption,
    this.isEstimated = false,
    this.isAnomaly = false,
    this.anomalyReason,
    this.message,
  });

  final String clientUuid;

  /// `recorded` | `already_synced` | `error`.
  final String status;
  final int? readingId;
  final String? consumption;
  final bool isEstimated;
  final bool isAnomaly;
  final String? anomalyReason;

  /// Pesan galat (status `error`) — wajib ditampilkan ke petugas.
  final String? message;

  bool get isOk => status == 'recorded' || status == 'already_synced';

  factory SyncItemResult.fromJson(Map<String, dynamic> json) => SyncItemResult(
        clientUuid: json['client_uuid'] as String? ?? '',
        status: json['status'] as String? ?? 'error',
        readingId: json['reading_id'] as int?,
        consumption: json['consumption']?.toString(),
        isEstimated: json['is_estimated'] as bool? ?? false,
        isAnomaly: json['is_anomaly'] as bool? ?? false,
        anomalyReason: json['anomaly_reason'] as String?,
        message: json['message'] as String?,
      );
}

class SyncResponse {
  SyncResponse({
    required this.recorded,
    required this.alreadySynced,
    required this.error,
    required this.results,
  });

  final int recorded;
  final int alreadySynced;
  final int error;
  final List<SyncItemResult> results;

  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as Map<String, dynamic>? ?? const {});
    final results = (json['results'] as List<dynamic>? ?? const [])
        .map((e) => SyncItemResult.fromJson(e as Map<String, dynamic>))
        .toList();
    return SyncResponse(
      recorded: summary['recorded'] as int? ?? 0,
      alreadySynced: summary['already_synced'] as int? ?? 0,
      error: summary['error'] as int? ?? 0,
      results: results,
    );
  }
}
