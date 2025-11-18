import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _circonscriptionKey = 'circonscription';
  static const String _idcircoKey = 'idcirco';
  static const String _createdAtKey = 'created_at';

  // Sauvegarder la session utilisateur
  Future<void> saveUserSession(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setInt(_userIdKey, user['id']);
    await prefs.setString(_usernameKey, user['username']);
    await prefs.setString(_circonscriptionKey, user['circonscription']);
    if (user['idcirco'] != null) {
      await prefs.setString(_idcircoKey, user['idcirco']);
    }
    await prefs.setString(_createdAtKey, user['created_at']);
  }

  // Vérifier si l'utilisateur est connecté
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // Récupérer les données utilisateur stockées
  Future<Map<String, dynamic>?> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    
    if (!isLoggedIn) return null;

    // Vérifier que toutes les données nécessaires sont présentes
    final userId = prefs.getInt(_userIdKey);
    final username = prefs.getString(_usernameKey);
    final circonscription = prefs.getString(_circonscriptionKey);
    final idcirco = prefs.getString(_idcircoKey);
    final createdAt = prefs.getString(_createdAtKey);

    if (userId == null || username == null || circonscription == null || createdAt == null) {
      // Si des données sont manquantes, nettoyer la session
      await clearSession();
      return null;
    }

    // Vérifier que l'utilisateur existe toujours dans la base de données
    final userExists = await _verifyUserExists(username);
    
    if (!userExists) {
      // L'utilisateur n'existe plus, nettoyer la session
      await clearSession();
      return null;
    }

    return {
      'id': userId,
      'username': username,
      'circonscription': circonscription,
      'idcirco': idcirco,
      'created_at': createdAt,
    };
  }

  // Vérifier que l'utilisateur existe encore dans la base de données
  Future<bool> _verifyUserExists(String username) async {
    try {
      final databaseService = DatabaseService();
      final db = await databaseService.database;
      
      final result = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username.toLowerCase()],
      );
      
      return result.isNotEmpty;
    } catch (e) {
      print('Erreur lors de la vérification de l\'utilisateur: $e');
      return false;
    }
  }

  // Supprimer la session (déconnexion)
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_circonscriptionKey);
    await prefs.remove(_createdAtKey);
  }

  // Mettre à jour les informations utilisateur (en cas de modification)
  Future<void> updateUserSession({
    String? circonscription,
    String? idcirco,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    
    if (!isLoggedIn) return;

    if (circonscription != null) {
      await prefs.setString(_circonscriptionKey, circonscription);
    }
    
    if (idcirco != null) {
      await prefs.setString(_idcircoKey, idcirco);
    }
  }
}