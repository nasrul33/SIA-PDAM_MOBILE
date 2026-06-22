/// Entry bacaan lokal (offline-first). Kunci alami sync = (connection_id, period_id).
/// Skema wajib sesuai §4.3 "Pola local DB".
class ReadingEntry {
  ReadingEntry({
    required this.clientUuid,
    required this.connectionId,
    required this.periodId,
    this.currentReading,
    this.readingDate,
    this.synced = false,
    this.syncError,
    this.readingId,
    this.photoPath,
    this.photoSynced = false,
    this.isAnomaly = false,
    this.anomalyReason,
    this.consumption,
    this.isEstimated = false,
  });

  /// UUID v4 dibuat client saat entry — PK & idempotency key.
  final String clientUuid;
  final int connectionId;
  final int periodId;

  /// String desimal; `null` = minta estimasi server.
  String? currentReading;

  /// YYYY-MM-DD; `null` = default tanggal server.
  String? readingDate;

  bool synced;
  String? syncError;

  /// Diisi dari response sync → dipakai untuk upload foto.
  int? readingId;

  /// Path file foto lokal (belum tentu ter-upload).
  String? photoPath;
  bool photoSynced;

  bool isAnomaly;
  String? anomalyReason;
  String? consumption;
  bool isEstimated;

  Map<String, dynamic> toDb() => {
        'client_uuid': clientUuid,
        'connection_id': connectionId,
        'period_id': periodId,
        'current_reading': currentReading,
        'reading_date': readingDate,
        'synced': synced ? 1 : 0,
        'sync_error': syncError,
        'reading_id': readingId,
        'photo_path': photoPath,
        'photo_synced': photoSynced ? 1 : 0,
        'is_anomaly': isAnomaly ? 1 : 0,
        'anomaly_reason': anomalyReason,
        'consumption': consumption,
        'is_estimated': isEstimated ? 1 : 0,
      };

  factory ReadingEntry.fromDb(Map<String, dynamic> row) => ReadingEntry(
        clientUuid: row['client_uuid'] as String,
        connectionId: row['connection_id'] as int,
        periodId: row['period_id'] as int,
        currentReading: row['current_reading'] as String?,
        readingDate: row['reading_date'] as String?,
        synced: (row['synced'] as int? ?? 0) == 1,
        syncError: row['sync_error'] as String?,
        readingId: row['reading_id'] as int?,
        photoPath: row['photo_path'] as String?,
        photoSynced: (row['photo_synced'] as int? ?? 0) == 1,
        isAnomaly: (row['is_anomaly'] as int? ?? 0) == 1,
        anomalyReason: row['anomaly_reason'] as String?,
        consumption: row['consumption'] as String?,
        isEstimated: (row['is_estimated'] as int? ?? 0) == 1,
      );

  /// Payload untuk /readings/sync. `current_reading` selalu dikirim:
  /// string desimal, atau `null` untuk minta estimasi server (§4.3).
  Map<String, dynamic> toSyncJson() => {
        'client_uuid': clientUuid,
        'connection_id': connectionId,
        'current_reading': currentReading,
        if (readingDate != null) 'reading_date': readingDate,
      };
}
