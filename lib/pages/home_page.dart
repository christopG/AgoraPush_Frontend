import 'package:flutter/material.dart';
import 'account_page.dart';
import 'my_stats_page.dart';
import 'deputies_list_page.dart';
import 'admin_page.dart';
import 'deputy_detail_page.dart';
import 'scrutins_page.dart';
import 'scrutins_autres_page.dart';
import 'scrutin_detail_page.dart';
import 'groupes_list_page.dart';
import '../services/api_service.dart';
import '../services/admin_auth_service.dart';
import '../services/session_service.dart';
import '../providers/deputy_provider.dart';
import '../data/models/deputy_model.dart';
import '../data/models/scrutin_model.dart';

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
  DeputyModel? userDeputy; // Variable pour stocker le député de l'utilisateur
  bool isLoadingDeputy = false; // État de chargement du député
  
  // Variables pour les scrutins
  int motionCount = 0; // Motion de censure + Motion de rejet
  int loiCount = 0; // Projet de Loi + Proposition de Loi
  int autresScrutinsCount = 0; // Tous les autres scrutins
  bool isLoadingScrutins = true;
  ScrutinModel? scrutinDuJour; // Le dernier scrutin Motion/Loi
  
  // Variables pour les groupes
  int? groupesCount; // Nombre de groupes actifs
  
  // Variables admin
  final AdminAuthService _adminAuthService = AdminAuthService();
  bool? _isAdmin;

  @override
  void initState() {
    super.initState();
    _loadDeputiesCount(); // Charger le nombre de députés au démarrage
    _loadUserDeputy(); // Charger le député de l'utilisateur
    _loadScrutinsCounts(); // Charger les compteurs de scrutins
    _loadGroupesCount(); // Charger le nombre de groupes actifs
    _checkAdminStatus(); // Vérifier le statut admin
    deputyProvider.loadAllDeputies(); // Charger tous les députés dans le cache global
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

  // Méthode pour charger le nombre de groupes actifs
  Future<void> _loadGroupesCount() async {
    try {
      final groupes = await ApiService.getActiveGroupesPolitiques();
      if (mounted) {
        setState(() {
          groupesCount = groupes.length;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement du nombre de groupes: $e');
      if (mounted) {
        setState(() {
          groupesCount = null;
        });
      }
    }
  }

  // Méthode pour charger les compteurs de scrutins depuis l'API
  Future<void> _loadScrutinsCounts() async {
    try {
      // Utiliser le nouvel endpoint optimisé
      final response = await ApiService.getScrutinsStatsForHome();
      
      if (mounted && response != null) {
        setState(() {
          motionCount = response['stats']['motionCount'] ?? 0;
          loiCount = response['stats']['loiCount'] ?? 0;
          autresScrutinsCount = response['stats']['autresCount'] ?? 0;
          
          // Convertir le scrutin du jour en ScrutinModel si disponible
          if (response['scrutinDuJour'] != null) {
            scrutinDuJour = ScrutinModel.fromJson(response['scrutinDuJour']);
          }
          
          isLoadingScrutins = false;
        });
        print('📊 Scrutins comptés (optimisé) - Motions: $motionCount, Lois: $loiCount, Autres: $autresScrutinsCount');
        if (scrutinDuJour != null) {
          print('🗳️ Scrutin du jour: ${scrutinDuJour!.titre}');
        }
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des scrutins: $e');
      if (mounted) {
        setState(() {
          isLoadingScrutins = false;
        });
      }
    }
  }

  // Méthode pour charger le député de l'utilisateur basé sur sa circonscription
  Future<void> _loadUserDeputy() async {
    final idcirco = widget.user['idcirco'];
    print('🔍 Tentative de chargement du député pour idcirco: $idcirco');
    print('📊 Données utilisateur: ${widget.user}');
    
    if (idcirco == null || idcirco.toString().isEmpty) {
      print('❌ Aucun idcirco trouvé pour l\'utilisateur');
      return;
    }
    
    setState(() {
      isLoadingDeputy = true;
    });
    
    try {
      // Charger tous les députés (comme dans deputies_list_page)
      print('📋 Chargement de tous les députés pour recherche locale...');
      final allDeputies = await deputyRepositoryProvider.getAllDeputies();
      
      if (allDeputies.isEmpty) {
        print('⚠️ Aucun député récupéré de l\'API');
        setState(() {
          isLoadingDeputy = false;
        });
        return;
      }
      
      // Normaliser l'idcirco pour la recherche
      final normalizedIdcirco = _normalizeIdcirco(idcirco.toString());
      print('🔄 idcirco normalisé: $normalizedIdcirco');
      print('🔍 Recherche locale parmi ${allDeputies.length} députés...');
      
      // Chercher le député correspondant ACTIF uniquement
      DeputyModel? foundDeputy;
      
      for (final deputy in allDeputies) {
        // Debug pour les premiers députés
        if (allDeputies.indexOf(deputy) < 3) {
          print('   Deputy ${allDeputies.indexOf(deputy) + 1}: idcirco="${deputy.idcirco}", codeCirco="${deputy.codeCirco}", nom="${deputy.nom}", active=${deputy.active}');
        }
        
        // IMPORTANT: Vérifier que le député est ACTIF (active == 1)
        if (deputy.active != 1) {
          continue; // Ignorer les députés inactifs
        }
        
        // Vérifier plusieurs formats d'identifiants de circonscription
        if (deputy.idcirco == idcirco.toString() ||
            deputy.codeCirco == idcirco.toString() ||
            deputy.idcirco == normalizedIdcirco ||
            deputy.codeCirco == normalizedIdcirco) {
          foundDeputy = deputy;
          print('✅ Député ACTIF trouvé: ${deputy.fullName} (active=${deputy.active})');
          break;
        }
      }
      
      if (foundDeputy != null && mounted) {
        print('✅ Député ACTIF chargé avec succès: ${foundDeputy.fullName} (active=${foundDeputy.active})');
        setState(() {
          userDeputy = foundDeputy;
          isLoadingDeputy = false;
        });
      } else if (mounted) {
        print('⚠️ Aucun député ACTIF trouvé pour l\'idcirco: $idcirco');
        // Debug: afficher quelques exemples de députés actifs pour comprendre le format
        print('🔍 Exemples de députés ACTIFS disponibles:');
        final activeDeputies = allDeputies.where((d) => d.active == 1).take(5).toList();
        for (int i = 0; i < activeDeputies.length; i++) {
          final deputy = activeDeputies[i];
          print('   ${deputy.nom}: idcirco="${deputy.idcirco}", codeCirco="${deputy.codeCirco}", active=${deputy.active}');
        }
        setState(() {
          isLoadingDeputy = false;
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement du député: $e');
      if (mounted) {
        setState(() {
          isLoadingDeputy = false;
        });
      }
    }
  }

  // Nouvelle méthode pour recharger les données utilisateur depuis la session
  Future<void> _reloadUserData() async {
    try {
      print('🔄 Rechargement des données utilisateur depuis la session...');
      final sessionService = SessionService();
      final userSession = await sessionService.getUserSession();
      
      if (userSession != null) {
        print('📊 Nouvelles données utilisateur: $userSession');
        setState(() {
          // Mettre à jour les données utilisateur
          widget.user.clear();
          widget.user.addAll(userSession);
        });
        print('✅ Données utilisateur mises à jour');
      } else {
        print('⚠️ Aucune session utilisateur trouvée');
      }
    } catch (e) {
      print('❌ Erreur lors du rechargement des données utilisateur: $e');
    }
  }

  // Fonction pour normaliser l'idcirco (copiée depuis deputies_list_page)
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

  // Vérifier le statut admin
  Future<void> _checkAdminStatus() async {
    try {
      final isAdmin = await _adminAuthService.isAdminAuthenticated();
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
        });
      }
    } catch (e) {
      print('Erreur lors de la vérification admin: $e');
      if (mounted) {
        setState(() {
          _isAdmin = false;
        });
      }
    }
  }

  String _getDeputyPhotoUrl(String deputyId) {
    // Supprime le préfixe "PA" de l'ID pour obtenir l'URL de la photo
    final photoId = deputyId.replaceFirst('PA', '');
    return 'https://www.assemblee-nationale.fr/dyn/static/tribun/17/photos/carre/$photoId.jpg';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header avec profil et navigation
                SliverToBoxAdapter(
                  child: _buildHeader(context),
                ),

                // Vote du jour - Hero Section
                SliverToBoxAdapter(
                  child: _buildVoteDuJour(),
                ),

                // Grid de cartes avec les 4 tuiles
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  sliver: SliverToBoxAdapter(
                    child: _buildMainGrid(),
                  ),
                ),

                // Section Footer avec informations
                SliverToBoxAdapter(
                  child: _buildFooterSection(),
                ),

                // Espacement pour le bandeau du bas
                const SliverToBoxAdapter(
                  child: SizedBox(height: 20),
                ),
              ],
            ),
          ),


        ],
      ),
    );
  }

  Widget _buildVoteDuJour() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: GestureDetector(
        onTap: () {
          if (scrutinDuJour != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ScrutinDetailPage(scrutin: scrutinDuJour!),
              ),
            );
          }
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4E8),
            borderRadius: BorderRadius.circular(35),
            border: Border.all(
              color: Colors.white,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF556B2F).withOpacity(0.15),
                blurRadius: 25,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(31), // 35 - 4 (border width)
            child: Stack(
              children: [
                // Forme principale (très grande) - en bordure de toute la carte
                Positioned(
                  right: -160,
                  top: -160,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      color: const Color(0xFF556B2F).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(160),
                    ),
                  ),
                ),
                // Forme moyenne - décalée
                Positioned(
                  right: -80,
                  top: -60,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8FBC8F).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(110),
                    ),
                  ),
                ),
                // Petite forme - accent visible
                Positioned(
                  right: 30,
                  top: 30,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDEB887).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(60),
                    ),
                  ),
                ),

                // Contenu principal de la carte
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre principal
                      const Text(
                        'Découvrez le\nvote du jour!',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Contenu du scrutin
                      if (isLoadingScrutins)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: CircularProgressIndicator(
                              color: Color(0xFF556B2F),
                            ),
                          ),
                        )
                      else if (scrutinDuJour != null)
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (scrutinDuJour!.sousTitre != null &&
                                  scrutinDuJour!.sousTitre!.isNotEmpty)
                                Text(
                                  scrutinDuJour!.sousTitre!.isNotEmpty
                                      ? '${scrutinDuJour!.sousTitre![0].toUpperCase()}${scrutinDuJour!.sousTitre!.substring(1)}'
                                      : scrutinDuJour!.sousTitre!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C3E50),
                                    height: 1.3,
                                  ),
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                )
                              else if (scrutinDuJour!.titre != null)
                                Text(
                                  scrutinDuJour!.titre!.isNotEmpty
                                      ? '${scrutinDuJour!.titre![0].toUpperCase()}${scrutinDuJour!.titre!.substring(1)}'
                                      : scrutinDuJour!.titre!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C3E50),
                                    height: 1.3,
                                  ),
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        )
                      else
                        const Text(
                          'Aucun scrutin disponible',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF556B2F),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid 2x3 style Art1Gallery - Toutes les cartes même taille (largeur ET hauteur)
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
            const SizedBox(height: 15),
            // Troisième ligne
            Row(
              children: [
                // Groupes
                Expanded(
                  child: _buildGroupesCard(),
                ),
                const SizedBox(width: 15),
                // Scrutins Autres
                Expanded(
                  child: _buildScrutinsAutresCard(),
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
      VoidCallback onTap,
      {int? count}) {
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
          
          // Badge de compteur si count est fourni
          if (count != null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: gradient.colors.first,
                  ),
                ),
              ),
            ),
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
      onTap: () {
        if (userDeputy != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeputyDetailPage(deputy: userDeputy!),
            ),
          );
        }
      },
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
                  // Photo du député en haut à gauche
                  Row(
                    children: [
                      if (isLoadingDeputy)
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                        )
                      else if (userDeputy != null)
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.network(
                              _getDeputyPhotoUrl(userDeputy!.id),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.white.withOpacity(0.2),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 25,
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.how_to_vote_rounded,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                    ],
                  ),

                  // Prénom et nom entre l'image et le titre
                  if (userDeputy != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Prénom
                        Text(
                          userDeputy!.prenom,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // Nom
                        Text(
                          userDeputy!.nom,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                  else
                    const Text(
                      'Aucun député trouvé',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // Titre en bas à gauche
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

  Widget _buildGroupesCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GroupesListPage()),
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
                colors: [Color(0xFFBC8F8F), Color(0xFF8B6969)],
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
                          Icons.diversity_3_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),

                      // Badge avec le nombre de groupes
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
                        child: groupesCount != null
                            ? Text(
                                '$groupesCount',
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

                  // Titre en bas
                  const Text(
                    'Groupes',
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

          // Formes décoratives
          ..._buildShapes('top-center'),
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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ScrutinsPage(),
          ),
        );
      },
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
                        child: isLoadingScrutins
                            ? const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Badge Loi (Projet + Proposition)
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
                                    child: Text(
                                      'Loi : $loiCount',
                                      style: const TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),

                                  // Badge Motion (Censure + Rejet)
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
                                    child: Text(
                                      'Motion : $motionCount',
                                      style: const TextStyle(
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
                    'Motion et\nprojet de Loi',
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

  Widget _buildScrutinsAutresCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ScrutinsAutresPage()),
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
                colors: [Color(0xFF9370DB), Color(0xFF7B68EE)],
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
                  // Row avec icône et badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.how_to_vote_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),

                      // Badge avec compteur
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
                        child: isLoadingScrutins
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                '$autresScrutinsCount',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ],
                  ),

                  // Titre
                  const Text(
                    'Scrutins\nAutres',
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

          // Formes décoratives
          ..._buildShapes('left-two-thirds'),
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
            onTap: () async {
              // Navigation vers la page de compte et rafraîchir le statut admin au retour
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AccountPage(user: widget.user),
                ),
              );
              print('DEBUG: Retour d\'AccountPage avec result = $result');
              // Vérifier à nouveau le statut admin après le retour
              _checkAdminStatus();
              // Recharger les données du député seulement si la circonscription a été modifiée
              if (result == true) {
                print('DEBUG: Rechargement des données utilisateur et du député');
                await _reloadUserData(); // Recharger les données utilisateur d'abord
                _loadUserDeputy(); // Puis recharger le député
              }
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

  Widget _buildFooterSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
              child: _buildFooterIcon(
                  'FAQ', Icons.help_outline_rounded, _showFAQBottomSheet)),
          Expanded(
              child: _buildFooterIcon('À propos',
                  Icons.info_outline_rounded, _showAboutBottomSheet)),
          Expanded(
              child: _buildFooterIcon('Contact',
                  Icons.contact_mail_outlined, _showContactBottomSheet)),
          Expanded(
              child: _buildFooterIcon('Soutenir',
                  Icons.favorite_outline_rounded, _showSupportBottomSheet)),
          if (_isAdmin == true)
            Expanded(
              child: _buildFooterIcon(
                'Admin',
                Icons.admin_panel_settings_outlined,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminPage()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooterIcon(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF556B2F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF556B2F),
                size: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Volets simples
  void _showFAQBottomSheet() {
    _showSimpleBottomSheet('FAQ', 'Foire aux Questions', Icons.help_outline);
  }

  void _showAboutBottomSheet() {
    _showSimpleBottomSheet('À Propos', 'À propos d\'AgoraPush', Icons.info_outline);
  }

  void _showContactBottomSheet() {
    _showSimpleBottomSheet('Contact', 'Nous contacter', Icons.contact_mail_outlined);
  }

  void _showSupportBottomSheet() {
    _showSimpleBottomSheet('Soutenir', 'Soutenir le projet', Icons.favorite_outline_rounded);
  }

  void _showSimpleBottomSheet(String title, String subtitle, IconData icon) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 32,
                    color: const Color(0xFF556B2F),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF556B2F).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.construction,
                        size: 60,
                        color: Color(0xFF556B2F),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Section en développement',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cette section sera bientôt disponible.\nMerci de votre patience !',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
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