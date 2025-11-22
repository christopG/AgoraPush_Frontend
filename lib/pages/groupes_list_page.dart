import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'groupe_detail_page.dart';

class GroupesListPage extends StatefulWidget {
  const GroupesListPage({super.key});

  @override
  State<GroupesListPage> createState() => _GroupesListPageState();
}

class _GroupesListPageState extends State<GroupesListPage> {
  List<Map<String, dynamic>> _groupes = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();
  bool _showHeader = true;
  String _selectedMetric = 'effectif'; // Métrique actuellement affichée

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadGroupes();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 50 && _showHeader) {
      setState(() => _showHeader = false);
    } else if (_scrollController.offset <= 50 && !_showHeader) {
      setState(() => _showHeader = true);
    }
  }

  Future<void> _loadGroupes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groupesRaw = await ApiService.getActiveGroupesPolitiques();
      
      // Convertir en List<Map<String, dynamic>>
      final groupes = groupesRaw.cast<Map<String, dynamic>>();
      
      // Trier par effectif décroissant
      groupes.sort((a, b) {
        final effectifA = a['effectif'] ?? 0;
        final effectifB = b['effectif'] ?? 0;
        return effectifB.compareTo(effectifA);
      });

      setState(() {
        _groupes = groupes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des groupes: $e';
        _isLoading = false;
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

  Widget _buildBarChart(
    String title,
    IconData icon,
    Color color,
    List<MapEntry<String, double>> data, {
    double? maxValue,
  }) {
    if (data.isEmpty) return const SizedBox.shrink();
    
    // Trier par valeur décroissante
    data.sort((a, b) => b.value.compareTo(a.value));
    
    final max = maxValue ?? data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    if (max == 0) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...data.map((entry) {
              final percentage = max > 0 ? entry.value / max : 0.0;
              final couleurGroupe = _groupes.firstWhere(
                (g) => (g['libelle_abrev'] ?? g['libelle_abrege']) == entry.key,
                orElse: () => {},
              )['couleur_associee'];
              final barColor = couleurGroupe != null 
                  ? _getCouleur(couleurGroupe) 
                  : color.withOpacity(0.7);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          entry.value % 1 == 0 
                              ? entry.value.toInt().toString()
                              : entry.value.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 13,
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
                        value: percentage,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // AppBar with animation
          SliverAppBar(
            expandedHeight: 0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 2,
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
                          color: Colors.black.withOpacity(0.1),
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
                const Expanded(
                  child: Text(
                    'Groupes Politiques',
                    style: TextStyle(
                      color: Color(0xFF2C3E50),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    '${_groupes.length}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF6B8E23))),
                )
              : _errorMessage != null
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(_errorMessage!),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadGroupes,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Métrique selector chips
                          _buildMetricSelector(),
                          const SizedBox(height: 16),
                          
                          // Graphique de la métrique sélectionnée
                          _buildSelectedMetricChart(),
                          const SizedBox(height: 24),
                          
                          // Titre de la liste
                          const Text(
                            'Liste des groupes',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Liste des groupes
                          ..._groupes.map((groupe) => _buildGroupeCard(groupe)).toList(),
                        ]),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildMetricSelector() {
    final metrics = [
      {'key': 'effectif', 'label': 'Effectif', 'icon': Icons.people},
      {'key': 'women', 'label': 'Femmes', 'icon': Icons.female},
      {'key': 'age', 'label': 'Âge', 'icon': Icons.calendar_today},
      {'key': 'score_rose', 'label': 'Score Rose', 'icon': Icons.favorite},
      {'key': 'cohesion', 'label': 'Cohésion', 'icon': Icons.group_work},
      {'key': 'participation', 'label': 'Participation', 'icon': Icons.how_to_vote},
      {'key': 'majorite', 'label': 'Majorité', 'icon': Icons.check_circle},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: metrics.map((metric) {
          final isSelected = _selectedMetric == metric['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    metric['icon'] as IconData,
                    size: 16,
                    color: isSelected ? Colors.white : const Color(0xFF2C3E50),
                  ),
                  const SizedBox(width: 6),
                  Text(metric['label'] as String),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedMetric = metric['key'] as String;
                });
              },
              selectedColor: const Color(0xFF6B8E23),
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF2C3E50),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedMetricChart() {
    switch (_selectedMetric) {
      case 'effectif':
        return _buildBarChart(
          'Effectif par groupe',
          Icons.people,
          Colors.blue,
          _groupes.map((g) => MapEntry<String, double>(
            (g['libelle_abrev'] ?? g['libelle_abrege'] ?? 'N/A') as String,
            ((g['effectif'] ?? 0) as num).toDouble(),
          )).toList(),
        );
      case 'women':
        return _buildBarChart(
          'Pourcentage de femmes',
          Icons.female,
          Colors.pink,
          _groupes.map((g) {
            final effectif = (g['effectif'] ?? 0) as num;
            final women = (g['women'] ?? 0) as num;
            final percentage = effectif > 0 ? (women / effectif * 100) : 0.0;
            return MapEntry<String, double>(
              (g['libelle_abrev'] ?? g['libelle_abrege'] ?? 'N/A') as String,
              percentage,
            );
          }).toList(),
          maxValue: 100,
        );
      case 'age':
        return _buildBarChart(
          'Âge moyen',
          Icons.calendar_today,
          Colors.orange,
          _groupes.map((g) => MapEntry<String, double>(
            (g['libelle_abrev'] ?? g['libelle_abrege'] ?? 'N/A') as String,
            ((g['age'] ?? 0) as num).toDouble(),
          )).toList(),
          maxValue: 80,
        );
      case 'score_rose':
        return _buildBarChart(
          'Score Rose',
          Icons.favorite,
          Colors.red,
          _groupes.map((g) {
            final scoreStr = g['score_rose']?.toString() ?? '0';
            final score = double.tryParse(scoreStr) ?? 0.0;
            return MapEntry<String, double>(
              (g['libelle_abrev'] ?? g['libelle_abrege'] ?? 'N/A') as String,
              score,
            );
          }).toList(),
          maxValue: 1.0,
        );
      case 'cohesion':
        return _buildBarChart(
          'Cohésion du groupe',
          Icons.group_work,
          Colors.purple,
          _groupes.map((g) {
            final scoreStr = g['socre_cohesion']?.toString() ?? '0';
            final score = double.tryParse(scoreStr) ?? 0.0;
            return MapEntry<String, double>(
              (g['libelle_abrev'] ?? g['libelle_abrege'] ?? 'N/A') as String,
              score,
            );
          }).toList(),
          maxValue: 1.0,
        );
      case 'participation':
        return _buildBarChart(
          'Taux de participation',
          Icons.how_to_vote,
          Colors.green,
          _groupes.map((g) {
            final scoreStr = g['score_participation']?.toString() ?? '0';
            final score = double.tryParse(scoreStr) ?? 0.0;
            return MapEntry<String, double>(
              (g['libelle_abrev'] ?? g['libelle_abrege'] ?? 'N/A') as String,
              score,
            );
          }).toList(),
          maxValue: 1.0,
        );
      case 'majorite':
        return _buildBarChart(
          'Alignement majorité',
          Icons.check_circle,
          Colors.teal,
          _groupes.map((g) {
            final scoreStr = g['score_majorite']?.toString() ?? '0';
            final score = double.tryParse(scoreStr) ?? 0.0;
            return MapEntry<String, double>(
              (g['libelle_abrev'] ?? g['libelle_abrege'] ?? 'N/A') as String,
              score,
            );
          }).toList(),
          maxValue: 1.0,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGroupeCard(Map<String, dynamic> groupe) {
    final couleur = _getCouleur(groupe['couleur_associee']);
    final effectif = groupe['effectif'] ?? 0;
    final libelle = groupe['libelle'] ?? 'Groupe';
    final libelleAbrev = groupe['libelle_abrev'] ?? groupe['libelle_abrege'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupeDetailPage(groupe: groupe),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Bande de couleur
              Container(
                width: 6,
                height: 60,
                decoration: BoxDecoration(
                  color: couleur,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 16),
              // Informations
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      libelleAbrev.isNotEmpty ? libelleAbrev : libelle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      libelle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.people, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '$effectif député${effectif > 1 ? "s" : ""}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Icône chevron
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
}
