import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';

class CodeVerificationScreen extends StatefulWidget {
  const CodeVerificationScreen({Key? key}) : super(key: key);

  @override
  State<CodeVerificationScreen> createState() => _CodeVerificationScreenState();
}

class _CodeVerificationScreenState extends State<CodeVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isCodeComplete = false;
  int _resendSeconds = 60; // 1 minute countdown
  Timer? _resendTimer;
  bool _canResend = false;
  bool _isDisposed = false; // Track disposal state

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _isDisposed = true; // Mark as disposed first

    // Cancel timer before disposing controller
    _resendTimer?.cancel();
    _resendTimer = null;

    // Dispose controller
    _codeController.dispose();

    super.dispose();
  }

  void _startResendTimer() {
    // Cancel existing timer
    _resendTimer?.cancel();

    // Check if widget is still mounted
    if (_isDisposed || !mounted) return;

    setState(() {
      _resendSeconds = 60;
      _canResend = false;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Critical: Check if widget is disposed or unmounted
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }

      // Safe setState call
      if (mounted) {
        setState(() {
          if (_resendSeconds > 0) {
            _resendSeconds--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTimeString(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _resendCode() async {
    if (!_canResend || _isDisposed || !mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final phoneNumber = authService.phoneNumber;

    if (phoneNumber != null) {
      // Reset the code field
      if (mounted && !_isDisposed) {
        _codeController.clear();
        setState(() => _isCodeComplete = false);
      }

      // Resend code and restart timer
      final success = await authService.verifyPhoneNumber(phoneNumber);
      if (success && mounted && !_isDisposed) {
        _startResendTimer();
      }
    }
  }

  void _verifyCode() async {
    if (_isDisposed || !mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);

    // Submit verification code
    final success = await authService.verifySmsCode(_codeController.text);

    if (success && mounted && !_isDisposed) {
      // Navigate to success screen
      Navigator.of(context).pushNamedAndRemoveUntil('/auth_success', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return empty container if disposed
    if (_isDisposed) {
      return const SizedBox.shrink();
    }

    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.phoneVerification),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (mounted && !_isDisposed) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.enterCode,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Code sent to ${authService.phoneNumber}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),

            // PIN code input field
            PinCodeTextField(
              appContext: context,
              length: 6,
              controller: _codeController,
              obscureText: false,
              animationType: AnimationType.fade,
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(12),
                fieldHeight: 50,
                fieldWidth: 40,
                activeFillColor: Colors.white,
                inactiveFillColor: Colors.grey[100],
                selectedFillColor: Colors.grey[200],
                activeColor: Theme.of(context).primaryColor,
                inactiveColor: Colors.grey[300],
                selectedColor: Theme.of(context).primaryColor,
              ),
              animationDuration: const Duration(milliseconds: 300),
              enableActiveFill: true,
              keyboardType: TextInputType.number,
              onCompleted: (value) {
                if (mounted && !_isDisposed) {
                  setState(() => _isCodeComplete = true);
                }
              },
              onChanged: (value) {
                if (mounted && !_isDisposed) {
                  setState(() => _isCodeComplete = value.length == 6);
                }
              },
            ),

            const SizedBox(height: 16),

            // Resend code text
            Center(
              child: _canResend
                  ? TextButton(
                onPressed: _resendCode,
                child: const Text(AppConstants.sendCodeAgain),
              )
                  : Text(
                '${AppConstants.resendCodeIn} ${_formatTimeString(_resendSeconds)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),

            const SizedBox(height: 8),

            // Auto-detect message
            Center(
              child: Text(
                AppConstants.autoDetectCode,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),

            const SizedBox(height: 24),

            // Error message if any
            if (authService.errorMessage != null) ...[
              ErrorContainer(
                message: authService.errorMessage!,
                onRetry: () {
                  authService.resetError();
                },
              ),
              const SizedBox(height: 24),
            ],

            // Verify button
            CustomButton(
              text: 'Verify',
              onPressed: _isCodeComplete ? _verifyCode : null,
              isLoading: authService.isLoading,
              isEnabled: _isCodeComplete,
            ),
          ],
        ),
      ),
    );
  }
}