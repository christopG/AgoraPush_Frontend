import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Helper class for setting up test environment
class TestHelper {
  /// Initialize test environment for database and shared preferences
  static void initializeTestEnvironment() {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Initialize FFI for SQLite tests
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // Clear shared preferences
    SharedPreferences.setMockInitialValues({});
  }
  
  /// Clean up test environment
  static Future<void> cleanupTestEnvironment() async {
    // Clear shared preferences
    SharedPreferences.setMockInitialValues({});
  }
  
  /// Create a test user data map
  static Map<String, dynamic> createTestUser({
    int id = 1,
    String username = 'testuser',
    String circonscription = 'Test Circonscription',
    String? createdAt,
  }) {
    return {
      'id': id,
      'username': username,
      'circonscription': circonscription,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }
  
  /// Generate test credentials
  static Map<String, String> generateTestCredentials({
    String username = 'testuser',
    String password = 'testpassword123',
    String recoveryPhrase = 'test recovery phrase',
    String circonscription = 'Test Circonscription',
  }) {
    return {
      'username': username,
      'password': password,
      'recoveryPhrase': recoveryPhrase,
      'circonscription': circonscription,
    };
  }
}