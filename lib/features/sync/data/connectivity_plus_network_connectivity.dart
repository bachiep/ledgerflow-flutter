import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:ledgerflow_flutter/features/sync/domain/network_connectivity.dart';

class ConnectivityPlusNetworkConnectivity implements NetworkConnectivity {
  ConnectivityPlusNetworkConnectivity({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  @override
  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _hasConnection(results);
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }

  @override
  Stream<bool> get onIsOnlineChanged {
    return _connectivity.onConnectivityChanged
        .map(_hasConnection)
        .handleError((Object _) {}, test: (error) => error is MissingPluginException);
  }
}

class AlwaysOnlineNetworkConnectivity implements NetworkConnectivity {
  const AlwaysOnlineNetworkConnectivity();

  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> get onIsOnlineChanged => const Stream<bool>.empty();
}
