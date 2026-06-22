import '../core/api_client.dart';
import '../models/assignment.dart';
import '../models/period.dart';
import 'app_database.dart';

class FieldRepository {
  FieldRepository(this._api, this._db);

  final ApiClient _api;
  final AppDatabase _db;

  /// GET /periods — hanya periode terbuka. Refresh sebelum tiap sync (§4.1).
  Future<List<Period>> periods() async {
    final body = await _api.getJson('/periods');
    final list = (body['data'] as List<dynamic>? ?? const [])
        .map((e) => Period.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  /// GET /assignments?period_id= — unduh lalu cache ke local DB (§4.2).
  Future<List<Assignment>> fetchAndCacheAssignments(int periodId) async {
    final body = await _api.getJson('/assignments', query: {'period_id': periodId});
    final items = (body['data'] as List<dynamic>? ?? const [])
        .map((e) => Assignment.fromJson(e as Map<String, dynamic>))
        .toList();
    await _db.replaceAssignments(periodId, items);
    return items;
  }

  /// Versi offline — baca dari cache.
  Future<List<Assignment>> cachedAssignments(int periodId) =>
      _db.assignments(periodId);
}
