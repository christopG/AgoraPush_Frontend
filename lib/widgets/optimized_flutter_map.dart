import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Widget wrapper pour FlutterMap avec gestion d'erreurs améliorée
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

class _OptimizedFlutterMapState extends State<OptimizedFlutterMap> {
  bool _hasNetworkError = false;

  @override
  void initState() {
    super.initState();
    
    // Écouter les erreurs Flutter globalement si nécessaire
    FlutterError.onError = (FlutterErrorDetails details) {
      // Vérifier si c'est une erreur réseau liée aux tiles
      if (details.exception.toString().contains('tile.openstreetmap.org') ||
          details.exception.toString().contains('ClientException') ||
          details.exception.toString().contains('SocketException')) {
        setState(() {
          _hasNetworkError = true;
        });
        // Ne pas loguer ces erreurs pour réduire le spam
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
        FlutterMap(
          options: widget.options,
          children: widget.children,
        ),
        if (_hasNetworkError && widget.showErrorMessage)
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Connexion réseau lente - La carte peut prendre du temps à charger',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
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
                      size: 16,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    // Remettre le handler d'erreur par défaut
    FlutterError.onError = FlutterError.dumpErrorToConsole;
    super.dispose();
  }
}