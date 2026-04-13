import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:data_analyzer/main.dart';
import 'package:data_analyzer/theme_provider.dart';
import 'package:data_analyzer/language_provider.dart';
import 'package:data_analyzer/register_page.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: child,
    );
  }

  testWidgets('Login Validation Test - Invalid Email', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(const MyApp()));
    await tester.pumpAndSettle();

    final emailField = find.widgetWithText(TextFormField, 'Email');
    final loginButton = find.byType(ElevatedButton);

    await tester.enterText(emailField, 'not-an-email');
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('Login Validation Test - Empty Password', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(const MyApp()));
    await tester.pumpAndSettle();

    final emailField = find.widgetWithText(TextFormField, 'Email');
    final loginButton = find.byType(ElevatedButton);

    await tester.enterText(emailField, 'test@example.com');
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Enter password'), findsOneWidget);
  });

  testWidgets('Register Validation Test - Empty Fields', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(const MaterialApp(home: RegisterPage())));
    await tester.pumpAndSettle();

    final registerButton = find.text('Register'); 
    await tester.ensureVisible(registerButton);
    await tester.pumpAndSettle(); // Wait for scrolling to finish!
    
    await tester.tap(registerButton);
    await tester.pumpAndSettle();

    // In RegisterPage, 'enter_email' -> 'Enter Email'
    expect(find.text('Enter Email'), findsOneWidget);
  });

  testWidgets('Register Validation Test - Phone Number', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(const MaterialApp(home: RegisterPage())));
    await tester.pumpAndSettle();

    // Fill in other required fields so only Phone Number is missing/invalid
    await tester.enterText(find.widgetWithText(TextFormField, 'First Name'), 'John');
    await tester.enterText(find.widgetWithText(TextFormField, 'Last Name'), 'Doe');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'john@test.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'johndoe123');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'Password123!');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password'), 'Password123!');
    
    // Specifically test invalid phone number
    await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number'), '123');

    final registerButton = find.text('Register');
    await tester.ensureVisible(registerButton);
    await tester.pumpAndSettle(); // Wait for scrolling to finish!
    
    await tester.tap(registerButton);
    await tester.pumpAndSettle();

    expect(find.text('❌ Invalid or unrecognized number'), findsOneWidget);
  });

  testWidgets('Dark Mode Toggle Persistence Test', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(const MyApp()));
    await tester.pumpAndSettle();

    final themeProvider = Provider.of<ThemeProvider>(
        tester.element(find.byType(MyApp)), listen: false);
    
    expect(themeProvider.themeMode, ThemeMode.dark); // Default is dark based on theme_provider.dart

    // Toggle theme (manually via provider for this test)
    themeProvider.toggleTheme(false);
    await tester.pumpAndSettle();

    expect(themeProvider.themeMode, ThemeMode.light);
  });
}
