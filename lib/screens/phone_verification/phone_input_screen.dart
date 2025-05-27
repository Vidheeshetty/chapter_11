import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({Key? key}) : super(key: key);

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedCountryCode = '+91';
  bool _isButtonEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_validateInput);
    // Pre-fill with test number
    _useTestNumber();
  }

  @override
  void dispose() {
    _phoneController.removeListener(_validateInput);
    _phoneController.dispose();
    super.dispose();
  }

  void _validateInput() {
    if (mounted) {
      setState(() {
        _isButtonEnabled = _phoneController.text.length >= 10;
      });
    }
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (value.length < 10) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  void _useTestNumber() {
    setState(() {
      _selectedCountryCode = '+91';
      _phoneController.text = '7718556613';
      _isButtonEnabled = true;
    });
  }

  Future<void> _submitPhoneNumber() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final fullPhoneNumber = '$_selectedCountryCode${_phoneController.text.trim()}';

    try {
      // Send verification code
      final success = await authService.verifyPhoneNumber(fullPhoneNumber);

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          // Navigate to code verification screen
          Navigator.of(context).pushNamed('/code_verification');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      AppConstants.enterPhone,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We\'ll send you a verification code to confirm your number',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Phone number input with country code
                    Text(
                      'Phone Number',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Country code dropdown
                        Container(
                          width: 80,
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCountryCode,
                              icon: const Icon(Icons.arrow_drop_down, size: 20),
                              items: const [
                                DropdownMenuItem(
                                  value: '+91',
                                  child: Text('+91', style: TextStyle(fontSize: 14)),
                                ),
                                DropdownMenuItem(
                                  value: '+1',
                                  child: Text('+1', style: TextStyle(fontSize: 14)),
                                ),
                                DropdownMenuItem(
                                  value: '+44',
                                  child: Text('+44', style: TextStyle(fontSize: 14)),
                                ),
                              ],
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() => _selectedCountryCode = newValue);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Phone number input
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              hintText: '1234567890',
                              prefixIcon: const Icon(Icons.phone),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Theme.of(context).primaryColor),
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: _validatePhoneNumber,
                            onFieldSubmitted: (_) => _submitPhoneNumber(),
                            enabled: !_isLoading,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Test number info - simplified
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green[50]!, Colors.green[100]!],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green[200]!, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green[600],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.info, color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Test Number Ready',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '+91 7718556613 is pre-filled. Use code 123456 for verification.',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 13,
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

                    // Send code button
                    CustomButton(
                      text: _isLoading ? AppConstants.sending : AppConstants.sendCode,
                      onPressed: _isButtonEnabled && !_isLoading ? _submitPhoneNumber : null,
                      isLoading: _isLoading,
                      isEnabled: _isButtonEnabled,
                    ),

                    const SizedBox(height: 16),

                    // Terms and conditions
                    Text(
                      'By continuing, you agree to receive SMS messages for verification. Standard messaging rates may apply.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}