import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CirconscriptionMapPage extends StatefulWidget {
  final Function(String idcirco, String dep, String libelle) onCirconscriptionSelected;
  final String? initialIdcirco;

  const CirconscriptionMapPage({
    super.key,
    required this.onCirconscriptionSelected,
    this.initialIdcirco,
  });

  @override
  State<CirconscriptionMapPage> createState() => _CirconscriptionMapPageState();
}

class _CirconscriptionMapPageState extends State<CirconscriptionMapPage> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _circonscriptions = [];
  String? _selectedIdcirco;
  bool _isLoading = true;
  bool _isProcessingTap = false;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _selectedIdcirco = widget.initialIdcirco;
    _loadCirconscriptions();
  }

  Future<void> _loadCirconscriptions() async {
    try {
      final String geojsonString = await rootBundle
          .loadString('data/circomaps/circonscriptions_legislatives_030522.geojson');
      final Map<String, dynamic> geojson = json.decode(geojsonString);
      
      final List<Map<String, dynamic>> circonscriptions = [];
      
      for (var feature in geojson['features']) {
        try {
          final properties = feature['properties'];
          final geometry = feature['geometry'];
          
          // Vérifications de sécurité
          if (properties != null && geometry != null && 
              geometry['coordinates'] != null && 
              (properties['id_circo'] != null || properties['libelle'] != null)) {
            
            circonscriptions.add({
              'id_circo': properties['id_circo']?.toString() ?? '',
              'dep': properties['dep']?.toString() ?? '',
              'libelle': properties['libelle']?.toString() ?? '',
              'geometry': geometry,
            });
          }
        } catch (e) {
          print('Erreur lors du traitement d\'une circonscription: $e');
          // Continuer avec la suivante
        }
      }
      
      // Trier par département puis par libellé
      circonscriptions.sort((a, b) {
        final depCompare = a['dep'].compareTo(b['dep']);
        if (depCompare != 0) return depCompare;
        return a['libelle'].compareTo(b['libelle']);
      });
      
      setState(() {
        _circonscriptions = circonscriptions;
        _isLoading = false;
      });
      
      print('✅ Circonscriptions chargées: ${_circonscriptions.length}');
      print('📊 Exemples de circonscriptions:');
      // Debug: afficher quelques exemples
      if (_circonscriptions.isNotEmpty) {
        print('  • Première: ${_circonscriptions.first['libelle']} (${_circonscriptions.first['id_circo']})');
        if (_circonscriptions.length > 1) {
          print('  • Dernière: ${_circonscriptions.last['libelle']} (${_circonscriptions.last['id_circo']})');
        }
        if (_circonscriptions.length > 10) {
          print('  • Milieu: ${_circonscriptions[_circonscriptions.length ~/ 2]['libelle']} (${_circonscriptions[_circonscriptions.length ~/ 2]['id_circo']})');
        }
      }
      
      // Vérifier le filtrage
      print('👀 Circonscriptions chargées et affichées: ${_circonscriptions.length}');
    } catch (e) {
      print('Erreur lors du chargement des circonscriptions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Polygon> _createPolygons(Map<String, dynamic> geometry, Color color, String idCirco) {
    List<Polygon> polygons = [];
    
    try {
      // Vérifications de sécurité
      if (geometry['coordinates'] == null) {
        return polygons;
      }
      
      if (geometry['type'] == 'Polygon') {
        final coords = geometry['coordinates'];
        if (coords is List && coords.isNotEmpty && coords[0] is List) {
          final coordinates = coords[0] as List;
          List<LatLng> points = _extractSafePoints(coordinates);
          
          if (points.length >= 3) {
            polygons.add(Polygon(
              points: points,
              color: color.withOpacity(0.2),
              borderColor: color,
              borderStrokeWidth: 1.5,
              isFilled: true,
            ));
          }
        }
      } else if (geometry['type'] == 'MultiPolygon') {
        final coords = geometry['coordinates'];
        if (coords is List) {
          for (var polygon in coords) {
            if (polygon is List && polygon.isNotEmpty && polygon[0] is List) {
              final coordinates = polygon[0] as List;
              List<LatLng> points = _extractSafePoints(coordinates);
              
              if (points.length >= 3) {
                polygons.add(Polygon(
                  points: points,
                  color: color.withOpacity(0.2),
                  borderColor: color,
                  borderStrokeWidth: 1.5,
                  isFilled: true,
                ));
              }
            }
          }
        }
      }
    } catch (e) {
      print('Erreur lors de la création des polygones pour $idCirco: $e');
    }
    
    return polygons;
  }

  List<LatLng> _extractSafePoints(List coordinates) {
    List<LatLng> points = [];
    
    try {
      // Simplification modérée pour éviter les crashes tout en gardant la précision
      int step = coordinates.length > 1000 ? 4 : (coordinates.length > 500 ? 3 : (coordinates.length > 200 ? 2 : 1));
      
      for (int i = 0; i < coordinates.length; i += step) {
        var coord = coordinates[i];
        if (coord is List && coord.length >= 2) {
          final lat = coord[1];
          final lng = coord[0];
          
          // Vérifier que les coordonnées sont valides
          if (lat is num && lng is num && 
              lat.isFinite && lng.isFinite &&
              lat >= -90 && lat <= 90 && 
              lng >= -180 && lng <= 180) {
            points.add(LatLng(lat.toDouble(), lng.toDouble()));
          }
        }
      }
    } catch (e) {
      print('Erreur lors de l\'extraction des points: $e');
    }
    
    return points;
  }

  void _onPolygonTapped(Map<String, dynamic> circonscription, LatLng tapPosition) {
    _showCirconscriptionDialog(circonscription);
  }

  void _showCirconscriptionDialog(Map<String, dynamic> circonscription) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.location_on,
                color: Color(0xFF556B2F),
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Circonscription sélectionnée',
                  style: const TextStyle(
                    color: Color(0xFF556B2F),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                circonscription['libelle'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Département: ${circonscription['dep']}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Code circonscription: ${circonscription['id_circo']}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Annuler',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                widget.onCirconscriptionSelected(
                  circonscription['id_circo'],
                  circonscription['dep'],
                  circonscription['libelle'],
                );
                Navigator.of(context).pop(); // Fermer le dialog
                Navigator.of(context).pop(); // Retourner à la page login
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF556B2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Valider',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Choisir votre circonscription',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF556B2F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF556B2F),
              ),
            )
          : Column(
              children: [
                // Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF556B2F).withOpacity(0.1),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.touch_app,
                        color: Color(0xFF556B2F),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cliquez sur votre circonscription sur la carte',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Carte plein écran
                Expanded(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(46.603354, 1.888334),
                      initialZoom: 6,
                      minZoom: 5,
                      maxZoom: 9, // Limité pour éviter les crashes
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.doubleTapZoom,
                        pinchZoomThreshold: 0.3,
                        pinchMoveThreshold: 40.0,
                        scrollWheelVelocity: 0.005,
                      ),
                      onTap: (tapPosition, point) async {
                        // Protections contre les crashes
                        if (!point.latitude.isFinite || !point.longitude.isFinite) {
                          return;
                        }
                        
                        // Debounce pour éviter les multiples clics rapides
                        final now = DateTime.now();
                        if (_isProcessingTap || 
                            (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds < 500)) {
                          return;
                        }
                        
                        _lastTapTime = now;
                        _isProcessingTap = true;
                        
                        try {
                          // Chercher quelle circonscription a été cliquée avec timeout
                          Map<String, dynamic>? foundCirco;
                          
                          // Limiter la recherche à un temps raisonnable
                          await Future.microtask(() {
                            for (var circo in _circonscriptions) {
                              try {
                                if (_isPointInCirconscription(point, circo['geometry'])) {
                                  foundCirco = circo;
                                  break;
                                }
                              } catch (e) {
                                // Ignorer cette circonscription et continuer
                                continue;
                              }
                            }
                          }).timeout(const Duration(seconds: 2), onTimeout: () {
                            print('Timeout lors de la recherche de circonscription');
                          });
                          
                          // Si pas trouvé, essayer la détection par proximité
                          if (foundCirco == null) {
                            double minDistance = double.infinity;
                            for (var circo in _circonscriptions) {
                              double distance = _calculateDistanceToCirconscription(point, circo['geometry']);
                              if (distance < minDistance && distance < 0.2) { // Seuil plus permissif
                                minDistance = distance;
                                foundCirco = circo;
                              }
                            }
                          }
                          
                          // Si on a trouvé une circonscription
                          if (foundCirco != null) {
                            _onPolygonTapped(foundCirco!, point);
                          }
                        } catch (e) {
                          print('Erreur lors du clic: $e');
                        } finally {
                          _isProcessingTap = false;
                        }
                      },
                    ),
                    children: [
                      // Couche de tuiles OpenStreetMap optimisée
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.agorapush.app',
                        maxNativeZoom: 18,
                        maxZoom: 9,
                        keepBuffer: 2, // Réduire le buffer des tuiles
                        backgroundColor: Colors.grey[200]!,
                      ),
                      
                      // Couche des polygones des circonscriptions
                      PolygonLayer(
                        polygons: [
                          // Afficher toutes les circonscriptions avec protection mémoire
                          for (var circo in _circonscriptions.where((c) => 
                            c['geometry'] != null && c['geometry']['coordinates'] != null))
                            ..._createPolygons(
                              circo['geometry'],
                              circo['id_circo'] == _selectedIdcirco
                                  ? const Color(0xFF556B2F)
                                  : const Color(0xFF2196F3),
                              circo['id_circo'],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  bool _isPointInCirconscription(LatLng point, Map<String, dynamic> geometry) {
    try {
      // Vérifications de sécurité
      if (geometry['coordinates'] == null || 
          !point.latitude.isFinite || !point.longitude.isFinite) {
        return false;
      }
      
      if (geometry['type'] == 'Polygon') {
        final coords = geometry['coordinates'];
        if (coords is List && coords.isNotEmpty && coords[0] is List) {
          final coordinates = coords[0] as List;
          return _isPointInPolygonSafe(point, coordinates);
        }
      } else if (geometry['type'] == 'MultiPolygon') {
        final coords = geometry['coordinates'];
        if (coords is List) {
          // Vérifier tous les polygones
          for (var polygon in coords) {
            if (polygon is List && polygon.isNotEmpty && polygon[0] is List) {
              final coordinates = polygon[0] as List;
              if (_isPointInPolygonSafe(point, coordinates)) {
                return true;
              }
            }
          }
        }
      }
    } catch (e) {
      print('Erreur lors de la détection de point: $e');
    }
    return false;
  }

  bool _isPointInPolygonSafe(LatLng point, List coordinates) {
    try {
      // Vérifications de sécurité
      if (coordinates.length < 3) return false;
      
      bool inside = false;
      int j = coordinates.length - 1;
      
      for (int i = 0; i < coordinates.length; i++) {
        final coordI = coordinates[i];
        final coordJ = coordinates[j];
        
        // Vérifier que les coordonnées sont valides
        if (coordI is! List || coordJ is! List || 
            coordI.length < 2 || coordJ.length < 2) {
          j = i;
          continue;
        }
        
        final yi = coordI[1];
        final xi = coordI[0];
        final yj = coordJ[1];
        final xj = coordJ[0];
        
        // Vérifier que les valeurs sont des nombres valides
        if (yi is! num || xi is! num || yj is! num || xj is! num ||
            !yi.isFinite || !xi.isFinite || !yj.isFinite || !xj.isFinite) {
          j = i;
          continue;
        }
        
        // Algorithme ray casting sécurisé
        if (((yi > point.latitude) != (yj > point.latitude)) &&
            (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)) {
          inside = !inside;
        }
        j = i;
      }
      
      return inside;
    } catch (e) {
      print('Erreur dans _isPointInPolygonSafe: $e');
      return false;
    }
  }

  double _calculateDistanceToCirconscription(LatLng point, Map<String, dynamic> geometry) {
    try {
      // Version optimisée qui calcule seulement le centroïde approximatif
      if (geometry['type'] == 'Polygon') {
        final coordinates = geometry['coordinates'][0] as List;
        return _fastDistanceToCentroid(point, coordinates);
      } else if (geometry['type'] == 'MultiPolygon') {
        // Prendre seulement le premier polygone pour les performances
        if (geometry['coordinates'].isNotEmpty) {
          final coordinates = geometry['coordinates'][0][0] as List;
          return _fastDistanceToCentroid(point, coordinates);
        }
      }
    } catch (e) {
      return double.infinity;
    }
    return double.infinity;
  }

  double _fastDistanceToCentroid(LatLng point, List coordinates) {
    if (coordinates.isEmpty) return double.infinity;
    
    try {
      // Prendre seulement quelques points pour calculer un centroïde approximatif
      double sumLat = 0, sumLng = 0;
      int count = 0;
      int step = coordinates.length > 100 ? 10 : 5; // Échantillonnage
      
      for (int i = 0; i < coordinates.length; i += step) {
        var coord = coordinates[i];
        if (coord is List && coord.length >= 2) {
          sumLng += coord[0];
          sumLat += coord[1];
          count++;
        }
        if (count >= 10) break; // Limiter à 10 points max
      }
      
      if (count > 0) {
        double centroidLat = sumLat / count;
        double centroidLng = sumLng / count;
        
        // Distance euclidienne simple
        double deltaLat = point.latitude - centroidLat;
        double deltaLng = point.longitude - centroidLng;
        return (deltaLat * deltaLat + deltaLng * deltaLng).abs();
      }
    } catch (e) {
      return double.infinity;
    }
    
    return double.infinity;
  }
}