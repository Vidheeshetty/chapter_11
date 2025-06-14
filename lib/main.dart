import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'services/network_service.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'utils/app_logger.dart';
import 'firebase_options.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize services
    final storageService = StorageService();
    await storageService.initialize();

    final networkService = NetworkService();
    await networkService.initialize();

    final authService = AuthService();
    await authService.initialize();

    // Run the app with providers
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NetworkService>.value(value: networkService),
          ChangeNotifierProvider<AuthService>.value(value: authService),
        ],
        child: const ChapterApp(),
      ),
    );
  } catch (e, stackTrace) {
    AppLogger.e('Error initializing app', e, stackTrace);
    // Show error screen if initialization fails
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Failed to initialize app. Please restart.'),
        ),
      ),
    ));
  }
}