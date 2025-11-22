import 'theme_model.dart';

class ScrutinModel {
  final String uid;
  final String? numero;
  final String? organeRef;
  final String? legislature;
  final DateTime? dateScrutin;
  final String? titre;
  final String? objet;
  final String? typeVote;
  final String? modePublication;
  final String? sujet;
  final int? nbVotants;
  final int? nbExprimes;
  final int? nbPour;
  final int? nbContre;
  final int? nbAbstentions;
  final int? nbNonVotants;
  final String? voteAbstention;
  final String? voteContre;
  final String? voteGroupe;
  final String? votePour;
  final String? argumentContre;
  final String? argumentPour;
  final String? contenuTexte;
  final String? contexte;
  final String? enjeux;
  final String? resume;
  final String? themes;
  final String? typeScrutin;
  final String? sousTitre;
  final bool? verifie;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ThemeModel> themesList; // Nouvelle propriété pour les thèmes

  ScrutinModel({
    required this.uid,
    this.numero,
    this.organeRef,
    this.legislature,
    this.dateScrutin,
    this.titre,
    this.objet,
    this.typeVote,
    this.modePublication,
    this.sujet,
    this.nbVotants,
    this.nbExprimes,
    this.nbPour,
    this.nbContre,
    this.nbAbstentions,
    this.nbNonVotants,
    this.voteAbstention,
    this.voteContre,
    this.voteGroupe,
    this.votePour,
    this.argumentContre,
    this.argumentPour,
    this.contenuTexte,
    this.contexte,
    this.enjeux,
    this.resume,
    this.themes,
    this.typeScrutin,
    this.sousTitre,
    this.verifie,
    this.createdAt,
    this.updatedAt,
    this.themesList = const [],
  });

  factory ScrutinModel.fromJson(Map<String, dynamic> json) {
    // Parser les thèmes depuis le JSON
    List<ThemeModel> parsedThemes = [];
    if (json['themes'] != null) {
      try {
        if (json['themes'] is List) {
          parsedThemes = (json['themes'] as List)
              .map((t) => ThemeModel.fromJson(t as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        print('Erreur lors du parsing des thèmes: $e');
      }
    }

    return ScrutinModel(
      uid: json['uid']?.toString() ?? '',
      numero: json['numero']?.toString(),
      organeRef: json['organe_ref']?.toString(),
      legislature: json['legislature']?.toString(),
      dateScrutin: _parseDate(json['date_scrutin']),
      titre: json['titre']?.toString(),
      objet: json['objet']?.toString(),
      typeVote: json['type_vote']?.toString(),
      modePublication: json['mode_publication']?.toString(),
      sujet: json['sujet']?.toString(),
      nbVotants: _parseInt(json['nb_votants']),
      nbExprimes: _parseInt(json['nb_exprimes']),
      nbPour: _parseInt(json['nb_pour']),
      nbContre: _parseInt(json['nb_contre']),
      nbAbstentions: _parseInt(json['nb_abstentions']),
      nbNonVotants: _parseInt(json['nb_non_votants']),
      voteAbstention: json['vote_abstention']?.toString(),
      voteContre: json['vote_contre']?.toString(),
      voteGroupe: json['vote_groupe']?.toString(),
      votePour: json['vote_pour']?.toString(),
      argumentContre: json['argument_contre']?.toString(),
      argumentPour: json['argument_pour']?.toString(),
      contenuTexte: json['contenu_texte']?.toString(),
      contexte: json['contexte']?.toString(),
      enjeux: json['enjeux']?.toString(),
      resume: json['resume']?.toString(),
      themes: json['themes']?.toString(),
      typeScrutin: json['type_scrutin']?.toString(),
      sousTitre: json['sous_titre']?.toString(),
      verifie: json['verifie'] == true || json['verifie'] == 1,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      themesList: parsedThemes,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String && value.isNotEmpty) {
      try {
        return int.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  String get formattedDate {
    if (dateScrutin == null) return '';
    final months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return '${dateScrutin!.day} ${months[dateScrutin!.month - 1]} ${dateScrutin!.year}';
  }

  String get shortDate {
    if (dateScrutin == null) return '';
    return '${dateScrutin!.day.toString().padLeft(2, '0')}/${dateScrutin!.month.toString().padLeft(2, '0')}/${dateScrutin!.year}';
  }

  double? get tauxParticipation {
    if (nbVotants == null || nbVotants == 0) return null;
    return (nbExprimes ?? 0) / nbVotants! * 100;
  }

  @override
  String toString() {
    return 'ScrutinModel(uid: $uid, numero: $numero, titre: $titre, date: $formattedDate)';
  }
}
