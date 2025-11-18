import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdminAuthService {
  static final AdminAuthService _instance = AdminAuthService._internal();
  factory AdminAuthService() => _instance;
  AdminAuthService._internal();

  // 🌐 URL de l'API Railway depuis variables d'environnement
  static String get _baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
  // Fallback pour tests locaux si .env manque
  
  // 💾 Clés pour le stockage local
  static const String _tokenKey = 'admin_jwt_token';
  static const String _roleKey = 'admin_role';
  static const String _expirationKey = 'admin_token_expiration';

  // 🔐 Authentifier un admin avec mot de passe
  Future<AdminAuthResult> authenticateAdmin(String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        // Sauvegarder le token et les infos
        await _saveAdminSession(
          token: responseData['token'],
          role: responseData['role'],
          expiresIn: responseData['expiresIn'],
        );

        return AdminAuthResult(
          success: true,
          isAdmin: true,
          token: responseData['token'],
          message: 'Authentification admin réussie',
        );
      } else {
        return AdminAuthResult(
          success: false,
          isAdmin: false,
          message: responseData['error'] ?? 'Mot de passe admin incorrect',
          errorCode: responseData['code'],
        );
      }
    } on http.ClientException {
      return AdminAuthResult(
        success: false,
        isAdmin: false,
        message: 'Erreur de connexion au serveur',
        errorCode: 'NETWORK_ERROR',
      );
    } catch (e) {
      return AdminAuthResult(
        success: false,
        isAdmin: false,
        message: 'Erreur lors de l\'authentification: $e',
        errorCode: 'UNKNOWN_ERROR',
      );
    }
  }

  // 💾 Sauvegarder la session admin
  Future<void> _saveAdminSession({
    required String token,
    required String role,
    required String expiresIn,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Calculer l'heure d'expiration
    final now = DateTime.now();
    final duration = _parseDuration(expiresIn);
    final expirationTime = now.add(duration);

    await prefs.setString(_tokenKey, token);
    await prefs.setString(_roleKey, role);
    await prefs.setString(_expirationKey, expirationTime.toIso8601String());
  }

  // 🕒 Parser la durée d'expiration (ex: "6h" -> Duration)
  Duration _parseDuration(String durationString) {
    final regex = RegExp(r'^(\d+)([hmd])$');
    final match = regex.firstMatch(durationString.toLowerCase());
    
    if (match == null) return const Duration(hours: 6); // Défaut: 6h
    
    final value = int.parse(match.group(1)!);
    final unit = match.group(2)!;
    
    switch (unit) {
      case 'h': return Duration(hours: value);
      case 'm': return Duration(minutes: value);
      case 'd': return Duration(days: value);
      default: return const Duration(hours: 6);
    }
  }

  // 🔍 Vérifier si l'utilisateur est admin (avec token valide)
  Future<bool> isAdminAuthenticated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final token = prefs.getString(_tokenKey);
      final role = prefs.getString(_roleKey);
      final expirationString = prefs.getString(_expirationKey);

      // Vérifier que toutes les données sont présentes
      if (token == null || role == null || expirationString == null) {
        return false;
      }

      // Vérifier l'expiration
      final expiration = DateTime.parse(expirationString);
      if (DateTime.now().isAfter(expiration)) {
        await clearAdminSession(); // Nettoyer la session expirée
        return false;
      }

      // Vérifier le rôle
      if (role != 'admin') {
        return false;
      }

      // Optionnel : vérifier le token auprès du serveur
      return await _verifyTokenWithServer(token);
      
    } catch (e) {
      print('Erreur lors de la vérification admin: $e');
      return false;
    }
  }

  // 🌐 Vérifier le token auprès du serveur
  Future<bool> _verifyTokenWithServer(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['success'] == true && responseData['valid'] == true;
      }
      
      return false;
    } catch (e) {
      // En cas d'erreur réseau, faire confiance au cache local si pas expiré
      return true;
    }
  }

  // 🗑️ Supprimer la session admin
  Future<void> clearAdminSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_expirationKey);
  }

  // 🔑 Obtenir le token admin (pour faire des requêtes authentifiées)
  Future<String?> getAdminToken() async {
    if (await isAdminAuthenticated()) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    }
    return null;
  }

  // 📊 Exemple : appeler une API admin protégée
  Future<Map<String, dynamic>?> getAdminStats() async {
    final token = await getAdminToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        // Token expiré ou invalide
        await clearAdminSession();
        return null;
      }
    } catch (e) {
      print('Erreur lors de la récupération des stats admin: $e');
    }
    
    return null;
  }

  // 🕒 Obtenir le temps restant avant expiration
  Future<Duration?> getTokenTimeRemaining() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expirationString = prefs.getString(_expirationKey);
      
      if (expirationString == null) return null;
      
      final expiration = DateTime.parse(expirationString);
      final now = DateTime.now();
      
      if (now.isAfter(expiration)) {
        return Duration.zero;
      }
      
      return expiration.difference(now);
    } catch (e) {
      return null;
    }
  }
}

// 📊 Classe pour le résultat de l'authentification
class AdminAuthResult {
  final bool success;
  final bool isAdmin;
  final String? token;
  final String? message;
  final String? errorCode;

  AdminAuthResult({
    required this.success,
    required this.isAdmin,
    this.token,
    this.message,
    this.errorCode,
  });

  @override
  String toString() {
    return 'AdminAuthResult(success: $success, isAdmin: $isAdmin, message: $message)';
  }
}