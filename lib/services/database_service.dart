import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'agorapush.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        recovery_phrase TEXT NOT NULL,
        circonscription TEXT NOT NULL,
        idcirco TEXT,
        notifications_enabled INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE users ADD COLUMN notifications_enabled INTEGER DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE users ADD COLUMN idcirco TEXT');
    }
    // Version 4: Ensure idcirco exists if missing (fix for databases created with wrong schema)
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN idcirco TEXT');
      } catch (e) {
        // Column already exists, ignore error
        print('Column idcirco already exists: $e');
      }
    }
  }

  // Génère un salt aléatoire
  String _generateSalt() {
    var bytes = utf8.encode(DateTime.now().millisecondsSinceEpoch.toString());
    var digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  // Hash le mot de passe avec le salt
  String _hashPassword(String password, String salt) {
    var bytes = utf8.encode(password + salt);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Hash la phrase de récupération
  String _hashRecoveryPhrase(String phrase) {
    var bytes = utf8.encode(phrase.toLowerCase().trim());
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Créer un nouveau compte utilisateur
  Future<bool> createUser({
    required String username,
    required String password,
    required String recoveryPhrase,
    required String circonscription,
    String? idcirco,
  }) async {
    try {
      final db = await database;
      
      // Vérifier si l'utilisateur existe déjà
      final existingUser = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username.toLowerCase()],
      );
      
      if (existingUser.isNotEmpty) {
        return false; // Utilisateur déjà existant
      }

      final salt = _generateSalt();
      final passwordHash = _hashPassword(password, salt);
      final recoveryHash = _hashRecoveryPhrase(recoveryPhrase);

      await db.insert('users', {
        'username': username.toLowerCase(),
        'password_hash': passwordHash,
        'salt': salt,
        'recovery_phrase': recoveryHash,
        'circonscription': circonscription,
        'idcirco': idcirco,
        'notifications_enabled': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Erreur lors de la création de l\'utilisateur: $e');
      return false;
    }
  }

  // Authentifier un utilisateur
  Future<Map<String, dynamic>?> authenticateUser({
    required String username,
    required String password,
  }) async {
    try {
      final db = await database;
      
      final result = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username.toLowerCase()],
      );

      if (result.isEmpty) {
        return null; // Utilisateur non trouvé
      }

      final user = result.first;
      final storedHash = user['password_hash'] as String;
      final salt = user['salt'] as String;
      final passwordHash = _hashPassword(password, salt);

      if (storedHash == passwordHash) {
        return {
          'id': user['id'],
          'username': user['username'],
          'circonscription': user['circonscription'],
          'idcirco': user['idcirco'],
          'created_at': user['created_at'],
        };
      }

      return null; // Mot de passe incorrect
    } catch (e) {
      print('Erreur lors de l\'authentification: $e');
      return null;
    }
  }

  // Récupérer le mot de passe avec la phrase de récupération
  Future<String?> recoverPassword({
    required String username,
    required String recoveryPhrase,
  }) async {
    try {
      final db = await database;
      
      final result = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username.toLowerCase()],
      );

      if (result.isEmpty) {
        return null; // Utilisateur non trouvé
      }

      final user = result.first;
      final storedRecoveryHash = user['recovery_phrase'] as String;
      final recoveryHash = _hashRecoveryPhrase(recoveryPhrase);

      if (storedRecoveryHash == recoveryHash) {
        // Génère un nouveau mot de passe temporaire
        return _generateTemporaryPassword();
      }

      return null; // Phrase de récupération incorrecte
    } catch (e) {
      print('Erreur lors de la récupération: $e');
      return null;
    }
  }

  // Changer le mot de passe (avec vérification du mot de passe actuel)
  Future<bool> changePassword({
    required String username,
    String? currentPassword,
    required String newPassword,
  }) async {
    try {
      final db = await database;
      
      // Si currentPassword est fourni, vérifier qu'il est correct
      if (currentPassword != null) {
        final user = await authenticateUser(username: username, password: currentPassword);
        if (user == null) {
          return false; // Mot de passe actuel incorrect
        }
      }
      
      final salt = _generateSalt();
      final passwordHash = _hashPassword(newPassword, salt);

      final result = await db.update(
        'users',
        {
          'password_hash': passwordHash,
          'salt': salt,
        },
        where: 'username = ?',
        whereArgs: [username.toLowerCase()],
      );

      return result > 0;
    } catch (e) {
      print('Erreur lors du changement de mot de passe: $e');
      return false;
    }
  }

  // Génère un mot de passe temporaire
  String _generateTemporaryPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    var rng = DateTime.now().millisecondsSinceEpoch;
    String password = '';
    for (int i = 0; i < 8; i++) {
      rng = (rng * 1103515245 + 12345) & 0x7fffffff;
      password += chars[rng % chars.length];
    }
    return password;
  }

  // Obtenir tous les utilisateurs (pour debug)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query('users');
  }

  // Supprimer un utilisateur
  Future<bool> deleteUser(String username) async {
    try {
      final db = await database;
      final result = await db.delete(
        'users',
        where: 'username = ?',
        whereArgs: [username.toLowerCase()],
      );
      return result > 0;
    } catch (e) {
      print('Erreur lors de la suppression: $e');
      return false;
    }
  }

  // Obtenir les paramètres de notification d'un utilisateur
  Future<bool> getNotificationSettings(String username) async {
    try {
      final db = await database;
      final result = await db.query(
        'users',
        columns: ['notifications_enabled'],
        where: 'username = ?',
        whereArgs: [username.toLowerCase()],
      );
      
      if (result.isNotEmpty) {
        return (result.first['notifications_enabled'] as int) == 1;
      }
      return false;
    } catch (e) {
      print('Erreur lors de la récupération des paramètres de notification: $e');
      return false;
    }
  }

  // Mettre à jour les paramètres de notification d'un utilisateur
  Future<bool> updateNotificationSettings(String username, bool enabled) async {
    try {
      final db = await database;
      final result = await db.update(
        'users',
        {'notifications_enabled': enabled ? 1 : 0},
        where: 'username = ?',
        whereArgs: [username.toLowerCase()],
      );
      return result > 0;
    } catch (e) {
      print('Erreur lors de la mise à jour des notifications: $e');
      return false;
    }
  }

  // Mettre à jour la circonscription d'un utilisateur
  Future<bool> updateUserCirconscription(String username, String circonscription, {String? idcirco}) async {
    try {
      final db = await database;
      final updateData = {'circonscription': circonscription};
      if (idcirco != null) {
        updateData['idcirco'] = idcirco;
      }
      
      final result = await db.update(
        'users',
        updateData,
        where: 'username = ?',
        whereArgs: [username.toLowerCase()],
      );
      return result > 0;
    } catch (e) {
      print('Erreur lors de la mise à jour de la circonscription: $e');
      return false;
    }
  }
}