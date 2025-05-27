import 'dart:async';
import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../widgets/app_logo.dart';

class AuthSuccessScreen extends StatefulWidget {
  const AuthSuccessScreen({Key? key}) : super(key: key);

  @override
  State<AuthSuccessScreen> createState() => _AuthSuccessScreenState();
}

class _AuthSuccessScreenState extends State<AuthSuccessScreen> {
  Timer? _redirectTimer;
  int _activeDotIndex = 0;

  @override
  void initState() {
    super.initState();

    // Start dot animation
    _startDotAnimation();

    // Redirect to home after 3 seconds
    _redirectTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        // Navigate to the main app
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  void _startDotAnimation() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _activeDotIndex = (_activeDotIndex + 1) % 3;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green[50],
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.green,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),

                // App logo
                const AppLogo(size: 60),
                const SizedBox(height: 32),

                // Success message
                Text(
                  AppConstants.signInSuccessful,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  AppConstants.redirectingToOnboarding,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

                // Animated loading dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) => _buildDot(index == _activeDotIndex)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Theme.of(context).primaryColor : Colors.grey[300],
      ),
    );
  }
}