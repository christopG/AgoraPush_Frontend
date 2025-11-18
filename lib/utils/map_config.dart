import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Configuration optimisée pour FlutterMap
/// Réduit les erreurs réseau et améliore les performances
class MapConfig {
  static const int maxZoom = 15;
  static const int minZoom = 6;
  static const int maxNativeZoom = 19;
  
  /// Options par défaut pour la carte
  static MapOptions defaultMapOptions({
    required LatLng center,
    required double zoom,
    required Function(TapPosition, LatLng) onTap,
  }) {
    return MapOptions(
      initialCenter: center,
      initialZoom: zoom,
      minZoom: minZoom.toDouble(),
      maxZoom: maxZoom.toDouble(),
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        enableScrollWheel: true,
        scrollWheelVelocity: 0.005,
      ),
      onTap: onTap,
    );
  }

  /// Configuration TileLayer optimisée pour réduire les erreurs réseau
  static TileLayer defaultTileLayer() {
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.agorapush',
      maxZoom: maxZoom.toDouble(),
      minZoom: minZoom.toDouble(),
      maxNativeZoom: maxNativeZoom,
      // Configuration pour réduire les erreurs réseau
      panBuffer: 1, // Réduit le nombre de tiles chargées
      keepBuffer: 2, // Garde moins de tiles en mémoire
    );
  }

  /// Couleurs pour les circonscriptions
  static const Color unselectedColor = Color(0xFF8FBC8F);
  static const Color selectedColor = Color(0xFF556B2F);
  static const Color borderColor = Color(0xFF556B2F);
  
  /// Styles pour les polygones
  static Polygon createPolygon({
    required List<LatLng> points,
    required bool isSelected,
  }) {
    return Polygon(
      points: points,
      color: isSelected 
          ? selectedColor.withOpacity(0.6)
          : unselectedColor.withOpacity(0.3),
      borderColor: isSelected
          ? borderColor.withOpacity(1.0)
          : borderColor.withOpacity(0.7),
      borderStrokeWidth: isSelected ? 3.0 : 2.0,
    );
  }
}