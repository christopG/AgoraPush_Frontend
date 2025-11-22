import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/deputy_model.dart';
import '../providers/deputy_provider.dart';
import 'deputy_detail_page.dart';

class GroupeDetailPage extends StatefulWidget {
  final Map<String, dynamic> groupe;

  const GroupeDetailPage({super.key, required this.groupe});

  @override
  State<GroupeDetailPage> createState() => _GroupeDetailPageState();
}

class _GroupeDetailPageState extends State<GroupeDetailPage> {
  List<Map<String, dynamic>> _deputies = [];
  bool _isLoadingDeputies = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDeputies();
  }

  Future<void> _loadDeputies() async {
    setState(() {
      _isLoadingDeputies = true;
      _errorMessage = null;
    });

    try {
      // Attendre que le cache soit prêt
      List<DeputyModel> cachedDeputies = deputyProvider.deputies;
      
      // Si le cache est vide ET que le provider est en train de charger, attendre
      if (cachedDeputies.isEmpty && deputyProvider.loading) {
        print('⏳ En attente du chargement en cours...');
        // Attendre que le chargement se termine
        while (deputyProvider.loading) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        cachedDeputies = deputyProvider.deputies;
        print('✅ Chargement terminé: ${cachedDeputies.length} députés');
      } else if (cachedDeputies.isEmpty) {
        // Cache vraiment vide, charger
        print('📥 Cache vide, chargement des députés...');
        await deputyProvider.loadAllDeputies();
        cachedDeputies = deputyProvider.deputies;
      } else {
        print('✅ Utilisation du cache existant: ${cachedDeputies.length} députés');
      }
      
      // Filtrer les députés de ce groupe
      final groupeAbrev = widget.groupe['libelle_abrev'] ?? widget.groupe['libelle_abrege'];
      final groupeLibelle = widget.groupe['libelle'];
      print('🔍 Filtrage pour groupe_abrev: $groupeAbrev, libelle: $groupeLibelle');
      
      final groupeDeputies = cachedDeputies
          .where((d) {
            // Essayer de matcher avec libelleAb OU famillePolLibelle
            final matchAbrev = d.libelleAb == groupeAbrev;
            final matchLibelle = d.famillePolLibelle == groupeLibelle;
            final isActive = d.active == 1;
            return (matchAbrev || matchLibelle) && isActive;
          })
          .map((d) => {
            'id': d.id,
            'prenom': d.prenom,
            'nom': d.nom,
            'libelle': d.libelle,
            'groupe_abrev': d.libelleAb,
            'active': d.active == 1,
          })
          .toList();
      
      print('📊 ${groupeDeputies.length} députés trouvés pour le groupe $groupeAbrev');
      
      // Trier par nom
      groupeDeputies.sort((a, b) {
        final nomA = a['nom']?.toString() ?? '';
        final nomB = b['nom']?.toString() ?? '';
        return nomA.compareTo(nomB);
      });

      setState(() {
        _deputies = groupeDeputies;
        _isLoadingDeputies = false;
      });
    } catch (e) {
      print('❌ Erreur chargement députés: $e');
      setState(() {
        _errorMessage = 'Erreur lors du chargement des députés: $e';
        _isLoadingDeputies = false;
      });
    }
  }

  Color _getCouleur(String? couleurHex) {
    if (couleurHex == null || couleurHex.isEmpty) {
      return Colors.grey;
    }
    
    try {
      String hex = couleurHex.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _getDeputyPhotoUrl(String deputyId) {
    // Enlever le préfixe "PA" de l'ID pour obtenir le numéro
    final photoId = deputyId.startsWith('PA') ? deputyId.substring(2) : deputyId;
    return 'https://www.assemblee-nationale.fr/dyn/static/tribun/17/photos/carre/$photoId.jpg';
  }

  Widget _buildDeputyCard(Map<String, dynamic> deputy, Color couleurGroupe) {
    final prenom = deputy['prenom']?.toString() ?? '';
    final nom = deputy['nom']?.toString() ?? '';
    final libelle = deputy['libelle']?.toString() ?? '';
    final deputyId = deputy['id']?.toString() ?? '';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Trouver le DeputyModel complet depuis le cache
          final fullDeputy = deputyProvider.deputies.firstWhere(
            (d) => d.id == deputyId,
            orElse: () => throw Exception('Député non trouvé'),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeputyDetailPage(deputy: fullDeputy),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Photo du député
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: deputyId.isNotEmpty
                      ? Image.network(
                          _getDeputyPhotoUrl(deputyId),
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              decoration: BoxDecoration(
                                color: couleurGroupe.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(couleurGroupe),
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                color: couleurGroupe.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person,
                                size: 32,
                                color: couleurGroupe,
                              ),
                            );
                          },
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: couleurGroupe.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            size: 32,
                            color: couleurGroupe,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Informations
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$prenom $nom',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (libelle.isNotEmpty)
                      Text(
                        libelle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Icône
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final couleur = _getCouleur(widget.groupe['couleur_associee']);
    final libelle = widget.groupe['libelle'] ?? 'Groupe';
    final libelleAbrev = widget.groupe['libelle_abrev'] ?? widget.groupe['libelle_abrege'] ?? '';
    final effectif = (widget.groupe['effectif'] ?? 0) as num;
    final women = (widget.groupe['women'] ?? 0) as num;
    final age = ((widget.groupe['age'] ?? 0) as num).toDouble();
    final positionPolitique = widget.groupe['position_politique'] ?? '';
    final updatedAt = widget.groupe['updated_at'];
    
    // Scores
    final scoreRose = double.tryParse(widget.groupe['score_rose']?.toString() ?? '0') ?? 0.0;
    final scoreCohesion = double.tryParse(widget.groupe['socre_cohesion']?.toString() ?? '0') ?? 0.0;
    final scoreParticipation = double.tryParse(widget.groupe['score_participation']?.toString() ?? '0') ?? 0.0;
    final scoreMajorite = double.tryParse(widget.groupe['score_majorite']?.toString() ?? '0') ?? 0.0;

    // Calcul du pourcentage de femmes
    final pourcentageFemmes = effectif > 0 ? (women / effectif * 100) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // AppBar avec couleur du groupe
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            backgroundColor: couleur,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    libelleAbrev.isNotEmpty ? libelleAbrev : libelle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3.0,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${effectif.toInt()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenu
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom complet du groupe
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        libelle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      if (positionPolitique.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              positionPolitique,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Statistiques du groupe
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Statistiques',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Grille de statistiques
                      _buildStatsGrid(effectif.toInt(), women.toInt(), pourcentageFemmes, age),
                      
                      const SizedBox(height: 12),
                      
                      // Scores si disponibles
                      _buildScoresSection(scoreRose, scoreCohesion, scoreParticipation, scoreMajorite),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Liste des députés
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Députés du groupe',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      Text(
                        '${_deputies.length} député${_deputies.length > 1 ? "s" : ""}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Cartes des députés
                if (_isLoadingDeputies)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: couleur),
                    ),
                  )
                else if (_errorMessage != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  )
                else if (_deputies.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Aucun député trouvé pour ce groupe',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  )
                else
                  ..._deputies.map((deputy) => _buildDeputyCard(deputy, couleur)).toList(),

                // Footer avec date de mise à jour
                if (updatedAt != null)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'Mise à jour le ${_formatDate(updatedAt)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(int effectif, int women, double pourcentageFemmes, double age) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Effectif',
            effectif.toString(),
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Femmes',
            '${pourcentageFemmes.round()}%',
            Icons.woman,
            Colors.pink,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Âge moyen',
            age > 0 ? '${age.round()} ans' : 'N/A',
            Icons.cake,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScoresSection(double scoreRose, double scoreCohesion, double scoreParticipation, double scoreMajorite) {
    final scores = <Map<String, dynamic>>[
      if (scoreRose > 0) {'label': 'Score Rose', 'value': scoreRose, 'icon': Icons.favorite, 'color': Colors.red},
      if (scoreCohesion > 0) {'label': 'Cohésion', 'value': scoreCohesion, 'icon': Icons.group_work, 'color': Colors.purple},
      if (scoreParticipation > 0) {'label': 'Participation', 'value': scoreParticipation, 'icon': Icons.how_to_vote, 'color': Colors.green},
      if (scoreMajorite > 0) {'label': 'Majorité', 'value': scoreMajorite, 'icon': Icons.check_circle, 'color': Colors.teal},
    ];
    
    if (scores.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scores',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 12),
          ...scores.map((score) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildScoreBar(
              score['label'] as String,
              score['value'] as double,
              score['icon'] as IconData,
              score['color'] as Color,
            ),
          )).toList(),
        ],
      ),
    );
  }
  
  Widget _buildScoreBar(String label, double value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              (value * 100).toStringAsFixed(0) + '%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
