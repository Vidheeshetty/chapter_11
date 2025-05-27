import 'dart:async';
import 'dart:math';
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

class _CodeVerificationScreenState extends State<CodeVerificationScreen>
    with TickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  bool _isCodeComplete = false;
  int _resendSeconds = 60;
  Timer? _resendTimer;
  bool _canResend = false;
  bool _isVerifying = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _startResendTimer();

    // Pre-fill with test code
    _codeController.text = '123456';
    _isCodeComplete = true;

    // Initialize shake animation for error feedback
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _shakeAnimation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _resendTimer = null;
    _codeController.dispose();
    _shakeController.dispose();
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
      }
    }
  }

  Future<void> _verifyCode() async {
    if (!mounted || _isVerifying || _codeController.text.length < 6) return;

    setState(() => _isVerifying = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.verifySmsCode(_codeController.text);

      if (mounted) {
        setState(() => _isVerifying = false);

        if (success) {
          // Navigate directly to welcome screen (sign in page)
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/welcome',
                (route) => false,
          );
        } else {
          // Shake animation for error
          _shakeController.forward().then((_) => _shakeController.reset());

          // Clear the code field
          _codeController.clear();
          setState(() => _isCodeComplete = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);

        // Shake animation for error
        _shakeController.forward().then((_) => _shakeController.reset());

        // Clear the code field
        _codeController.clear();
        setState(() => _isCodeComplete = false);
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
                children: [
                  // Header
                  Text(
                    AppConstants.enterCode,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                      children: [
                        const TextSpan(text: 'Enter the 6-digit code sent to '),
                        TextSpan(
                          text: authService.phoneNumber ?? 'your phone',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // PIN code input field with animation
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      final sineValue = sin(4 * 2 * pi * _shakeAnimation.value);
                      return Transform.translate(
                        offset: Offset(sineValue * 6, 0),
                        child: PinCodeTextField(
                          appContext: context,
                          length: 6,
                          controller: _codeController,
                          obscureText: false,
                          animationType: AnimationType.fade,
                          pinTheme: PinTheme(
                            shape: PinCodeFieldShape.box,
                            borderRadius: BorderRadius.circular(12),
                            fieldHeight: 56,
                            fieldWidth: 48,
                            activeFillColor: Colors.white,
                            inactiveFillColor: Colors.grey[100],
                            selectedFillColor: Theme.of(context).primaryColor.withOpacity(0.1),
                            activeColor: Theme.of(context).primaryColor,
                            inactiveColor: Colors.grey[300],
                            selectedColor: Theme.of(context).primaryColor,
                            disabledColor: Colors.grey[200],
                          ),
                          animationDuration: const Duration(milliseconds: 300),
                          enableActiveFill: true,
                          keyboardType: TextInputType.number,
                          enabled: !_isVerifying,
                          onCompleted: (value) {
                            if (mounted) {
                              setState(() => _isCodeComplete = true);
                              _verifyCode();
                            }
                          },
                          onChanged: (value) {
                            if (mounted) {
                              setState(() => _isCodeComplete = value.length == 6);
                            }
                          },
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Test code helper - prominent
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[50]!, Colors.blue[100]!],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue[200]!, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue[600],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.security, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Test Code: 123456',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'The test code 123456 is pre-filled and ready to verify.',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Resend code section
                  Center(
                    child: Column(
                      children: [
                        if (_canResend)
                          TextButton.icon(
                            onPressed: _resendCode,
                            icon: const Icon(Icons.refresh, size: 20),
                            label: const Text(AppConstants.sendCodeAgain),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).primaryColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Text(
                                  '${AppConstants.resendCodeIn} ${_formatTimeString(_resendSeconds)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Error message if any - simplified
                  if (authService.errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Verify button
                  CustomButton(
                    text: _isVerifying ? 'Verifying...' : 'Verify Code',
                    onPressed: _isCodeComplete && !_isVerifying ? _verifyCode : null,
                    isLoading: _isVerifying,
                    isEnabled: _isCodeComplete && !_isVerifying,
                  ),

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