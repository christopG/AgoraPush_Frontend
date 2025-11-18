import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  // URL de base du backend depuis le fichier .env
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'https://agorapushbackend-production.up.railway.app';
  
  /// Récupère le nombre de députés depuis le backend
  static Future<int?> getDeputiesCount() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/deputies/count'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['count'] as int;
        }
      }
      
      print('Erreur API: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Erreur lors de la récupération du nombre de députés: $e');
      return null;
    }
  }
  
  /// Vérifie la connectivité avec le backend
  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Erreur de connectivité backend: $e');
      return false;
    }
  }
}