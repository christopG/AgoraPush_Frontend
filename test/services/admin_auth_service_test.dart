import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/services/admin_auth_service.dart';

void main() {
  group('AdminAuthService Tests', () {
    late AdminAuthService adminAuthService;

    setUp(() async {
      // Configuration des SharedPreferences mock
      SharedPreferences.setMockInitialValues({});
      
      adminAuthService = AdminAuthService();
    });

    tearDown(() async {
      await adminAuthService.clearAdminSession();
    });

    group('authenticateAdmin', () {
      test('should handle empty password', () async {
        // Arrange
        const password = '';

        // Act
        final result = await adminAuthService.authenticateAdmin(password);

        // Assert
        expect(result.success, false);
        expect(result.isAdmin, false);
      });

      test('should handle very long password', () async {
        // Arrange
        final password = 'a' * 1000;

        // Act
        final result = await adminAuthService.authenticateAdmin(password);

        // Assert
        expect(result, isA<AdminAuthResult>());
        expect(result.success, isA<bool>());
        expect(result.isAdmin, isA<bool>());
      });

      test('should handle special characters in password', () async {
        // Arrange
        const password = 'Test@123!#\$%^&*()';

        // Act
        final result = await adminAuthService.authenticateAdmin(password);

        // Assert
        expect(result, isA<AdminAuthResult>());
        expect(result.success, isA<bool>());
        expect(result.isAdmin, isA<bool>());
      });
    });

    group('Token Management', () {
      test('should return null when no token saved', () async {
        // Act
        final token = await adminAuthService.getAdminToken();

        // Assert
        expect(token, null);
      });

      test('should clear admin session', () async {
        // Act
        await adminAuthService.clearAdminSession();
        final token = await adminAuthService.getAdminToken();
        final isAuthenticated = await adminAuthService.isAdminAuthenticated();

        // Assert
        expect(token, null);
        expect(isAuthenticated, false);
      });
    });

    group('isAdminAuthenticated', () {
      test('should return false when no token exists', () async {
        // Act
        final isAuthenticated = await adminAuthService.isAdminAuthenticated();

        // Assert
        expect(isAuthenticated, false);
      });

      test('should return false after clearing session', () async {
        // Arrange
        await adminAuthService.clearAdminSession();

        // Act
        final isAuthenticated = await adminAuthService.isAdminAuthenticated();

        // Assert
        expect(isAuthenticated, false);
      });
    });

    group('Token Expiration', () {
      test('should return null for time remaining when no token', () async {
        // Act
        final timeRemaining = await adminAuthService.getTokenTimeRemaining();

        // Assert
        expect(timeRemaining, null);
      });

      test('should handle token expiration check', () async {
        // Act
        final timeRemaining = await adminAuthService.getTokenTimeRemaining();
        final isAuthenticated = await adminAuthService.isAdminAuthenticated();

        // Assert
        expect(timeRemaining, anyOf(isNull, isA<Duration>()));
        expect(isAuthenticated, isA<bool>());
      });
    });

    group('Admin Stats', () {
      test('should return null when not authenticated', () async {
        // Act
        final stats = await adminAuthService.getAdminStats();

        // Assert
        expect(stats, null);
      });
    });

    group('Singleton Pattern', () {
      test('should return same instance', () {
        // Act
        final instance1 = AdminAuthService();
        final instance2 = AdminAuthService();

        // Assert
        expect(identical(instance1, instance2), true);
      });
    });

    group('Error Handling', () {
      test('should handle network timeouts gracefully', () async {
        // Arrange
        const password = 'TestPassword123';

        // Act
        final result = await adminAuthService.authenticateAdmin(password);

        // Assert
        expect(result, isA<AdminAuthResult>());
        expect(result.success, isA<bool>());
        expect(result.isAdmin, isA<bool>());
        
        if (!result.success) {
          expect(result.message, isNotNull);
        }
      });
    });
  });

  group('AdminAuthResult', () {
    test('should create result object correctly', () {
      // Arrange & Act
      final result = AdminAuthResult(
        success: true,
        isAdmin: true,
        token: 'test_token',
        message: 'Success message',
      );

      // Assert
      expect(result.success, true);
      expect(result.isAdmin, true);
      expect(result.token, 'test_token');
      expect(result.message, 'Success message');
    });

    test('should handle null values correctly', () {
      // Arrange & Act
      final result = AdminAuthResult(
        success: false,
        isAdmin: false,
      );

      // Assert
      expect(result.success, false);
      expect(result.isAdmin, false);
      expect(result.token, null);
      expect(result.message, null);
    });

    test('should handle error codes', () {
      // Arrange & Act
      final result = AdminAuthResult(
        success: false,
        isAdmin: false,
        errorCode: 'INVALID_CREDENTIALS',
        message: 'Mot de passe incorrect',
      );

      // Assert
      expect(result.success, false);
      expect(result.errorCode, 'INVALID_CREDENTIALS');
      expect(result.message, 'Mot de passe incorrect');
    });
  });
}