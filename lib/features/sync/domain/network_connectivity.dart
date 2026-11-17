abstract interface class NetworkConnectivity {
  Future<bool> isOnline();
  Stream<bool> get onIsOnlineChanged;
}
