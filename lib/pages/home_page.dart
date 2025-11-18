import 'package:flutter/material.dart';
import 'account_page.dart';
import 'my_stats_page.dart';
import 'deputies_list_page.dart';
import 'my_deputy_page.dart';
import 'old_votes_page.dart';
import '../services/api_service.dart';

// CustomPainter pour créer une vague décorative
class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();

    // Créer une vague subtile
    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.3,
      size.width * 0.5,
      size.height * 0.6,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.9,
      size.width,
      size.height * 0.5,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Ajouter une deuxième vague plus subtile
    final paint2 = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.5);
    path2.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.1,
      size.width * 0.6,
      size.height * 0.4,
    );
    path2.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.7,
      size.width,
      size.height * 0.3,
    );
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int? deputiesCount; // Variable pour stocker le nombre de députés

  @override
  void initState() {
    super.initState();
    _loadDeputiesCount(); // Charger le nombre de députés au démarrage
  }

  // Méthode pour charger le nombre de députés depuis le backend
  Future<void> _loadDeputiesCount() async {
    try {
      final count = await ApiService.getDeputiesCount();
      if (count != null && mounted) {
        setState(() {
          deputiesCount = count;
        });
      } else if (mounted) {
        setState(() {
          deputiesCount = 577; // Valeur par défaut
        });
      }
    } catch (e) {
      print('Erreur lors du chargement du nombre de députés: $e');
      // En cas d'erreur, on garde la valeur par défaut
      if (mounted) {
        setState(() {
          deputiesCount = 577;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header avec profil et navigation
            SliverToBoxAdapter(
              child: _buildHeader(context),
            ),

            // Grid de cartes avec les 4 tuiles
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              sliver: SliverToBoxAdapter(
                child: _buildMainGrid(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid 2x2 style Art1Gallery - Toutes les cartes même taille (largeur ET hauteur)
        Column(
          children: [
            // Première ligne
            Row(
              children: [
                // Mes statistiques - Formes en haut au centre
                Expanded(
                  child: _buildArt1CategoryCard(
                    'Mes\nstatistiques',
                    Icons.analytics_outlined,
                    const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8FBC8F), Color(0xFF6B8E6B)],
                    ),
                    160,
                    'top-center',
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MyStatsPage())),
                  ),
                ),
                const SizedBox(width: 15),
                // Députés - Formes en haut à gauche
                Expanded(
                  child: _buildDeputiesCard(),
                ),
              ],
            ),
            const SizedBox(height: 15),
            // Deuxième ligne
            Row(
              children: [
                // Mon député - Formes en bas à gauche
                Expanded(
                  child: _buildMyDeputyCard(),
                ),
                const SizedBox(width: 15),
                // Anciens votes - Carte améliorée
                Expanded(
                  child: _buildLatestVotesCard(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildArt1CategoryCard(
      String title,
      IconData icon,
      LinearGradient gradient,
      double height,
      String shapePosition,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Container principal de la carte
          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Vague décorative en arrière-plan (seulement pour top-center)
                if (shapePosition == 'top-center')
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SizedBox(
                      height: 40,
                      child: CustomPaint(
                        painter: WavePainter(),
                      ),
                    ),
                  ),

                // Contenu principal avec padding
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Icône en haut à gauche
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),

                      // Titre en bas
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Formes décoratives positionnées par rapport au bord extérieur de la carte
          ..._buildShapes(shapePosition),
        ],
      ),
    );
  }

  List<Widget> _buildShapes(String position) {
    switch (position) {
      case 'top-center':
        return [
          // Grande forme au milieu du bord haut - vraiment au bord de la carte
          Positioned(
            left: 50, // Position approximative au centre
            top: -30, // Sortant du vrai bord supérieur de la carte
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          // Forme moyenne à droite
          Positioned(
            left: 85,
            top: -20, // Plus proche du bord
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          // Petite forme à gauche
          Positioned(
            left: 15,
            top: -15, // Plus proche du bord
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12.5),
              ),
            ),
          ),
        ];
      case 'left-two-thirds':
        return [
          // Grande forme sur le bord droit à 2/3 de la hauteur (taille doublée)
          Positioned(
            right: -70, // Sortant du bord droit
            top: 160 * 2 / 3 -
                70, // 2/3 de la hauteur (160px) moins la moitié de la forme pour centrer
            child: Container(
              width: 140, // Taille doublée (70 * 2)
              height: 140, // Taille doublée (70 * 2)
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(70), // Rayon doublé
              ),
            ),
          ),
          // Forme moyenne à côté
          Positioned(
            right: -40, // Moins sortante du bord
            top: 160 * 2 / 3 -
                40, // Même position verticale, centrée sur sa hauteur
            child: Container(
              width: 80, // Taille doublée (40 * 2)
              height: 80, // Taille doublée (40 * 2)
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(40), // Rayon doublé
              ),
            ),
          ),
        ];
      case 'bottom-left-partial':
        return [
          // Grande forme partiellement sur le bord droit en bas
          Positioned(
            right: -25, // Partiellement sortante du bord droit
            bottom: -25, // Partiellement sortante du bord bas
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(35),
              ),
            ),
          ),
          // Forme moyenne entièrement dans la carte
          Positioned(
            right: 30, // Bien à l'intérieur de la carte (côté droit)
            bottom: 15, // Légèrement au-dessus du bord
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
          // Petite forme entièrement dans la carte
          Positioned(
            right: 70, // Plus vers le centre (côté droit)
            bottom: 30, // Plus haut que les autres
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ];
      case 'bottom-right':
        return [
          // Grande forme collée au coin bas-droit
          Positioned(
            right: -25,
            bottom: -25,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(35),
              ),
            ),
          ),
          // Forme moyenne
          Positioned(
            right: 5,
            bottom: 5,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ];
      default:
        return [];
    }
  }

  Widget _buildMyDeputyCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MyDeputyPage()),
      ),
      child: Stack(
        children: [
          // Container principal de la carte
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF556B2F), Color(0xFF3A4A1F)],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icône par défaut
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.how_to_vote_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),

                  // Titre
                  const Text(
                    'Mon député',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Formes décoratives positionnées par rapport au bord extérieur de la carte
          ..._buildShapes('left-two-thirds'),
        ],
      ),
    );
  }

  Widget _buildDeputiesCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DeputiesListPage()),
      ),
      child: Stack(
        children: [
          // Container principal de la carte
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF778B77), Color(0xFF556B55)],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Row avec icône principale et badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Icône principale
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),

                      // Badge avec le nombre de députés
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: deputiesCount != null
                            ? Text(
                                '$deputiesCount',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),

                  // Titre
                  const Text(
                    'Liste des députés',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Formes décoratives positionnées par rapport au bord extérieur de la carte
          ..._buildShapes('bottom-left-partial'),
        ],
      ),
    );
  }

  Widget _buildLatestVotesCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const OldVotesPage()),
      ),
      child: Stack(
        children: [
          // Container principal de la carte
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFDEB887), Color(0xFFCD853F)],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icône principale en haut à gauche avec badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.ballot_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),

                      // Colonnes de badges à droite
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Badge Loi avec le nombre
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'Loi : 245',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            // Badge Motion de rejet
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'M. rejet : 12',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            // Badge Motion de censure
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'M. censure : 3',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Titre
                  const Text(
                    'Anciens votes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Formes décoratives positionnées par rapport au bord extérieur de la carte
          ..._buildShapes('bottom-right'),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Message de bienvenue à gauche
          Text(
            'Bienvenue ${widget.user['username'] ?? 'Utilisateur'} !',
            style: TextStyle(
              fontSize: 24,
              color: const Color(0xFF556B2F).withOpacity(0.8),
              fontWeight: FontWeight.bold,
            ),
          ),

          // Profil utilisateur avec style Art1Gallery
          GestureDetector(
            onTap: () {
              // Navigation vers la page de compte
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AccountPage(user: widget.user),
                ),
              );
            },
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
                Icons.person_rounded,
                color: Color(0xFF556B2F),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }


}