import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';

class AuthFailureScreen extends StatelessWidget {
  const AuthFailureScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red[50],
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 32),

                // Error message
                Text(
                  authService.errorMessage ?? AppConstants.couldntSignIn,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Return button
                SizedBox(
                  width: 200,
                  child: CustomButton(
                    text: AppConstants.return_,
                    onPressed: () {
                      authService.resetError();
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/welcome',
                            (route) => false,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}