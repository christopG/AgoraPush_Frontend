import 'package:flutter/material.dart';

class TabIndicationPainter extends CustomPainter {
  final PageController pageController;

  TabIndicationPainter({required this.pageController}) : super(repaint: pageController);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Créer un indicateur de tab arrondi
    final double tabWidth = size.width / 2;
    final double tabHeight = size.height;
    
    // Position basée sur le pageController si disponible
    double offset = 0.0;
    if (pageController.hasClients && pageController.position.hasContentDimensions) {
      // Utiliser la position actuelle de la page pour l'animation fluide
      final double page = pageController.page ?? pageController.initialPage.toDouble();
      offset = page;
    }
    
    final double indicatorLeft = offset * tabWidth;
    
    path.addRRect(
      RRect.fromLTRBR(
        indicatorLeft + 4,
        4,
        indicatorLeft + tabWidth - 4,
        tabHeight - 4,
        const Radius.circular(20),
      ),
    );
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TabIndicationPainter oldDelegate) {
    return oldDelegate.pageController != pageController;
  }
}