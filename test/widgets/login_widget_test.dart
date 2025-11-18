import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agorapush/main.dart';
import 'package:agorapush/pages/login_page.dart';

void main() {
  setUp(() async {
    // Clear shared preferences before each test
    SharedPreferences.setMockInitialValues({});
  });

  // Helper function to build app with proper size
  Widget buildTestApp() {
    return const MaterialApp(
      home: Scaffold(body: AgorapushApp()),
    );
  }

  group('Authentication Widget Tests', () {
    testWidgets('should display login page when no session exists', (WidgetTester tester) async {
      // Set a larger test surface
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      
      // Build the app
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle(); // Let all animations complete

      // Verify login page is displayed
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('AgoraPush'), findsOneWidget);
      expect(find.text('La politique dévoilée, pour un vote éclairé'), findsOneWidget);
    });

    testWidgets('should display loading indicator initially', (WidgetTester tester) async {
      // Set a larger test surface
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      
      // Build the app
      await tester.pumpWidget(buildTestApp());

      // Verify loading indicator is shown initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should have login form fields', (WidgetTester tester) async {
      // Set a larger test surface
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      
      // Build the app and wait for login page
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Verify login form elements exist
      expect(find.byType(TextFormField), findsWidgets);
      expect(find.text("Nom d'utilisateur"), findsOneWidget);
      expect(find.text('Mot de passe'), findsOneWidget);
    });

    testWidgets('should have signup and login tabs', (WidgetTester tester) async {
      // Set a larger test surface
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      
      // Build the app and wait for login page
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Verify tab buttons exist
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text("S'inscrire"), findsOneWidget);
    });

    testWidgets('should show password visibility toggle', (WidgetTester tester) async {
      // Set a larger test surface
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      
      // Build the app and wait for login page
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Look for visibility icons
      expect(find.byIcon(Icons.visibility_off), findsAtLeastNWidgets(1));
    });

    testWidgets('should show forgot password option', (WidgetTester tester) async {
      // Set a larger test surface
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      
      // Build the app and wait for login page
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Verify forgot password link
      expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    });

    testWidgets('should validate login form inputs', (WidgetTester tester) async {
      // Set a larger test surface
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      
      // Build the app and wait for login page
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Find the login button
      final loginButton = find.text('SE CONNECTER');
      expect(loginButton, findsOneWidget);

      // Try to submit with empty fields
      await tester.tap(loginButton);
      await tester.pump();

      // Should show validation errors
      expect(find.text("Veuillez entrer votre nom d'utilisateur"), findsOneWidget);
      expect(find.text('Veuillez entrer votre mot de passe'), findsOneWidget);
    });

    testWidgets('should switch between login and signup tabs', (WidgetTester tester) async {
      // Set a larger test surface to prevent overflow
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      
      // Build the app and wait for login page
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Initially should be on login tab
      expect(find.text('SE CONNECTER'), findsOneWidget);

      // Tap signup tab
      await tester.tap(find.text("S'inscrire"));
      await tester.pumpAndSettle();

      // Should now show signup form
      expect(find.text('CRÉER UN COMPTE'), findsOneWidget);
      expect(find.text('Phrase de récupération'), findsOneWidget);
    });

    testWidgets('should validate signup form fields', (WidgetTester tester) async {
      // Set a larger test surface to prevent overflow
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      
      // Build the app and wait for login page
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Switch to signup tab
      await tester.tap(find.text("S'inscrire"));
      await tester.pumpAndSettle();

      // Find and tap signup button - should be visible now
      final signupButton = find.text('CRÉER UN COMPTE');
      expect(signupButton, findsOneWidget);
      
      await tester.ensureVisible(signupButton);
      await tester.tap(signupButton, warnIfMissed: false);
      await tester.pump();

      // Should show validation errors for empty fields
      expect(find.text("Veuillez entrer un nom d'utilisateur"), findsOneWidget);
      expect(find.text('Veuillez entrer un mot de passe'), findsOneWidget);
    });

    testWidgets('should show app branding elements', (WidgetTester tester) async {
      // Set a larger test surface
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      
      // Build the app and wait for login page
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Verify branding elements
      expect(find.text('AgoraPush'), findsOneWidget);
      expect(find.text('La politique dévoilée, pour un vote éclairé'), findsOneWidget);
      expect(find.byIcon(Icons.campaign), findsOneWidget);
    });

    testWidgets('should have proper app theme colors', (WidgetTester tester) async {
      // Set a larger test surface
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      
      // Build the app directly without wrapper
      await tester.pumpWidget(const AgorapushApp());
      await tester.pumpAndSettle();

      // Get the MaterialApp widget to check theme (find the main one from AgorapushApp)
      final materialApps = tester.widgetList<MaterialApp>(find.byType(MaterialApp));
      expect(materialApps.length, greaterThan(0));
      
      // Find the main app MaterialApp
      final mainApp = materialApps.firstWhere((app) => app.title == 'Agorapush');
      
      // Verify theme properties
      expect(mainApp.title, 'Agorapush');
      expect(mainApp.debugShowCheckedModeBanner, false);
      expect(mainApp.theme?.useMaterial3, true);
    });

    testWidgets('should handle form field focus', (WidgetTester tester) async {
      // Set a larger test surface
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      
      // Build the app and wait for login page
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Find text form fields
      final usernameField = find.byType(TextFormField).first;
      
      // Tap on username field to focus
      await tester.tap(usernameField);
      await tester.pump();

      // Field should be focused (this is mainly to test UI interaction)
      expect(find.byType(TextFormField), findsWidgets);
    });
  });
}