import 'package:flutter_test/flutter_test.dart';
import 'package:sia_pdam_field/models/assignment.dart';
import 'package:sia_pdam_field/models/period.dart';
import 'package:sia_pdam_field/models/reading_entry.dart';
import 'package:sia_pdam_field/models/sync_result.dart';
import 'package:sia_pdam_field/models/user.dart';

void main() {
  group('Assignment', () {
    test('fromJson + DB roundtrip mempertahankan nilai (angka = string)', () {
      final a = Assignment.fromJson({
        'connection_id': 101,
        'meter_no': 'MTR-000101',
        'customer_name': 'Budi',
        'address': 'Jl. Melati',
        'last_reading': '1234.00',
        'already_read': true,
      });
      expect(a.lastReading, '1234.00');
      expect(a.lastReading, isA<String>());
      expect(a.alreadyRead, isTrue);

      final back = Assignment.fromDb(a.toDb(7));
      expect(back.connectionId, 101);
      expect(back.meterNo, 'MTR-000101');
      expect(back.lastReading, '1234.00');
      expect(back.alreadyRead, isTrue);
    });

    test('default aman untuk field hilang', () {
      final a = Assignment.fromJson({'connection_id': 1});
      expect(a.lastReading, '0');
      expect(a.alreadyRead, isFalse);
    });
  });

  group('ReadingEntry', () {
    test('DB roundtrip mempertahankan flag & nilai', () {
      final e = ReadingEntry(
        clientUuid: 'u1',
        connectionId: 101,
        periodId: 7,
        currentReading: '1290',
        synced: true,
        readingId: 555,
        photoPath: '/x/y.jpg',
        photoSynced: false,
        isAnomaly: true,
        anomalyReason: 'naik tinggi',
        consumption: '56.00',
      );
      final back = ReadingEntry.fromDb(e.toDb());
      expect(back.clientUuid, 'u1');
      expect(back.synced, isTrue);
      expect(back.readingId, 555);
      expect(back.photoPath, '/x/y.jpg');
      expect(back.photoSynced, isFalse);
      expect(back.isAnomaly, isTrue);
      expect(back.anomalyReason, 'naik tinggi');
      expect(back.consumption, '56.00');
    });
  });

  group('Period & User', () {
    test('Period.fromJson', () {
      final p = Period.fromJson({'id': 7, 'code': '2026-06'});
      expect(p.id, 7);
      expect(p.code, '2026-06');
    });

    test('User.isReader hanya untuk role yang diizinkan (SoD)', () {
      expect(AppUser(id: 1, name: 'A', role: 'petugas_meter').isReader, isTrue);
      expect(AppUser(id: 1, name: 'A', role: 'super_admin').isReader, isTrue);
      expect(AppUser(id: 1, name: 'A', role: 'kasir').isReader, isFalse);
    });
  });

  group('SyncItemResult', () {
    test('status menentukan isOk', () {
      expect(SyncItemResult(clientUuid: 'u', status: 'recorded').isOk, isTrue);
      expect(SyncItemResult(clientUuid: 'u', status: 'already_synced').isOk,
          isTrue);
      expect(SyncItemResult(clientUuid: 'u', status: 'error').isOk, isFalse);
    });
  });
}
