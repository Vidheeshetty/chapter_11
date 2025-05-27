import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class NetworkService extends ChangeNotifier {
  bool _isConnected = false;
  bool _isInitialized = false;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  final Connectivity _connectivity = Connectivity();
  final InternetConnectionChecker _checker = InternetConnectionChecker();

  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    // Check initial connection status
    await _checkConnectivity();

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((_) {
      _checkConnectivity();
    });

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    final hasConnection = connectivityResult != ConnectivityResult.none;

    // Double check with actual internet connectivity
    bool hasInternet = false;
    if (hasConnection) {
      hasInternet = await _checker.hasConnection;
    }

    // Only update and notify if there's a change
    if (_isConnected != hasInternet) {
      _isConnected = hasInternet;
      notifyListeners();
    }
  }

  Future<bool> checkConnection() async {
    await _checkConnectivity();
    return _isConnected;
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }
}