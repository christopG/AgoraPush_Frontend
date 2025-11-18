import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

class MockHelpers {
  static Database? _testDatabase;

  /// Initialise les mocks pour les tests
  static void initializeMocks() {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    
    // Mock sqflite pour éviter les erreurs de base de données
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
    } catch (e) {
      // Ignore si déjà initialisé
    }
  }

  /// Reset les mocks entre les tests
  static Future<void> resetMocks() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    // Close test database if exists
    if (_testDatabase != null) {
      try {
        await _testDatabase!.close();
        _testDatabase = null;
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
  }

  /// Données utilisateur de test standard
  static Map<String, dynamic> get testUser => {
    'username': 'testuser',
    'circonscription': 'Paris 1er'
  };

  /// Données utilisateur sans circonscription
  static Map<String, dynamic> get testUserNoCirconscription => {
    'username': 'testuser',
  };

  /// Données utilisateur admin
  static Map<String, dynamic> get testAdminUser => {
    'username': 'adminuser',
    'circonscription': 'Admin Zone'
  };
}