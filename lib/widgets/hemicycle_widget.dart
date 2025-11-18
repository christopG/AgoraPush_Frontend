import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HemicycleWidget extends StatefulWidget {
  final String? placeHemicycle;
  final String? groupeAbrev;
  final String? famillePolLibelle;

  const HemicycleWidget({
    super.key,
    this.placeHemicycle,
    this.groupeAbrev,
    this.famillePolLibelle,
  });

  @override
  State<HemicycleWidget> createState() => _HemicycleWidgetState();
}

class _HemicycleWidgetState extends State<HemicycleWidget> {
  String? _modifiedSvgContent;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAndModifySvg();
  }

  Future<void> _loadAndModifySvg() async {
    try {
      // Charger le contenu du SVG
      final svgContent = await rootBundle.loadString('data/hemicycle-an.svg');
      
      // Modifier la couleur du siège du député si place_hemicycle est fourni
      String modifiedContent = svgContent;
      
      if (widget.placeHemicycle != null && widget.placeHemicycle!.isNotEmpty) {
        final deputyColor = _getGroupeColor(widget.famillePolLibelle ?? widget.groupeAbrev ?? '');
        final colorHex = '#${deputyColor.value.toRadixString(16).substring(2)}';
        
        // Remplacer la couleur du path correspondant à la place du député
        final placePattern = RegExp(r'<path[^>]*place="' + RegExp.escape(widget.placeHemicycle!) + r'"[^>]*>');
        modifiedContent = modifiedContent.replaceAllMapped(placePattern, (match) {
          final pathElement = match.group(0)!;
          // Remplacer fill="#cbcbcb" par la couleur du groupe politique
          return pathElement.replaceFirst(RegExp(r'fill="[^"]*"'), 'fill="$colorHex"');
        });
      }
      
      setState(() {
        _modifiedSvgContent = modifiedContent;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement du SVG: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getGroupeColor(String? groupe) {
    if (groupe == null || groupe.isEmpty) {
      return const Color(0xFF64748B); // Gris par défaut
    }

    // Couleurs basées sur les groupes politiques français
    switch (groupe.toUpperCase()) {
      case 'RN':
        return const Color(0xFF1F2937); // Bleu très foncé
      case 'LR':
        return const Color(0xFF1E40AF); // Bleu
      case 'DEM':
      case 'RE':
      case 'MODEM':
        return const Color(0xFFF59E0B); // Orange/Jaune
      case 'SOC':
      case 'PS':
        return const Color(0xFFDC2626); // Rouge
      case 'LFI':
      case 'GDR':
        return const Color(0xFF991B1B); // Rouge foncé
      case 'ECOLO':
      case 'EELV':
        return const Color(0xFF059669); // Vert
      case 'UDI':
        return const Color(0xFF7C3AED); // Violet
      case 'LIOT':
        return const Color(0xFF0891B2); // Cyan
      case 'HOR':
        return const Color(0xFF9333EA); // Violet clair
      default:
        return const Color(0xFF64748B); // Gris par défaut
    }
  }

  Widget _buildCustomHemicycle() {
    return CustomPaint(
      size: const Size(280, 160),
      painter: HemicyclePainter(
        placeHemicycle: widget.placeHemicycle,
        groupeColor: _getGroupeColor(widget.famillePolLibelle ?? widget.groupeAbrev),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Titre de la section
          Row(
            children: [
              Icon(
                Icons.account_balance_outlined,
                size: 18,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Place dans l\'hémicycle',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Affichage de l'hémicycle
          Container(
            height: 160,
            width: 280,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _isLoading 
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _modifiedSvgContent != null
                  ? SvgPicture.string(
                      _modifiedSvgContent!,
                      fit: BoxFit.contain,
                      placeholderBuilder: (context) => _buildCustomHemicycle(),
                    )
                  : _buildCustomHemicycle(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Informations sur la place
          if (widget.placeHemicycle != null && widget.placeHemicycle!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getGroupeColor(widget.famillePolLibelle ?? widget.groupeAbrev).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getGroupeColor(widget.famillePolLibelle ?? widget.groupeAbrev).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getGroupeColor(widget.famillePolLibelle ?? widget.groupeAbrev),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Place n°${widget.placeHemicycle}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 12),

        ],
      ),
    );
  }
}

class HemicyclePainter extends CustomPainter {
  final String? placeHemicycle;
  final Color groupeColor;

  HemicyclePainter({
    this.placeHemicycle,
    required this.groupeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height * 0.75);
    
    // Dessiner les rangées de l'hémicycle
    for (int i = 1; i <= 5; i++) {
      final radius = size.width * 0.15 * i;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        math.pi,
        false,
        paint,
      );
    }
    
    // Dessiner la place du député si fournie
    if (placeHemicycle != null && placeHemicycle!.isNotEmpty) {
      final position = _calculatePosition(placeHemicycle!);
      final deputyPosition = Offset(
        position['x']! * size.width,
        position['y']! * size.height,
      );
      
      final deputyPaint = Paint()
        ..color = groupeColor
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(deputyPosition, 4, deputyPaint);
      
      // Cercle de highlight
      final highlightPaint = Paint()
        ..color = groupeColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      canvas.drawCircle(deputyPosition, 8, highlightPaint);
    }
  }

  Map<String, double> _calculatePosition(String place) {
    try {
      final placeNum = int.tryParse(place);
      
      if (placeNum != null) {
        // Mapping approximatif basé sur l'analyse du SVG hemicycle-an.svg
        if (placeNum >= 1 && placeNum <= 100) {
          final seatInRow = (placeNum - 1) % 50;
          final angle = math.pi * (seatInRow / 49.0);
          final radius = 0.3;
          
          final x = 0.5 + radius * math.cos(math.pi - angle);
          final y = 0.75 - radius * math.sin(math.pi - angle);
          
          return {'x': x.clamp(0.1, 0.9), 'y': y.clamp(0.2, 0.9)};
          
        } else if (placeNum >= 101 && placeNum <= 250) {
          final seatInRow = (placeNum - 101) % 75;
          final angle = math.pi * (seatInRow / 74.0);
          final radius = 0.45;
          
          final x = 0.5 + radius * math.cos(math.pi - angle);
          final y = 0.75 - radius * math.sin(math.pi - angle);
          
          return {'x': x.clamp(0.05, 0.95), 'y': y.clamp(0.15, 0.9)};
          
        } else if (placeNum >= 251 && placeNum <= 400) {
          final seatInRow = (placeNum - 251) % 75;
          final angle = math.pi * (seatInRow / 74.0);
          final radius = 0.6;
          
          final x = 0.5 + radius * math.cos(math.pi - angle);
          final y = 0.75 - radius * math.sin(math.pi - angle);
          
          return {'x': x.clamp(0.02, 0.98), 'y': y.clamp(0.1, 0.9)};
          
        } else if (placeNum >= 401 && placeNum <= 577) {
          final seatInRow = (placeNum - 401) % 88;
          final angle = math.pi * (seatInRow / 87.0);
          final radius = 0.75;
          
          final x = 0.5 + radius * math.cos(math.pi - angle);
          final y = 0.75 - radius * math.sin(math.pi - angle);
          
          return {'x': x.clamp(0.0, 1.0), 'y': y.clamp(0.05, 0.9)};
        }
      }
    } catch (e) {
      // En cas d'erreur, retourner une position par défaut
    }
    
    // Position par défaut au centre de l'hémicycle
    return {'x': 0.5, 'y': 0.6};
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! HemicyclePainter ||
        oldDelegate.placeHemicycle != placeHemicycle ||
        oldDelegate.groupeColor != groupeColor;
  }
}