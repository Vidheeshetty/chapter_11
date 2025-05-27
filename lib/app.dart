import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'constants/app_constants.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/phone_verification/phone_input_screen.dart';
import 'screens/phone_verification/code_verification_screen.dart';
import 'screens/auth_result/auth_success_screen.dart';
import 'screens/auth_result/auth_failure_screen.dart';
import 'screens/home_screen.dart';

class ChapterApp extends StatelessWidget {
  const ChapterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Follow system theme
      home: const SplashScreen(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/phone_verification': (context) => const PhoneInputScreen(),
        '/code_verification': (context) => const CodeVerificationScreen(),
        '/auth_success': (context) => const AuthSuccessScreen(),
        '/auth_failure': (context) => const AuthFailureScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}