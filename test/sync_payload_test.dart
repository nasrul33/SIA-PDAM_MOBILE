import 'package:flutter_test/flutter_test.dart';
import 'package:sia_pdam_field/models/reading_entry.dart';
import 'package:sia_pdam_field/models/sync_result.dart';

void main() {
  group('ReadingEntry.toSyncJson', () {
    test('mengirim current_reading sebagai string', () {
      final e = ReadingEntry(
        clientUuid: 'u1',
        connectionId: 101,
        periodId: 7,
        currentReading: '1290',
      );
      final json = e.toSyncJson();
      expect(json['current_reading'], '1290');
      expect(json['current_reading'], isA<String>());
      expect(json.containsKey('reading_date'), isFalse);
    });

    test('current_reading null = minta estimasi', () {
      final e = ReadingEntry(
        clientUuid: 'u2',
        connectionId: 102,
        periodId: 7,
        currentReading: null,
      );
      expect(e.toSyncJson()['current_reading'], isNull);
    });
  });

  group('SyncResponse.fromJson', () {
    test('parse recorded + error', () {
      final resp = SyncResponse.fromJson({
        'summary': {'recorded': 1, 'already_synced': 0, 'error': 1},
        'results': [
          {
            'client_uuid': 'u1',
            'status': 'recorded',
            'reading_id': 555,
            'consumption': '56.00',
            'is_estimated': false,
            'is_anomaly': false,
            'anomaly_reason': null,
          },
          {
            'client_uuid': 'u2',
            'status': 'error',
            'message': 'Angka meter turun.',
          },
        ],
      });
      expect(resp.recorded, 1);
      expect(resp.error, 1);
      expect(resp.results.first.isOk, isTrue);
      expect(resp.results.first.readingId, 555);
      expect(resp.results.last.isOk, isFalse);
      expect(resp.results.last.message, 'Angka meter turun.');
    });
  });
}
