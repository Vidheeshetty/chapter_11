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
  bool _isGoogleLoading = false;
  bool _isPhoneLoading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<NetworkService, AuthService>(
      builder: (context, networkService, authService, child) {
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
                            onPressed: () async {
                              if (!networkService.isConnected) {
                                setState(() => _showNetworkError = true);
                                return;
                              }

                              setState(() {
                                _isPhoneLoading = true;
                                _showNetworkError = false;
                                _showGoogleError = false;
                              });

                              // Small delay to show loading state
                              await Future.delayed(const Duration(milliseconds: 300));

                              if (mounted) {
                                setState(() => _isPhoneLoading = false);
                                Navigator.of(context).pushNamed('/phone_verification');
                              }
                            },
                            isLoading: _isPhoneLoading,
                          ),

                          const SizedBox(height: 24),
                          Text(AppConstants.orContinueWith),
                          const SizedBox(height: 24),

                          // Google sign-in button
                          _buildGoogleSignInButton(networkService, authService),

                          // Network error message
                          if (_showNetworkError) ...[
                            const SizedBox(height: 16),
                            _buildErrorContainer(
                              AppConstants.networkError,
                                  () async {
                                final isConnected = await networkService.checkConnection();
                                setState(() => _showNetworkError = !isConnected);
                              },
                            ),
                          ],

                          // Google sign-in error message
                          if (_showGoogleError) ...[
                            const SizedBox(height: 16),
                            _buildErrorContainer(
                              authService.errorMessage ?? AppConstants.googleSignInFailed,
                                  () {
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Use phone or Google sign-in above to log in'),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Use phone or Google sign-in above to create account'),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
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
      },
    );
  }

  Widget _buildGoogleSignInButton(NetworkService networkService, AuthService authService) {
    return InkWell(
      onTap: _isGoogleLoading ? null : () => _handleGoogleSignIn(networkService, authService),
      borderRadius: BorderRadius.circular(25),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).dividerColor),
          color: _isGoogleLoading ? Colors.grey[100] : Colors.white,
        ),
        child: Center(
          child: _isGoogleLoading
              ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          )
              : Text(
            'G',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn(NetworkService networkService, AuthService authService) async {
    if (!networkService.isConnected) {
      setState(() => _showNetworkError = true);
      return;
    }

    print('Starting Google Sign-In from UI');

    setState(() {
      _isGoogleLoading = true;
      _showNetworkError = false;
      _showGoogleError = false;
    });

    try {
      // Clear any previous errors
      authService.resetError();

      print('Calling signInWithGoogle');
      // Attempt Google Sign-In
      final success = await authService.signInWithGoogle();

      print('Google Sign-In result: $success');

      if (mounted) {
        setState(() => _isGoogleLoading = false);

        if (success) {
          print('Navigating to success screen');
          // Add a small delay to ensure state is properly updated
          await Future.delayed(const Duration(milliseconds: 200));

          if (mounted) {
            // Navigate to success screen
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/auth_success',
                  (route) => false,
            );
          }
        } else {
          print('Google Sign-In failed, showing error');
          // Show error if sign-in failed
          setState(() => _showGoogleError = true);
        }
      }
    } catch (e) {
      print('Google Sign-In exception: $e');
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
          _showGoogleError = true;
        });
      }
    }
  }

  Widget _buildErrorContainer(String message, VoidCallback onRetry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[600], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red[600]),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: TextStyle(color: Theme.of(context).primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}