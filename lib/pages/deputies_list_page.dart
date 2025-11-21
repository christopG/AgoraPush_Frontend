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
  final ScrollController _scrollController = ScrollController();
  List<DeputyModel> _searchResults = [];
  List<DeputyModel> _allDeputies = [];
  bool _isLoadingAllDeputies = false;
  bool _showHeader = true; // Pour contrôler l'affichage du header
  double _lastScrollOffset = 0.0;
  
  // Filter states
  bool _showOnlyActive = true; // Actif par défaut
  String? _selectedLegislature;
  String? _selectedDepartment;
  String? _selectedGroup;
  String? _selectedJob;
  RangeValues? _ageRange;
  RangeValues? _experienceRange;
  RangeValues? _loyauteRange;
  RangeValues? _majoriteRange;
  RangeValues? _participationRange;
  RangeValues? _participationSpecialiteRange;
  bool _showFilters = false;
  
  // Available filter options (will be populated from data)
  List<String> _legislatures = [];
  List<String> _departments = [];
  List<String> _groups = [];
  List<String> _jobs = [];
  
  // Min/Max values for numeric filters
  int _minAge = 0;
  int _maxAge = 100;
  int _minExperience = 0;
  int _maxExperience = 50;
  double _minLoyaute = 0.0;
  double _maxLoyaute = 1.0;
  double _minMajorite = 0.0;
  double _maxMajorite = 1.0;
  double _minParticipation = 0.0;
  double _maxParticipation = 1.0;
  double _minParticipationSpecialite = 0.0;
  double _maxParticipationSpecialite = 1.0;

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
  
  // Couleurs des groupes politiques
  Map<String, String> _groupColors = {};
  
  // Variables pour l'optimisation des performances
  static final Map<String, List<DeputyModel>> _deputiesCache = {};
  static final Map<String, List<Polygon>> _geoJsonCache = {};
  static final Map<String, List<Map<String, dynamic>>> _circonscriptionDataCache = {};
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
    _scrollController.addListener(_onScroll);
    
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
          _circonscriptions = _geoJsonCache['geojson']!;
          _circonscriptionData = _circonscriptionDataCache['data']!;
          _isLoadingAllDeputies = false;
          _isLoadingGeoJson = false;
          _isInitialized = true;
        });
        
        // Apply initial filters (active only by default)
        _applyFilters();
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
        _loadGroupColors(),
        _loadAllDeputiesOptimized(),
      ]);
      await _loadGeoJsonDataOptimized(); // Après avoir chargé les députés et couleurs
      _loadInitialData();
    } else {
      // Si cache présent, mise à jour silencieuse en arrière-plan
      _updateCacheInBackground();
    }
  }
  
  /// Charge les couleurs des groupes politiques depuis les organes
  Future<void> _loadGroupColors() async {
    try {
      print('🎨 Début chargement des couleurs de groupes...');
      final organes = await deputyRepositoryProvider.getAllOrganes();
      print('📊 ${organes.length} organes reçus');
      final Map<String, String> colors = {};
      
      for (final organe in organes) {
        final libelle = organe['libelle']?.toString();
        final couleur = organe['couleur_associee']?.toString();
        if (libelle != null && couleur != null && couleur.isNotEmpty) {
          colors[libelle] = couleur;
          print('   ✓ $libelle → $couleur');
        }
      }
      
      setState(() {
        _groupColors = colors;
      });
      
      print('✅ ${colors.length} couleurs de groupes chargées et appliquées');
    } catch (e) {
      print('⚠️ Erreur chargement couleurs groupes: $e');
    }
  }

  void _onSearchFocusChange() {
    setState(() {}); // Met à jour l'affichage quand le focus change
  }
  
  void _onScroll() {
    final currentOffset = _scrollController.offset;
    
    if (currentOffset > _lastScrollOffset && currentOffset > 50) {
      if (_showHeader) {
        setState(() => _showHeader = false);
      }
    } else if (currentOffset < _lastScrollOffset || currentOffset < 50) {
      if (!_showHeader) {
        setState(() => _showHeader = true);
      }
    }
    
    _lastScrollOffset = currentOffset;
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
  
  /// Populates filter options from deputies list
  void _populateFilterOptions(List<DeputyModel> deputies) {
    if (deputies.isEmpty) {
      print('⚠️ Aucun député à traiter pour les filtres');
      return;
    }
    
    final Set<String> legislatureSet = {};
    final Set<String> departmentSet = {};
    final Set<String> groupSet = {};
    final Set<String> jobSet = {};
    
    // Calculate min/max for numeric filters - start with first valid values
    int? minAge;
    int? maxAge;
    int? minExp;
    int? maxExp;
    double? minLoy;
    double? maxLoy;
    double? minMaj;
    double? maxMaj;
    double? minPart;
    double? maxPart;
    double? minPartSpec;
    double? maxPartSpec;
    
    // Debug: check first deputy data
    if (deputies.isNotEmpty) {
      final firstDeputy = deputies[0];
      print('🔍 Premier député:');
      print('  id: "${firstDeputy.id}"');
      print('  legislature: "${firstDeputy.legislature}"');
      print('  dep: "${firstDeputy.dep}"');
      print('  groupe: "${firstDeputy.famillePolLibelleDb}"');
      print('  profession: "${firstDeputy.profession}"');
    }
    
    int legislatureCount = 0;
    int depCount = 0;
    int groupCount = 0;
    int jobCount = 0;
    
    for (final deputy in deputies) {
      // Collect filter values (protect against string "null")
      if (deputy.legislature != null && deputy.legislature!.isNotEmpty && deputy.legislature != 'null') {
        legislatureSet.add(deputy.legislature!);
        legislatureCount++;
      }
      if (deputy.dep != null && deputy.dep!.isNotEmpty && deputy.dep != 'null') {
        departmentSet.add(deputy.dep!);
        depCount++;
      }
      if (deputy.famillePolLibelleDb != null && deputy.famillePolLibelleDb!.isNotEmpty && deputy.famillePolLibelleDb != 'null') {
        groupSet.add(deputy.famillePolLibelleDb!);
        groupCount++;
      }
      if (deputy.profession != null && deputy.profession!.isNotEmpty && deputy.profession != 'null') {
        jobSet.add(deputy.profession!);
        jobCount++;
      }
      
      // Calculate ranges
      if (deputy.age != null) {
        minAge = minAge == null ? deputy.age! : (deputy.age! < minAge ? deputy.age! : minAge);
        maxAge = maxAge == null ? deputy.age! : (deputy.age! > maxAge ? deputy.age! : maxAge);
      }
      if (deputy.experienceDepute != null) {
        minExp = minExp == null ? deputy.experienceDepute! : (deputy.experienceDepute! < minExp ? deputy.experienceDepute! : minExp);
        maxExp = maxExp == null ? deputy.experienceDepute! : (deputy.experienceDepute! > maxExp ? deputy.experienceDepute! : maxExp);
      }
      if (deputy.scoreLoyaute != null) {
        minLoy = minLoy == null ? deputy.scoreLoyaute! : (deputy.scoreLoyaute! < minLoy ? deputy.scoreLoyaute! : minLoy);
        maxLoy = maxLoy == null ? deputy.scoreLoyaute! : (deputy.scoreLoyaute! > maxLoy ? deputy.scoreLoyaute! : maxLoy);
      }
      if (deputy.scoreMajorite != null) {
        minMaj = minMaj == null ? deputy.scoreMajorite! : (deputy.scoreMajorite! < minMaj ? deputy.scoreMajorite! : minMaj);
        maxMaj = maxMaj == null ? deputy.scoreMajorite! : (deputy.scoreMajorite! > maxMaj ? deputy.scoreMajorite! : maxMaj);
      }
      if (deputy.scoreParticipation != null) {
        minPart = minPart == null ? deputy.scoreParticipation! : (deputy.scoreParticipation! < minPart ? deputy.scoreParticipation! : minPart);
        maxPart = maxPart == null ? deputy.scoreParticipation! : (deputy.scoreParticipation! > maxPart ? deputy.scoreParticipation! : maxPart);
      }
      if (deputy.scoreParticipationSpectialite != null) {
        minPartSpec = minPartSpec == null ? deputy.scoreParticipationSpectialite! : (deputy.scoreParticipationSpectialite! < minPartSpec ? deputy.scoreParticipationSpectialite! : minPartSpec);
        maxPartSpec = maxPartSpec == null ? deputy.scoreParticipationSpectialite! : (deputy.scoreParticipationSpectialite! > maxPartSpec ? deputy.scoreParticipationSpectialite! : maxPartSpec);
      }
    }
    
    print('📊 Statistiques de collecte:');
    print('  $legislatureCount députés avec législature');
    print('  $depCount députés avec département');
    print('  $groupCount députés avec groupe');
    print('  $jobCount députés avec profession');
    
    // Populate filter options sorted
    _legislatures = legislatureSet.toList()..sort();
    _departments = departmentSet.toList()..sort((a, b) {
      // Sort departments numerically
      final aNum = int.tryParse(a) ?? 0;
      final bNum = int.tryParse(b) ?? 0;
      return aNum.compareTo(bNum);
    });
    _groups = groupSet.toList()..sort();
    _jobs = jobSet.toList()..sort();
    
    // Set ranges with safe defaults
    _minAge = minAge ?? 0;
    _maxAge = maxAge ?? 100;
    _minExperience = minExp ?? 0;
    _maxExperience = maxExp ?? 50;
    _minLoyaute = minLoy ?? 0.0;
    _maxLoyaute = maxLoy ?? 1.0;
    _minMajorite = minMaj ?? 0.0;
    _maxMajorite = maxMaj ?? 1.0;
    _minParticipation = minPart ?? 0.0;
    _maxParticipation = maxPart ?? 1.0;
    _minParticipationSpecialite = minPartSpec ?? 0.0;
    _maxParticipationSpecialite = maxPartSpec ?? 1.0;
    
    // Debug: print filter lists
    print('🔍 Filtres disponibles:');
    print('  Législatures: $_legislatures (${_legislatures.length} items)');
    print('  Départements: ${_departments.length} items');
    print('  Groupes: ${_groups.length} items');
    print('  Jobs: ${_jobs.length} items');
  }
  
  /// Charge depuis SharedPreferences pour persistance entre sessions
  Future<void> _loadFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Vérifier la date de mise à jour du cache
      final cacheTimestamp = prefs.getInt('deputies_cache_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Cache valide pour 5 minutes
      if (now - cacheTimestamp > 300000) {
        print('💾 Cache SharedPreferences expiré');
        // Clear old cache
        await prefs.remove('deputies_cache');
        await prefs.remove('deputies_cache_timestamp');
        return;
      }
      
      // Charger les députés depuis le cache
      final deputiesJson = prefs.getString('deputies_cache');
      if (deputiesJson != null) {
        final List<dynamic> deputiesData = json.decode(deputiesJson);
        final deputies = deputiesData.map((data) => DeputyModel.fromJson(data)).toList();
        
        print('💾 ${deputies.length} députés chargés depuis SharedPreferences');
        
        // Populate filter options
        _populateFilterOptions(deputies);
        
        setState(() {
          _allDeputies = deputies;
          _isLoadingAllDeputies = false;
          _isInitialized = true;
        });
        
        // Apply initial filters (active only by default)
        _applyFilters();
        
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
      
      // Grouper les députés par groupe politique (uniquement les actifs)
      for (final deputy in _allDeputies) {
        // Filtrer uniquement les députés actifs
        if (deputy.active != 1) continue;
        
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
      print('📊 Total features GeoJSON: ${features.length}');
      
      int matchedCount = 0;
      int unmatchedCount = 0;
      
      for (int featureIndex = 0; featureIndex < features.length; featureIndex++) {
        var feature = features[featureIndex];

        Map<String, dynamic> circonscriptionInfo = {
          'id_circo': feature['properties']?['id_circo'] ?? '',
          'dep': feature['properties']?['dep'] ?? '',
          'libelle': feature['properties']?['libelle'] ?? '',
          'nom_circ': feature['properties']?['nom_circ'] ??
              feature['properties']?['libelle'] ??
              'Circonscription ${featureIndex + 1}',
        };

        // Trouver le député actif de cette circonscription pour obtenir sa couleur de groupe
        String? couleur;
        final idCirco = feature['properties']?['id_circo'] as String?;
        
        if (idCirco != null && idCirco.isNotEmpty) {
          // Chercher le député actif dont l'idcirco correspond exactement
          bool found = false;
          for (final deputy in _allDeputies) {
            if (deputy.active == 1 && deputy.idcirco == idCirco) {
              final groupe = deputy.famillePolLibelleDb ?? deputy.famillePolLibelle;
              if (groupe != null && _groupColors.containsKey(groupe)) {
                couleur = _groupColors[groupe];
                found = true;
                matchedCount++;
                if (matchedCount <= 5) { // Log pour les 5 premiers matchs réussis
                  print('🗺️ ✅ Circo $idCirco: ${deputy.nom} → groupe=$groupe → couleur=$couleur');
                }
              }
              break;
            }
          }
          
          if (!found) {
            unmatchedCount++;
            if (unmatchedCount <= 15) { // Log des 15 premiers échecs pour debug avec détails
              // Chercher si un député existe pour ce dep (pour debug)
              final dep = idCirco.length >= 2 ? idCirco.substring(0, 2) : '';
              final foundForDep = _allDeputies.where((d) => d.dep == dep && d.active == 1).take(3).toList();
              if (foundForDep.isNotEmpty) {
                print('🗺️ ⚠️ Circo GeoJSON "$idCirco": AUCUN MATCH - Députés actifs dep $dep: ${foundForDep.map((d) => '${d.nom} (idcirco="${d.idcirco}")').join(", ")}');
              } else {
                print('🗺️ ⚠️ Circo GeoJSON "$idCirco": AUCUN DÉPUTÉ ACTIF TROUVÉ POUR DEP $dep');
              }
            }
          }
        }
        
        // Utiliser la couleur du groupe ou gris par défaut si pas de député
        final Color fillColor = parseColor(couleur ?? '#CCCCCC', opacity: 0.5);
        final Color borderColor = parseColor(couleur ?? '#999999', opacity: 1.0);

        if (feature['geometry']['type'] == 'Polygon') {
          List<LatLng> points = [];
          var coordinates = feature['geometry']['coordinates'][0];

          if (coordinates != null && coordinates.isNotEmpty) {
            // Garder TOUS les points pour des frontières précises
            for (int i = 0; i < coordinates.length; i++) {
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
                  borderStrokeWidth: 0.5,
                  isFilled: true,
                ),
              );
              circonscriptionData.add(circonscriptionInfo);
            }
          }
        } else if (feature['geometry']['type'] == 'MultiPolygon') {
          // Traiter TOUS les polygones du MultiPolygon
          for (var polygon in feature['geometry']['coordinates']) {
            List<LatLng> points = [];
            var coordinates = polygon[0];

            if (coordinates != null && coordinates.isNotEmpty) {
              // Garder tous les points
              for (int i = 0; i < coordinates.length; i++) {
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
                    borderStrokeWidth: 0.5,
                    isFilled: true,
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
        // Populate filter options from loaded deputies
        _populateFilterOptions(allDeputies);
        
        setState(() {
          _allDeputies = allDeputies;
          _isLoadingAllDeputies = false;
          _isInitialized = true;
        });
        
        // Apply initial filters (active only by default)
        _applyFilters();
        
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
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(35),
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
      onTap: () async {
        setState(() {
          _currentMode = mode;
        });
        if (mode == ViewMode.groups) {
          _loadGroupsOptimized();
        } else if (mode == ViewMode.map) {
          // S'assurer que tout est chargé avant d'afficher la carte
          if (_groupColors.isEmpty) {
            await _loadGroupColors();
          }
          if (_isLoadingGeoJson || _circonscriptions.isEmpty) {
            await _loadGeoJsonDataOptimized();
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF556B2F) : Colors.transparent,
          borderRadius: BorderRadius.circular(0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? Colors.white : const Color(0xFF556B2F),
            ),
            const SizedBox(height: 6),
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
        // Barre de recherche avec bouton filtres (se cache lors du scroll)
        if (_showHeader)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Nom, prénom...',
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
                              _applyFilters();
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
                  onChanged: (value) => _applyFilters(),
                ),
              ),
              // Bouton filtres
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _hasActiveFilters()
                        ? const Color(0xFF556B2F)
                        : const Color(0xFF556B2F).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.filter_list,
                    color: _hasActiveFilters()
                        ? Colors.white
                        : const Color(0xFF556B2F).withOpacity(0.8),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Active filters chips (se cache lors du scroll)
        if (_showHeader && _hasActiveFilters())
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Filtered count chip
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF556B2F).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF556B2F).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_alt, size: 14, color: Color(0xFF556B2F)),
                      const SizedBox(width: 4),
                      Text(
                        '${_searchResults.length} député${_searchResults.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF556B2F),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showOnlyActive) _buildFilterChip('Actifs', () {
                  setState(() {
                    _showOnlyActive = false;
                    _applyFilters();
                  });
                }),
                if (_selectedLegislature != null) _buildFilterChip('Lég. $_selectedLegislature', () {
                  setState(() {
                    _selectedLegislature = null;
                    _applyFilters();
                  });
                }),
                if (_selectedDepartment != null) _buildFilterChip('Dép. $_selectedDepartment', () {
                  setState(() {
                    _selectedDepartment = null;
                    _applyFilters();
                  });
                }),
                if (_selectedGroup != null) _buildFilterChip(_selectedGroup!, () {
                  setState(() {
                    _selectedGroup = null;
                    _applyFilters();
                  });
                }, maxWidth: 150),
                if (_selectedJob != null) _buildFilterChip(_selectedJob!, () {
                  setState(() {
                    _selectedJob = null;
                    _applyFilters();
                  });
                }, maxWidth: 120),
                if (_ageRange != null) _buildFilterChip('Âge: ${_ageRange!.start.round()}-${_ageRange!.end.round()}', () {
                  setState(() {
                    _ageRange = null;
                    _applyFilters();
                  });
                }),
                if (_experienceRange != null) _buildFilterChip('Exp: ${_experienceRange!.start.round()}-${_experienceRange!.end.round()}', () {
                  setState(() {
                    _experienceRange = null;
                    _applyFilters();
                  });
                }),
                if (_loyauteRange != null) _buildFilterChip('Loyauté: ${_loyauteRange!.start.toStringAsFixed(2)}-${_loyauteRange!.end.toStringAsFixed(2)}', () {
                  setState(() {
                    _loyauteRange = null;
                    _applyFilters();
                  });
                }),
                if (_majoriteRange != null) _buildFilterChip('Majorité: ${_majoriteRange!.start.toStringAsFixed(2)}-${_majoriteRange!.end.toStringAsFixed(2)}', () {
                  setState(() {
                    _majoriteRange = null;
                    _applyFilters();
                  });
                }),
                if (_participationRange != null) _buildFilterChip('Particip.: ${_participationRange!.start.toStringAsFixed(2)}-${_participationRange!.end.toStringAsFixed(2)}', () {
                  setState(() {
                    _participationRange = null;
                    _applyFilters();
                  });
                }),
                if (_participationSpecialiteRange != null) _buildFilterChip('Part. Spé.: ${_participationSpecialiteRange!.start.toStringAsFixed(2)}-${_participationSpecialiteRange!.end.toStringAsFixed(2)}', () {
                  setState(() {
                    _participationSpecialiteRange = null;
                    _applyFilters();
                  });
                }),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showOnlyActive = false;
                      _selectedLegislature = null;
                      _selectedDepartment = null;
                      _selectedGroup = null;
                      _selectedJob = null;
                      _ageRange = null;
                      _experienceRange = null;
                      _loyauteRange = null;
                      _majoriteRange = null;
                      _participationRange = null;
                      _participationSpecialiteRange = null;
                      _applyFilters();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.clear_all, size: 14, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          'Tout effacer',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Show count even without active filters if search is active (se cache lors du scroll)
        if (_showHeader && !_hasActiveFilters() && _searchController.text.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF556B2F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search, size: 16, color: Color(0xFF556B2F)),
                const SizedBox(width: 8),
                Text(
                  '${_searchResults.length} résultat${_searchResults.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF556B2F),
                  ),
                ),
              ],
            ),
          ),
        
        // Filter panel (se cache lors du scroll)
        if (_showHeader && _showFilters)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            constraints: const BoxConstraints(maxHeight: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fixed header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, size: 18, color: Color(0xFF556B2F)),
                      const SizedBox(width: 8),
                      const Text(
                        'Filtres',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF556B2F),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                
                // Active only toggle
                _buildFilterRow(
                  'Actifs uniquement',
                  Switch(
                    value: _showOnlyActive,
                    onChanged: (value) {
                      setState(() {
                        _showOnlyActive = value;
                        _applyFilters();
                      });
                    },
                    activeColor: const Color(0xFF556B2F),
                  ),
                ),
                
                const Divider(height: 20),
                
                // Legislature filter
                _buildDropdownFilter(
                  'Législature',
                  _selectedLegislature,
                  _legislatures,
                  (value) {
                    setState(() {
                      _selectedLegislature = value;
                      _applyFilters();
                    });
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Department filter
                _buildDropdownFilter(
                  'Département',
                  _selectedDepartment,
                  _departments,
                  (value) {
                    setState(() {
                      _selectedDepartment = value;
                      _applyFilters();
                    });
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Group filter
                _buildDropdownFilter(
                  'Groupe politique',
                  _selectedGroup,
                  _groups,
                  (value) {
                    setState(() {
                      _selectedGroup = value;
                      _applyFilters();
                    });
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Job filter
                _buildDropdownFilter(
                  'Profession',
                  _selectedJob,
                  _jobs,
                  (value) {
                    setState(() {
                      _selectedJob = value;
                      _applyFilters();
                    });
                  },
                ),
                
                const Divider(height: 24),
                
                // Age range filter
                _buildRangeFilter(
                  'Âge',
                  _ageRange ?? RangeValues(_minAge.toDouble(), _maxAge.toDouble()),
                  _minAge.toDouble(),
                  _maxAge.toDouble(),
                  (values) {
                    setState(() {
                      _ageRange = values;
                      _applyFilters();
                    });
                  },
                  divisions: math.max(1, _maxAge - _minAge),
                ),
                
                const SizedBox(height: 12),
                
                // Experience range filter
                _buildRangeFilter(
                  'Expérience (années)',
                  _experienceRange ?? RangeValues(_minExperience.toDouble(), _maxExperience.toDouble()),
                  _minExperience.toDouble(),
                  _maxExperience.toDouble(),
                  (values) {
                    setState(() {
                      _experienceRange = values;
                      _applyFilters();
                    });
                  },
                  divisions: math.max(1, _maxExperience - _minExperience),
                ),
                
                const SizedBox(height: 12),
                
                // Loyaute score filter
                _buildRangeFilter(
                  'Score de loyauté',
                  _loyauteRange ?? RangeValues(_minLoyaute, _maxLoyaute),
                  _minLoyaute,
                  _maxLoyaute,
                  (values) {
                    setState(() {
                      _loyauteRange = values;
                      _applyFilters();
                    });
                  },
                  divisions: 100,
                  isDecimal: true,
                ),
                
                const SizedBox(height: 12),
                
                // Majorite score filter
                _buildRangeFilter(
                  'Score de majorité',
                  _majoriteRange ?? RangeValues(_minMajorite, _maxMajorite),
                  _minMajorite,
                  _maxMajorite,
                  (values) {
                    setState(() {
                      _majoriteRange = values;
                      _applyFilters();
                    });
                  },
                  divisions: 100,
                  isDecimal: true,
                ),
                
                const SizedBox(height: 12),
                
                // Participation score filter
                _buildRangeFilter(
                  'Score de participation',
                  _participationRange ?? RangeValues(_minParticipation, _maxParticipation),
                  _minParticipation,
                  _maxParticipation,
                  (values) {
                    setState(() {
                      _participationRange = values;
                      _applyFilters();
                    });
                  },
                  divisions: 100,
                  isDecimal: true,
                ),
                
                const SizedBox(height: 12),
                
                // Participation specialite score filter
                _buildRangeFilter(
                  'Score participation spécialité',
                  _participationSpecialiteRange ?? RangeValues(_minParticipationSpecialite, _maxParticipationSpecialite),
                  _minParticipationSpecialite,
                  _maxParticipationSpecialite,
                  (values) {
                    setState(() {
                      _participationSpecialiteRange = values;
                      _applyFilters();
                    });
                  },
                  divisions: 100,
                  isDecimal: true,
                ),
                      ],
                    ),
                  ),
                ),
              ],
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
                          controller: _scrollController,
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
        borderRadius: BorderRadius.circular(40),
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
          borderRadius: BorderRadius.circular(35),
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
                const SizedBox(width: 8),
                // Flèche moderne alignée avec le groupe
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
        shape: BoxShape.circle,
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
      child: ClipOval(
        child: Image.network(
          _getDeputyPhotoUrl(deputy.id),
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              decoration: const BoxDecoration(
                color: Color(0x1A556B2F),
                shape: BoxShape.circle,
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
                shape: BoxShape.circle,
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
          Row(
            children: [
              Flexible(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: const BoxDecoration(
                    color: Color(0x1A556B2F),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Text(
                    deputy.famillePolLibelleDb!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xCC556B2F),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
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
          shape: BoxShape.circle,
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
        borderRadius: BorderRadius.all(Radius.circular(35)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
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
      ),
    );
  }
  
  Widget _buildGroupHeader(String group, int count) {
    return Row(
      children: [
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

  void _applyFilters() {
    _searchDebounceTimer?.cancel();
    
    _searchDebounceTimer = Timer(_searchDebounceDelay, () {
      if (!mounted) return;
      
      List<DeputyModel> filtered = List.from(_allDeputies);
      
      // Filter by active status
      if (_showOnlyActive) {
        filtered = filtered.where((d) => d.active == 1).toList();
      }
      
      // Filter by legislature
      if (_selectedLegislature != null) {
        filtered = filtered.where((d) => d.legislature == _selectedLegislature).toList();
      }
      
      // Filter by department
      if (_selectedDepartment != null) {
        filtered = filtered.where((d) => d.dep == _selectedDepartment).toList();
      }
      
      // Filter by group
      if (_selectedGroup != null) {
        filtered = filtered.where((d) => d.famillePolLibelleDb == _selectedGroup).toList();
      }
      
      // Filter by job
      if (_selectedJob != null) {
        filtered = filtered.where((d) => d.profession == _selectedJob).toList();
      }
      
      // Filter by age range
      if (_ageRange != null && 
          (_ageRange!.start > _minAge.toDouble() || _ageRange!.end < _maxAge.toDouble())) {
        filtered = filtered.where((d) {
          if (d.age == null) return false;
          return d.age! >= _ageRange!.start.round() && d.age! <= _ageRange!.end.round();
        }).toList();
      }
      
      // Filter by experience range
      if (_experienceRange != null &&
          (_experienceRange!.start > _minExperience.toDouble() || _experienceRange!.end < _maxExperience.toDouble())) {
        filtered = filtered.where((d) {
          if (d.experienceDepute == null) return false;
          return d.experienceDepute! >= _experienceRange!.start.round() && 
                 d.experienceDepute! <= _experienceRange!.end.round();
        }).toList();
      }
      
      // Filter by loyaute score range
      if (_loyauteRange != null &&
          (_loyauteRange!.start > _minLoyaute || _loyauteRange!.end < _maxLoyaute)) {
        filtered = filtered.where((d) {
          if (d.scoreLoyaute == null) return false;
          return d.scoreLoyaute! >= _loyauteRange!.start && 
                 d.scoreLoyaute! <= _loyauteRange!.end;
        }).toList();
      }
      
      // Filter by majorite score range
      if (_majoriteRange != null &&
          (_majoriteRange!.start > _minMajorite || _majoriteRange!.end < _maxMajorite)) {
        filtered = filtered.where((d) {
          if (d.scoreMajorite == null) return false;
          return d.scoreMajorite! >= _majoriteRange!.start && 
                 d.scoreMajorite! <= _majoriteRange!.end;
        }).toList();
      }
      
      // Filter by participation score range
      if (_participationRange != null &&
          (_participationRange!.start > _minParticipation || _participationRange!.end < _maxParticipation)) {
        filtered = filtered.where((d) {
          if (d.scoreParticipation == null) return false;
          return d.scoreParticipation! >= _participationRange!.start && 
                 d.scoreParticipation! <= _participationRange!.end;
        }).toList();
      }
      
      // Filter by participation specialite score range
      if (_participationSpecialiteRange != null &&
          (_participationSpecialiteRange!.start > _minParticipationSpecialite || _participationSpecialiteRange!.end < _maxParticipationSpecialite)) {
        filtered = filtered.where((d) {
          if (d.scoreParticipationSpectialite == null) return false;
          return d.scoreParticipationSpectialite! >= _participationSpecialiteRange!.start && 
                 d.scoreParticipationSpectialite! <= _participationSpecialiteRange!.end;
        }).toList();
      }
      
      // Filter by search text
      final searchQuery = _searchController.text.trim();
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        filtered = filtered.where((deputy) {
          final fullName = deputy.fullName.toLowerCase();
          return fullName.contains(query);
        }).toList();
      }
      
      setState(() {
        _searchResults = filtered;
      });
    });
  }
  
  bool _hasActiveFilters() {
    return _showOnlyActive || 
           _selectedLegislature != null || 
           _selectedDepartment != null || 
           _selectedGroup != null ||
           _selectedJob != null ||
           _ageRange != null ||
           _experienceRange != null ||
           _loyauteRange != null ||
           _majoriteRange != null ||
           _participationRange != null ||
           _participationSpecialiteRange != null;
  }
  
  Widget _buildFilterChip(String label, VoidCallback onRemove, {double? maxWidth}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      constraints: maxWidth != null ? BoxConstraints(maxWidth: maxWidth) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF556B2F),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFilterRow(String label, Widget trailing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF556B2F),
          ),
        ),
        trailing,
      ],
    );
  }
  
  Widget _buildDropdownFilter(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    // Add null option to allow deselection
    final allItems = [
      DropdownMenuItem<String>(
        value: null,
        child: Text(
          'Tous',
          style: TextStyle(
            fontSize: 14,
            color: const Color(0xFF556B2F).withOpacity(0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
      ...items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF556B2F),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF556B2F),
              ),
            ),
            Text(
              '${items.length}',
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFF556B2F).withOpacity(0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0x0D556B2F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x33556B2F)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: Text(
                'Tous',
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF556B2F).withOpacity(0.6),
                ),
              ),
              items: allItems,
              onChanged: onChanged,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF556B2F)),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildRangeFilter(
    String label,
    RangeValues values,
    double min,
    double max,
    ValueChanged<RangeValues> onChanged,
    {
      int? divisions,
      bool isDecimal = false,
    }
  ) {
    // Ensure min and max are different to avoid RangeSlider assertion error
    if (min >= max) {
      return const SizedBox.shrink(); // Don't show slider if range is invalid
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF556B2F),
              ),
            ),
            Text(
              isDecimal 
                ? '${values.start.toStringAsFixed(2)} - ${values.end.toStringAsFixed(2)}'
                : '${values.start.round()} - ${values.end.round()}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF556B2F).withOpacity(0.7),
              ),
            ),
          ],
        ),
        RangeSlider(
          values: values,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: const Color(0xFF556B2F),
          inactiveColor: const Color(0x33556B2F),
          onChanged: onChanged,
        ),
      ],
    );
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
      
      // Extraire le département et le numéro de circonscription de l'id_circo
      // Format: "2301" = département 23, circonscription 01
      String? depFromCirco;
      String? codeCircoFromCirco;
      
      if (foundCirconscription.length >= 3) {
        depFromCirco = foundCirconscription.substring(0, 2);
        codeCircoFromCirco = foundCirconscription.substring(2);
        // Enlever les zéros de tête du code circonscription
        codeCircoFromCirco = codeCircoFromCirco.replaceFirst(RegExp(r'^0+'), '');
        if (codeCircoFromCirco.isEmpty) codeCircoFromCirco = '1';
        
        print('📍 Extrait: département=$depFromCirco, circonscription=$codeCircoFromCirco');
      }
      
      if (_allDeputies.isNotEmpty) {
        print('📊 Échantillon de données deputés:');
        for (int i = 0; i < math.min(5, _allDeputies.length); i++) {
          final deputy = _allDeputies[i];
          print('   Deputy ${i+1}: dep="${deputy.dep}", codeCirco="${deputy.codeCirco}", nom="${deputy.nom}", prenom="${deputy.prenom}"');
        }
      }
      
      // Chercher le député correspondant à cette circonscription (UNIQUEMENT ACTIFS)
      DeputyModel? foundDeputy;
      
      for (final deputy in _allDeputies) {
        // Filtrer uniquement les députés actifs
        if (deputy.active != 1) continue;
        
        // Matcher par département ET code circonscription
        if (depFromCirco != null && codeCircoFromCirco != null) {
          if (deputy.dep == depFromCirco && deputy.codeCirco == codeCircoFromCirco) {
            foundDeputy = deputy;
            print('✅ Député trouvé: ${deputy.nom} ${deputy.prenom} (dep=${deputy.dep}, circo=${deputy.codeCirco}, active=${deputy.active})');
            break;
          }
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }
}