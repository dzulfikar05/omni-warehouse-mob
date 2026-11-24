import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityChecker {
  ConnectivityChecker._();

  static final ConnectivityChecker instance = ConnectivityChecker._();
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_hasConnection);

  Future<bool> isOnline() async =>
      _hasConnection(await _connectivity.checkConnectivity());

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}

final connectivityStatusProvider = StateProvider<bool>((ref) => true);
