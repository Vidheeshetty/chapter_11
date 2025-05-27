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

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_validateInput);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _validateInput() {
    setState(() {
      // Enable button only if phone number is 10 digits (excluding country code)
      _isButtonEnabled = _phoneController.text.length >= 10;
    });
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
    if (_formKey.currentState!.validate()) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final fullPhoneNumber = '$_selectedCountryCode${_phoneController.text.trim()}';

      // Send verification code
      final success = await authService.verifyPhoneNumber(fullPhoneNumber);

      if (success && mounted) {
        // Navigate to code verification screen
        Navigator.of(context).pushNamed('/code_verification');
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
              const SizedBox(height: 24),

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
                        hintText: '123-456-7890',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: _validatePhoneNumber,
                      onFieldSubmitted: (_) => _submitPhoneNumber(),
                    ),
                  ),
                ],
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
                text: AppConstants.sendCode,
                onPressed: _submitPhoneNumber,
                isLoading: authService.isLoading,
                isEnabled: _isButtonEnabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}