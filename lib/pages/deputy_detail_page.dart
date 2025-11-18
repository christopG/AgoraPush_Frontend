import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models/deputy_model.dart';
import '../widgets/hemicycle_widget.dart';

class MandatInfo {
  final String statut;
  final String organisme;
  
  MandatInfo(this.statut, this.organisme);
}

class MandatTypeInfo {
  final String label;
  final IconData icon;
  
  MandatTypeInfo(this.label, this.icon);
}

class DeputyDetailPage extends StatefulWidget {
  final DeputyModel deputy;

  const DeputyDetailPage({super.key, required this.deputy});

  @override
  State<DeputyDetailPage> createState() => _DeputyDetailPageState();
}

class _DeputyDetailPageState extends State<DeputyDetailPage> {
  late DeputyModel _deputy;
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _deputy = widget.deputy;
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _getDeputyPhotoUrl(String deputyId) {
    // Supprime le préfixe "PA" de l'ID pour obtenir l'URL de la photo
    final photoId = deputyId.replaceFirst('PA', '');
    return 'https://www.assemblee-nationale.fr/dyn/static/tribun/17/photos/carre/$photoId.jpg';
  }

  Future<void> _launchUrl(String url) async {
    print('Ouverture URL: $url');
    try {
      final uri = Uri.parse(url);

      // Essaie d'abord avec le navigateur externe
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
        ),
      );

      if (launched) {
        print('✅ URL ouverte avec succès en mode externe');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ouverture de la déclaration de patrimoine...'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print('❌ Échec ouverture mode externe, essai mode platformDefault');
        // Si ça échoue, essaie avec le mode par défaut
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);

        if (launched) {
          print('✅ URL ouverte avec succès en mode platformDefault');
        } else {
          print('❌ Impossible d\'ouvrir l\'URL avec tous les modes');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Impossible d\'ouvrir le lien: $url'),
                duration: const Duration(seconds: 3),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('🚫 Erreur lors de l\'ouverture de l\'URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDeputyAvatar(DeputyModel deputy) {
    return CircleAvatar(
      radius: 36,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Image.network(
          _getDeputyPhotoUrl(deputy.id),
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Si la photo ne charge pas, afficher les initiales
            return Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${deputy.prenom[0]}${deputy.nom[0]}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            // Pendant le chargement, afficher un indicateur
            return Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  int? get _age {
    if (_deputy.dateNaissance == null) return null;
    final now = DateTime.now();
    final birth = _deputy.dateNaissance!;
    int age = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE8F4F8),
                  Color(0xFFF0F8F0),
                  Color(0xFFF8F0F8),
                ],
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header with back button and title
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
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF556B2F).withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF556B2F),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Député',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF556B2F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Scrollable content
                Expanded(
                  child: Column(
                    children: [
                      // Indicateurs de pages
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildPageIndicator(0, 'Informations'),
                              const SizedBox(width: 12),
                              _buildPageIndicator(1, 'Mandats'),
                              const SizedBox(width: 12),
                              _buildPageIndicator(2, 'Votes'),
                              const SizedBox(width: 12),
                              _buildPageIndicator(3, 'Performance'),
                            ],
                          ),
                        ),
                      ),
                      // PageView avec les trois blocs
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          children: [
                            // Bloc 1: Données personnelles + Transparence + Parti politique
                            _buildPersonalInfoPage(),
                            // Bloc 2: Autres mandats et fonctions
                            _buildMandatsPage(),
                            // Bloc 3: Votes à l'Assemblée
                            _buildVotesPage(),
                            // Bloc 4: Performance et comportement
                            _buildPerformancePage(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int index, String label) {
    final isActive = _currentPage == index;
    return GestureDetector(
      onTap: () => _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF556B2F)
              : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFF556B2F)
                : Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF556B2F),
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF556B2F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFF556B2F),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF556B2F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF556B2F),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF556B2F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPartiPolitiqueLibelle() {
    // Essayer d'abord le libellé depuis la DB (JOIN avec groupePolitique)
    if (_deputy.famillePolLibelleDb != null && _deputy.famillePolLibelleDb!.isNotEmpty) {
      return _deputy.famillePolLibelleDb!;
    }
    
    // Fallback vers les champs existants
    if (_deputy.famillePolLibelle != null && _deputy.famillePolLibelle!.isNotEmpty) {
      return _deputy.famillePolLibelle!;
    }
    
    // Utiliser famillesPol comme dernier recours
    if (_deputy.famillesPol != null && _deputy.famillesPol!.isNotEmpty) {
      return _deputy.famillesPol!;
    }
    
    return 'Non spécifié';
  }

  Widget _buildPersonalInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Carte principale avec les informations essentielles
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildDeputyAvatar(_deputy),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _deputy.fullName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF556B2F),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_deputy.famillePolLibelle != null &&
                          _deputy.famillePolLibelle!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF556B2F).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _deputy.famillePolLibelle!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF556B2F),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        _deputy.circonscriptionComplete,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Informations personnelles
          _buildSectionCard('Informations personnelles', [
            if (_deputy.dateNaissance != null && _age != null) ...[
              _buildInfoRow(
                'Naissance',
                '${_formatDate(_deputy.dateNaissance!)} ($_age ans)',
              ),
            ],
            if (_deputy.profession != null && _deputy.profession!.isNotEmpty)
              _buildInfoRow('Profession', _deputy.profession!),
            if (_deputy.catSocPro != null && _deputy.catSocPro!.isNotEmpty)
              _buildInfoRow('Catégorie socio-professionnelle', _deputy.catSocPro!),
            if (_deputy.nombreMandats != null)
              _buildInfoRow(
                'Nombre de mandats',
                '${_deputy.nombreMandats}${_deputy.experienceDepute != null ? ' (${_deputy.experienceDepute} ans d\'expérience)' : ''}',
              ),
            if (_deputy.mail != null && _deputy.mail!.isNotEmpty)
              _buildInfoRow('Contact', _deputy.mail!),
          ]),
          const SizedBox(height: 16),

          // Déclaration de patrimoine (cadre séparé)
          if (_deputy.uriHatvp != null && _deputy.uriHatvp!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF556B2F).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Color(0xFF556B2F),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Transparence financière',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF556B2F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _launchUrl(_deputy.uriHatvp!),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF556B2F).withOpacity(0.1),
                            const Color(0xFF556B2F).withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFF556B2F).withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF556B2F),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.open_in_new,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Déclaration de patrimoine',
                                  style: TextStyle(
                                    color: Color(0xFF556B2F),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Consultez la déclaration officielle sur le site de la HATVP',
                                  style: TextStyle(
                                    color: Color(0xFF556B2F),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 18,
                            color: Color(0xFF556B2F),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Déclaration obligatoire auprès de la Haute Autorité pour la transparence de la vie publique',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Parti politique
          _buildSectionCard('Parti politique', [
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getPartiPolitiqueLibelle(),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF556B2F),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  HemicycleWidget(
                    placeHemicycle: _deputy.placeHemicycle,
                    groupeAbrev: _deputy.famillesPol,
                    famillePolLibelle: _deputy.famillePolLibelle ??
                        _deputy.famillePolLibelleDb,
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // Sources
          _buildSourcesCard(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMandatsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // Section des mandats
          if (_deputy.mandatsResume != null && _deputy.mandatsResume!.isNotEmpty)
            _buildStructuredMandatsCard()
          else
            _buildEmptyMandatsCard(),

          const SizedBox(height: 24),

          // Sources
          _buildSourcesCard(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStructuredMandatsCard() {
    final mandats = _parseMandats(_deputy.mandatsResume ?? '');
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF556B2F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.work_outline,
                  color: Color(0xFF556B2F),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Mandats et fonctions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF556B2F),
                ),
              ),
              if (mandats.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '(${mandats.length} type${mandats.length > 1 ? 's' : ''})',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),

          if (mandats.isEmpty) ...[
            const SizedBox(height: 20),
            _buildEmptyMandatsContent(),
          ] else ...[
            const SizedBox(height: 20),
            ...mandats.entries.map((entry) => _buildMandatTypeSection(entry.key, entry.value)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyMandatsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF556B2F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.work_outline,
                  color: Color(0xFF556B2F),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Mandats et fonctions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF556B2F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildEmptyMandatsContent(),
        ],
      ),
    );
  }

  Widget _buildEmptyMandatsContent() {
    return Column(
      children: [
        Icon(
          Icons.work_outline,
          size: 32,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 12),
        Text(
          'Aucun autre mandat',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Aucun autre mandat ou fonction n\'est enregistré.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[500],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Map<String, List<MandatInfo>> _parseMandats(String mandatsStr) {
    final Map<String, List<MandatInfo>> result = {};
    
    // Diviser par points-virgules pour séparer chaque mandat
    final mandatsList = mandatsStr.split(';').where((m) => m.trim().isNotEmpty).toList();
    
    for (final mandatStr in mandatsList) {
      final trimmed = mandatStr.trim();
      if (trimmed.isEmpty) continue;
      
      // Format attendu : "TYPE: STATUT (ORGANISME)" ou "TYPE: STATUT"
      final colonIndex = trimmed.indexOf(':');
      if (colonIndex == -1) continue;
      
      final type = trimmed.substring(0, colonIndex).trim();
      final reste = trimmed.substring(colonIndex + 1).trim();
      
      String statut;
      String organisme = '';
      
      // Chercher des parenthèses pour extraire l'organisme
      final parenthesesMatch = RegExp(r'(.+?)\s*\((.+)\)').firstMatch(reste);
      if (parenthesesMatch != null) {
        statut = parenthesesMatch.group(1)!.trim();
        organisme = parenthesesMatch.group(2)!.trim();
      } else {
        statut = reste;
      }
      
      result.putIfAbsent(type, () => []).add(MandatInfo(statut, organisme));
    }
    
    return result;
  }

  Widget _buildMandatTypeSection(String type, List<MandatInfo> mandats) {
    final typeInfo = _getMandatTypeInfo(type);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du type avec icône
          Row(
            children: [
              Icon(
                typeInfo.icon,
                size: 18,
                color: const Color(0xFF556B2F),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${typeInfo.label} (${mandats.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF556B2F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Liste des mandats pour ce type
          ...mandats.asMap().entries.map((entry) {
            final index = entry.key;
            final mandat = entry.value;
            final isLast = index == mandats.length - 1;
            
            return Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF556B2F).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF556B2F).withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Bullet point
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF556B2F),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Contenu du mandat
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Statut (gras)
                        Text(
                          mandat.statut,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF556B2F),
                          ),
                        ),
                        // Organisme (si disponible)
                        if (mandat.organisme.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            mandat.organisme,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  MandatTypeInfo _getMandatTypeInfo(String type) {
    switch (type.toUpperCase()) {
      case 'CMP':
        return MandatTypeInfo('Commission mixte paritaire', Icons.gavel_outlined);
      case 'GA':
        return MandatTypeInfo('Groupe d\'amitié', Icons.handshake_outlined);
      case 'GE':
        return MandatTypeInfo('Groupe d\'études', Icons.school_outlined);
      case 'GEVI':
        return MandatTypeInfo('Groupe d\'études à vocation internationale', Icons.language_outlined);
      case 'COMPER':
        return MandatTypeInfo('Commission permanente', Icons.account_balance_outlined);
      case 'ORGEXTPARL':
        return MandatTypeInfo('Organisme extra-parlementaire', Icons.business_outlined);
      case 'COMNL':
        return MandatTypeInfo('Commission nationale', Icons.flag_outlined);
      case 'GP':
        return MandatTypeInfo('Groupe parlementaire', Icons.groups_outlined);
      case 'ASSEMBLEE':
        return MandatTypeInfo('Assemblée nationale', Icons.account_balance_outlined);
      case 'MISINFO':
        return MandatTypeInfo('Mission d\'information', Icons.search_outlined);
      case 'DELEG':
        return MandatTypeInfo('Délégation', Icons.people_outline);
      case 'BUREAU':
        return MandatTypeInfo('Bureau', Icons.work_outline);
      case 'COMMISSION':
        return MandatTypeInfo('Commission', Icons.gavel_outlined);
      default:
        return MandatTypeInfo(type, Icons.circle_outlined);
    }
  }

  Widget _buildVotesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // Section des votes (à compléter plus tard)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.how_to_vote_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Votes à l\'Assemblée',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cette section sera complétée prochainement avec les détails des votes du député.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Sources
          _buildSourcesCard(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPerformancePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // Section Scores de performance
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF556B2F).withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header avec icône moderne
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF556B2F), Color(0xFF5BA282)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.analytics_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Scores de performance',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF556B2F),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Score de participation
                _buildScoreItem(
                  'Participation générale',
                  'Présence aux votes à l\'Assemblée',
                  (_deputy.scoreParticipation ?? 0.0) * 100,
                  Icons.how_to_vote_rounded,
                  const Color(0xFF556B2F),
                ),

                const SizedBox(height: 20),

                // Score de participation spécialisée
                _buildScoreItem(
                  'Participation spécialisée',
                  'Participation aux votes de spécialité',
                  (_deputy.scoreParticipationSpectialite ?? 0.0) * 100,
                  Icons.psychology_outlined,
                  const Color(0xFF5BA282),
                ),

                const SizedBox(height: 20),

                // Score de loyauté
                _buildScoreItem(
                  'Loyauté au groupe',
                  'Cohérence avec la ligne du parti',
                  (_deputy.scoreLoyaute ?? 0.0) * 100,
                  Icons.groups_outlined,
                  const Color(0xFF789F32),
                ),

                const SizedBox(height: 20),

                // Score de majorité si disponible
                if (_deputy.scoreMajorite != null)
                  _buildScoreItem(
                    'Soutien à la majorité',
                    'Votes en faveur de la majorité',
                    _deputy.scoreMajorite! * 100,
                    Icons.thumb_up_outlined,
                    const Color(0xFF8FA862),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Attribution des données
          _buildSourcesCard(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildScoreItem(
    String title,
    String description,
    double score,
    IconData icon,
    Color color,
  ) {
    final scorePercentage = score.clamp(0.0, 100.0);

    Color getScoreColor(double score) {
      if (score >= 80) return const Color(0xFF556B2F); // Vert principal
      if (score >= 60) return const Color(0xFF5BA282); // Vert secondaire
      if (score >= 40) return const Color(0xFF8FA862); // Vert olive clair
      return const Color(0xFFA0A4A8); // Gris neutre
    }

    final scoreColor = getScoreColor(scorePercentage);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.03),
            color.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec icône et titre
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Score badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: scoreColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: scoreColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${scorePercentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Barre de progression moderne
          Stack(
            children: [
              // Barre de fond
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Barre de score avec animation
              Container(
                height: 6,
                width: (scorePercentage / 100) *
                    MediaQuery.of(context).size.width *
                    0.7,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scoreColor, scoreColor.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: scoreColor.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourcesCard() {
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
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
                children: const [
                  TextSpan(text: 'Sources : '),
                  TextSpan(
                    text: 'Assemblée nationale, Regards citoyens',
                    style: TextStyle(
                      color: Color(0xFF556B2F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              const url = 'https://www.nosdeputes.fr/';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              }
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF556B2F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.open_in_new,
                size: 14,
                color: Color(0xFF556B2F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}