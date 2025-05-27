import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chapter_11/widgets/app_logo.dart';
import 'package:chapter_11/widgets/custom_button.dart';
import 'package:chapter_11/widgets/loading_indicator.dart';

void main() {
  group('Chapter 11 Widget Tests', () {

    testWidgets('AppLogo widget displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLogo(size: 80),
          ),
        ),
      );

      // Verify the logo widget is present
      expect(find.byType(AppLogo), findsOneWidget);
    });

    testWidgets('CustomButton displays and responds to tap', (WidgetTester tester) async {
      bool buttonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(
              text: 'Test Button',
              onPressed: () {
                buttonPressed = true;
              },
            ),
          ),
        ),
      );

      // Verify button text
      expect(find.text('Test Button'), findsOneWidget);

      // Tap the button
      await tester.tap(find.text('Test Button'));
      await tester.pump();

      // Verify button was pressed
      expect(buttonPressed, true);
    });

    testWidgets('CustomButton shows loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(
              text: 'Loading Button',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      // Verify loading indicator is shown instead of text
      expect(find.byType(LoadingIndicator), findsOneWidget);
      expect(find.text('Loading Button'), findsNothing);
    });

    testWidgets('GoogleSignInButton displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              onPressed: () {},
            ),
          ),
        ),
      );

      // Verify Google button
      expect(find.text('G'), findsOneWidget);
      expect(find.byType(GoogleSignInButton), findsOneWidget);
    });

    testWidgets('LoadingIndicator displays', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(),
          ),
        ),
      );

      expect(find.byType(LoadingIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}