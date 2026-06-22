import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/config.dart';
import '../models/reading_entry.dart';
import '../models/sync_result.dart';
import 'app_database.dart';

class SyncOutcome {
  SyncOutcome({
    this.recorded = 0,
    this.alreadySynced = 0,
    this.errors = 0,
    this.photosUploaded = 0,
    this.photosFailed = 0,
    this.anomalies = 0,
  });

  int recorded;
  int alreadySynced;
  int errors;
  int photosUploaded;
  int photosFailed;
  int anomalies;

  int get synced => recorded + alreadySynced;
}

class SyncService {
  SyncService(this._api, this._db);

  final ApiClient _api;
  final AppDatabase _db;

  /// Alur lengkap: batch /readings/sync (paginate >500), lalu upload foto (§4.3, §4.4).
  Future<SyncOutcome> syncPeriod(int periodId) async {
    final outcome = SyncOutcome();
    final pending = await _db.unsyncedEntries(periodId);

    for (var i = 0; i < pending.length; i += ApiConfig.batchMax) {
      final batch = pending.sublist(
          i, (i + ApiConfig.batchMax).clamp(0, pending.length));
      await _syncBatch(periodId, batch, outcome);
    }

    // Foto: hanya setelah reading_id tersedia (synced=true).
    final photoQueue = await _db.pendingPhotoEntries(periodId);
    for (final e in photoQueue) {
      await _uploadPhoto(e, outcome);
    }
    return outcome;
  }

  Future<void> _syncBatch(
    int periodId,
    List<ReadingEntry> batch,
    SyncOutcome outcome,
  ) async {
    final body = await _api.postJson('/readings/sync', body: {
      'period_id': periodId,
      'readings': batch.map((e) => e.toSyncJson()).toList(),
    });
    final resp = SyncResponse.fromJson(body);

    final byUuid = {for (final e in batch) e.clientUuid: e};
    for (final r in resp.results) {
      final entry = byUuid[r.clientUuid];
      if (entry == null) continue;

      if (r.isOk) {
        entry.synced = true;
        entry.syncError = null;
        entry.readingId = r.readingId ?? entry.readingId;
        entry.consumption = r.consumption;
        entry.isEstimated = r.isEstimated;
        entry.isAnomaly = r.isAnomaly;
        entry.anomalyReason = r.anomalyReason;
        if (r.status == 'recorded') outcome.recorded++;
        if (r.status == 'already_synced') outcome.alreadySynced++;
        if (r.isAnomaly) outcome.anomalies++;
      } else {
        // status `error` — biarkan di antrian untuk dikoreksi petugas.
        entry.synced = false;
        entry.syncError = r.message ?? 'Galat sinkronisasi.';
        outcome.errors++;
      }
      await _db.upsertEntry(entry);
    }
  }

  Future<void> _uploadPhoto(ReadingEntry e, SyncOutcome outcome) async {
    final path = e.photoPath;
    final readingId = e.readingId;
    if (path == null || readingId == null) return;

    final file = File(path);
    if (!file.existsSync()) {
      outcome.photosFailed++;
      return;
    }

    // Pra-validasi client (§4.4) — hemat bandwidth & hindari 422.
    if (file.lengthSync() > ApiConfig.photoMaxBytes) {
      e.syncError = 'Foto melebihi 5 MB.';
      await _db.upsertEntry(e);
      outcome.photosFailed++;
      return;
    }
    final mime = lookupMimeType(path) ?? '';
    if (!ApiConfig.photoMimes.contains(mime)) {
      e.syncError = 'Format foto harus JPEG/PNG.';
      await _db.upsertEntry(e);
      outcome.photosFailed++;
      return;
    }

    try {
      final parts = mime.split('/');
      final form = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          path,
          filename: p.basename(path),
          contentType: MediaType(parts.first, parts.last),
        ),
      });
      await _api.postMultipart('/readings/$readingId/photo', form);
      e.photoSynced = true;
      e.syncError = null;
      await _db.upsertEntry(e);
      outcome.photosUploaded++;
    } on ApiException catch (ex) {
      // 403 "Bukan bacaan Anda" / 422 supersede → jangan loop retry; tandai.
      e.syncError = ex.message;
      await _db.upsertEntry(e);
      outcome.photosFailed++;
    }
  }
}
