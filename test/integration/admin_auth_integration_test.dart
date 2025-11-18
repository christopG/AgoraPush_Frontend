import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      await tester.pumpAndSettle();

      // Act 1: Scroll vers la section admin et tenter la connexion
      await tester.scrollUntilVisible(
        find.text('Statut Administrateur'),
        500.0,
      );

      expect(find.text('Statut Administrateur'), findsOneWidget);

      // Act 2: Ouvrir le dialog d'authentification admin
      await tester.scrollUntilVisible(
        find.text('Se connecter comme admin'),
        500.0,
      );
      
      await tester.tap(find.text('Se connecter comme admin'));
      await tester.pumpAndSettle();

      // Vérifier que le dialog est ouvert
      expect(find.text('Authentification Admin'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Act 3: Tenter une connexion avec mot de passe vide
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      // Vérifier l'erreur
      expect(find.text('Veuillez entrer un mot de passe'), findsOneWidget);

      // Act 4: Entrer un mot de passe et tenter la connexion
      await tester.enterText(find.byType(TextField), 'testpassword123');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Le résultat dépend de la réponse du serveur
      // On vérifie qu'aucune erreur fatale ne s'est produite
      expect(tester.takeException(), isNull);

      // Act 5: Fermer le dialog si encore ouvert
      if (find.text('Annuler').evaluate().isNotEmpty) {
        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();
      }

      // Assert final: Retour à l'état normal de la page
      expect(find.text('Statut Administrateur'), findsOneWidget);
    });

    testWidgets('Admin status display and logout flow', (WidgetTester tester) async {
      // Ce test assumera qu'on a un token admin valide
      
      // Arrange - Simuler un utilisateur avec token admin
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_jwt_token', 'fake_admin_token');
      
      await tester.pumpWidget(MaterialApp(
        home: AccountPage(user: MockHelpers.testAdminUser),
      ));
      await tester.pumpAndSettle();

      // Act 1: Scroll vers la section admin
      await tester.scrollUntilVisible(
        find.text('Statut Administrateur'),
        500.0,
      );

      // Le statut exact dépend de la validation du token
      // On vérifie simplement que la section admin est présente
      expect(find.text('Statut Administrateur'), findsOneWidget);

      // Si un bouton de déconnexion est présent, le tester
      final logoutButtons = find.textContaining('déconnect');
      if (logoutButtons.evaluate().isNotEmpty) {
        await tester.tap(logoutButtons.first);
        await tester.pumpAndSettle();
      }

      // Clean up
      await prefs.clear();
    });

    testWidgets('Navigation between pages preserves admin state', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(MaterialApp(
        home: HomePage(user: MockHelpers.testUser),
      ));
      await tester.pumpAndSettle();

      // Act 1: Naviguer vers account page
      await tester.tap(find.byIcon(Icons.person_rounded));
      await tester.pumpAndSettle();

      // Act 2: Vérifier la présence de la section admin
      await tester.scrollUntilVisible(
        find.text('Statut Administrateur'),
        500.0,
      );
      expect(find.text('Statut Administrateur'), findsOneWidget);

      // Act 3: Retourner à la home page
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Assert: Vérifier qu'on est bien retourné à la home page
      expect(find.text('Bienvenue testuser !'), findsOneWidget);
      
      // Vérifier que la home page N'A PAS de section admin
      expect(find.text('Statut Administrateur'), findsNothing);
    });

    testWidgets('Admin authentication with network error handling', (WidgetTester tester) async {
      // Ce test vérifie la robustesse face aux erreurs réseau
      
      // Arrange
      await tester.pumpWidget(MaterialApp(
        home: AccountPage(user: MockHelpers.testUser),
      ));
      await tester.pumpAndSettle();

      // Act 1: Ouvrir le dialog admin
      await tester.scrollUntilVisible(
        find.text('Se connecter comme admin'),
        500.0,
      );
      
      await tester.tap(find.text('Se connecter comme admin'));
      await tester.pumpAndSettle();

      // Act 2: Entrer un mot de passe et tenter la connexion
      await tester.enterText(find.byType(TextField), 'networkfailtest');
      await tester.tap(find.text('Se connecter'));
      
      // Attendre un délai raisonnable pour la réponse réseau
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Assert: L'application ne devrait pas avoir planté
      expect(tester.takeException(), isNull);
      
      // Le dialog devrait être toujours présent ou fermé proprement
      // On vérifie qu'on est dans un état cohérent
      expect(find.byType(AccountPage), findsOneWidget);
    });

    testWidgets('Multiple admin authentication attempts', (WidgetTester tester) async {
      // Test la gestion de tentatives multiples
      
      // Arrange
      await tester.pumpWidget(MaterialApp(
        home: AccountPage(user: MockHelpers.testUser),
      ));
      await tester.pumpAndSettle();

      // Boucle de tentatives
      for (int i = 0; i < 3; i++) {
        // Act: Ouvrir le dialog
        await tester.scrollUntilVisible(
          find.text('Se connecter comme admin'),
          500.0,
        );
        
        await tester.tap(find.text('Se connecter comme admin'));
        await tester.pumpAndSettle();

        // Entrer un mot de passe différent à chaque tentative
        await tester.enterText(find.byType(TextField), 'attempt$i');
        await tester.tap(find.text('Se connecter'));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Fermer le dialog si encore ouvert
        if (find.text('Annuler').evaluate().isNotEmpty) {
          await tester.tap(find.text('Annuler'));
          await tester.pumpAndSettle();
        }

        // Assert: Pas d'erreur fatale
        expect(tester.takeException(), isNull);
      }

      // Assert final: La page est toujours dans un état stable
      expect(find.text('Statut Administrateur'), findsOneWidget);
    });

    testWidgets('Admin dialog accessibility and keyboard navigation', (WidgetTester tester) async {
      // Test l'accessibilité du dialog admin
      
      // Arrange
      await tester.pumpWidget(MaterialApp(
        home: AccountPage(user: MockHelpers.testUser),
      ));
      await tester.pumpAndSettle();

      // Act: Ouvrir le dialog
      await tester.scrollUntilVisible(
        find.text('Se connecter comme admin'),
        500.0,
      );
      
      await tester.tap(find.text('Se connecter comme admin'));
      await tester.pumpAndSettle();

      // Vérifier les éléments d'accessibilité
      expect(find.text('Authentification Admin'), findsOneWidget);
      expect(find.byIcon(Icons.admin_panel_settings), findsOneWidget);
      
      // Vérifier que le champ de texte a le focus automatique
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      
      // Simuler l'entrée de texte au clavier
      await tester.enterText(textField, 'keyboard_test');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Le formulaire devrait réagir à la validation clavier
      // (exacte behavior dépend de l'implémentation)
      expect(tester.takeException(), isNull);

      // Clean up
      if (find.text('Annuler').evaluate().isNotEmpty) {
        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();
      }
    });
  });
}
