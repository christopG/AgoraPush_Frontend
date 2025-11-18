import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/pages/account_page.dart';
import '../mock_helpers.dart';

void main() {
  group('AccountPage Basic Tests', () {
    setUp(() {
      MockHelpers.initializeMocks();
    });

    testWidgets('should create AccountPage without crashing', (WidgetTester tester) async {
      // Test basique - juste créer la page sans planter
      await tester.pumpWidget(MaterialApp(
        home: AccountPage(user: MockHelpers.testUser),
      ));

      // Pump une seule fois pour le rendu initial
      await tester.pump();

      // Assert - La page existe
      expect(find.byType(AccountPage), findsOneWidget);
    });

    testWidgets('should display account title', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AccountPage(user: MockHelpers.testUser),
      ));
      await tester.pump();

      // Le titre de la page devrait être présent immédiatement
      expect(find.text('Mon Compte'), findsOneWidget);
    });

    testWidgets('should display back button', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AccountPage(user: MockHelpers.testUser),
      ));
      await tester.pump();

      // Le bouton retour devrait être présent
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('should display username', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AccountPage(user: MockHelpers.testUser),
      ));
      await tester.pump();

      // Le nom d'utilisateur devrait être affiché
      expect(find.text('testuser'), findsOneWidget);
    });

    testWidgets('should handle user without circonscription', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AccountPage(user: MockHelpers.testUserNoCirconscription),
      ));
      await tester.pump();

      // Ne devrait pas planter même sans circonscription
      expect(find.byType(AccountPage), findsOneWidget);
      expect(find.text('testuser'), findsOneWidget);
    });

    testWidgets('should be scrollable container', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AccountPage(user: MockHelpers.testUser),
      ));
      await tester.pump();

      // Devrait avoir un conteneur scrollable
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('should handle empty user data gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AccountPage(user: {}),
      ));
      await tester.pump();

      // Ne devrait pas planter avec des données utilisateur vides
      expect(find.byType(AccountPage), findsOneWidget);
      expect(find.text('Mon Compte'), findsOneWidget);
    });

    testWidgets('should display scaffold structure', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AccountPage(user: MockHelpers.testUser),
      ));
      await tester.pump();

      // Vérifier la structure de base Scaffold
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}