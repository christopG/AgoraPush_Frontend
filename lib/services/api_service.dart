import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  // URL de base du backend depuis le fichier .env
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'https://agorapushbackend-production.up.railway.app';
  
  // Configuration pour les timeouts et retry
  static const Duration _timeout = Duration(seconds: 15);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  
  // Cache local simple pour réduire les appels API
  static Map<String, dynamic> _cache = {};
  static Map<String, DateTime> _cacheTimestamps = {};
  
  // Client HTTP configuré
  static final http.Client _client = http.Client();
  
  /// Méthode générique pour les appels HTTP avec retry et cache
  static Future<Map<String, dynamic>?> _makeRequest(
    String endpoint, {
    Map<String, String>? headers,
    Duration? cacheDuration,
    bool useCache = false,
  }) async {
    // Vérifier le cache local si activé
    if (useCache && cacheDuration != null) {
      final cacheKey = endpoint;
      final cachedData = _cache[cacheKey];
      final timestamp = _cacheTimestamps[cacheKey];
      
      if (cachedData != null && timestamp != null) {
        if (DateTime.now().difference(timestamp) < cacheDuration) {
          print('📊 Cache hit pour: $endpoint');
          return cachedData;
        } else {
          // Nettoyer le cache expiré
          _cache.remove(cacheKey);
          _cacheTimestamps.remove(cacheKey);
        }
      }
    }

    Map<String, String> defaultHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'AgoraPush-Mobile/1.0.0',
    };
    
    if (headers != null) {
      defaultHeaders.addAll(headers);
    }

    Exception? lastException;
    
    // Retry logic
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        print('🌐 API Call (tentative $attempt): $baseUrl$endpoint');
        
        final response = await _client
            .get(
              Uri.parse('$baseUrl$endpoint'),
              headers: defaultHeaders,
            )
            .timeout(_timeout);

        print('📡 Response Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          
          // Mettre en cache si demandé
          if (useCache && cacheDuration != null) {
            _cache[endpoint] = data;
            _cacheTimestamps[endpoint] = DateTime.now();
          }
          
          return data;
        } else if (response.statusCode == 429) {
          // Rate limited - attendre plus longtemps avant retry
          final retryAfter = int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
          print('⏳ Rate limited, attente ${retryAfter}s...');
          await Future.delayed(Duration(seconds: retryAfter));
          continue;
        } else if (response.statusCode >= 500) {
          // Erreur serveur - continuer les retries
          print('🚨 Erreur serveur: ${response.statusCode}');
          lastException = HttpException('Server error: ${response.statusCode}');
        } else {
          // Erreur client (4xx) - ne pas retry
          print('❌ Erreur client: ${response.statusCode} - ${response.body}');
          return null;
        }
      } on SocketException catch (e) {
        print('🔌 Erreur réseau (tentative $attempt): $e');
        lastException = e;
      } on FormatException catch (e) {
        print('📋 Erreur format JSON: $e');
        return null; // Ne pas retry pour les erreurs de format
      } on Exception catch (e) {
        print('❌ Erreur API (tentative $attempt): $e');
        lastException = e;
      }

      // Attendre avant le prochain retry
      if (attempt < _maxRetries) {
        final delay = _retryDelay * attempt; // Backoff exponentiel
        print('⏳ Retry dans ${delay.inSeconds}s...');
        await Future.delayed(delay);
      }
    }

    print('💥 Échec après $_maxRetries tentatives: $lastException');
    return null;
  }

  /// Récupère le nombre de députés depuis le backend avec cache
  static Future<int?> getDeputiesCount() async {
    try {
      final data = await _makeRequest(
        '/api/deputies/count',
        useCache: true,
        cacheDuration: Duration(minutes: 30), // Cache 30 minutes
      );

      if (data != null && data['success'] == true) {
        final count = data['count'] as int?;
        print('📊 Nombre de députés récupéré: $count');
        return count;
      }
      
      return null;
    } catch (e) {
      print('❌ Erreur lors de la récupération du nombre de députés: $e');
      return null;
    }
  }
  
  /// Vérifie la connectivité avec le backend
  static Future<bool> checkHealth() async {
    try {
      final data = await _makeRequest('/health');
      final isHealthy = data != null && data['status'] == 'healthy';
      print('🏥 Health check: ${isHealthy ? "OK" : "FAIL"}');
      return isHealthy;
    } catch (e) {
      print('❌ Erreur health check: $e');
      return false;
    }
  }

  /// Récupère la liste complète des députés avec cache
  static Future<List<Map<String, dynamic>>?> getAllDeputies() async {
    try {
      final data = await _makeRequest(
        '/api/deputies',
        useCache: true,
        cacheDuration: Duration(minutes: 15), // Cache 15 minutes
      );

      if (data != null && data['success'] == true) {
        final deputies = List<Map<String, dynamic>>.from(data['data'] ?? []);
        print('👥 ${deputies.length} députés récupérés');
        
        // Debug: afficher le premier député pour comprendre la structure
        if (deputies.isNotEmpty) {
          print('🔍 Structure JSON du premier député:');
          print(jsonEncode(deputies.first));
        }
        
        return deputies;
      }
      
      return null;
    } catch (e) {
      print('❌ Erreur lors de la récupération des députés: $e');
      return null;
    }
  }

  /// Récupère un député par circonscription
  static Future<Map<String, dynamic>?> getDeputyByCirconscription(String idcirco) async {
    try {
      final data = await _makeRequest(
        '/api/deputies/circonscription/$idcirco',
        useCache: true,
        cacheDuration: Duration(minutes: 15),
      );

      if (data != null && data['success'] == true) {
        final deputy = data['data'] as Map<String, dynamic>?;
        print('👤 Député récupéré pour circonscription $idcirco');
        return deputy;
      }
      
      return null;
    } catch (e) {
      print('❌ Erreur lors de la récupération du député par circonscription: $e');
      return null;
    }
  }

  /// Récupère les députés groupés par groupe politique
  static Future<Map<String, dynamic>> getDeputiesByGroup() async {
    try {
      final data = await _makeRequest(
        '/api/deputies/groups',
        useCache: true,
        cacheDuration: Duration(minutes: 20),
      );

      if (data != null && data['success'] == true) {
        final groups = data['data'] as Map<String, dynamic>;
        print('🏛️ ${groups.length} groupes politiques récupérés');
        return groups;
      }
      
      return {};
    } catch (e) {
      print('❌ Erreur lors de la récupération des groupes: $e');
      return {};
    }
  }

  /// Récupère tous les organes politiques avec leurs couleurs
  static Future<List<dynamic>> getAllOrganes() async {
    try {
      final data = await _makeRequest(
        '/api/organes',
        useCache: true,
        cacheDuration: Duration(hours: 24), // Cache long car les couleurs changent rarement
      );

      if (data != null && data['success'] == true) {
        final organes = data['data'] as List<dynamic>;
        print('🎨 ${organes.length} organes récupérés');
        return organes;
      }
      
      return [];
    } catch (e) {
      print('❌ Erreur lors de la récupération des organes: $e');
      return [];
    }
  }

  /// Récupère tous les scrutins
  static Future<List<dynamic>> getAllScrutins() async {
    try {
      final data = await _makeRequest(
        '/api/scrutins',
        useCache: true,
        cacheDuration: Duration(minutes: 30),
      );

      if (data != null && data['success'] == true) {
        final scrutins = data['data'] as List<dynamic>;
        print('📊 ${scrutins.length} scrutins récupérés');
        return scrutins;
      }
      
      return [];
    } catch (e) {
      print('❌ Erreur lors de la récupération des scrutins: $e');
      return [];
    }
  }

  /// Récupère les scrutins avec pagination et filtres
  static Future<Map<String, dynamic>?> getScrutinsPaginated({
    int page = 0,
    int limit = 15,
    List<String>? themeIds,
    List<int>? years,
    List<String>? months,
    String? search,
  }) async {
    try {
      // Construction des query parameters
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      if (themeIds != null && themeIds.isNotEmpty) {
        queryParams['themes'] = themeIds.join(',');
      }
      
      if (years != null && years.isNotEmpty) {
        queryParams['years'] = years.map((y) => y.toString()).join(',');
      }
      
      if (months != null && months.isNotEmpty) {
        queryParams['months'] = months.join(',');
      }
      
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final data = await _makeRequest(
        '/api/scrutins/paginated?$queryString',
        useCache: false, // Pas de cache pour les données paginées
      );

      if (data != null && data['success'] == true) {
        print('📊 ${(data['data'] as List).length} scrutins récupérés (page $page)');
        return data;
      }
      
      return null;
    } catch (e) {
      print('❌ Erreur lors de la récupération des scrutins paginés: $e');
      return null;
    }
  }

  // Nouvel endpoint optimisé pour la page d'accueil
  static Future<Map<String, dynamic>?> getScrutinsStatsForHome() async {
    try {
      final data = await _makeRequest(
        '/api/scrutins/stats/home',
        useCache: true,
        cacheDuration: Duration(minutes: 5), // Cache court pour données récentes
      );

      if (data != null && data['success'] == true) {
        print('📊 Stats home chargées: ${data['stats']}');
        return data;
      }
      
      return null;
    } catch (e) {
      print('❌ Erreur lors de la récupération des stats home: $e');
      return null;
    }
  }

  static Future<List<dynamic>> getAllThemes() async {
    try {
      final data = await _makeRequest(
        '/api/themes',
        useCache: true,
        cacheDuration: Duration(hours: 1),
      );

      if (data != null && data['success'] == true) {
        final themes = data['data'] as List<dynamic>;
        print('🏷️ ${themes.length} thèmes récupérés');
        return themes;
      }
      
      return [];
    } catch (e) {
      print('❌ Erreur lors de la récupération des thèmes: $e');
      return [];
    }
  }

  /// Nettoie le cache local
  static void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
    print('🗑️ Cache API nettoyé');
  }

  /// Statistiques du cache
  static Map<String, dynamic> getCacheStats() {
    return {
      'entries': _cache.length,
      'size_bytes': _cache.toString().length,
      'oldest_entry': _cacheTimestamps.values.isNotEmpty 
          ? _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String()
          : null,
    };
  }

  /// Ferme le client HTTP
  static void dispose() {
    _client.close();
    clearCache();
  }
}