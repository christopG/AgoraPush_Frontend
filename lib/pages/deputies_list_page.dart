import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' as math;
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
  bool _isSearching = false;
  bool _isLoadingAllDeputies = false;

  // Variables pour la carte
  List<Polygon> _circonscriptions = [];
  List<Map<String, dynamic>> _circonscriptionData = [];
  bool _isLoadingGeoJson = true;
  final LatLng _mapCenter =
      const LatLng(46.603354, 1.888334); // Centre de la France
  final double _mapZoom = 6.0;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusChange);
    _loadInitialData();
    _loadGeoJsonData();
    _loadAllDeputies();
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

  Future<void> _loadGeoJsonData() async {
    try {
      final String geoJsonString = await rootBundle.loadString(
        'data/circomaps/circonscriptions_legislatives_030522.geojson',
      );
      final Map<String, dynamic> geoJson = json.decode(geoJsonString);

      List<Polygon> polygons = [];
      List<Map<String, dynamic>> circonscriptionData = [];

      Color parseColor(String? hexColor, {double opacity = 0.3}) {
        if (hexColor == null || hexColor.isEmpty) {
          return Colors.grey.withOpacity(opacity); // fallback
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

      for (int featureIndex = 0;
          featureIndex < geoJson['features'].length;
          featureIndex++) {
        var feature = geoJson['features'][featureIndex];

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
            for (var coord in coordinates) {
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
                  borderStrokeWidth: 2.0,
                ),
              );
              circonscriptionData.add(circonscriptionInfo);
            }
          }
        } else if (feature['geometry']['type'] == 'MultiPolygon') {
          for (var polygon in feature['geometry']['coordinates']) {
            List<LatLng> points = [];
            var coordinates = polygon[0];

            if (coordinates != null && coordinates.isNotEmpty) {
              for (var coord in coordinates) {
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
                    borderStrokeWidth: 2.0,
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

  /// Charge tous les députés triés par ordre alphabétique
  Future<void> _loadAllDeputies() async {
    setState(() {
      _isLoadingAllDeputies = true;
    });

    try {
      await deputyProvider.loadAllDeputies();
      final allDeputies = deputyProvider.deputies;

      // Trier par ordre alphabétique (nom + prénom)
      allDeputies.sort((a, b) => a.fullName.compareTo(b.fullName));

      if (mounted) {
        setState(() {
          _allDeputies = allDeputies;
          _searchResults = allDeputies; // Afficher tous les députés par défaut
          _isLoadingAllDeputies = false;
        });
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
          deputyProvider.loadDeputiesByGroup();
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
                          _isSearching = false;
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
                                _loadAllDeputies();
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
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
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF556B2F).withOpacity(0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      _getDeputyPhotoUrl(deputy.id),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF556B2F).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.person,
                            size: 32,
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
                        deputy.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: Color(0xFF556B2F),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (deputy.famillePolLibelle != null &&
                          deputy.famillePolLibelle!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF556B2F).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            deputy.famillePolLibelle!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF556B2F).withOpacity(0.8),
                            ),
                          ),
                        ),
                      Text(
                        deputy.circonscriptionComplete,
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF556B2F).withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Flèche moderne
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF556B2F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: const Color(0xFF556B2F).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
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
              child: FlutterMap(
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
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGroupsView() {
    final deputiesByGroup = deputyProvider.deputiesByGroup;
    final loading = deputyProvider.loading;
    final error = deputyProvider.error;

    if (loading) {
      return Center(
        child: Container(
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
      );
    }

    if (error != null) {
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
                  deputyProvider.loadDeputiesByGroup();
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
      return Center(
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
                  Icons.group_off,
                  size: 40,
                  color: const Color(0xFF556B2F).withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Aucune donnée de groupe disponible',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF556B2F).withOpacity(0.8),
                ),
              ),
            ],
          ),
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

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ExpansionTile(
            title: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF556B2F),
                        Color(0xFF6B8E3E),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
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
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF556B2F).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${deputies.length} député${deputies.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF556B2F).withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            children: deputies.map((deputy) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF556B2F).withOpacity(0.1),
                  backgroundImage: NetworkImage(_getDeputyPhotoUrl(deputy.id)),
                  onBackgroundImageError: (_, __) {},
                  child: Icon(
                    Icons.person,
                    color: const Color(0xFF556B2F).withOpacity(0.6),
                  ),
                ),
                title: Text(
                  deputy.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF556B2F),
                  ),
                ),
                subtitle: Text(
                  deputy.circonscriptionComplete,
                  style: TextStyle(
                    color: const Color(0xFF556B2F).withOpacity(0.7),
                  ),
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
            }).toList(),
          ),
        );
      },
    );
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = _allDeputies;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final filteredDeputies = _allDeputies.where((deputy) {
      final fullName = deputy.fullName.toLowerCase();
      final searchQuery = query.toLowerCase();
      return fullName.contains(searchQuery);
    }).toList();

    setState(() {
      _searchResults = filteredDeputies;
      _isSearching = false;
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
        // Députe trouvé, naviguer vers sa page de détail
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeputyDetailPage(deputy: foundDeputy!),
          ),
        );
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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }
}