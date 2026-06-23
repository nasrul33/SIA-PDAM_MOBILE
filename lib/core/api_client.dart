import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'config.dart';
import 'token_store.dart';

/// Wrapper Dio: header default, auth interceptor, dan normalisasi galat (§1, §2).
class ApiClient {
  ApiClient(this._tokenStore,
      {Dio? dio, this.onUnauthorized, Future<void> Function(Duration)? sleeper})
      : _sleep = sleeper ?? Future<void>.delayed {
    _dio = dio ??
        Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
          headers: {'Accept': 'application/json'},
          // Kita tangani semua status sendiri agar bisa di-map ke ApiException.
          validateStatus: (_) => true,
        ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _tokenStore.cachedToken;
        if (token != null && options.extra['skipAuth'] != true) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  late final Dio _dio;
  final TokenStore _tokenStore;
  final Future<void> Function(Duration) _sleep;

  /// Dipanggil saat menerima 401 dari endpoint terproteksi → app logout.
  final Future<void> Function()? onUnauthorized;

  Dio get raw => _dio;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    bool skipAuth = false,
  }) =>
      _send(() => _dio.post(
            path,
            data: body,
            options: Options(
              headers: {'Content-Type': 'application/json'},
              extra: {'skipAuth': skipAuth},
            ),
          ));

  Future<Map<String, dynamic>> postMultipart(String path, FormData form) =>
      _send(() => _dio.post(path, data: form));

  /// Jalankan request dengan retry exponential-backoff untuk galat sementara
  /// (5xx & jaringan). 4xx langsung dilempar tanpa retry (§2).
  Future<Map<String, dynamic>> _send(Future<Response> Function() call) async {
    var attempt = 0;
    while (true) {
      try {
        final res = await call();
        final code = res.statusCode ?? 0;
        if (code >= 500 && attempt < ApiConfig.maxRetries) {
          await _sleep(ApiConfig.retryBaseDelay * (1 << attempt));
          attempt++;
          continue;
        }
        return _handle(res);
      } on DioException catch (e) {
        if (_isNetwork(e) && attempt < ApiConfig.maxRetries) {
          await _sleep(ApiConfig.retryBaseDelay * (1 << attempt));
          attempt++;
          continue;
        }
        throw _fromDio(e);
      }
    }
  }

  bool _isNetwork(DioException e) =>
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.connectionError;

  Map<String, dynamic> _handle(Response res) {
    final code = res.statusCode ?? 0;
    final data = res.data;

    if (code == 200) {
      if (data is Map<String, dynamic>) return data;
      return {'data': data};
    }

    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final message = (map['message'] as String?) ?? _defaultMessage(code);
    final errors = map['errors'] as Map<String, dynamic>?;

    if (code == 401) {
      // Fire-and-forget: bersihkan sesi.
      onUnauthorized?.call();
    }
    throw ApiException(code, message, fieldErrors: errors);
  }

  ApiException _fromDio(DioException e) {
    if (_isNetwork(e)) {
      return ApiException(0, 'Tidak ada koneksi ke server.', isNetwork: true);
    }
    return ApiException(0, e.message ?? 'Galat jaringan.', isNetwork: true);
  }

  String _defaultMessage(int code) {
    switch (code) {
      case 401:
        return 'Sesi berakhir. Silakan masuk kembali.';
      case 403:
        return 'Anda tidak berhak melakukan tindakan ini.';
      case 422:
        return 'Permintaan ditolak.';
      case 500:
      default:
        return 'Galat server. Coba lagi nanti.';
    }
  }
}
