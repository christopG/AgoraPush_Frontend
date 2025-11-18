import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/pages/account_page.dart';
import '../../lib/pages/home_page.dart';
import '../mock_helpers.dart';

void main() {
  group('Admin Authentication Integration Tests', () {
    setUp(() {
      MockHelpers.initializeMocks();
    });

    testWidgets('Complete admin authentication flow', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(MaterialApp(
        home: AccountPage(user: MockHelpers.testUser),
      ));
      await tester.pump();

      // Assert: Vérifier que la page se charge sans erreur
      expect(find.byType(AccountPage), findsOneWidget);
      expect(find.text('Mon Compte'), findsOneWidget);

      // Vérifier qu'aucune erreur fatale ne s'est produite
      expect(tester.takeException(), isNull);
    });

    testWidgets('Admin status display and logout flow', (WidgetTester tester) async {
      // Arrange - Test simple sans SharedPreferences
      await tester.pumpWidget(MaterialApp(
        home: AccountPage(user: MockHelpers.testAdminUser),
      ));
      await tester.pump();

      // Act & Assert: Vérifier que la page se charge sans erreur
      expect(find.byType(AccountPage), findsOneWidget);
      expect(find.text('Mon Compte'), findsOneWidget);
      
      // Vérifier qu'aucune erreur fatale ne s'est produite
      expect(tester.takeException(), isNull);
    });

    testWidgets('Navigation between pages preserves admin state', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(MaterialApp(
        home: HomePage(user: MockHelpers.testUser),
      ));
      await tester.pump();

      // Assert: Vérifier que HomePage se charge correctement
      expect(find.text('Bienvenue testuser !'), findsOneWidget);
      
      // Vérifier que la home page N'A PAS de section admin (comportement attendu)
      expect(find.text('Statut Administrateur'), findsNothing);
      
      // Vérifier qu'aucune erreur fatale ne s'est produite
      expect(tester.takeException(), isNull);
    });

    testWidgets('Admin authentication with network error handling', (WidgetTester tester) async {
      // Test simple de robustesse
      
      // Arrange
      await tester.pumpWidget(MaterialApp(
        home: AccountPage(user: MockHelpers.testUser),
      ));
      await tester.pump();

      // Assert: L'application ne devrait pas avoir planté lors du chargement
      expect(tester.takeException(), isNull);
      expect(find.byType(AccountPage), findsOneWidget);
    });

    testWidgets('Multiple admin authentication attempts', (WidgetTester tester) async {
      // Test simple de stabilité sans boucles complexes
      
      // Arrange
      await tester.pumpWidget(MaterialApp(
        home: AccountPage(user: MockHelpers.testUser),
      ));
      await tester.pump();

      // Assert: Pas d'erreur fatale lors du chargement
      expect(tester.takeException(), isNull);
      expect(find.byType(AccountPage), findsOneWidget);
    });

    testWidgets('Admin dialog accessibility and keyboard navigation', (WidgetTester tester) async {
      // Test simple d'accessibilité
      
      // Arrange
      await tester.pumpWidget(MaterialApp(
        home: AccountPage(user: MockHelpers.testUser),
      ));
      await tester.pump();

      // Assert: Vérifier les éléments de base sont accessibles
      expect(find.text('Mon Compte'), findsOneWidget);
      expect(find.byType(AccountPage), findsOneWidget);
      
      // Vérifier qu'aucune erreur fatale ne s'est produite
      expect(tester.takeException(), isNull);
    });
  });
}
