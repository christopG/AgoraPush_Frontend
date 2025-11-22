import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models/deputy_model.dart';
import '../data/models/scrutin_model.dart';
import '../data/models/groupe_model.dart';
import '../providers/deputy_provider.dart';
import '../services/api_service.dart';
import 'deputy_detail_page.dart';

// Classe helper pour associer un député à son vote
class DeputyVoteInfo {
  final DeputyModel deputy;
  final String vote; // 'pour', 'contre', 'abstention'

  DeputyVoteInfo({
    required this.deputy,
    required this.vote,
  });
}

class ScrutinGroupDetailPage extends StatefulWidget {
  final String groupId;
  final ScrutinModel scrutin;

  const ScrutinGroupDetailPage({
    super.key,
    required this.groupId,
    required this.scrutin,
  });

  @override
  State<ScrutinGroupDetailPage> createState() => _ScrutinGroupDetailPageState();
}

class _ScrutinGroupDetailPageState extends State<ScrutinGroupDetailPage> {
  String _selectedFilter = 'tous'; // 'tous', 'pour', 'contre', 'abstention'
  List<DeputyVoteInfo> _deputyVotes = [];
  bool _isLoading = true;
  GroupeModel? _groupe;

  @override
  void initState() {
    super.initState();
    _loadGroupeInfo();
    _loadDeputyVotes();
  }

  Future<void> _loadGroupeInfo() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/groupes'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['groupes'] != null) {
          for (var groupeJson in data['groupes']) {
            final groupe = GroupeModel.fromJson(groupeJson);
            if (groupe.id == widget.groupId) {
              setState(() {
                _groupe = groupe;
              });
              break;
            }
          }
        }
      }
    } catch (e) {
      print('Erreur lors du chargement du groupe: $e');
    }
  }

  Future<void> _loadDeputyVotes() async {
    setState(() => _isLoading = true);

    try {
      // Attendre que les députés soient chargés
      int attempts = 0;
      while (deputyProvider.deputies.isEmpty && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      // Récupérer tous les députés du cache
      final allDeputies = deputyProvider.deputies;

      print('🔍 Recherche des députés du groupe: ${widget.groupId}');
      print('📊 Nombre total de députés dans le cache: ${allDeputies.length}');

      // Parser les IDs de vote
      final pourIds = _parseVoteIds(widget.scrutin.votePour);
      final contreIds = _parseVoteIds(widget.scrutin.voteContre);
      final abstentionIds = _parseVoteIds(widget.scrutin.voteAbstention);

      print('📊 IDs pour: ${pourIds.length}, contre: ${contreIds.length}, abstention: ${abstentionIds.length}');
      
      // Debug: afficher quelques IDs
      if (pourIds.isNotEmpty) print('Exemple ID pour: ${pourIds.take(3).join(", ")}');
      if (contreIds.isNotEmpty) print('Exemple ID contre: ${contreIds.take(3).join(", ")}');

      // Filtrer les députés du groupe et déterminer leur vote
      List<DeputyVoteInfo> votes = [];

      // Debug: afficher quelques groupePolitiqueRef
      final groupRefs = allDeputies.map((d) => d.groupePolitiqueRef).where((ref) => ref != null).toSet();
      print('📋 Groupes (groupePolitiqueRef): ${groupRefs.take(5).join(", ")}...');

      for (var deputy in allDeputies) {
        // Vérifier si le député appartient au groupe via groupePolitiqueRef
        if (deputy.groupePolitiqueRef == widget.groupId) {
          String? vote;
          
          if (pourIds.contains(deputy.id)) {
            vote = 'pour';
          } else if (contreIds.contains(deputy.id)) {
            vote = 'contre';
          } else if (abstentionIds.contains(deputy.id)) {
            vote = 'abstention';
          }

          if (vote != null) {
            votes.add(DeputyVoteInfo(deputy: deputy, vote: vote));
            print('✅ Député ajouté: ${deputy.prenom} ${deputy.nom} - Vote: $vote');
          } else {
            print('⚠️ Député du groupe ${widget.groupId} trouvé mais sans vote: ${deputy.prenom} ${deputy.nom} (${deputy.id})');
          }
        }
      }

      print('📋 Total de députés trouvés pour ce groupe: ${votes.length}');

      setState(() {
        _deputyVotes = votes;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des votes: $e');
      setState(() => _isLoading = false);
    }
  }

  List<String> _parseVoteIds(String? voteData) {
    if (voteData == null || voteData.isEmpty) return [];
    try {
      String cleaned = voteData.trim();
      if (cleaned.startsWith('[')) cleaned = cleaned.substring(1);
      if (cleaned.endsWith(']')) cleaned = cleaned.substring(0, cleaned.length - 1);
      return cleaned.split(',').map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  String _getDeputyPhotoUrl(String deputyId) {
    final photoId = deputyId.startsWith('PA') ? deputyId.substring(2) : deputyId;
    return 'https://www.assemblee-nationale.fr/dyn/static/tribun/17/photos/carre/$photoId.jpg';
  }

  List<DeputyVoteInfo> _getFilteredDeputies() {
    if (_selectedFilter == 'tous') {
      return _deputyVotes;
    }
    return _deputyVotes.where((dv) => dv.vote == _selectedFilter).toList();
  }

  int _getCountForFilter(String filter) {
    if (filter == 'tous') {
      return _deputyVotes.length;
    }
    return _deputyVotes.where((dv) => dv.vote == filter).length;
  }

  @override
  Widget build(BuildContext context) {
    final filteredDeputies = _getFilteredDeputies();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF8F9FA),
                Color(0xFFFFFFFF),
              ],
            ),
          ),
          child: Column(
            children: [
              // Header avec bouton retour et titre
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Row(
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
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _groupe?.libelle ?? widget.groupId,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Scrutin n°${widget.scrutin.numero ?? ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Filtres
              if (!_isLoading) _buildFilters(),

              const SizedBox(height: 16),

              // Liste des députés
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredDeputies.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildEmptyState(),
                              const SizedBox(height: 20),
                              Text(
                                'Debug Info:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Group ID: ${widget.groupId}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              Text(
                                'Total votes: ${_deputyVotes.length}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              Text(
                                'Filter: $_selectedFilter',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              Text(
                                'Deputies in cache: ${deputyProvider.deputies.length}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredDeputies.length,
                            itemBuilder: (context, index) {
                              return _buildDeputyCard(filteredDeputies[index]);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('Tous', 'tous', _getCountForFilter('tous'), null),
            const SizedBox(width: 8),
            _buildFilterChip('Pour', 'pour', _getCountForFilter('pour'),
                const Color(0xFF5BA282)),
            const SizedBox(width: 8),
            _buildFilterChip('Contre', 'contre', _getCountForFilter('contre'),
                const Color(0xFFD95C3F)),
            const SizedBox(width: 8),
            _buildFilterChip('Abstention', 'abstention',
                _getCountForFilter('abstention'), const Color(0xFFFF8C00)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
      String label, String filterKey, int count, Color? color) {
    final isSelected = _selectedFilter == filterKey;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterKey;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? const Color(0xFF556B2F)).withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected
                ? (color ?? const Color(0xFF556B2F))
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? (color ?? const Color(0xFF556B2F))
                    : const Color(0xFF4A5568),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? (color ?? const Color(0xFF556B2F))
                    : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeputyCard(DeputyVoteInfo deputyVote) {
    final deputy = deputyVote.deputy;
    final vote = deputyVote.vote;

    Color voteColor = Colors.grey;
    String voteLabel = '';

    switch (vote) {
      case 'pour':
        voteColor = const Color(0xFF5BA282);
        voteLabel = 'Pour';
        break;
      case 'contre':
        voteColor = const Color(0xFFD95C3F);
        voteLabel = 'Contre';
        break;
      case 'abstention':
        voteColor = const Color(0xFFFF8C00);
        voteLabel = 'Abstention';
        break;
      default:
        voteColor = Colors.grey;
        voteLabel = 'Non voté';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeputyDetailPage(deputy: deputy),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Photo du député
            ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Image.network(
                _getDeputyPhotoUrl(deputy.id),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.grey.shade600,
                      size: 24,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: 16),

            // Informations du député
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom et prénom
                  Text(
                    '${deputy.prenom} ${deputy.nom}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Circonscription
                  if (deputy.libelle != null && deputy.libelle!.isNotEmpty)
                    Text(
                      deputy.libelle!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),

            // Badge de vote
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: voteColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: voteColor, width: 1),
              ),
              child: Text(
                voteLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: voteColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = 'Aucun député trouvé';

    switch (_selectedFilter) {
      case 'pour':
        message = 'Aucun député n\'a voté pour';
        break;
      case 'contre':
        message = 'Aucun député n\'a voté contre';
        break;
      case 'abstention':
        message = 'Aucun député ne s\'est abstenu';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
