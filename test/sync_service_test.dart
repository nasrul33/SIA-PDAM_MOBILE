import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sia_pdam_field/core/api_client.dart';
import 'package:sia_pdam_field/core/token_store.dart';
import 'package:sia_pdam_field/data/app_database.dart';
import 'package:sia_pdam_field/data/sync_service.dart';
import 'package:sia_pdam_field/models/reading_entry.dart';

/// Adapter Dio yang selalu mengembalikan satu body JSON tetap.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.body);
  final String body;
  @override
  Future<ResponseBody> fetch(
          RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async =>
      ResponseBody.fromString(body, 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });
  @override
  void close({bool force = false}) {}
}

ApiClient _api(String body) {
  final dio = Dio(BaseOptions(validateStatus: (_) => true))
    ..httpClientAdapter = _FixedAdapter(body);
  return ApiClient(TokenStore(), dio: dio, sleeper: (_) async {});
}

ReadingEntry _entry(String uuid, int conn) => ReadingEntry(
      clientUuid: uuid,
      connectionId: conn,
      periodId: 7,
      currentReading: '100',
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('syncPeriod memetakan recorded/already_synced/error + anomali ke DB',
      () async {
    final db = AppDatabase.forTesting(inMemoryDatabasePath);
    await db.upsertEntry(_entry('u1', 101));
    await db.upsertEntry(_entry('u2', 102));
    await db.upsertEntry(_entry('u3', 103));

    final api = _api('''
      {"summary":{"recorded":1,"already_synced":1,"error":1},
       "results":[
         {"client_uuid":"u1","status":"recorded","reading_id":11,"consumption":"5.00","is_anomaly":true,"anomaly_reason":"naik tajam"},
         {"client_uuid":"u2","status":"error","message":"Angka meter turun."},
         {"client_uuid":"u3","status":"already_synced","reading_id":13}
       ]}
    ''');

    final outcome = await SyncService(api, db).syncPeriod(7);

    expect(outcome.recorded, 1);
    expect(outcome.alreadySynced, 1);
    expect(outcome.errors, 1);
    expect(outcome.anomalies, 1);
    expect(outcome.synced, 2);

    final byConn = {for (final e in await db.allEntries(7)) e.connectionId: e};
    // u1: recorded + anomali
    expect(byConn[101]!.synced, isTrue);
    expect(byConn[101]!.readingId, 11);
    expect(byConn[101]!.isAnomaly, isTrue);
    expect(byConn[101]!.anomalyReason, 'naik tajam');
    expect(byConn[101]!.consumption, '5.00');
    // u2: error tetap di antrian
    expect(byConn[102]!.synced, isFalse);
    expect(byConn[102]!.syncError, 'Angka meter turun.');
    // u3: already_synced
    expect(byConn[103]!.synced, isTrue);
    expect(byConn[103]!.readingId, 13);

    // hanya u2 yang tersisa belum sync
    expect(await db.countUnsynced(7), 1);
  });

  test('syncPeriod tanpa entry → outcome kosong', () async {
    final db = AppDatabase.forTesting(inMemoryDatabasePath);
    final outcome = await SyncService(_api('{"summary":{},"results":[]}'), db)
        .syncPeriod(7);
    expect(outcome.synced, 0);
    expect(outcome.errors, 0);
  });
}
