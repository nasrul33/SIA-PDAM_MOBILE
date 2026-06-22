import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/api_exception.dart';
import '../data/app_database.dart';
import '../data/connectivity_service.dart';
import '../data/field_repository.dart';
import '../data/sync_service.dart';
import '../models/assignment.dart';
import '../models/period.dart';
import '../models/reading_entry.dart';

class FieldProvider extends ChangeNotifier {
  FieldProvider(this._repo, this._db, this._sync, this._connectivity) {
    _connectivity.isOnline().then((v) => online = v);
    _connSub = _connectivity.onStatusChange.listen(_onConnectivityChanged);
  }

  final FieldRepository _repo;
  final AppDatabase _db;
  final SyncService _sync;
  final ConnectivityService _connectivity;
  StreamSubscription<bool>? _connSub;
  static const _uuid = Uuid();

  bool online = true;

  void _onConnectivityChanged(bool isOnline) {
    final cameBackOnline = isOnline && !online;
    online = isOnline;
    notifyListeners();
    // Auto-sync saat sinyal kembali & ada antrian.
    if (cameBackOnline && selectedPeriod != null && unsyncedCount > 0) {
      syncNow();
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  List<Period> periods = [];
  Period? selectedPeriod;
  List<Assignment> assignments = [];
  Map<int, ReadingEntry> entriesByConnection = {};
  int unsyncedCount = 0;

  bool loading = false;
  bool syncing = false;
  String? error;
  SyncOutcome? lastSync;

  Future<void> loadPeriods() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      periods = await _repo.periods();
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectPeriod(Period period, {bool refresh = true}) async {
    selectedPeriod = period;
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (refresh) {
        try {
          assignments = await _repo.fetchAndCacheAssignments(period.id);
        } on ApiException catch (e) {
          // Offline → pakai cache.
          error = e.isNetwork ? null : e.message;
          assignments = await _repo.cachedAssignments(period.id);
        }
      } else {
        assignments = await _repo.cachedAssignments(period.id);
      }
      await _reloadEntries();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadEntries() async {
    if (selectedPeriod == null) return;
    final list = await _db.allEntries(selectedPeriod!.id);
    entriesByConnection = {for (final e in list) e.connectionId: e};
    unsyncedCount = await _db.countUnsynced(selectedPeriod!.id);
  }

  ReadingEntry? entryFor(int connectionId) => entriesByConnection[connectionId];

  /// Simpan/timpa bacaan lokal (offline). `currentReading` null = minta estimasi.
  Future<void> saveReading({
    required Assignment assignment,
    required String? currentReading,
    String? readingDate,
    String? photoPath,
  }) async {
    final periodId = selectedPeriod!.id;
    final existing = await _db.entryForConnection(assignment.connectionId, periodId);

    final entry = existing ??
        ReadingEntry(
          clientUuid: _uuid.v4(),
          connectionId: assignment.connectionId,
          periodId: periodId,
        );
    entry.currentReading = currentReading;
    entry.readingDate = readingDate;
    if (photoPath != null) {
      entry.photoPath = photoPath;
      entry.photoSynced = false;
    }
    // Diedit ulang → perlu sync lagi.
    entry.synced = false;
    entry.syncError = null;

    await _db.upsertEntry(entry);
    await _reloadEntries();
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (selectedPeriod == null || syncing) return;
    syncing = true;
    error = null;
    notifyListeners();
    try {
      // Refresh periode terbuka sebelum sync (§4.1).
      lastSync = await _sync.syncPeriod(selectedPeriod!.id);
      await _reloadEntries();
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }
}
