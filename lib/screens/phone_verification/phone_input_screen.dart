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
  String _selectedCountryCode = '+91'; // Default to India
  bool _isButtonEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_validateInput);
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
        // Enable button only if phone number is 10 digits (excluding country code)
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

  void _submitPhoneNumber() async {
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
        // Error handling is done in the auth service and displayed via provider
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.phoneVerification),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.enterPhone,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'We\'ll send you a verification code',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),

              // Phone number input with country code
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
                    ),
                    child: Center(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCountryCode,
                          icon: const Icon(Icons.arrow_drop_down),
                          items: const [
                            DropdownMenuItem(
                              value: '+91',
                              child: Text('+91'),
                            ),
                            DropdownMenuItem(
                              value: '+1',
                              child: Text('+1'),
                            ),
                            DropdownMenuItem(
                              value: '+44',
                              child: Text('+44'),
                            ),
                            DropdownMenuItem(
                              value: '+86',
                              child: Text('+86'),
                            ),
                            DropdownMenuItem(
                              value: '+33',
                              child: Text('+33'),
                            ),
                            DropdownMenuItem(
                              value: '+49',
                              child: Text('+49'),
                            ),
                          ],
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedCountryCode = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Phone number input
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        hintText: '1234567890',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: _validatePhoneNumber,
                      onFieldSubmitted: (_) => _submitPhoneNumber(),
                      enabled: !_isLoading,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Test number hint
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Test Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use +917718556613 with code 123456 for testing',
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
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
                'By continuing, you agree to receive SMS messages for verification. Standard rates may apply.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}