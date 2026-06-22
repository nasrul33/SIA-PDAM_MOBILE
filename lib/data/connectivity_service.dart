import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Membungkus connectivity_plus → stream `bool online` yang ringkas.
class ConnectivityService {
  ConnectivityService([Connectivity? c]) : _c = c ?? Connectivity();

  final Connectivity _c;

  static bool _isOnline(List<ConnectivityResult> r) =>
      r.isNotEmpty && r.any((e) => e != ConnectivityResult.none);

  Future<bool> isOnline() async => _isOnline(await _c.checkConnectivity());

  Stream<bool> get onStatusChange =>
      _c.onConnectivityChanged.map(_isOnline).distinct();
}
