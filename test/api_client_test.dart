import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sia_pdam_field/core/api_client.dart';
import 'package:sia_pdam_field/core/api_exception.dart';
import 'package:sia_pdam_field/core/token_store.dart';

/// Adapter Dio palsu: kembalikan respons dari antrian; `null` = lempar galat jaringan.
class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this._queue);
  final List<({int? status, String body})?> _queue;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final item = _queue[calls];
    calls++;
    if (item == null) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.connectionError);
    }
    return ResponseBody.fromString(item.body, item.status ?? 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(List<({int? status, String body})?> queue,
    {void Function()? onUnauth}) {
  final dio = Dio(BaseOptions(validateStatus: (_) => true))
    ..httpClientAdapter = _QueueAdapter(queue);
  return ApiClient(
    TokenStore(),
    dio: dio,
    onUnauthorized: onUnauth == null ? null : () async => onUnauth(),
    sleeper: (_) async {}, // tanpa delay nyata di tes
  );
}

void main() {
  test('200 → kembalikan body map', () async {
    final c = _client([(status: 200, body: '{"ok":true}')]);
    final r = await c.getJson('/x');
    expect(r['ok'], isTrue);
  });

  test('422 → ApiException dengan fieldErrors', () async {
    final c = _client([
      (status: 422, body: '{"message":"Validasi","errors":{"email":["wajib"]}}')
    ]);
    try {
      await c.postJson('/x');
      fail('harus melempar');
    } on ApiException catch (e) {
      expect(e.statusCode, 422);
      expect(e.message, 'Validasi');
      expect(e.fieldErrors!['email'], isNotNull);
    }
  });

  test('401 → memicu onUnauthorized & isUnauthorized', () async {
    var logged = false;
    final c = _client([(status: 401, body: '{"message":"expired"}')],
        onUnauth: () => logged = true);
    try {
      await c.getJson('/x');
      fail('harus melempar');
    } on ApiException catch (e) {
      expect(e.isUnauthorized, isTrue);
    }
    expect(logged, isTrue);
  });

  test('500 di-retry lalu sukses', () async {
    final adapter = _QueueAdapter([
      (status: 500, body: '{}'),
      (status: 500, body: '{}'),
      (status: 200, body: '{"ok":1}'),
    ]);
    final dio = Dio(BaseOptions(validateStatus: (_) => true))
      ..httpClientAdapter = adapter;
    final c = ApiClient(TokenStore(), dio: dio, sleeper: (_) async {});
    final r = await c.getJson('/x');
    expect(r['ok'], 1);
    expect(adapter.calls, 3); // 2 gagal + 1 sukses
  });

  test('galat jaringan di-retry, lalu menyerah → ApiException network',
      () async {
    final c = _client([null, null, null, null]);
    try {
      await c.getJson('/x');
      fail('harus melempar');
    } on ApiException catch (e) {
      expect(e.isNetwork, isTrue);
    }
  });

  test('422 TIDAK di-retry (hanya 1 panggilan)', () async {
    final adapter = _QueueAdapter([
      (status: 422, body: '{"message":"x"}'),
      (status: 200, body: '{"ok":1}'),
    ]);
    final dio = Dio(BaseOptions(validateStatus: (_) => true))
      ..httpClientAdapter = adapter;
    final c = ApiClient(TokenStore(), dio: dio, sleeper: (_) async {});
    await expectLater(c.getJson('/x'), throwsA(isA<ApiException>()));
    expect(adapter.calls, 1);
  });
}
