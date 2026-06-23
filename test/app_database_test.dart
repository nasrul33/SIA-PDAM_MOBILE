import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sia_pdam_field/data/app_database.dart';
import 'package:sia_pdam_field/models/assignment.dart';
import 'package:sia_pdam_field/models/reading_entry.dart';

Assignment _a(int id, String name, {bool read = false}) => Assignment(
      connectionId: id,
      meterNo: 'MTR-$id',
      customerName: name,
      address: 'Jl. $name',
      lastReading: '0',
      alreadyRead: read,
    );

ReadingEntry _e(int conn,
        {bool synced = false,
        int? readingId,
        String? photoPath,
        bool photoSynced = false}) =>
    ReadingEntry(
      clientUuid: 'u$conn',
      connectionId: conn,
      periodId: 7,
      currentReading: '100',
      synced: synced,
      readingId: readingId,
      photoPath: photoPath,
      photoSynced: photoSynced,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
      'replaceAssignments menyimpan & assignments terurut nama; replace bersih',
      () async {
    final db = AppDatabase.forTesting(inMemoryDatabasePath);
    await db.replaceAssignments(7, [_a(2, 'Siti'), _a(1, 'Budi')]);
    var list = await db.assignments(7);
    expect(list.map((a) => a.customerName), ['Budi', 'Siti']); // orderBy name

    // replace menghapus data lama periode itu
    await db.replaceAssignments(7, [_a(3, 'Cici')]);
    list = await db.assignments(7);
    expect(list.length, 1);
    expect(list.first.customerName, 'Cici');
  });

  test('upsert idempoten pada (connection_id, period_id) + unsynced/count',
      () async {
    final db = AppDatabase.forTesting(inMemoryDatabasePath);
    await db.upsertEntry(_e(101));
    await db.upsertEntry(_e(101, synced: true, readingId: 5)); // upsert sama
    final all = await db.allEntries(7);
    expect(all.length, 1, reason: 'kunci alami unik → satu baris');
    expect(all.first.synced, isTrue);
    expect(all.first.readingId, 5);

    await db.upsertEntry(_e(102)); // belum sync
    expect(await db.countUnsynced(7), 1);
    expect((await db.unsyncedEntries(7)).single.connectionId, 102);
  });

  test('entryForConnection mengembalikan baris yang tepat / null', () async {
    final db = AppDatabase.forTesting(inMemoryDatabasePath);
    await db.upsertEntry(_e(101));
    expect((await db.entryForConnection(101, 7))!.clientUuid, 'u101');
    expect(await db.entryForConnection(999, 7), isNull);
  });

  test('pendingPhotoEntries hanya synced+reading_id+photo belum upload',
      () async {
    final db = AppDatabase.forTesting(inMemoryDatabasePath);
    await db.upsertEntry(
        _e(1, synced: true, readingId: 1, photoPath: '/a.jpg')); // ✓
    await db
        .upsertEntry(_e(2, synced: false, photoPath: '/b.jpg')); // belum sync
    await db.upsertEntry(_e(3, synced: true, readingId: 3)); // tanpa foto
    await db.upsertEntry(_e(4,
        synced: true,
        readingId: 4,
        photoPath: '/d.jpg',
        photoSynced: true)); // sudah upload
    final pending = await db.pendingPhotoEntries(7);
    expect(pending.map((e) => e.connectionId), [1]);
  });
}
