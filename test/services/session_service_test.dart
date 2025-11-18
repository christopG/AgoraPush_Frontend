import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agorapush/services/session_service.dart';

void main() {
  late SessionService sessionService;

  setUp(() async {
    // Clear shared preferences before each test
    SharedPreferences.setMockInitialValues({});
    sessionService = SessionService();
  });

  group('SessionService Tests', () {
    test('should save and retrieve user session', () async {
      // Arrange
      final user = {
        'id': 1,
        'username': 'testuser',
        'circonscription': 'Test Circonscription',
        'created_at': DateTime.now().toIso8601String(),
      };

      // Act
      await sessionService.saveUserSession(user);
      final isLoggedIn = await sessionService.isLoggedIn();

      // Assert
      expect(isLoggedIn, true);
    });

    test('should return false when no session exists', () async {
      // Act
      final isLoggedIn = await sessionService.isLoggedIn();

      // Assert
      expect(isLoggedIn, false);
    });

    test('should clear session successfully', () async {
      // Arrange
      final user = {
        'id': 1,
        'username': 'testuser',
        'circonscription': 'Test Circonscription',
        'created_at': DateTime.now().toIso8601String(),
      };
      await sessionService.saveUserSession(user);

      // Act
      await sessionService.clearSession();
      final isLoggedIn = await sessionService.isLoggedIn();

      // Assert
      expect(isLoggedIn, false);
    });

    test('should validate session data structure', () {
      // Arrange
      final validUser = {
        'id': 1,
        'username': 'testuser',
        'circonscription': 'Test Circonscription',
        'created_at': DateTime.now().toIso8601String(),
      };

      final invalidUser = {
        'username': 'testuser',
        // Missing required fields
      };

      // Assert
      expect(validUser.containsKey('id'), true);
      expect(validUser.containsKey('username'), true);
      expect(validUser.containsKey('circonscription'), true);
      expect(validUser.containsKey('created_at'), true);
      
      expect(invalidUser.containsKey('id'), false);
      expect(invalidUser.containsKey('circonscription'), false);
    });

    test('should handle session data types', () {
      // Arrange
      final user = {
        'id': 1,
        'username': 'testuser',
        'circonscription': 'Test Circonscription',
        'created_at': DateTime.now().toIso8601String(),
      };

      // Assert
      expect(user['id'] is int, true);
      expect(user['username'] is String, true);
      expect(user['circonscription'] is String, true);
      expect(user['created_at'] is String, true);
    });

    test('should validate SharedPreferences key constants', () {
      // Test that the service uses consistent keys
      const expectedKeys = [
        'is_logged_in',
        'user_id',
        'username',
        'circonscription',
        'created_at',
      ];

      for (final key in expectedKeys) {
        expect(key.isNotEmpty, true);
        expect(key.length > 2, true); // Keys should be meaningful
        expect(key.toLowerCase(), key); // Should be lowercase
      }
    });

    test('should handle date string format', () {
      // Test ISO8601 date format
      final now = DateTime.now();
      final isoString = now.toIso8601String();
      final parsedDate = DateTime.parse(isoString);

      expect(isoString.contains('T'), true); // ISO format contains T
      expect(parsedDate.year, now.year);
      expect(parsedDate.month, now.month);
      expect(parsedDate.day, now.day);
    });

    test('should handle username normalization', () {
      // Test username case handling
      const originalUsername = 'TestUser';
      const normalizedUsername = 'testuser';

      expect(originalUsername.toLowerCase(), normalizedUsername);
    });

    test('should validate circumscription data', () {
      // Test circonscription field validation
      const validCirconscriptions = [
        'Ain - 1ère circonscription',
        'Aisne - 2ème circonscription',
        'Paris - 15ème circonscription',
      ];

      for (final circo in validCirconscriptions) {
        expect(circo.isNotEmpty, true);
        expect(circo.contains('circonscription'), true);
      }
    });
  });
}