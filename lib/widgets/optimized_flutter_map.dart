import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Widget wrapper pour FlutterMap avec optimisations de performance
class OptimizedFlutterMap extends StatefulWidget {
  final MapOptions options;
  final List<Widget> children;
  final bool showErrorMessage;

  const OptimizedFlutterMap({
    super.key,
    required this.options,
    required this.children,
    this.showErrorMessage = false,
  });

  @override
  State<OptimizedFlutterMap> createState() => _OptimizedFlutterMapState();
}

class _OptimizedFlutterMapState extends State<OptimizedFlutterMap> with TickerProviderStateMixin {
  bool _hasNetworkError = false;
  late MapController _mapController;
  late final AnimationController _loadingController;

  @override
  void initState() {
    super.initState();
    
    _mapController = MapController();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    // Optimisation : désactiver les erreurs de tiles pour éviter le spam
    FlutterError.onError = (FlutterErrorDetails details) {
      // Filtrer les erreurs réseau liées aux tiles de carte
      final errorMessage = details.exception.toString().toLowerCase();
      if (errorMessage.contains('tile.openstreetmap.org') ||
          errorMessage.contains('clientexception') ||
          errorMessage.contains('socketexception') ||
          errorMessage.contains('failed to load network image') ||
          errorMessage.contains('http')) {
        
        // Marquer l'erreur réseau mais ne pas crasher
        if (mounted) {
          setState(() {
            _hasNetworkError = true;
          });
        }
        return;
      }
      
      // Pour les autres erreurs, utiliser le handler par défaut
      FlutterError.dumpErrorToConsole(details);
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Carte optimisée
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            // Reprendre les options originales
            initialCenter: widget.options.initialCenter,
            initialZoom: widget.options.initialZoom,
            
            // Optimisations de performance
            interactiveFlags: InteractiveFlag.all,
            
            // Limiter le zoom pour éviter de charger trop de tiles
            maxZoom: 18.0,
            minZoom: 5.0,
            
            // Optimisation : keepAlive des tiles
            keepAlive: true,
            
            // Copier les autres callbacks
            onMapReady: () {
              if (mounted) {
                setState(() {
                  _hasNetworkError = false;
                });
              }
              // Appeler le callback original s'il existe
              widget.options.onMapReady?.call();
            },
            
            onTap: widget.options.onTap,
            onLongPress: widget.options.onLongPress,
            onPositionChanged: widget.options.onPositionChanged,
          ),
          children: [
            // Tiles avec configuration optimisée
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.agorapush.app',
              
              // Optimisations réseau
              maxZoom: 18,
              
              // Optimisations de rendu
              keepBuffer: 2,
              panBuffer: 2,
              
              // Réduire la qualité sur les connexions lentes
              retinaMode: false,
              
              // Headers dans additionalOptions
              additionalOptions: const {
                'User-Agent': 'AgoraPush Mobile App',
              },
            ),
            
            // Ajouter les autres layers
            ...widget.children,
          ],
        ),
        
        // Indicateur de chargement
        if (_hasNetworkError)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildNetworkErrorBanner(),
          ),
          
        // Loading indicator pour le premier chargement
        if (_hasNetworkError)
          Center(
            child: _buildLoadingIndicator(),
          ),
      ],
    );
  }

  Widget _buildNetworkErrorBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          RotationTransition(
            turns: _loadingController,
            child: const Icon(
              Icons.refresh,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Chargement de la carte...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'La connexion est lente, veuillez patienter',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _hasNetworkError = false;
              });
            },
            icon: const Icon(
              Icons.close,
              color: Colors.white,
              size: 18,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _loadingController,
            child: const Icon(
              Icons.map_outlined,
              color: Color(0xFF556B2F),
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Initialisation de la carte...',
            style: TextStyle(
              color: Color(0xFF556B2F),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Méthode pour centrer la carte sur une position
  void centerOn(LatLng position, {double zoom = 13.0}) {
    _mapController.move(position, zoom);
  }

  /// Méthode pour ajuster la vue sur des bornes
  void fitBounds(LatLngBounds bounds, {EdgeInsets? padding}) {
    _mapController.fitBounds(
      bounds,
      options: FitBoundsOptions(
        padding: padding ?? const EdgeInsets.all(20),
        maxZoom: 15.0,
      ),
    );
  }

  @override
  void dispose() {
    _loadingController.dispose();
    // Remettre le handler d'erreur par défaut si nécessaire
    super.dispose();
  }
}