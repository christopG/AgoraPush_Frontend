import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../services/database_service.dart';
import '../services/session_service.dart';
import '../utils/map_config.dart';

class EditCirconscriptionPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(String circonscription) onUpdate;

  const EditCirconscriptionPage({
    super.key,
    required this.user,
    required this.onUpdate,
  });

  @override
  State<EditCirconscriptionPage> createState() =>
      _EditCirconscriptionPageState();
}

class _EditCirconscriptionPageState extends State<EditCirconscriptionPage> {
  String? _error;

  // Position par défaut : Paris
  LatLng _selectedLocation = const LatLng(48.8566, 2.3522);

  // Données GeoJSON des circonscriptions
  List<Polygon> _circonscriptions = [];
  List<Polygon> _originalPolygons = []; // Polygones originaux pour les calculs
  List<String> _circonscriptionNames = []; // Noms des circonscriptions
  List<int> _polygonToFeatureIndex =
      []; // Mapping polygone vers feature original
  List<Map<String, dynamic>> _circonscriptionData =
      []; // Données complètes des circonscriptions
  bool _isLoadingGeoJson = true;
  int? _selectedPolygonIndex; // Index du polygone sélectionné

  // Zoom par défaut pour voir une circonscription
  final double _initialZoom = 10.0;

  final DatabaseService _databaseService = DatabaseService();
  final SessionService _sessionService = SessionService();

  @override
  void initState() {
    super.initState();
    _loadGeoJsonData();
  }

  // Fonction pour calculer le centre d'un polygone
  LatLng _calculatePolygonCenter(List<LatLng> points) {
    if (points.isEmpty)
      return const LatLng(48.8566, 2.3522); // Paris par défaut

    double totalLat = 0;
    double totalLng = 0;
    int count = 0;

    for (var point in points) {
      totalLat += point.latitude;
      totalLng += point.longitude;
      count++;
    }

    return LatLng(totalLat / count, totalLng / count);
  }

  Future<void> _loadGeoJsonData() async {
    try {
      debugPrint('Début du chargement du GeoJSON...');
      final String geoJsonString = await rootBundle.loadString(
          'data/circomaps/circonscriptions_legislatives_030522.geojson');
      final Map<String, dynamic> geoJson = json.decode(geoJsonString);

      List<Polygon> polygons = [];
      List<String> names = [];
      List<int> featureMapping = [];
      List<Map<String, dynamic>> circonscriptionData = [];

      debugPrint(
          'Nombre de features dans le GeoJSON: ${geoJson['features']?.length}');

      // Traiter les features GeoJSON
      for (int featureIndex = 0;
          featureIndex < geoJson['features'].length;
          featureIndex++) {
        var feature = geoJson['features'][featureIndex];
        String circumscriptionName = '';

        Map<String, dynamic> circonscriptionInfo = {
          'id_circo': feature['properties']?['id_circo'] ?? '',
          'dep': feature['properties']?['dep'] ?? '',
          'libelle': feature['properties']?['libelle'] ?? '',
        };

        // Extraire le nom de la circonscription des propriétés
        if (feature['properties'] != null) {
          var props = feature['properties'];
          circumscriptionName = props['nom_circ'] ??
              props['nom_circonscription'] ??
              props['libelle'] ??
              props['name'] ??
              props['NOM'] ??
              props['LIBELLE'] ??
              'Circonscription ${names.length + 1}';
        } else {
          circumscriptionName = 'Circonscription ${names.length + 1}';
        }

        if (feature['geometry']['type'] == 'Polygon') {
          List<LatLng> points = [];
          var coordinates = feature['geometry']['coordinates'][0];

          if (coordinates == null || coordinates.isEmpty) {
            debugPrint(
                'Polygone avec coordonnées vides pour: $circumscriptionName');
            names.add(circumscriptionName);
            continue;
          }

          for (var coord in coordinates) {
            if (coord != null && coord.length >= 2) {
              points.add(LatLng(coord[1], coord[0]));
            }
          }

          if (points.length < 3) {
            debugPrint(
                'Polygone avec moins de 3 points pour: $circumscriptionName (${points.length} points)');
            names.add(circumscriptionName);
            continue;
          }

          if (coordinates.isNotEmpty) {
            var lastCoord = coordinates.last;
            if (lastCoord != null && lastCoord.length >= 2) {
              points.add(LatLng(lastCoord[1], lastCoord[0]));
            }
          }

          polygons.add(Polygon(
            points: points,
            color: const Color(0xFF8FBC8F).withOpacity(0.3),
            borderColor: const Color(0xFF556B2F).withOpacity(1.0),
            borderStrokeWidth: 2.0,
          ));

          names.add(circumscriptionName);
          featureMapping.add(featureIndex);
          circonscriptionData.add(circonscriptionInfo);
        } else if (feature['geometry']['type'] == 'MultiPolygon') {
          for (var polygon in feature['geometry']['coordinates']) {
            List<LatLng> points = [];
            var coordinates = polygon[0];

            if (coordinates == null || coordinates.isEmpty) {
              debugPrint(
                  'MultiPolygone avec coordonnées vides pour: $circumscriptionName');
              continue;
            }

            for (var coord in coordinates) {
              if (coord != null && coord.length >= 2) {
                points.add(LatLng(coord[1], coord[0]));
              }
            }

            if (points.length < 3) {
              debugPrint(
                  'MultiPolygone avec moins de 3 points pour: $circumscriptionName (${points.length} points)');
              continue;
            }

            if (coordinates.isNotEmpty) {
              var lastCoord = coordinates.last;
              if (lastCoord != null && lastCoord.length >= 2) {
                points.add(LatLng(lastCoord[1], lastCoord[0]));
              }
            }

            polygons.add(Polygon(
              points: points,
              color: const Color(0xFF8FBC8F).withOpacity(0.3),
              borderColor: const Color(0xFF556B2F).withOpacity(1.0),
              borderStrokeWidth: 2.0,
            ));

            names.add(circumscriptionName);
            featureMapping.add(featureIndex);
            circonscriptionData.add(circonscriptionInfo);
          }
        }
      }

      debugPrint('Nombre de polygones créés: ${polygons.length}');

      // Trouver la circonscription actuelle de l'utilisateur
      int? currentCirconscriptionIndex;
      LatLng? currentCirconscriptionCenter;
      List<LatLng> currentCirconscriptionPoints = [];

      // Extraire l'ID de circonscription du nom complet
      String userCirconscription = widget.user['circonscription'] ?? '';
      String userIdCirco = '';
      
      // Essayer d'extraire l'ID de la circonscription depuis le nom
      // Format attendu: "Département - Nème circonscription" -> "dep-N"
      if (userCirconscription.isNotEmpty) {
        final parts = userCirconscription.split(' - ');
        if (parts.length >= 2) {
          String dep = parts[0];
          String circonscriptionPart = parts[1];
          // Extraire le numéro de la circonscription
          final numMatch = RegExp(r'(\d+)').firstMatch(circonscriptionPart);
          if (numMatch != null) {
            String num = numMatch.group(1)!;
            userIdCirco = '$dep-$num';
          }
        }
      }

      for (int i = 0; i < circonscriptionData.length; i++) {
        String currentIdCirco = circonscriptionData[i]['id_circo'] ?? '';
        String currentLibelle = circonscriptionData[i]['libelle'] ?? '';
        
        if (currentIdCirco == userIdCirco || 
            currentLibelle == userCirconscription ||
            names[i] == userCirconscription) {
          currentCirconscriptionIndex ??= i;
          // Collecter tous les points de tous les polygones de cette circonscription
          currentCirconscriptionPoints.addAll(polygons[i].points);
        }
      }

      // Calculer le centre de tous les polygones de la circonscription actuelle
      if (currentCirconscriptionPoints.isNotEmpty) {
        currentCirconscriptionCenter =
            _calculatePolygonCenter(currentCirconscriptionPoints);
      }

      debugPrint(
          'Circonscription actuelle trouvée: ${currentCirconscriptionIndex != null}');
      debugPrint('Centre calculé: $currentCirconscriptionCenter');

      setState(() {
        _originalPolygons = polygons;
        _circonscriptions = polygons;
        _circonscriptionNames = names;
        _polygonToFeatureIndex = featureMapping;
        _circonscriptionData = circonscriptionData;
        _selectedPolygonIndex = currentCirconscriptionIndex;
        // Centrer la carte sur la circonscription actuelle si trouvée
        if (currentCirconscriptionCenter != null) {
          _selectedLocation = currentCirconscriptionCenter;
        }
        _isLoadingGeoJson = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement du GeoJSON: $e');
      setState(() {
        _isLoadingGeoJson = false;
        _error = 'Erreur lors du chargement de la carte. Vérifiez que le fichier GeoJSON existe.';
      });
    }
  }

  // Fonction pour vérifier si un point est dans un polygone
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersections = 0;
    for (int i = 0; i < polygon.length - 1; i++) {
      if (_rayIntersectsSegment(point, polygon[i], polygon[i + 1])) {
        intersections++;
      }
    }
    return intersections % 2 == 1;
  }

  bool _rayIntersectsSegment(LatLng point, LatLng a, LatLng b) {
    if (a.latitude > b.latitude) {
      var temp = a;
      a = b;
      b = temp;
    }

    if (point.latitude < a.latitude || point.latitude > b.latitude) {
      return false;
    }

    if (point.longitude >=
        (a.longitude > b.longitude ? a.longitude : b.longitude)) {
      return false;
    }

    if (point.longitude <
        (a.longitude < b.longitude ? a.longitude : b.longitude)) {
      return true;
    }

    double slope = (b.latitude - a.latitude) / (b.longitude - a.longitude);
    double intersectX = (point.latitude - a.latitude) / slope + a.longitude;

    return point.longitude < intersectX;
  }

  // Fonction pour trouver le polygone qui contient le point cliqué
  int? _findPolygonContainingPoint(LatLng point) {
    for (int i = 0; i < _originalPolygons.length; i++) {
      if (_isPointInPolygon(point, _originalPolygons[i].points)) {
        return i;
      }
    }
    return null;
  }

  // Fonction pour créer les polygones avec les bonnes couleurs
  List<Polygon> _createPolygons(List<Polygon> originalPolygons) {
    List<Polygon> polygons = [];
    for (int i = 0; i < originalPolygons.length; i++) {
      bool isSelected = false;
      if (_selectedPolygonIndex != null) {
        int selectedFeatureIndex =
            _polygonToFeatureIndex[_selectedPolygonIndex!];
        int currentFeatureIndex = _polygonToFeatureIndex[i];
        isSelected = selectedFeatureIndex == currentFeatureIndex;
      }

      polygons.add(MapConfig.createPolygon(
        points: originalPolygons[i].points,
        isSelected: isSelected,
      ));
    }
    return polygons;
  }

  Future<void> _updateCirconscription() async {
    if (_selectedPolygonIndex == null) {
      setState(() =>
          _error = 'Veuillez sélectionner une circonscription sur la carte');
      return;
    }

    final selectedCirconscription = _circonscriptionData[_selectedPolygonIndex!];
    final selectedName = _circonscriptionNames[_selectedPolygonIndex!];
    
    // Utiliser le nom complet de la circonscription pour la compatibilité
    final circonscriptionToSave = selectedCirconscription['libelle']?.isNotEmpty == true 
        ? selectedCirconscription['libelle'] 
        : selectedName;
    
    try {
      // Mettre à jour dans la base de données
      final success = await _databaseService.updateUserCirconscription(
        widget.user['username'],
        circonscriptionToSave,
        idcirco: selectedCirconscription['id_circo'],
      );

      if (success) {
        // Mettre à jour la session
        await _sessionService.updateUserSession(
          circonscription: circonscriptionToSave,
          idcirco: selectedCirconscription['id_circo'],
        );

        // Appeler le callback
        widget.onUpdate(circonscriptionToSave);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Circonscription mise à jour avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Retourne true pour indiquer que la circonscription a été modifiée
        }
      } else {
        setState(() => _error = 'Erreur lors de la mise à jour de la circonscription');
      }
    } catch (e) {
      setState(() => _error = 'Erreur lors de la mise à jour: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header avec icône de retour
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE8F4F8), Color(0xFFF0F8FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF556B2F),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Modifier ma circonscription',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            // Content - Map takes most of the space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Instructions card (compact)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8FBC8F).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFF8FBC8F).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_rounded,
                            color: Color(0xFF8FBC8F),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cliquez sur la carte pour sélectionner votre circonscription',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF8FBC8F),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Map container - much larger
                    Expanded(
                      flex: 6, // Take most of the remaining space
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: _isLoadingGeoJson
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Color(0xFF556B2F),
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Chargement de la carte...',
                                        style: TextStyle(
                                          color: Color(0xFF666666),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : FlutterMap(
                                  options: MapConfig.defaultMapOptions(
                                    center: _selectedLocation,
                                    zoom: _initialZoom,
                                    onTap: (tapPosition, point) {
                                      setState(() {
                                        _selectedLocation = point;
                                        _selectedPolygonIndex =
                                            _findPolygonContainingPoint(point);
                                        _error = null;
                                      });
                                    },
                                  ),
                                  children: [
                                    MapConfig.defaultTileLayer(),
                                    PolygonLayer(
                                      polygons:
                                          _createPolygons(_circonscriptions),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Bottom section - compact
                    if (_selectedPolygonIndex != null || _error != null) ...[
                      // Selected circonscription info or error
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _error != null
                              ? Colors.red.withOpacity(0.1)
                              : const Color(0xFF8FBC8F).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: _error != null
                                ? Colors.red.withOpacity(0.3)
                                : const Color(0xFF8FBC8F).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _error != null
                                  ? Icons.error_rounded
                                  : Icons.check_circle_rounded,
                              color: _error != null
                                  ? Colors.red
                                  : const Color(0xFF8FBC8F),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error ??
                                    (_selectedPolygonIndex != null
                                        ? 'Circonscription sélectionnée: ${_circonscriptionNames[_selectedPolygonIndex!]}'
                                        : ''),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _error != null
                                      ? Colors.red
                                      : const Color(0xFF8FBC8F),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Action buttons - compact
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF778B77),
                                width: 1.5,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(12),
                                child: const Center(
                                  child: Text(
                                    'Annuler',
                                    style: TextStyle(
                                      color: Color(0xFF778B77),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF556B2F),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF556B2F).withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _updateCirconscription,
                                borderRadius: BorderRadius.circular(12),
                                child: const Center(
                                  child: Text(
                                    'Mettre à jour',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}