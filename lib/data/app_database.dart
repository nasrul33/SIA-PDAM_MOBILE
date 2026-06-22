import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/assignment.dart';
import '../models/reading_entry.dart';

/// Local DB offline-first (sqflite). Menyimpan cache assignments & antrian bacaan.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'sia_pdam_field.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, _) async {
        await d.execute('''
          CREATE TABLE assignments (
            connection_id INTEGER NOT NULL,
            period_id     INTEGER NOT NULL,
            meter_no      TEXT,
            customer_name TEXT,
            address       TEXT,
            last_reading  TEXT,
            already_read  INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (connection_id, period_id)
          )
        ''');
        await d.execute('''
          CREATE TABLE reading_entries (
            client_uuid     TEXT PRIMARY KEY,
            connection_id   INTEGER NOT NULL,
            period_id       INTEGER NOT NULL,
            current_reading TEXT,
            reading_date    TEXT,
            synced          INTEGER NOT NULL DEFAULT 0,
            sync_error      TEXT,
            reading_id      INTEGER,
            photo_path      TEXT,
            photo_synced    INTEGER NOT NULL DEFAULT 0,
            is_anomaly      INTEGER NOT NULL DEFAULT 0,
            anomaly_reason  TEXT,
            consumption     TEXT,
            is_estimated    INTEGER NOT NULL DEFAULT 0,
            UNIQUE (connection_id, period_id)
          )
        ''');
      },
    );
  }

  // ---- Assignments ----

  Future<void> replaceAssignments(int periodId, List<Assignment> items) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('assignments', where: 'period_id = ?', whereArgs: [periodId]);
      final batch = txn.batch();
      for (final a in items) {
        batch.insert('assignments', a.toDb(periodId),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Assignment>> assignments(int periodId) async {
    final d = await db;
    final rows = await d.query('assignments',
        where: 'period_id = ?', whereArgs: [periodId], orderBy: 'customer_name');
    return rows.map(Assignment.fromDb).toList();
  }

  // ---- Reading entries ----

  /// Upsert entry berdasarkan kunci alami (connection_id, period_id).
  Future<void> upsertEntry(ReadingEntry e) async {
    final d = await db;
    await d.insert('reading_entries', e.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ReadingEntry?> entryForConnection(int connectionId, int periodId) async {
    final d = await db;
    final rows = await d.query('reading_entries',
        where: 'connection_id = ? AND period_id = ?',
        whereArgs: [connectionId, periodId],
        limit: 1);
    if (rows.isEmpty) return null;
    return ReadingEntry.fromDb(rows.first);
  }

  Future<List<ReadingEntry>> unsyncedEntries(int periodId) async {
    final d = await db;
    final rows = await d.query('reading_entries',
        where: 'period_id = ? AND synced = 0', whereArgs: [periodId]);
    return rows.map(ReadingEntry.fromDb).toList();
  }

  Future<List<ReadingEntry>> allEntries(int periodId) async {
    final d = await db;
    final rows = await d.query('reading_entries',
        where: 'period_id = ?', whereArgs: [periodId]);
    return rows.map(ReadingEntry.fromDb).toList();
  }

  /// Entry yang sudah sync tapi punya foto lokal belum ter-upload.
  Future<List<ReadingEntry>> pendingPhotoEntries(int periodId) async {
    final d = await db;
    final rows = await d.query(
      'reading_entries',
      where:
          'period_id = ? AND synced = 1 AND reading_id IS NOT NULL AND photo_path IS NOT NULL AND photo_synced = 0',
      whereArgs: [periodId],
    );
    return rows.map(ReadingEntry.fromDb).toList();
  }

  Future<int> countUnsynced(int periodId) async {
    final d = await db;
    final r = await d.rawQuery(
        'SELECT COUNT(*) c FROM reading_entries WHERE period_id = ? AND synced = 0',
        [periodId]);
    return (r.first['c'] as int?) ?? 0;
  }
}
