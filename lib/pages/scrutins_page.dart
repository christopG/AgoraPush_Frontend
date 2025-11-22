import 'package:flutter/material.dart';
import '../data/models/scrutin_model.dart';
import '../data/models/theme_model.dart';
import '../services/api_service.dart';
import 'scrutin_detail_page.dart';

class ScrutinsPage extends StatefulWidget {
  const ScrutinsPage({super.key});

  @override
  State<ScrutinsPage> createState() => _ScrutinsPageState();
}

class _ScrutinsPageState extends State<ScrutinsPage> {
  List<ScrutinModel> _allScrutins = []; // Tous les scrutins chargés jusqu'à présent
  List<ThemeModel> _allThemes = [];
  List<String> _selectedThemeIds = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showHeader = true;
  
  // Pagination côté serveur
  int _currentPage = 0;
  int _totalCount = 0;
  bool _hasMore = true;
  
  // Filtres
  bool _showFilters = false;
  DateTimeRange? _selectedDateRange;
  String? _selectedPeriodType;
  List<int> _selectedYears = [];
  List<String> _selectedMonths = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadScrutins();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    // Cacher/montrer le header
    if (_scrollController.offset > 50 && _showHeader) {
      setState(() => _showHeader = false);
    } else if (_scrollController.offset <= 50 && !_showHeader) {
      setState(() => _showHeader = true);
    }
    
    // Charger plus de scrutins quand on approche du bas
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreScrutins();
    }
  }

  Future<void> _loadScrutins() async {
    setState(() => _isLoading = true);
    try {
      // Charger les thèmes une seule fois
      final themesData = await ApiService.getAllThemes();
      final themes = themesData.map((data) => ThemeModel.fromJson(data)).toList();
      
      // Charger la première page de scrutins
      final result = await ApiService.getScrutinsPaginated(
        page: 0,
        limit: 15,
      );
      
      if (result != null && mounted) {
        final scrutins = (result['data'] as List)
            .map((data) => ScrutinModel.fromJson(data))
            .toList();
        
        setState(() {
          _allThemes = themes;
          _allScrutins = scrutins;
          _currentPage = 0;
          _totalCount = result['pagination']['total'];
          _hasMore = result['pagination']['hasMore'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des scrutins: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() async {
    // Recharger depuis le début avec les nouveaux filtres
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _allScrutins = [];
    });
    
    try {
      final result = await ApiService.getScrutinsPaginated(
        page: 0,
        limit: 15,
        themeIds: _selectedThemeIds.isNotEmpty ? _selectedThemeIds : null,
        years: _selectedYears.isNotEmpty ? _selectedYears : null,
        months: _selectedMonths.isNotEmpty ? _selectedMonths : null,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      
      if (result != null && mounted) {
        final scrutins = (result['data'] as List)
            .map((data) => ScrutinModel.fromJson(data))
            .toList();
        
        setState(() {
          _allScrutins = scrutins;
          _currentPage = 0;
          _totalCount = result['pagination']['total'];
          _hasMore = result['pagination']['hasMore'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur lors de l\'application des filtres: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _loadMoreScrutins() async {
    if (_isLoadingMore || !_hasMore) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      final result = await ApiService.getScrutinsPaginated(
        page: _currentPage + 1,
        limit: 15,
        themeIds: _selectedThemeIds.isNotEmpty ? _selectedThemeIds : null,
        years: _selectedYears.isNotEmpty ? _selectedYears : null,
        months: _selectedMonths.isNotEmpty ? _selectedMonths : null,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      
      if (result != null && mounted) {
        final newScrutins = (result['data'] as List)
            .map((data) => ScrutinModel.fromJson(data))
            .toList();
        
        setState(() {
          _allScrutins.addAll(newScrutins);
          _currentPage++;
          _hasMore = result['pagination']['hasMore'];
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement de plus de scrutins: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Map<String, List<ScrutinModel>> _groupByDate() {
    final Map<String, List<ScrutinModel>> grouped = {};
    
    // Grouper les scrutins chargés
    for (var scrutin in _allScrutins) {
      if (scrutin.dateScrutin != null) {
        final dateKey = scrutin.formattedDate;
        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
        }
        grouped[dateKey]!.add(scrutin);
      }
    }
    
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedScrutins = _groupByDate();
    final sortedDates = groupedScrutins.keys.toList()
      ..sort((a, b) {
        // Trier par date décroissante (plus récent en premier)
        final dateA = groupedScrutins[a]!.first.dateScrutin!;
        final dateB = groupedScrutins[b]!.first.dateScrutin!;
        return dateB.compareTo(dateA);
      });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F2),
      body: SafeArea(
        child: Column(
          children: [
            // Header avec bouton retour et titre (caché au scroll)
            if (_showHeader) _buildHeader(),
            
            // Barre de recherche (toujours visible)
            _buildSearchBar(),
            
            // Liste avec timeline
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _allScrutins.isEmpty
                      ? _buildEmptyState()
                      : _buildTimelineList(sortedDates, groupedScrutins),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7F2),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  'Scrutins',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF556B2F),
                  ),
                ),
              ),
              // Badge avec le nombre de scrutins (chargés/total)
              // Container(
              //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              //   decoration: BoxDecoration(
              //     color: const Color(0xFF556B2F).withOpacity(0.1),
              //     borderRadius: BorderRadius.circular(20),
              //   ),
              //   child: Text(
              //     '${_allScrutins.length}/$_totalCount',
              //     style: const TextStyle(
              //       fontSize: 14,
              //       fontWeight: FontWeight.bold,
              //       color: Color(0xFF556B2F),
              //     ),
              //   ),
              // ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      children: [
        Focus(
          onFocusChange: (hasFocus) {
            setState(() {});
          },
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
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (query) {
                            setState(() {
                              _searchQuery = query;
                            });
                            _applyFilters();
                          },
                          decoration: InputDecoration(
                            hintText: 'Rechercher un scrutin...',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: const Color(0xFF556B2F).withOpacity(0.6),
                              size: 24,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                      _applyFilters();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          ),
                        ),
                      ),
                      // Bouton filtres
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showFilters = !_showFilters;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _showFilters
                                ? const Color(0xFF556B2F)
                                : const Color(0xFF556B2F).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.filter_list,
                            color: _showFilters ? Colors.white : const Color(0xFF556B2F),
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
        // Panel de filtres
        if (_showFilters) _buildFiltersPanel(),
        
        // Barre de thèmes
        if (_allThemes.isNotEmpty) _buildThemesBar(),
      ],
    );
  }

  Widget _buildThemesBar() {
    // Filtrer uniquement les thèmes avec count > 0
    final themesWithScrutins = _allThemes.where((theme) => (theme.count ?? 0) > 0).toList();
    
    if (themesWithScrutins.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 16),
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: themesWithScrutins.length,
        itemBuilder: (context, index) {
          final theme = themesWithScrutins[index];
          final isSelected = _selectedThemeIds.contains(theme.id);
          
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedThemeIds.remove(theme.id);
                } else {
                  _selectedThemeIds.add(theme.id);
                }
              });
              _applyFilters();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Color(theme.getColor()).withOpacity(isSelected ? 0.85 : 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Color(theme.getColor()).withOpacity(isSelected ? 0.9 : 0.4),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  theme.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Color(theme.getColor()).withOpacity(0.9),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineList(List<String> dates, Map<String, List<ScrutinModel>> groupedScrutins) {
    // Grouper les scrutins CHARGÉS par date
    final Map<String, List<ScrutinModel>> filteredGroupedByDate = {};
    for (var scrutin in _allScrutins) {
      if (scrutin.dateScrutin != null) {
        final dateKey = scrutin.formattedDate;
        if (!filteredGroupedByDate.containsKey(dateKey)) {
          filteredGroupedByDate[dateKey] = [];
        }
        filteredGroupedByDate[dateKey]!.add(scrutin);
      }
    }
    
    // Trier les dates (uniquement celles qui ont des scrutins filtrés)
    final filteredDates = filteredGroupedByDate.keys.toList()
      ..sort((a, b) {
        final dateA = filteredGroupedByDate[a]!.first.dateScrutin!;
        final dateB = filteredGroupedByDate[b]!.first.dateScrutin!;
        return dateB.compareTo(dateA);
      });
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
      itemCount: filteredDates.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Indicateur de chargement à la fin
        if (index == filteredDates.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF556B2F)),
              ),
            ),
          );
        }
        final date = filteredDates[index];
        final scrutinsForDate = filteredGroupedByDate[date]!;
        final isLast = index == filteredDates.length - 1;

        return _buildDateSection(date, scrutinsForDate, isLast);
      },
    );
  }

  Widget _buildDateSection(String date, List<ScrutinModel> scrutins, bool isLast) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ligne avec point et date alignés horizontalement
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Point de la timeline (décalé pour aligner avec la ligne verticale)
            Transform.translate(
              offset: const Offset(-4, 0),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF556B2F),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF556B2F).withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 5),
            
            // Date à côté du point
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF556B2F),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                date,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 2),
        
        // Ligne verticale + cartes
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne verticale continue avec bords arrondis
              SizedBox(
                width: 8,
                child: !isLast
                    ? Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: const Color(0xFF556B2F).withOpacity(0.2),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10),
                            bottom: Radius.circular(10),
                          ),
                        ),
                      )
                    : const SizedBox(),
              ),
              
              const SizedBox(width: 8),
              
              // Cartes de scrutins
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    ...scrutins.map((scrutin) => _buildScrutinCard(scrutin)).toList(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScrutinCard(ScrutinModel scrutin) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ScrutinDetailPage(scrutin: scrutin),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header avec type de scrutin
                if (scrutin.typeScrutin != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF556B2F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      scrutin.typeScrutin!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF556B2F),
                      ),
                    ),
                  ),
                
                // Thèmes du scrutin
                if (scrutin.themesList.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: scrutin.themesList.map((theme) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(theme.getColor()).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Color(theme.getColor()).withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          theme.name,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(theme.getColor()).withOpacity(0.9),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                
                const SizedBox(height: 12),
                
                // Titre (utilise le sous-titre)
                Text(
                  scrutin.sousTitre ?? scrutin.titre ?? 'Sans titre',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2C3E50),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 12),
                
                // Statistiques de vote
                Row(
                  children: [
                    _buildVoteStats('Pour', scrutin.nbPour, Colors.green),
                    const SizedBox(width: 12),
                    _buildVoteStats('Contre', scrutin.nbContre, Colors.red),
                    const SizedBox(width: 12),
                    _buildVoteStats('Abs.', scrutin.nbAbstentions, Colors.orange),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoteStats(String label, int? value, Color color) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color.withOpacity(0.7),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$label: ${value ?? 0}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, color: Color(0xFF556B2F), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Filtres',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const Spacer(),
              if (_selectedDateRange != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDateRange = null;
                    });
                    _applyFilters();
                  },
                  child: const Text(
                    'Réinitialiser',
                    style: TextStyle(color: Color(0xFF556B2F)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Filtre Période (simplifié)
          const Text(
            'Période',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          
          // Choix du type de période
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                label: 'Années',
                isSelected: _selectedPeriodType == 'year',
                onTap: () {
                  setState(() {
                    if (_selectedPeriodType == 'year') {
                      _selectedPeriodType = null;
                      _selectedYears.clear();
                    } else {
                      _selectedPeriodType = 'year';
                      _selectedMonths.clear();
                    }
                    _updateDateRangeFromSelection();
                  });
                },
              ),
              _buildFilterChip(
                label: 'Mois',
                isSelected: _selectedPeriodType == 'month',
                onTap: () {
                  setState(() {
                    if (_selectedPeriodType == 'month') {
                      _selectedPeriodType = null;
                      _selectedMonths.clear();
                    } else {
                      _selectedPeriodType = 'month';
                      _selectedYears.clear();
                    }
                    _updateDateRangeFromSelection();
                  });
                },
              ),
            ],
          ),
          
          // Sélecteur spécifique selon le type
          if (_selectedPeriodType != null) ...[
            const SizedBox(height: 12),
            _buildPeriodSelector(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPeriodSelector() {
    final now = DateTime.now();
    
    switch (_selectedPeriodType) {
      case 'year':
        return _buildYearSelector(now);
      case 'month':
        return _buildMonthSelector(now);
      default:
        return const SizedBox.shrink();
    }
  }
  
  void _updateDateRangeFromSelection() {
    if (_selectedYears.isEmpty && _selectedMonths.isEmpty) {
      _selectedDateRange = null;
      _applyFilters();
      return;
    }
    
    // Cette fonction n'est plus utilisée car on applique le filtre directement
    // Le filtre est maintenant basé sur _selectedYears et _selectedMonths
    _applyFilters();
  }
  
  Widget _buildYearSelector(DateTime now) {
    final years = List.generate(6, (i) => now.year - i);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: years.map((year) {
        final isSelected = _selectedYears.contains(year);
        return _buildFilterChip(
          label: year.toString(),
          isSelected: isSelected,
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedYears.remove(year);
              } else {
                _selectedYears.add(year);
              }
              _updateDateRangeFromSelection();
            });
          },
        );
      }).toList(),
    );
  }
  
  Widget _buildMonthSelector(DateTime now) {
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Liste des années disponibles
        const Text(
          'Années',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF556B2F)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(3, (i) => now.year - i).map((year) {
            final isYearSelected = _selectedMonths.any((m) => m.startsWith(year.toString()));
            return _buildFilterChip(
              label: year.toString(),
              isSelected: isYearSelected,
              onTap: () {
                setState(() {
                  if (isYearSelected) {
                    // Désélectionner tous les mois de cette année
                    _selectedMonths.removeWhere((m) => m.startsWith(year.toString()));
                  } else {
                    // Sélectionner tous les mois de cette année
                    for (int month = 1; month <= 12; month++) {
                      final monthKey = '$year-${month.toString().padLeft(2, '0')}';
                      if (!_selectedMonths.contains(monthKey)) {
                        _selectedMonths.add(monthKey);
                      }
                    }
                  }
                  _updateDateRangeFromSelection();
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        
        // Grille de mois par année
        ...List.generate(3, (i) => now.year - i).map((year) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                year.toString(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(12, (i) => i + 1).map((month) {
                  final monthKey = '$year-${month.toString().padLeft(2, '0')}';
                  final isSelected = _selectedMonths.contains(monthKey);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedMonths.remove(monthKey);
                        } else {
                          _selectedMonths.add(monthKey);
                        }
                        _updateDateRangeFromSelection();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF556B2F) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF556B2F) : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        months[month - 1],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          );
        }).toList(),
      ],
    );
  }
  
  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF556B2F) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF556B2F) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF2C3E50),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'Aucun scrutin disponible'
                : 'Aucun scrutin trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[400],
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Essayez avec d\'autres mots-clés',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
