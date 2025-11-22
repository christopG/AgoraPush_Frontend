import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xml/xml.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models/scrutin_model.dart';
import '../data/models/deputy_model.dart';
import '../data/models/groupe_model.dart';
import '../providers/deputy_provider.dart';
import '../services/api_service.dart';
import 'scrutin_group_detail_page.dart';

class ScrutinDetailPage extends StatefulWidget {
  final ScrutinModel scrutin;

  const ScrutinDetailPage({super.key, required this.scrutin});

  @override
  State<ScrutinDetailPage> createState() => _ScrutinDetailPageState();
}

class _ScrutinDetailPageState extends State<ScrutinDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showHeaderContent = true;
  List<HemicycleSeatModel>? _hemicycleSeats;
  bool _isLoadingHemicycle = false;
  String _selectedGroupTab = 'pour'; // Onglet sélectionné pour les groupes
  Map<String, GroupeModel> _groupes = {}; // Cache des groupes politiques

  @override
  void initState() {
    super.initState();
    // 2 onglets si le scrutin a du contenu, sinon 1 seul (Résultats)
    _tabController = TabController(length: _hasScrutinContent() ? 2 : 1, vsync: this);
    _loadHemicycleData();
    _loadGroupes();
  }

  Future<void> _loadHemicycleData() async {
    setState(() => _isLoadingHemicycle = true);
    try {
      // Attendre que les députés soient chargés
      int attempts = 0;
      while (deputyProvider.deputies.isEmpty && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      
      if (deputyProvider.deputies.isEmpty) {
        print('⚠️ Aucun député chargé dans le cache après 5 secondes');
      } else {
        print('✅ ${deputyProvider.deputies.length} députés chargés dans le cache');
      }
      
      final seats = _buildHemicycleSeats();
      setState(() {
        _hemicycleSeats = seats;
        _isLoadingHemicycle = false;
      });
    } catch (e) {
      print('Erreur lors du chargement de l\'hémicycle: $e');
      setState(() => _isLoadingHemicycle = false);
    }
  }

  void _handleScroll(double offset) {
    setState(() {
      // Garder le sous-titre visible, masquer seulement titre, type, thèmes et date
      _showHeaderContent = offset <= 50;
    });
  }

  // Vérifie si le scrutin a du contenu à afficher dans l'onglet "Le scrutin"
  bool _hasScrutinContent() {
    return widget.scrutin.resume != null && widget.scrutin.resume!.isNotEmpty;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F2),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _hasScrutinContent()
                    ? [
                        _buildScrutinTab(),
                        _buildResultsTab(),
                      ]
                    : [
                        _buildResultsTab(),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bouton retour et TabBar
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
              Expanded(child: _buildTabBar()),
            ],
          ),
          const SizedBox(height: 16),

          // Sous-titre (devient le titre principal) - TOUJOURS VISIBLE
          if (widget.scrutin.sousTitre != null)
            Text(
              widget.scrutin.sousTitre!,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
                height: 1.3,
              ),
            ),

          // Titre (devient le sous-titre)
          if (_showHeaderContent && widget.scrutin.titre != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.scrutin.titre!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF556B2F).withOpacity(0.8),
                height: 1.4,
              ),
            ),
          ],

          // Type de scrutin
          if (_showHeaderContent && widget.scrutin.typeScrutin != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF556B2F).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF556B2F).withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Text(
                widget.scrutin.typeScrutin!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF556B2F),
                ),
              ),
            ),
          ],

          // Thèmes (bulles)
          if (_showHeaderContent && widget.scrutin.themesList.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.scrutin.themesList.map((theme) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Color(theme.getColor()).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
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

          // Date
          if (_showHeaderContent && widget.scrutin.dateScrutin != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: const Color(0xFF556B2F).withOpacity(0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.scrutin.formattedDate,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF556B2F).withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF556B2F),
          borderRadius: BorderRadius.circular(30),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF556B2F),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        dividerColor: Colors.transparent,
        tabs: _hasScrutinContent()
            ? const [
                Tab(text: 'Le scrutin'),
                Tab(text: 'Résultats'),
              ]
            : const [
                Tab(text: 'Résultats'),
              ],
      ),
    );
  }

  Widget _buildScrutinTab() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          _handleScroll(notification.metrics.pixels);
        }
        return false;
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(0),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          
          // Résumé - Style article de presse
          if (widget.scrutin.resume != null)
            _buildNewsSection(
              'Résumé',
              widget.scrutin.resume!,
              isLead: true,
              showInfoIcon: true,
            ),

          // Contexte
          if (widget.scrutin.contexte != null)
            _buildNewsSection(
              'Contexte',
              widget.scrutin.contexte!,
            ),

          // Contenu du texte
          if (widget.scrutin.contenuTexte != null)
            _buildNewsSection(
              'Contenu du texte',
              widget.scrutin.contenuTexte!,
            ),

          // Enjeux
          if (widget.scrutin.enjeux != null)
            _buildNewsSection(
              'Enjeux',
              widget.scrutin.enjeux!,
            ),

          // Arguments pour - Style article avec fond vert léger
          if (widget.scrutin.argumentPour != null)
            _buildArgumentSection(
              'Arguments POUR',
              widget.scrutin.argumentPour!,
              Colors.green,
            ),

          // Arguments contre - Style article avec fond rouge léger
          if (widget.scrutin.argumentContre != null)
            _buildArgumentSection(
              'Arguments CONTRE',
              widget.scrutin.argumentContre!,
              Colors.red,
            ),

          const SizedBox(height: 20),
        ],
      ),
      ),
    );
  }

  Widget _buildResultsTab() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          _handleScroll(notification.metrics.pixels);
        }
        return false;
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(0),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          
          // Titre "Résultats du vote"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  Icons.bar_chart,
                  size: 24,
                  color: const Color(0xFF556B2F),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Résultats du vote',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showAssemblyLayoutInfo,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF556B2F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xFF556B2F),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Hémicycle SVG
          if (_isLoadingHemicycle)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF556B2F),
                ),
              ),
            )
          else if (_hemicycleSeats != null && _hemicycleSeats!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildHemicycleWidget(),
            )
          else
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Aucune donnée d\'hémicycle disponible',
                style: TextStyle(color: Colors.grey),
              ),
            ),

          const SizedBox(height: 24),

          // Détail par groupe
          if (widget.scrutin.voteGroupe != null && widget.scrutin.voteGroupe!.isNotEmpty)
            _buildGroupDetails(),

          const SizedBox(height: 24),
        ],
      ),
      ),
    );
  }

  // Style article de presse inspiré de vote_detail_page
  Widget _buildNewsSection(String title, String content, {bool isLead = false, bool showInfoIcon = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre de section avec icône info optionnelle
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isLead ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF556B2F),
                  letterSpacing: 0.5,
                ),
              ),
              if (showInfoIcon) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showInfoPopup(context, 'Analyse générée par IA',
                      '''📋 POURQUOI NOUS UTILISONS L'IA

🎯 Contexte du projet
AgoraPush est un projet bénévole créé par des citoyens pour améliorer la transparence démocratique. Notre équipe de volontaires n'a pas le temps ni les ressources pour analyser manuellement les centaines de projets de loi votés chaque année à l'Assemblée nationale.

⚖️ Besoin de neutralité
Pour garantir une information objective et non partisane, nous utilisons l'intelligence artificielle qui permet d'analyser les textes législatifs sans biais politique personnel. L'IA nous aide à maintenir une neutralité éditoriale stricte.

🔍 Processus d'analyse en deux étapes

1️⃣ Classification automatique (IA Mistral)
- Identification du type de scrutin (projet de loi, amendement, motion...)
- Extraction des thèmes principaux
- Coût : ~0,001€ par scrutin

2️⃣ Analyse détaillée (IA Perplexity)
- Résumé, contexte, enjeux et arguments
- Recherche web pour informations actualisées
- Coût : ~0,05€ par scrutin analysé

🤖 PROMPT UTILISÉ (pour transparence complète)

Voici le prompt exact envoyé à l'IA Perplexity pour chaque analyse :

"Tu es un assistant juridique neutre, spécialisé dans la synthèse factuelle, vulgarisée et directement compréhensible par un grand public non-spécialiste.

📌 Classification automatique du type de scrutin
Analyse le titre et classe le scrutin dans l'une des catégories suivantes : Amendement, Sous-amendement, Article, Motion de censure, Motion de rejet, Question préalable, Exception d'irrecevabilité, Résolution, Proposition de loi, Projet de loi, Autre.

🎯 Identification des thèmes
Détecte automatiquement les thèmes principaux parmi : Écologie, Économie, Santé, Éducation, Justice, Défense, Social, Agriculture, Transport, Logement, Immigration, International, Numérique, Culture, Sport, Sécurité, Fonction publique, Collectivités territoriales, Autre.

📄 Structure obligatoire du rapport :

1. Sous-titre obligatoire : Formulation 'Pour ou contre [la mesure la plus contestée, formulée en langage clair]'

2. Résumé vulgarisé approfondi (400-500 mots) : Expliquez en détail les faits essentiels avec des exemples concrets et chiffrés

3. Contexte détaillé et historique (400-500 mots) : Historique complet, événements déclencheurs, évolution des chiffres, comparaisons avec d'autres pays

4. Contenu du texte explicité en détail (500-600 mots) : Description exhaustive de ce que la mesure change concrètement

5. Enjeux approfondis (500-600 mots) : Impacts économiques, sociaux, environnementaux avec données chiffrées

6. Arguments pour développés (5-6 raisons avec 80-120 mots chacune)

7. Arguments contre développés (5-6 réserves avec 80-120 mots chacune)

🔒 Contraintes de neutralité :
- Zéro jargon juridique
- Aucune prise de position
- Aucune mention de parti politique
- Reformulation neutre de tout argument partisan
- Sourçage systématique des chiffres"

✅ Sources utilisées par l'IA
L'IA consulte automatiquement :
- Sites officiels (assemblee-nationale.fr, gouvernement.fr)
- Médias français reconnus (Le Monde, Le Figaro, Libération, etc.)
- Institutions publiques (INSEE, Cour des comptes, ministères)
- Think tanks et organisations professionnelles

⚠️ Limites à garder à l'esprit
- L'IA peut parfois commettre des erreurs factuelles
- Les analyses reflètent les informations disponibles au moment de la génération
- En cas de doute, consultez toujours les sources officielles
- Ce contenu est à usage informatif et ne constitue pas un conseil juridique

🔄 Amélioration continue
Vos retours nous aident à améliorer la qualité des analyses. N'hésitez pas à nous signaler toute erreur ou imprécision.'''),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF556B2F).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Color(0xFF556B2F),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          
          // Séparateur
          Container(
            width: 50,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF556B2F).withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          // Contenu justifié comme un article
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              content,
              style: TextStyle(
                fontSize: isLead ? 15 : 14,
                fontWeight: isLead ? FontWeight.bold : FontWeight.normal,
                color: const Color(0xFF2C3E50),
                height: 1.7,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.justify,
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  // Section pour les arguments avec fond coloré et liste à puces
  Widget _buildArgumentSection(String title, String content, Color color) {
    // Parser le contenu pour extraire les éléments de liste
    List<String> arguments = _parseArgumentsList(content);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre avec icône
            Row(
              children: [
                Icon(
                  title.contains('POUR') ? Icons.thumb_up : Icons.thumb_down,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Liste à puces des arguments
            if (arguments.isNotEmpty)
              ...arguments.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 12),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          arguments[entry.key],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2C3E50),
                            height: 1.7,
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList()
            else
              // Fallback si pas de liste détectée
              Text(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2C3E50),
                  height: 1.7,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.justify,
              ),
          ],
        ),
      ),
    );
  }

  // Parser les arguments depuis le format JSON array ou texte simple
  List<String> _parseArgumentsList(String content) {
    try {
      // Nettoyer le contenu
      String cleaned = content.trim();
      
      // Vérifier si c'est un tableau JSON
      if (cleaned.startsWith('[') && cleaned.endsWith(']')) {
        // Parser le JSON
        final dynamic parsed = const JsonDecoder().convert(cleaned);
        if (parsed is List) {
          return parsed.map((e) => e.toString()).toList();
        }
      }
      
      // Sinon, essayer de détecter des paragraphes séparés par des retours à la ligne doubles
      if (cleaned.contains('\n\n')) {
        return cleaned.split('\n\n').where((s) => s.trim().isNotEmpty).toList();
      }
      
      // Sinon retourner une liste vide pour utiliser le fallback
      return [];
    } catch (e) {
      return [];
    }
  }

  // Construire les données de l'hémicycle à partir des votes
  List<HemicycleSeatModel> _buildHemicycleSeats() {
    List<HemicycleSeatModel> seats = [];
    
    try {
      // Parser les IDs des votes
      List<String> pourIds = _parseVoteIds(widget.scrutin.votePour);
      List<String> contreIds = _parseVoteIds(widget.scrutin.voteContre);
      List<String> abstentionIds = _parseVoteIds(widget.scrutin.voteAbstention);
      
      // Pour chaque député qui a voté, créer un siège
      for (String deputyId in pourIds) {
        final deputy = _getDeputyInfo(deputyId);
        if (deputy != null && deputy.placeHemicycle != null) {
          seats.add(HemicycleSeatModel(
            idDeputy: deputyId,
            nom: deputy.nom,
            prenom: deputy.prenom,
            position: 'pour',
            numPlace: deputy.placeHemicycle,
          ));
        }
      }
      
      for (String deputyId in contreIds) {
        final deputy = _getDeputyInfo(deputyId);
        if (deputy != null && deputy.placeHemicycle != null) {
          seats.add(HemicycleSeatModel(
            idDeputy: deputyId,
            nom: deputy.nom,
            prenom: deputy.prenom,
            position: 'contre',
            numPlace: deputy.placeHemicycle,
          ));
        }
      }
      
      for (String deputyId in abstentionIds) {
        final deputy = _getDeputyInfo(deputyId);
        if (deputy != null && deputy.placeHemicycle != null) {
          seats.add(HemicycleSeatModel(
            idDeputy: deputyId,
            nom: deputy.nom,
            prenom: deputy.prenom,
            position: 'abstention',
            numPlace: deputy.placeHemicycle,
          ));
        }
      }
    } catch (e) {
      print('Erreur lors de la construction des sièges: $e');
    }
    
    return seats;
  }

  // Parser les IDs de vote depuis le JSON string
  List<String> _parseVoteIds(String? voteData) {
    if (voteData == null || voteData.isEmpty) return [];
    
    try {
      // Nettoyer la chaîne : enlever les crochets et séparer par virgules
      String cleaned = voteData.trim();
      if (cleaned.startsWith('[')) {
        cleaned = cleaned.substring(1);
      }
      if (cleaned.endsWith(']')) {
        cleaned = cleaned.substring(0, cleaned.length - 1);
      }
      
      // Séparer par virgule et nettoyer chaque ID
      return cleaned
          .split(',')
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      print('Erreur lors du parsing des IDs de vote: $e');
    }
    
    return [];
  }

  // Récupérer les informations d'un député depuis le cache du DeputyProvider
  DeputyModel? _getDeputyInfo(String deputyId) {
    try {
      // Utiliser la liste des députés déjà en cache dans le DeputyProvider
      final deputy = deputyProvider.deputies.firstWhere(
        (d) => d.id == deputyId,
        orElse: () => throw Exception('Deputy not found'),
      );
      return deputy;
    } catch (e) {
      print('Député $deputyId non trouvé dans le cache');
      return null;
    }
  }

  // Afficher le popup d'information sur la disposition de l'Assemblée
  void _showAssemblyLayoutInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF556B2F),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Disposition de l\'Assemblée',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Contenu scrollable
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hémicycle SVG avec couleurs des groupes politiques
                          FutureBuilder<Map<String, dynamic>>(
                            future: _fetchPoliticalGroupsData(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF556B2F),
                                  ),
                                ),
                              );
                            }
                            
                            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text(
                                    'Impossible de charger les données des groupes',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              );
                            }

                            final groups = snapshot.data!['groups'] as Map<String, dynamic>? ?? {};
                            final deputies = snapshot.data!['deputies'] as List<dynamic>? ?? [];

                            return _PopupHemicycleSVGWidget(
                              groups: groups.entries.map((e) {
                                final groupData = e.value as Map<String, dynamic>;
                                return {
                                  'id': e.key,
                                  'color': groupData['color'],
                                };
                              }).toList(),
                              deputies: deputies,
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        // Texte explicatif
                        const Text(
                          'Groupes politiques',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'L\'hémicycle de l\'Assemblée nationale est organisé par groupes politiques. Chaque couleur représente un groupe parlementaire différent.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4A5568),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Légende des groupes
                        FutureBuilder<Map<String, dynamic>>(
                          future: _fetchPoliticalGroupsData(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            final groups = snapshot.data!['groups'] as Map<String, dynamic>? ?? {};
                            
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: groups.entries.map((entry) {
                                final groupData = entry.value as Map<String, dynamic>;
                                final color = _parseHexColorForLegend(groupData['color']?.toString() ?? '#CCCCCC');
                                final libelle = groupData['libelle']?.toString() ?? entry.key;
                                final count = groupData['count'] ?? 0;
                                
                                return Container(
                                  constraints: const BoxConstraints(maxWidth: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          libelle,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2C3E50),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '($count)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Afficher le popup d'information sur l'IA
  void _showInfoPopup(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF556B2F),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2C3E50),
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Charger les groupes politiques
  Future<void> _loadGroupes() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/groupes'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['groupes'] != null) {
          final Map<String, GroupeModel> groupes = {};
          for (var groupeJson in data['groupes']) {
            final groupe = GroupeModel.fromJson(groupeJson);
            groupes[groupe.id] = groupe;
          }
          setState(() {
            _groupes = groupes;
          });
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des groupes: $e');
    }
  }

  // Récupérer les données des groupes politiques depuis l'API
  Future<Map<String, dynamic>> _fetchPoliticalGroupsData() async {
    try {
      // Utiliser le cache déjà chargé des groupes
      if (_groupes.isEmpty) {
        await _loadGroupes();
      }
      
      // Utiliser les députés déjà chargés depuis le provider
      final allDeputies = deputyProvider.deputies;
      
      // Convertir les députés en format Map pour le widget SVG
      List<Map<String, dynamic>> deputiesList = allDeputies.map((deputy) => {
        'placeHemicycle': deputy.placeHemicycle,
        'groupe_politique_ref': deputy.groupePolitiqueRef,
      }).toList();
      
      // Créer une Map id -> {couleur, libelle, count}
      Map<String, Map<String, dynamic>> groupsMap = {};
      
      // Compter les députés par groupe
      Map<String, int> deputyCount = {};
      for (var deputy in allDeputies) {
        if (deputy.groupePolitiqueRef != null) {
          deputyCount[deputy.groupePolitiqueRef!] = 
            (deputyCount[deputy.groupePolitiqueRef!] ?? 0) + 1;
        }
      }
      
      // Construire la map des groupes avec toutes les infos
      for (var groupe in _groupes.values) {
        if (groupe.couleurAssociee != null && groupe.couleurAssociee!.isNotEmpty) {
          groupsMap[groupe.id] = {
            'color': groupe.couleurAssociee,
            'libelle': groupe.libelle ?? groupe.id,
            'count': deputyCount[groupe.id] ?? 0,
          };
        }
      }
      
      return {
        'groups': groupsMap,
        'deputies': deputiesList,
      };
    } catch (e) {
      print('Erreur lors de la récupération des groupes politiques: $e');
    }
    return {};
  }

  // Parser le JSON vote_groupe (format non-standard sans guillemets)
  Map<String, dynamic> _parseVoteGroupe(String voteGroupeStr) {
    Map<String, dynamic> result = {};
    
    try {
      // Ajouter les guillemets manquants autour des clés et valeurs de chaînes
      String cleaned = voteGroupeStr
          .replaceAllMapped(
              RegExp(r'(\w+):'), (match) => '"${match.group(1)}":')
          .replaceAllMapped(
              RegExp(r':\s*([A-Z]\w+)'), (match) => ': "${match.group(1)}"');
      
      result = Map<String, dynamic>.from(json.decode(cleaned));
    } catch (e) {
      print('Erreur parsing vote_groupe: $e');
    }
    
    return result;
  }

  // Parser une couleur hexadécimale
  Color _parseHexColorForLegend(String hexColor) {
    try {
      String hex = hexColor.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  // Widget pour le détail par groupe
  Widget _buildGroupDetails() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Détail par groupe',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 16),
          _buildGroupTabs(),
          const SizedBox(height: 16),
          _buildGroupTabContent(),
        ],
      ),
    );
  }

  // Widget pour les onglets des groupes
  Widget _buildGroupTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildGroupTab('Pour', 'pour', const Color(0xFF5BA282), 0),
          _buildGroupTab('Contre', 'contre', const Color(0xFFD95C3F), 1),
          _buildGroupTab('Abstention', 'abstention', const Color(0xFFFF8C00), 2),
        ],
      ),
    );
  }

  // Widget pour un onglet de groupe
  Widget _buildGroupTab(String label, String tabKey, Color color, int index) {
    final isSelected = _selectedGroupTab == tabKey;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedGroupTab = tabKey;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }

  // Widget pour le contenu de l'onglet sélectionné
  Widget _buildGroupTabContent() {
    // Parser le JSON vote_groupe (format non-standard sans guillemets)
    Map<String, dynamic> voteGroupe = {};
    try {
      if (widget.scrutin.voteGroupe != null && widget.scrutin.voteGroupe!.isNotEmpty) {
        voteGroupe = _parseVoteGroupe(widget.scrutin.voteGroupe!);
      }
    } catch (e) {
      print('Erreur lors du parsing du vote_groupe: $e');
      return const Text('Erreur de chargement des données');
    }

    // Filtrer les groupes selon l'onglet sélectionné
    List<MapEntry<String, dynamic>> filteredGroups = [];
    
    for (var entry in voteGroupe.entries) {
      final groupId = entry.key;
      final votes = entry.value as Map<String, dynamic>;
      final pour = votes['pour'] ?? 0;
      final contre = votes['contre'] ?? 0;
      final abstention = votes['abstention'] ?? 0;
      final total = pour + contre + abstention;

      if (total == 0) continue;

      // Déterminer la majorité du groupe
      int maxVote = pour;
      String majority = 'pour';
      
      if (contre > maxVote) {
        maxVote = contre;
        majority = 'contre';
      }
      if (abstention > maxVote) {
        maxVote = abstention;
        majority = 'abstention';
      }

      // Ajouter si correspond à l'onglet sélectionné
      if (majority == _selectedGroupTab) {
        filteredGroups.add(entry);
      }
    }

    if (filteredGroups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'Aucun groupe dans cette catégorie',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    // Trier par nombre de votes dans la catégorie
    filteredGroups.sort((a, b) {
      final votesA = (a.value as Map<String, dynamic>)[_selectedGroupTab] ?? 0;
      final votesB = (b.value as Map<String, dynamic>)[_selectedGroupTab] ?? 0;
      return votesB.compareTo(votesA);
    });

    return Column(
      children: filteredGroups.map((entry) {
        return _buildGroupCard(entry.key, entry.value as Map<String, dynamic>);
      }).toList(),
    );
  }

  // Widget pour une carte de groupe
  Widget _buildGroupCard(String groupId, Map<String, dynamic> votes) {
    final pour = votes['pour'] ?? 0;
    final contre = votes['contre'] ?? 0;
    final abstention = votes['abstention'] ?? 0;
    final total = pour + contre + abstention;

    if (total == 0) return const SizedBox.shrink();

    final pourPct = pour / total;
    final contrePct = contre / total;
    final abstentionPct = abstention / total;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScrutinGroupDetailPage(
              groupId: groupId,
              scrutin: widget.scrutin,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
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
            // En-tête avec nom du groupe et nombre de députés
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _groupes[groupId]?.libelle ?? groupId,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF556B2F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$total député${total > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF556B2F),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Graphique en barres
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  if (pourPct > 0)
                    Expanded(
                      flex: (pourPct * 1000).round(),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5BA282),
                          borderRadius: pourPct == 1
                              ? BorderRadius.circular(8)
                              : const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                        ),
                      ),
                    ),
                  if (contrePct > 0)
                    Expanded(
                      flex: (contrePct * 1000).round(),
                      child: Container(
                        height: 12,
                        color: const Color(0xFFD95C3F),
                      ),
                    ),
                  if (abstentionPct > 0)
                    Expanded(
                      flex: (abstentionPct * 1000).round(),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF8C00),
                          borderRadius: abstentionPct == 1
                              ? BorderRadius.circular(8)
                              : const BorderRadius.only(
                                  topRight: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Détails des votes (une seule ligne)
            Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.start,
              children: [
                _buildCompactVoteStat('Pour', pour, const Color(0xFF5BA282)),
                _buildCompactVoteStat('Contre', contre, const Color(0xFFD95C3F)),
                _buildCompactVoteStat('Abstention', abstention, const Color(0xFFFF8C00)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget pour une statistique de vote compacte
  Widget _buildCompactVoteStat(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label : $count',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Graphique en barre horizontale
  // Widget pour l'hémicycle SVG
  Widget _buildHemicycleWidget() {
    return HemicycleSVGWidget(
      seats: _hemicycleSeats!,
      scrutin: widget.scrutin,
    );
  }
}

// Widget SVG pour l'hémicycle du popup avec couleurs des groupes politiques
class _PopupHemicycleSVGWidget extends StatefulWidget {
  final List<dynamic> groups;
  final List<dynamic> deputies;

  const _PopupHemicycleSVGWidget({
    required this.groups,
    required this.deputies,
  });

  @override
  State<_PopupHemicycleSVGWidget> createState() => _PopupHemicycleSVGWidgetState();
}

class _PopupHemicycleSVGWidgetState extends State<_PopupHemicycleSVGWidget> {
  String? _svgContent;
  bool _isSvgLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSVG();
  }

  Future<void> _loadSVG() async {
    try {
      final String svgString = await rootBundle.loadString('data/hemicycle-an.svg');
      setState(() {
        _svgContent = svgString;
        _isSvgLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement du SVG: $e');
      setState(() {
        _isSvgLoading = false;
      });
    }
  }

  void _cleanSvgDocument(XmlElement svg) {
    final elementsToRemove = <XmlElement>[];

    void findProblematicElements(XmlElement element) {
      for (final child in element.children.whereType<XmlElement>()) {
        if (child.name.local == 'sodipodi:namedview' ||
            child.name.local == 'metadata') {
          elementsToRemove.add(child);
        } else {
          findProblematicElements(child);
        }
      }
    }

    findProblematicElements(svg);

    for (final element in elementsToRemove) {
      try {
        element.remove();
      } catch (e) {
        print('Erreur lors de la suppression d\'élément: $e');
      }
    }

    final problematicAttributes = [
      'xmlns:sodipodi',
      'xmlns:inkscape',
      'sodipodi:docname',
      'inkscape:version',
    ];

    for (final attr in problematicAttributes) {
      try {
        svg.removeAttribute(attr);
      } catch (e) {
        print('Erreur lors de la suppression d\'attribut: $e');
      }
    }
  }

  String _modifySvgForPoliticalParties() {
    if (_svgContent == null) return '';

    try {
      final document = XmlDocument.parse(_svgContent!);
      final svg = document.rootElement;

      svg.setAttribute('viewBox', '0 0 900 600');
      svg.setAttribute('width', '900');
      svg.setAttribute('height', '600');

      _cleanSvgDocument(svg);

      // Créer un map des sièges par groupe
      final seatGroupMap = <String, String>{};
      for (final deputy in widget.deputies) {
        final placeHemicycle = deputy['placeHemicycle']?.toString();
        final groupeRef = deputy['groupe_politique_ref']?.toString();
        if (placeHemicycle != null && groupeRef != null) {
          seatGroupMap[placeHemicycle] = groupeRef;
        }
      }

      // Créer un map des couleurs par groupe
      final groupColorMap = <String, String>{};
      for (final group in widget.groups) {
        final id = group['id']?.toString();
        final color = group['color']?.toString();
        if (id != null && color != null) {
          groupColorMap[id] = color;
        }
      }

      final paths = svg.findAllElements('path').where(
        (element) => element.getAttribute('place') != null,
      ).toList();

      for (final path in paths) {
        final placeAttr = path.getAttribute('place');
        if (placeAttr != null && seatGroupMap.containsKey(placeAttr)) {
          final groupId = seatGroupMap[placeAttr]!;
          final color = groupColorMap[groupId] ?? '#CCCCCC';
          path.setAttribute('fill', color);
        }
      }

      return document.toXmlString();
    } catch (e) {
      print('Erreur lors de la modification du SVG: $e');
      return _svgContent ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSvgLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF556B2F),
        ),
      );
    }

    if (_svgContent == null) {
      return const Center(
        child: Text(
          'Erreur lors du chargement de l\'hémicycle',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final modifiedSvg = _modifySvgForPoliticalParties();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SvgPicture.string(
        modifiedSvg,
        width: double.infinity,
        height: 300,
        fit: BoxFit.contain,
      ),
    );
  }
}

// Modèle pour un siège d'hémicycle
class HemicycleSeatModel {
  final String? idDeputy;
  final String? nom;
  final String? prenom;
  final String? position;
  final String? numPlace;

  HemicycleSeatModel({
    this.idDeputy,
    this.nom,
    this.prenom,
    this.position,
    this.numPlace,
  });
}

// Widget SVG pour l'hémicycle
class HemicycleSVGWidget extends StatefulWidget {
  final List<HemicycleSeatModel> seats;
  final ScrutinModel scrutin;

  const HemicycleSVGWidget({
    super.key,
    required this.seats,
    required this.scrutin,
  });

  @override
  State<HemicycleSVGWidget> createState() => _HemicycleSVGWidgetState();
}

class _HemicycleSVGWidgetState extends State<HemicycleSVGWidget> {
  String? _svgContent;
  bool _isSvgLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSVG();
  }

  Future<void> _loadSVG() async {
    try {
      final String svgString = await rootBundle.loadString('data/hemicycle-an.svg');
      setState(() {
        _svgContent = svgString;
        _isSvgLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement du SVG: $e');
      setState(() {
        _isSvgLoading = false;
      });
    }
  }

  void _showZoomedImage(BuildContext context, String svgContent) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext dialogContext) {
        return GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: GestureDetector(
              onTap: () {}, // Empêcher la fermeture en cliquant sur l'image
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: SvgPicture.string(
                    svgContent,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Nettoyer le SVG des éléments problématiques
  void _cleanSvgDocument(XmlElement svg) {
    final elementsToRemove = <XmlElement>[];

    void findProblematicElements(XmlElement element) {
      for (final child in element.children.whereType<XmlElement>()) {
        if (child.name.local == 'sodipodi:namedview' ||
            child.name.local == 'metadata') {
          elementsToRemove.add(child);
        } else {
          findProblematicElements(child);
        }
      }
    }

    findProblematicElements(svg);

    for (final element in elementsToRemove) {
      try {
        element.remove();
      } catch (e) {
        print('Erreur lors de la suppression d\'élément: $e');
      }
    }

    final problematicAttributes = [
      'xmlns:sodipodi',
      'xmlns:inkscape',
      'sodipodi:docname',
      'inkscape:version',
    ];

    for (final attr in problematicAttributes) {
      try {
        svg.removeAttribute(attr);
      } catch (e) {
        print('Erreur lors de la suppression d\'attribut: $e');
      }
    }
  }

  String _getColorForPosition(String? position) {
    switch (position) {
      case 'pour':
        return '#5BA282';
      case 'contre':
        return '#D95C3F';
      case 'abstention':
        return '#FF8C00';
      default:
        return '#E0E0E0';
    }
  }

  String _modifySvgForSeats() {
    if (_svgContent == null) return '';

    try {
      final document = XmlDocument.parse(_svgContent!);
      final svg = document.rootElement;

      svg.setAttribute('viewBox', '0 0 900 600');
      svg.setAttribute('width', '900');
      svg.setAttribute('height', '600');
      svg.setAttribute('style', 'overflow: visible;');

      _cleanSvgDocument(svg);

      // Créer une map des positions
      final seatPositionMap = <String, String>{};
      for (final seat in widget.seats) {
        if (seat.numPlace != null && seat.position != null) {
          seatPositionMap[seat.numPlace!] = seat.position!;
        }
      }

      // Trouver tous les éléments path avec l'attribut place
      final paths = svg.findAllElements('path').where(
        (element) => element.getAttribute('place') != null,
      ).toList();

      int matchedSeats = 0;
      for (final path in paths) {
        final placeAttr = path.getAttribute('place');
        if (placeAttr != null && seatPositionMap.containsKey(placeAttr)) {
          final position = seatPositionMap[placeAttr]!;
          final color = _getColorForPosition(position);
          path.setAttribute('fill', color);
          matchedSeats++;
        }
      }

      

      return document.toXmlString();
    } catch (e) {
      print('Erreur lors de la modification du SVG: $e');
      return _svgContent ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSvgLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF556B2F),
        ),
      );
    }

    if (_svgContent == null) {
      return const Center(
        child: Text(
          'Erreur lors du chargement de l\'hémicycle',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final modifiedSvg = _modifySvgForSeats();

    final total = (widget.scrutin.nbPour ?? 0) +
        (widget.scrutin.nbContre ?? 0) +
        (widget.scrutin.nbAbstentions ?? 0);
    final pourPct = total > 0 ? (widget.scrutin.nbPour ?? 0) / total : 0.0;
    final contrePct = total > 0 ? (widget.scrutin.nbContre ?? 0) / total : 0.0;
    final abstPct = total > 0 ? (widget.scrutin.nbAbstentions ?? 0) / total : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showZoomedImage(context, modifiedSvg),
            child: SvgPicture.string(
              modifiedSvg,
              width: double.infinity,
              height: 280,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          // Barre de répartition
          const Text(
            'Répartition des votes',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF556B2F),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                if (pourPct > 0)
                  Expanded(
                    flex: (pourPct * 1000).round(),
                    child: Container(
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFF5BA282),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                      ),
                    ),
                  ),
                if (contrePct > 0)
                  Expanded(
                    flex: (contrePct * 1000).round(),
                    child: Container(
                      height: 12,
                      color: const Color(0xFFD95C3F),
                    ),
                  ),
                if (abstPct > 0)
                  Expanded(
                    flex: (abstPct * 1000).round(),
                    child: Container(
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF8C00),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('Pour', widget.scrutin.nbPour ?? 0, pourPct, const Color(0xFF5BA282)),
              _buildStatColumn('Contre', widget.scrutin.nbContre ?? 0, contrePct, const Color(0xFFD95C3F)),
              _buildStatColumn('Abstention', widget.scrutin.nbAbstentions ?? 0, abstPct, const Color(0xFFFF8C00)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, int value, double percentage, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(percentage * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF4A5568),
          ),
        ),
      ],
    );
  }
}
