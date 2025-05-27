import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/network_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/custom_button.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _showNetworkError = false;
  bool _showGoogleError = false;

  @override
  Widget build(BuildContext context) {
    final networkService = Provider.of<NetworkService>(context);
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 80),
                      const AppLogo(),
                      const SizedBox(height: 32),
                      Text(
                        AppConstants.welcomeMessage,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppConstants.signInOrSignUp,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 48),

                      // Phone sign-in button
                      CustomButton(
                        text: AppConstants.continueWithPhone,
                        onPressed: () {
                          if (!networkService.isConnected) {
                            setState(() => _showNetworkError = true);
                            return;
                          }
                          Navigator.of(context).pushNamed('/phone_verification');
                        },
                        isLoading: authService.isLoading && authService.lastMethod == AuthMethod.phone,
                      ),

                      const SizedBox(height: 24),
                      Text(AppConstants.orContinueWith),
                      const SizedBox(height: 24),

                      // Google sign-in button
                      GoogleSignInButton(
                        onPressed: () async {
                          if (!networkService.isConnected) {
                            setState(() => _showNetworkError = true);
                            return;
                          }

                          // Direct Google Sign-In with Firebase
                          final success = await authService.signInWithGoogle();

                          if (success && mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/auth_success', (route) => false);
                          } else if (mounted && authService.errorMessage != null) {
                            setState(() => _showGoogleError = true);
                          }
                        },
                        isLoading: authService.isLoading && authService.lastMethod == AuthMethod.google,
                      ),

                      // Network error message
                      if (_showNetworkError) ...[
                        const SizedBox(height: 16),
                        ErrorContainer(
                          message: AppConstants.networkError,
                          onRetry: () async {
                            final isConnected = await networkService.checkConnection();
                            setState(() => _showNetworkError = !isConnected);
                          },
                        ),
                      ],

                      // Google sign-in error message
                      if (_showGoogleError && authService.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        ErrorContainer(
                          message: authService.errorMessage!,
                          onRetry: () {
                            setState(() => _showGoogleError = false);
                            authService.resetError();
                          },
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Footer with log in and sign up links
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(AppConstants.alreadyMember),
                        TextButton(
                          onPressed: () {
                            // In a real app, this would navigate to a login screen
                          },
                          child: Text(AppConstants.logIn),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(AppConstants.dontHaveAccount),
                        TextButton(
                          onPressed: () {
                            // In a real app, this would navigate to a sign up screen
                          },
                          child: Text(AppConstants.signUp),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}