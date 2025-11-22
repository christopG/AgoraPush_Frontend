import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../data/models/scrutin_model.dart';

class ScrutinsAutresPage extends StatefulWidget {
  const ScrutinsAutresPage({super.key});

  @override
  State<ScrutinsAutresPage> createState() => _ScrutinsAutresPageState();
}

class _ScrutinsAutresPageState extends State<ScrutinsAutresPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  List<ScrutinModel> _allScrutins = [];
  List<ScrutinModel> _filteredScrutins = [];
  List<String> _availableTypes = [];
  List<String> _selectedTypes = [];
  
  bool _isLoading = true;
  bool _showHeader = true;
  bool _showFilters = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadScrutins();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 50 && _showHeader) {
      setState(() => _showHeader = false);
    } else if (_scrollController.offset <= 50 && !_showHeader) {
      setState(() => _showHeader = true);
    }
  }

  Future<void> _loadScrutins() async {
    try {
      final scrutinsData = await ApiService.getAllScrutins();
      
      final scrutins = scrutinsData
          .map((data) => ScrutinModel.fromJson(data))
          .where((scrutin) {
            // Exclure Motion de censure, Motion de rejet, Projet de loi, Proposition de loi
            const excludedTypes = [
              'Motion de censure',
              'Motion de rejet',
              'Projet de loi',
              'Proposition de loi',
            ];
            return scrutin.typeScrutin != null && 
                   !excludedTypes.contains(scrutin.typeScrutin);
          })
          .toList();

      // Trier par date décroissante
      scrutins.sort((a, b) {
        if (a.dateScrutin == null && b.dateScrutin == null) return 0;
        if (a.dateScrutin == null) return 1;
        if (b.dateScrutin == null) return -1;
        return b.dateScrutin!.compareTo(a.dateScrutin!);
      });

      // Extraire les types disponibles
      final types = scrutins
          .map((s) => s.typeScrutin)
          .where((type) => type != null)
          .toSet()
          .cast<String>()
          .toList();
      types.sort();

      if (mounted) {
        setState(() {
          _allScrutins = scrutins;
          _availableTypes = types;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      print('❌ Erreur chargement scrutins autres: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredScrutins = _allScrutins.where((scrutin) {
        // Filtre par type
        if (_selectedTypes.isNotEmpty) {
          if (scrutin.typeScrutin == null || !_selectedTypes.contains(scrutin.typeScrutin)) {
            return false;
          }
        }

        // Filtre recherche
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final fields = [
            scrutin.titre,
            scrutin.sousTitre,
            scrutin.objet,
            scrutin.contenuTexte,
            scrutin.contexte,
            scrutin.enjeux,
            scrutin.resume,
            scrutin.numero,
          ].map((f) => f?.toLowerCase() ?? '');
          
          if (!fields.any((field) => field.contains(query))) return false;
        }

        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F2),
      body: SafeArea(
        child: Column(
          children: [
            if (_showHeader) _buildHeader(),
            _buildSearchBar(),
            Expanded(child: _buildScrutinsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
                color: Color(0xFF556B2F),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Scrutins Autres',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF556B2F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      children: [
        Focus(
          onFocusChange: (hasFocus) => setState(() {}),
          child: Builder(
            builder: (context) {
              final hasFocus = Focus.of(context).hasFocus;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: hasFocus ? const Color(0xFF556B2F) : Colors.transparent,
                    width: 2,
                  ),
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
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher...',
                          hintStyle: TextStyle(
                            color: const Color(0xFF556B2F).withOpacity(0.5),
                            fontSize: 16,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: const Color(0xFF556B2F).withOpacity(0.7),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                          _applyFilters();
                        },
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _showFilters = !_showFilters);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _selectedTypes.isNotEmpty
                              ? const Color(0xFF556B2F)
                              : const Color(0xFF556B2F).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.filter_list,
                          color: _selectedTypes.isNotEmpty
                              ? Colors.white
                              : const Color(0xFF556B2F).withOpacity(0.8),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_showFilters) _buildFiltersPanel(),
      ],
    );
  }

  Widget _buildFiltersPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtres par type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF556B2F),
                ),
              ),
              if (_selectedTypes.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() => _selectedTypes.clear());
                    _applyFilters();
                  },
                  child: const Text('Réinitialiser'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableTypes.map((type) {
              final isSelected = _selectedTypes.contains(type);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedTypes.remove(type);
                    } else {
                      _selectedTypes.add(type);
                    }
                  });
                  _applyFilters();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF556B2F).withOpacity(0.85)
                        : const Color(0xFF556B2F).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF556B2F).withOpacity(isSelected ? 0.9 : 0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF556B2F),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildScrutinsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF556B2F),
        ),
      );
    }

    if (_filteredScrutins.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: const Color(0xFF556B2F).withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun scrutin trouvé',
              style: TextStyle(
                fontSize: 18,
                color: const Color(0xFF556B2F).withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _filteredScrutins.length,
      itemBuilder: (context, index) {
        final scrutin = _filteredScrutins[index];
        return _buildScrutinCard(scrutin);
      },
    );
  }

  Widget _buildScrutinCard(ScrutinModel scrutin) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type de scrutin
          if (scrutin.typeScrutin != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF556B2F).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF556B2F).withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Text(
                scrutin.typeScrutin!,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF556B2F),
                ),
              ),
            ),
          const SizedBox(height: 8),

          // Titre
          if (scrutin.titre != null)
            Text(
              scrutin.titre!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          
          // Sous-titre
          if (scrutin.sousTitre != null) ...[
            const SizedBox(height: 4),
            Text(
              scrutin.sousTitre!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF556B2F).withOpacity(0.8),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Date
          if (scrutin.dateScrutin != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: const Color(0xFF556B2F).withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(scrutin.dateScrutin!),
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF556B2F).withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],

          // Statistiques de vote
          if (scrutin.nbVotants != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildVoteStat('Pour', scrutin.nbPour, Colors.green),
                const SizedBox(width: 12),
                _buildVoteStat('Contre', scrutin.nbContre, Colors.red),
                const SizedBox(width: 12),
                _buildVoteStat('Abstention', scrutin.nbAbstentions, Colors.grey),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoteStat(String label, int? value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.withOpacity(0.7),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ${value ?? 0}',
          style: TextStyle(
            fontSize: 10,
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'janv', 'fév', 'mars', 'avr', 'mai', 'juin',
      'juil', 'août', 'sept', 'oct', 'nov', 'déc'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
