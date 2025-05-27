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
  int _resendSeconds = 60;
  Timer? _resendTimer;
  bool _canResend = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    // Cancel timer first
    _resendTimer?.cancel();
    _resendTimer = null;

    // Then dispose controller
    _codeController.dispose();

    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _resendSeconds = 60;
      _canResend = false;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  String _formatTimeString(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _resendCode() async {
    if (!_canResend || !mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final phoneNumber = authService.phoneNumber;

    if (phoneNumber != null) {
      // Reset the code field
      if (mounted) {
        _codeController.clear();
        setState(() => _isCodeComplete = false);
      }

      // Resend code and restart timer
      final success = await authService.verifyPhoneNumber(phoneNumber);
      if (success && mounted) {
        _startResendTimer();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification code sent successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _verifyCode() async {
    if (!mounted || _isVerifying) return;

    setState(() => _isVerifying = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.verifySmsCode(_codeController.text);

      if (mounted) {
        setState(() => _isVerifying = false);

        if (success) {
          // Use a delay to ensure state is properly updated
          await Future.delayed(const Duration(milliseconds: 100));

          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/auth_success',
                  (route) => false,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _fillTestCode() {
    if (mounted) {
      setState(() {
        _codeController.text = '123456';
        _isCodeComplete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(AppConstants.phoneVerification),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppConstants.enterCode,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Code sent to ${authService.phoneNumber ?? 'your phone'}',
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
                      if (mounted) {
                        setState(() => _isCodeComplete = true);
                      }
                    },
                    onChanged: (value) {
                      if (mounted) {
                        setState(() => _isCodeComplete = value.length == 6);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Test code helper
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.help_outline, size: 16, color: Colors.green[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Test Code',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'For test numbers, use code: 123456',
                          style: TextStyle(
                            color: Colors.green[600],
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _fillTestCode,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Fill Test Code',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Resend code section
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
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Error message if any
                  if (authService.errorMessage != null) ...[
                    Container(
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
                              authService.errorMessage!,
                              style: TextStyle(color: Colors.red[600]),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              authService.resetError();
                            },
                            child: Text(
                              'Retry',
                              style: TextStyle(color: Theme.of(context).primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Verify button
                  CustomButton(
                    text: 'Verify',
                    onPressed: _isCodeComplete && !_isVerifying ? _verifyCode : null,
                    isLoading: _isVerifying || authService.isLoading,
                    isEnabled: _isCodeComplete && !_isVerifying,
                  ),

                  // Extra padding for safe area
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}