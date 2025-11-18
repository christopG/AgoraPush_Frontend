import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/deputy_model.dart';
import '../providers/deputy_provider.dart';
import '../providers/auth_provider.dart';
import 'deputy_detail_page.dart';

enum ViewMode { search, map, groups }

class DeputiesListPage extends StatefulWidget {
  const DeputiesListPage({super.key});

  @override
  State<DeputiesListPage> createState() => _DeputiesListPageState();
}

class _DeputiesListPageState extends State<DeputiesListPage> {
  ViewMode _currentMode = ViewMode.search;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<DeputyModel> _searchResults = [];
  List<DeputyModel> _allDeputies = [];
  bool _isLoadingAllDeputies = false;

  // Variables pour la carte
  List<Polygon> _circonscriptions = [];
  List<Map<String, dynamic>> _circonscriptionData = [];
  bool _isLoadingGeoJson = true;
  final LatLng _mapCenter =
      const LatLng(46.603354, 1.888334); // Centre de la France
  final double _mapZoom = 6.0;
  
  // Variables pour le popup de la carte
  DeputyModel? _selectedDeputy;
  String? _selectedCirconscriptionName;
  
  // Variables pour l'optimisation des performances
  static final Map<String, List<DeputyModel>> _deputiesCache = {};
  static final Map<String, List<Polygon>> _geoJsonCache = {};
  static final Map<String, List<Map<String, dynamic>>> _circonscriptionDataCache = {};
  static final Map<String, List<DeputyModel>> _groupsCache = {}; // Cache pour les groupes
  static DateTime? _lastCacheUpdate;
  static DateTime? _lastGroupsUpdate; // Cache timestamp pour les groupes
  
  // Contrôleurs pour la recherche optimisée
  Timer? _searchDebounceTimer;
  final Duration _searchDebounceDelay = const Duration(milliseconds: 300);
  
  // États pour le lazy loading
  bool _isInitialized = false;
  bool _useCache = true;
  bool _groupsInitialized = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusChange);
    
    // Chargement instantané depuis le cache puis mise à jour en arrière-plan
    _loadFromCacheFirst();
    
    // Chargements en arrière-plan sans bloquer l'UI
    _loadInBackground();
  }
  
  /// Charge instantanément depuis le cache pour affichage immédiat
  Future<void> _loadFromCacheFirst() async {
    try {
      // Vérifier si nous avons des données en cache
      final cacheKey = 'deputies_list';
      if (_deputiesCache.containsKey(cacheKey) && 
          _geoJsonCache.containsKey('geojson') &&
          _lastCacheUpdate != null &&
          DateTime.now().difference(_lastCacheUpdate!).inMinutes < 30) {
        
        print('⚡ Chargement instantané depuis le cache');
        setState(() {
          _allDeputies = _deputiesCache[cacheKey]!;
          _searchResults = _allDeputies;
          _circonscriptions = _geoJsonCache['geojson']!;
          _circonscriptionData = _circonscriptionDataCache['data']!;
          _isLoadingAllDeputies = false;
          _isLoadingGeoJson = false;
          _isInitialized = true;
        });
        return;
      }
      
      // Essayer de charger depuis SharedPreferences si pas de cache mémoire
      await _loadFromSharedPreferences();
      
    } catch (e) {
      print('⚠️ Erreur cache: $e - Chargement normal');
      _useCache = false;
    }
  }
  
  /// Charge en arrière-plan sans bloquer l'UI
  Future<void> _loadInBackground() async {
    // Attendre un frame pour ne pas bloquer l'affichage initial
    await Future.delayed(const Duration(milliseconds: 50));
    
    if (!_isInitialized) {
      // Si pas de cache, charger normalement mais de manière optimisée
      await Future.wait([
        _loadGeoJsonDataOptimized(),
        _loadAllDeputiesOptimized(),
      ]);
      _loadInitialData();
    } else {
      // Si cache présent, mise à jour silencieuse en arrière-plan
      _updateCacheInBackground();
    }
  }

  void _onSearchFocusChange() {
    setState(() {}); // Met à jour l'affichage quand le focus change
  }

  void _loadInitialData() async {
    final user = authProvider.user;
    if (user?.idcirco != null) {
      final normalizedIdcirco = _normalizeIdcirco(user!.idcirco!);
      try {
        final myDeputy = await deputyRepositoryProvider.getDeputyByCirconscription(
          normalizedIdcirco,
        );
        if (myDeputy != null) {
          deputyProvider.setMyDeputy(myDeputy);
          if (mounted) setState(() {});
        }
      } catch (e) {}
    }
  }

  // Fonction pour normaliser l'idcirco
  String _normalizeIdcirco(String idcirco) {
    // Si l'idcirco est déjà au format XX-XX, on le retourne tel quel
    if (idcirco.contains('-')) {
      return idcirco;
    }

    // Sinon, on convertit XXXX vers XX-XX
    if (idcirco.length >= 4) {
      final dep = idcirco.substring(0, 2);
      final circo = idcirco.substring(2);
      return '$dep-$circo';
    }

    return idcirco; // Retour par défaut si le format n'est pas reconnu
  }
  
  /// Charge depuis SharedPreferences pour persistance entre sessions
  Future<void> _loadFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Vérifier la date de mise à jour du cache
      final cacheTimestamp = prefs.getInt('deputies_cache_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Cache valide pour 1 heure
      if (now - cacheTimestamp > 3600000) {
        print('💾 Cache SharedPreferences expiré');
        return;
      }
      
      // Charger les députés depuis le cache
      final deputiesJson = prefs.getString('deputies_cache');
      if (deputiesJson != null) {
        final List<dynamic> deputiesData = json.decode(deputiesJson);
        final deputies = deputiesData.map((data) => DeputyModel.fromJson(data)).toList();
        
        print('💾 ${deputies.length} députés chargés depuis SharedPreferences');
        
        setState(() {
          _allDeputies = deputies;
          _searchResults = deputies;
          _isLoadingAllDeputies = false;
          _isInitialized = true;
        });
        
        // Mettre en cache mémoire
        _deputiesCache['deputies_list'] = deputies;
        _lastCacheUpdate = DateTime.fromMillisecondsSinceEpoch(cacheTimestamp);
      }
      
    } catch (e) {
      print('⚠️ Erreur SharedPreferences: $e');
    }
  }
  
  /// Met à jour le cache en arrière-plan
  Future<void> _updateCacheInBackground() async {
    try {
      print('🔄 Mise à jour silencieuse du cache...');
      
      // Charger les nouvelles données
      final newDeputies = await deputyRepositoryProvider.getAllDeputies();
      
      // Comparer avec le cache actuel
      final currentCache = _deputiesCache['deputies_list'];
      if (currentCache != null && newDeputies.length == currentCache.length) {
        print('✅ Pas de nouvelles données, cache à jour');
        return;
      }
      
      // Mettre à jour le cache
      _deputiesCache['deputies_list'] = newDeputies;
      _lastCacheUpdate = DateTime.now();
      
      // Sauvegarder dans SharedPreferences
      await _saveToSharedPreferences(newDeputies);
      
      // Mise à jour de l'UI si nécessaire
      if (mounted && _searchController.text.isEmpty) {
        setState(() {
          _allDeputies = newDeputies;
          _searchResults = newDeputies;
        });
      }
      
    } catch (e) {
      print('⚠️ Erreur mise à jour cache: $e');
    }
  }
  
  /// Sauvegarde dans SharedPreferences
  Future<void> _saveToSharedPreferences(List<DeputyModel> deputies) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deputiesJson = json.encode(deputies.map((d) => d.toJson()).toList());
      
      await prefs.setString('deputies_cache', deputiesJson);
      await prefs.setInt('deputies_cache_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      print('💾 Cache sauvegardé: ${deputies.length} députés');
    } catch (e) {
      print('⚠️ Erreur sauvegarde cache: $e');
    }
  }
  
  /// Charge les groupes de manière optimisée
  Future<void> _loadGroupsOptimized() async {
    try {
      // Vérifier si nous avons déjà les données
      if (_groupsInitialized && 
          _lastGroupsUpdate != null &&
          DateTime.now().difference(_lastGroupsUpdate!).inMinutes < 30) {
        print('⚡ Groupes déjà en cache, pas besoin de recharger');
        return;
      }
      
      // Si nous avons les députés en cache, générer les groupes localement
      if (_allDeputies.isNotEmpty) {
        print('🛠️ Génération locale des groupes depuis les députés en cache');
        _generateGroupsFromDeputies();
        return;
      }
      
      print('📊 Chargement des députés pour générer les groupes...');
      
      // Charger les députés d'abord si pas en cache
      if (!_isInitialized) {
        await _loadAllDeputiesOptimized();
      }
      
      // Générer les groupes depuis les députés
      _generateGroupsFromDeputies();
      
    } catch (e) {
      print('❌ Erreur lors du chargement des groupes: $e');
      // Fallback sur l'ancienne méthode si nécessaire
      deputyProvider.loadDeputiesByGroup();
    }
  }
  
  /// Génère les groupes politiques localement depuis la liste des députés
  void _generateGroupsFromDeputies() {
    try {
      final Map<String, List<DeputyModel>> deputiesByGroup = {};
      
      // Grouper les députés par groupe politique
      for (final deputy in _allDeputies) {
        final groupName = deputy.famillePolLibelleDb ?? 
                         deputy.famillePolLibelle ?? 
                         'Groupe non défini';
        
        if (!deputiesByGroup.containsKey(groupName)) {
          deputiesByGroup[groupName] = [];
        }
        deputiesByGroup[groupName]!.add(deputy);
      }
      
      // Trier chaque groupe par ordre alphabétique
      deputiesByGroup.forEach((groupName, deputies) {
        deputies.sort((a, b) => a.fullName.compareTo(b.fullName));
      });
      
      // Mettre à jour le provider directement (optimisation)
      deputyProvider.updateDeputiesByGroupLocal(deputiesByGroup);
      
      // Marquer comme initialisé
      _groupsInitialized = true;
      _lastGroupsUpdate = DateTime.now();
      
      print('✅ ${deputiesByGroup.length} groupes générés localement en 0ms');
      
      // Déclencher un rebuild si nécessaire
      if (mounted && _currentMode == ViewMode.groups) {
        setState(() {});
      }
      
    } catch (e) {
      print('❌ Erreur génération groupes: $e');
    }
  }

  Future<void> _loadGeoJsonDataOptimized() async {
    // Vérifier le cache mémoire d'abord
    if (_geoJsonCache.containsKey('geojson') && _circonscriptionDataCache.containsKey('data')) {
      print('⚡ GeoJSON chargé depuis le cache');
      setState(() {
        _circonscriptions = _geoJsonCache['geojson']!;
        _circonscriptionData = _circonscriptionDataCache['data']!;
        _isLoadingGeoJson = false;
      });
      return;
    }
    
    try {
      final String geoJsonString = await rootBundle.loadString(
        'data/circomaps/circonscriptions_legislatives_030522.geojson',
      );
      final Map<String, dynamic> geoJson = json.decode(geoJsonString);

      List<Polygon> polygons = [];
      List<Map<String, dynamic>> circonscriptionData = [];

      Color parseColor(String? hexColor, {double opacity = 0.3}) {
        if (hexColor == null || hexColor.isEmpty) {
          return Colors.grey.withOpacity(opacity);
        }
        String hex = hexColor.replaceAll('#', '');
        if (hex.length == 6) hex = 'FF$hex';
        try {
          final color = Color(int.parse(hex, radix: 16)).withOpacity(opacity);
          return color;
        } catch (e) {
          return Colors.grey.withOpacity(opacity);
        }
      }

      // Traitement optimisé - limitation si trop de features pour les performances
      final features = geoJson['features'] as List;
      final maxFeatures = math.min(features.length, 1000); // Limiter à 1000 pour la fluidité
      
      for (int featureIndex = 0; featureIndex < maxFeatures; featureIndex++) {
        var feature = features[featureIndex];

        Map<String, dynamic> circonscriptionInfo = {
          'id_circo': feature['properties']?['id_circo'] ?? '',
          'dep': feature['properties']?['dep'] ?? '',
          'libelle': feature['properties']?['libelle'] ?? '',
          'nom_circ': feature['properties']?['nom_circ'] ??
              feature['properties']?['libelle'] ??
              'Circonscription ${featureIndex + 1}',
        };

        const String? couleur = null;
        final Color fillColor = parseColor(couleur, opacity: 0.3);
        final Color borderColor = parseColor(couleur, opacity: 0.8);

        if (feature['geometry']['type'] == 'Polygon') {
          List<LatLng> points = [];
          var coordinates = feature['geometry']['coordinates'][0];

          if (coordinates != null && coordinates.isNotEmpty) {
            // Optimisation: réduire le nombre de points pour les performances
            final step = math.max(1, coordinates.length ~/ 50); // Max 50 points par polygone
            
            for (int i = 0; i < coordinates.length; i += step) {
              var coord = coordinates[i];
              if (coord != null && coord.length >= 2) {
                points.add(LatLng(coord[1], coord[0]));
              }
            }

            if (points.length >= 3) {
              polygons.add(
                Polygon(
                  points: points,
                  color: fillColor,
                  borderColor: borderColor,
                  borderStrokeWidth: 1.0, // Réduit pour les performances
                ),
              );
              circonscriptionData.add(circonscriptionInfo);
            }
          }
        } else if (feature['geometry']['type'] == 'MultiPolygon') {
          // Simplifier le MultiPolygon - prendre seulement le premier polygone
          if (feature['geometry']['coordinates'].isNotEmpty) {
            var polygon = feature['geometry']['coordinates'][0];
            List<LatLng> points = [];
            var coordinates = polygon[0];

            if (coordinates != null && coordinates.isNotEmpty) {
              final step = math.max(1, coordinates.length ~/ 50);
              
              for (int i = 0; i < coordinates.length; i += step) {
                var coord = coordinates[i];
                if (coord != null && coord.length >= 2) {
                  points.add(LatLng(coord[1], coord[0]));
                }
              }

              if (points.length >= 3) {
                polygons.add(
                  Polygon(
                    points: points,
                    color: fillColor,
                    borderColor: borderColor,
                    borderStrokeWidth: 1.0,
                  ),
                );
                circonscriptionData.add(circonscriptionInfo);
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _circonscriptions = polygons;
          _circonscriptionData = circonscriptionData;
          _isLoadingGeoJson = false;
        });
        
        // Mettre en cache
        _geoJsonCache['geojson'] = polygons;
        _circonscriptionDataCache['data'] = circonscriptionData;
        
        print('✅ ${polygons.length} circonscriptions traitées et mises en cache');
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement du GeoJSON: $e');
      if (mounted) {
        setState(() {
          _isLoadingGeoJson = false;
        });
      }
    }
  }

  /// Charge tous les députés de manière optimisée
  Future<void> _loadAllDeputiesOptimized() async {
    if (_isInitialized) return; // Éviter les chargements multiples
    
    setState(() {
      _isLoadingAllDeputies = true;
    });

    try {
      // Utiliser directement le repository pour éviter le provider
      final allDeputies = await deputyRepositoryProvider.getAllDeputies();

      // Trier par ordre alphabétique (fait une seule fois)
      allDeputies.sort((a, b) => a.fullName.compareTo(b.fullName));

      if (mounted) {
        setState(() {
          _allDeputies = allDeputies;
          _searchResults = allDeputies;
          _isLoadingAllDeputies = false;
          _isInitialized = true;
        });
        
        // Mettre en cache
        _deputiesCache['deputies_list'] = allDeputies;
        _lastCacheUpdate = DateTime.now();
        
        // Sauvegarder pour la prochaine fois
        if (_useCache) {
          _saveToSharedPreferences(allDeputies);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAllDeputies = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F7F2), // Cohérent avec le thème vert olive
      body: SafeArea(
        child: Column(
          children: [
            // Header avec titre et bouton retour modernisé
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7F2),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            size: 20,
                            color: Color(0xFF556B2F),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Députés',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF556B2F),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recherche • Carte • Groupes politiques',
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF556B2F).withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Sélecteur de mode modernisé avec thème vert
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModeButton(
                      mode: ViewMode.search,
                      label: 'Recherche',
                      icon: Icons.search,
                      isSelected: _currentMode == ViewMode.search,
                    ),
                  ),
                  Expanded(
                    child: _buildModeButton(
                      mode: ViewMode.map,
                      label: 'Carte',
                      icon: Icons.map_outlined,
                      isSelected: _currentMode == ViewMode.map,
                    ),
                  ),
                  Expanded(
                    child: _buildModeButton(
                      mode: ViewMode.groups,
                      label: 'Groupes',
                      icon: Icons.groups_outlined,
                      isSelected: _currentMode == ViewMode.groups,
                    ),
                  ),
                ],
              ),
            ),

            // Contenu principal
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required ViewMode mode,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentMode = mode;
        });
        if (mode == ViewMode.groups) {
          _loadGroupsOptimized();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF556B2F) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : const Color(0xFF556B2F),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF556B2F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fonction pour générer l'URL de la photo d'un député
  String _getDeputyPhotoUrl(String deputyId) {
    // Enlever le préfixe "PA" de l'ID pour obtenir le numéro
    final photoId =
        deputyId.startsWith('PA') ? deputyId.substring(2) : deputyId;
    return 'https://www.assemblee-nationale.fr/dyn/static/tribun/17/photos/carre/$photoId.jpg';
  }

  Widget _buildContent() {
    switch (_currentMode) {
      case ViewMode.search:
        return _buildSearchView();
      case ViewMode.map:
        return _buildMapView();
      case ViewMode.groups:
        return _buildGroupsView();
    }
  }

  Widget _buildSearchView() {
    return Column(
      children: [
        // Barre de recherche épurée et moderne
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Rechercher un député...',
              hintStyle: TextStyle(
                color: const Color(0xFF556B2F).withOpacity(0.6),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: const Color(0xFF556B2F).withOpacity(0.7),
                size: 22,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = _allDeputies;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF556B2F).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: const Color(0xFF556B2F).withOpacity(0.8),
                        ),
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            ),
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF556B2F),
              fontWeight: FontWeight.w500,
            ),
            onChanged: _performSearch,
          ),
        ),

        // Résultats de recherche avec design moderne
        Expanded(
          child: _isLoadingAllDeputies
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF556B2F).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF556B2F)),
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chargement des députés...',
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFF556B2F).withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : deputyProvider.error != null
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.withOpacity(0.2)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red.withOpacity(0.7),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Erreur de connexion',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              deputyProvider.error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.red.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                deputyProvider.clearError();
                                _loadAllDeputiesOptimized();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF556B2F),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _searchResults.isEmpty
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF556B2F).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.search_off,
                                    size: 40,
                                    color: const Color(0xFF556B2F).withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Aucun député trouvé',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF556B2F).withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final deputy = _searchResults[index];
                            return _buildModernDeputyCard(deputy);
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildModernDeputyCard(DeputyModel deputy) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000), // Optimisation: couleur pré-calculée
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DeputyDetailPage(deputy: deputy),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Photo du député avec cadre moderne
                _buildDeputyPhoto(deputy),
                const SizedBox(width: 16),
                // Informations du député
                Expanded(
                  child: _buildDeputyInfo(deputy),
                ),
                // Flèche moderne
                _buildArrowIcon(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildDeputyPhoto(DeputyModel deputy) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0x33556B2F), // Pré-calculé
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000), // Pré-calculé
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          _getDeputyPhotoUrl(deputy.id),
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              decoration: const BoxDecoration(
                color: Color(0x1A556B2F),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF556B2F)),
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0x1A556B2F),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: const Icon(
                Icons.person,
                size: 32,
                color: Color(0x99556B2F),
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildDeputyInfo(DeputyModel deputy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          deputy.fullName,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Color(0xFF556B2F),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        if (deputy.famillePolLibelleDb != null &&
            deputy.famillePolLibelleDb!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0x1A556B2F),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: Text(
              deputy.famillePolLibelleDb!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xCC556B2F),
              ),
            ),
          ),
        Text(
          deputy.circonscriptionComplete,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xB3556B2F),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Widget _buildArrowIcon() {
    return const SizedBox(
      width: 32,
      height: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0x1A556B2F),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: Color(0xCC556B2F),
        ),
      ),
    );
  }

  Widget _buildMapView() {
    if (_isLoadingGeoJson) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF556B2F).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF556B2F)),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement de la carte...',
              style: TextStyle(
                fontSize: 16,
                color: const Color(0xFF556B2F).withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Instructions modernisées
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF556B2F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.touch_app,
                  size: 20,
                  color: const Color(0xFF556B2F).withOpacity(0.8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Touchez une circonscription pour découvrir votre député',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF556B2F).withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: _mapCenter,
                      initialZoom: _mapZoom,
                      onTap: (tapPosition, point) => _onMapTap(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.agorapush',
                      ),
                      PolygonLayer(polygons: _circonscriptions),
                    ],
                  ),
                  // Popup du député sélectionné
                  if (_selectedDeputy != null)
                    _buildDeputyPopup(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGroupsView() {
    // Si pas encore initialisé, charger les groupes
    if (!_groupsInitialized && _allDeputies.isNotEmpty) {
      // Génération immédiate sans attendre
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _generateGroupsFromDeputies();
      });
    }
    
    final deputiesByGroup = deputyProvider.deputiesByGroup;
    final loading = deputyProvider.loading;
    final error = deputyProvider.error;

    // Affichage de loading seulement si pas de cache et chargement en cours
    if (loading && deputiesByGroup.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF556B2F)),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Préparation des groupes...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xCC556B2F),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (error != null && deputiesByGroup.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'Erreur de connexion',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  deputyProvider.clearError();
                  _loadGroupsOptimized();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF556B2F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (deputiesByGroup.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group_off,
              size: 60,
              color: Color(0x99556B2F),
            ),
            SizedBox(height: 20),
            Text(
              'Aucune donnée de groupe disponible',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xCC556B2F),
              ),
            ),
          ],
        ),
      );
    }

    // Trier les groupes par ordre alphabétique des libellés
    final sortedGroups = deputiesByGroup.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView.separated(
      itemCount: sortedGroups.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final groupEntry = sortedGroups[index];
        final group = groupEntry.key;
        final deputies = groupEntry.value;

        return _buildOptimizedGroupCard(group, deputies);
      },
    );
  }
  
  /// Widget de groupe optimisé avec lazy loading des députés
  Widget _buildOptimizedGroupCard(String group, List<DeputyModel> deputies) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        title: _buildGroupHeader(group, deputies.length),
        children: [
          // Limiter à 10 députés par défaut pour les performances
          ...deputies.take(10).map((deputy) => _buildOptimizedGroupDeputyTile(deputy)),
          if (deputies.length > 10)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton.icon(
                onPressed: () {
                  // TODO: Implémenter une vue détaillée du groupe
                  _showFullGroupDialog(group, deputies);
                },
                icon: const Icon(Icons.more_horiz, color: Color(0xFF556B2F)),
                label: Text(
                  'Voir ${deputies.length - 10} autres députés...',
                  style: const TextStyle(color: Color(0xFF556B2F)),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildGroupHeader(String group, int count) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF556B2F), Color(0xFF6B8E3E)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(15)),
          ),
          child: const Icon(
            Icons.groups_rounded,
            size: 26,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF556B2F),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0x1A556B2F),
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: Text(
                  '$count député${count > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xCC556B2F),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildOptimizedGroupDeputyTile(DeputyModel deputy) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Color(0x1A556B2F),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.network(
            _getDeputyPhotoUrl(deputy.id),
            fit: BoxFit.cover,
            width: 40,
            height: 40,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF556B2F)),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0x1A556B2F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0x99556B2F),
                  size: 20,
                ),
              );
            },
          ),
        ),
      ),
      title: Text(
        deputy.fullName,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF556B2F),
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        deputy.circonscriptionComplete,
        style: const TextStyle(
          color: Color(0xB3556B2F),
          fontSize: 13,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Color(0x99556B2F),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeputyDetailPage(deputy: deputy),
          ),
        );
      },
    );
  }
  
  /// Affiche un dialog avec tous les députés du groupe
  void _showFullGroupDialog(String groupName, List<DeputyModel> deputies) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      groupName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF556B2F),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${deputies.length} députés',
                style: const TextStyle(
                  color: Color(0xB3556B2F),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: deputies.length,
                  itemBuilder: (context, index) {
                    return _buildOptimizedGroupDeputyTile(deputies[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _performSearch(String query) {
    // Annuler le timer précédent pour éviter les recherches multiples
    _searchDebounceTimer?.cancel();
    
    // Utiliser debouncing pour éviter trop de setState
    _searchDebounceTimer = Timer(_searchDebounceDelay, () {
      if (!mounted) return;
      
      if (query.trim().isEmpty) {
        setState(() {
          _searchResults = _allDeputies;
        });
        return;
      }

      // Recherche optimisée avec liste pré-triée
      final searchQuery = query.toLowerCase();
      final filteredDeputies = <DeputyModel>[];
      
      // Optimisation: arrêter la recherche après un certain nombre de résultats
      const maxResults = 100;
      
      for (final deputy in _allDeputies) {
        if (filteredDeputies.length >= maxResults) break;
        
        final fullName = deputy.fullName.toLowerCase();
        if (fullName.contains(searchQuery)) {
          filteredDeputies.add(deputy);
        }
      }

      setState(() {
        _searchResults = filteredDeputies;
      });
    });
  }

  void _onMapTap(LatLng point) async {
    try {
      // Chercher dans quel polygone (circonscription) se trouve le point cliqué
      String? foundCirconscription;
      
      for (int i = 0; i < _circonscriptions.length; i++) {
        final polygon = _circonscriptions[i];
        final circonscriptionInfo = _circonscriptionData[i];
        
        // Vérifier si le point est dans ce polygone
        if (_isPointInPolygon(point, polygon.points)) {
          foundCirconscription = circonscriptionInfo['id_circo'];
          
          // Afficher des informations sur la circonscription trouvée
          print('🗺️ Circonscription trouvée: $foundCirconscription');
          print('📍 Détails: ${circonscriptionInfo['nom_circ']} - ${circonscriptionInfo['libelle']}');
          
          break;
        }
      }
      
      if (foundCirconscription == null || foundCirconscription.isEmpty) {
        // Aucune circonscription trouvée à cet endroit
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aucune circonscription trouvée à cet endroit'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      
      // Debug: afficher quelques échantillons de données
      print('🔍 Recherche pour circonscription: $foundCirconscription');
      if (_allDeputies.isNotEmpty) {
        print('📊 Échantillon de données deputés:');
        for (int i = 0; i < math.min(5, _allDeputies.length); i++) {
          final deputy = _allDeputies[i];
          print('   Deputy ${i+1}: idcirco="${deputy.idcirco}", codeCirco="${deputy.codeCirco}", nom="${deputy.nom}", prenom="${deputy.prenom}"');
        }
        
        // Debug: Essayer de trouver des députés qui ont des circonscriptions non nulles
        final deputiesWithCirco = _allDeputies.where((d) => 
          d.idcirco != null || d.codeCirco != null).take(3).toList();
        
        if (deputiesWithCirco.isNotEmpty) {
          print('🎯 Députés avec circonscriptions:');
          for (final deputy in deputiesWithCirco) {
            print('   ${deputy.nom}: idcirco="${deputy.idcirco}", codeCirco="${deputy.codeCirco}"');
          }
        } else {
          print('⚠️ Aucun député trouvé avec des données de circonscription');
        }
      }
      
      // Chercher le député correspondant à cette circonscription
      DeputyModel? foundDeputy;
      
      for (final deputy in _allDeputies) {
        // Vérifier plusieurs formats d'identifiants de circonscription
        if (deputy.idcirco == foundCirconscription ||
            deputy.codeCirco == foundCirconscription ||
            deputy.idcirco == _normalizeIdcirco(foundCirconscription) ||
            deputy.codeCirco == _normalizeIdcirco(foundCirconscription)) {
          foundDeputy = deputy;
          break;
        }
      }
      
      if (foundDeputy != null) {
        // Députe trouvé, afficher le popup
        setState(() {
          _selectedDeputy = foundDeputy;
          _selectedCirconscriptionName = _circonscriptionData
              .firstWhere((c) => c['id_circo'] == foundCirconscription,
                  orElse: () => {'nom_circ': 'Circonscription inconnue'})['nom_circ'];
        });
      } else {
        // Aucun député trouvé pour cette circonscription
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Aucun député trouvé pour la circonscription $foundCirconscription'
            ),
            backgroundColor: Colors.amber,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      print('❌ Erreur lors de la recherche sur la carte: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la recherche sur la carte'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  /// Algorithme pour vérifier si un point est dans un polygone (Ray casting)
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    double x = point.longitude;
    double y = point.latitude;
    
    bool inside = false;
    int j = polygon.length - 1;
    
    for (int i = 0; i < polygon.length; i++) {
      double xi = polygon[i].longitude;
      double yi = polygon[i].latitude;
      double xj = polygon[j].longitude;
      double yj = polygon[j].latitude;
      
      if ((yi > y) != (yj > y) && 
          (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    
    return inside;
  }

  Widget _buildDeputyPopup() {
    if (_selectedDeputy == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header avec photo et informations principales
              Row(
                children: [
                  // Photo du député
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF556B2F).withOpacity(0.2),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        _getDeputyPhotoUrl(_selectedDeputy!.id),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF556B2F).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.person,
                              size: 35,
                              color: const Color(0xFF556B2F).withOpacity(0.6),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Informations du député
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedDeputy!.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: Color(0xFF556B2F),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (_selectedDeputy!.famillePolLibelleDb != null &&
                            _selectedDeputy!.famillePolLibelleDb!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF556B2F).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _selectedDeputy!.famillePolLibelleDb!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF556B2F).withOpacity(0.8),
                              ),
                            ),
                          ),
                        if (_selectedCirconscriptionName != null)
                          Text(
                            _selectedCirconscriptionName!,
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xFF556B2F).withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Bouton fermer
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDeputy = null;
                        _selectedCirconscriptionName = null;
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF556B2F).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: const Color(0xFF556B2F).withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedDeputy = null;
                          _selectedCirconscriptionName = null;
                        });
                      },
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Fermer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.grey.shade700,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Fermer le popup et naviguer vers la page de détail
                        final deputy = _selectedDeputy!;
                        setState(() {
                          _selectedDeputy = null;
                          _selectedCirconscriptionName = null;
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DeputyDetailPage(deputy: deputy),
                          ),
                        );
                      },
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('Voir les détails'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF556B2F),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchFocusNode.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }
}