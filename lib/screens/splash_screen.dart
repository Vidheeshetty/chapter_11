import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../services/network_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/loading_indicator.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  void _checkAuthAndNavigate() {
    final networkService = Provider.of<NetworkService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    if (networkService.isConnected) {
      // Wait a bit then check auth state
      _navigationTimer = Timer(
        const Duration(seconds: 2),
            () {
          if (!mounted) return;

          // Navigate based on auth state
          if (authService.isAuthenticated) {
            Navigator.of(context).pushReplacementNamed('/home');
          } else {
            Navigator.of(context).pushReplacementNamed('/welcome');
          }
        },
      );
    } else {
      // If not connected, wait for connection
      networkService.addListener(_onNetworkChanged);
    }
  }

  void _onNetworkChanged() {
    final networkService = Provider.of<NetworkService>(context, listen: false);

    if (networkService.isConnected) {
      // Remove listener to avoid multiple navigations
      networkService.removeListener(_onNetworkChanged);

      // Navigate after connection is restored
      _navigationTimer = Timer(
        const Duration(seconds: 1),
            () {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/welcome');
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final networkService = Provider.of<NetworkService>(context);
    final isConnected = networkService.isConnected;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 80),
                const SizedBox(height: 24),
                Text(
                  isConnected
                      ? AppConstants.appTagline
                      : AppConstants.waitingForNetwork,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                if (!isConnected) ...[
                  const SizedBox(height: 32),
                  const LoadingIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    AppConstants.retryingConnection,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  const SizedBox(height: 32),
                  const LoadingIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}