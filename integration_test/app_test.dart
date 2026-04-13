import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:data_analyzer/main.dart' as app;
import 'package:data_analyzer/services/api_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow Integration Test', () {
    testWidgets('Full Registration and OTP Verification Flow', (WidgetTester tester) async {
      // Enable mocks for deterministic test
      ApiService.useMocks = true;

      app.main();
      await tester.pumpAndSettle();

      // 1. Navigate to Register Page
      final registerTextButton = find.text("Don't have an account? Login"); // Note: This might be the login page button
      // Wait, if we are at LoginPage, we should find "Don't have an account? Register"
      // Let's check Translations for the exact string
      
      final goToRegister = find.textContaining('Register');
      await tester.tap(goToRegister.last); // Tapping the 'Register' at the bottom of login page
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);

      // 2. Fill Registration Details
      Finder findField(String label) => find.widgetWithText(TextFormField, label);

      await tester.enterText(findField('First Name'), 'Integration');
      await tester.enterText(findField('Last Name'), 'Test');
      await tester.enterText(findField('Email'), 'itest@example.com');
      await tester.enterText(findField('Username'), 'itestuser');
      await tester.enterText(findField('Phone Number'), '1234567890');
      await tester.enterText(findField('Password'), 'Password123');
      await tester.enterText(findField('Confirm Password'), 'Password123');

      final registerButton = find.widgetWithText(ElevatedButton, 'Register');
      await tester.ensureVisible(registerButton);
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      // 3. Verify Navigation to OTP Page
      expect(find.text('OTP Verification'), findsOneWidget);

      // 4. Enter OTP
      await tester.enterText(find.byType(TextField), '123456');
      final verifyButton = find.widgetWithText(ElevatedButton, 'Verify OTP');
      await tester.tap(verifyButton);
      await tester.pumpAndSettle();

      // 5. Verify Navigation to Home
      expect(find.text('OSINT Data Analyzer'), findsWidgets); // Title in home page
      expect(find.byIcon(Icons.search), findsWidgets);
    });
  });
}
