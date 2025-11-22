class GroupeModel {
  final String id;
  final String? legislature;
  final String? libelle;
  final String? libelleAbrev;
  final String? libelleAbrege;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final String? positionPolitique;
  final String? couleurAssociee;
  final int? effectif;
  final int? women;
  final double? age;
  final double? scoreRose;
  final double? scoreCohesion;
  final double? scoreParticipation;
  final double? scoreMajorite;
  final int? active;
  final DateTime? dateMaj;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GroupeModel({
    required this.id,
    this.legislature,
    this.libelle,
    this.libelleAbrev,
    this.libelleAbrege,
    this.dateDebut,
    this.dateFin,
    this.positionPolitique,
    this.couleurAssociee,
    this.effectif,
    this.women,
    this.age,
    this.scoreRose,
    this.scoreCohesion,
    this.scoreParticipation,
    this.scoreMajorite,
    this.active,
    this.dateMaj,
    this.createdAt,
    this.updatedAt,
  });

  factory GroupeModel.fromJson(Map<String, dynamic> json) {
    return GroupeModel(
      id: json['id'] as String,
      legislature: json['legislature'] as String?,
      libelle: json['libelle'] as String?,
      libelleAbrev: json['libelle_abrev'] as String?,
      libelleAbrege: json['libelle_abrege'] as String?,
      dateDebut: json['date_debut'] != null
          ? DateTime.parse(json['date_debut'] as String)
          : null,
      dateFin: json['date_fin'] != null
          ? DateTime.parse(json['date_fin'] as String)
          : null,
      positionPolitique: json['position_politique'] as String?,
      couleurAssociee: json['couleur_associee'] as String?,
      effectif: json['effectif'] as int?,
      women: json['women'] as int?,
      age: json['age'] != null 
          ? (json['age'] is String ? double.tryParse(json['age']) : (json['age'] as num).toDouble())
          : null,
      scoreRose: json['score_rose'] != null
          ? (json['score_rose'] is String ? double.tryParse(json['score_rose']) : (json['score_rose'] as num).toDouble())
          : null,
      scoreCohesion: json['socre_cohesion'] != null
          ? (json['socre_cohesion'] is String ? double.tryParse(json['socre_cohesion']) : (json['socre_cohesion'] as num).toDouble())
          : null,
      scoreParticipation: json['score_participation'] != null
          ? (json['score_participation'] is String ? double.tryParse(json['score_participation']) : (json['score_participation'] as num).toDouble())
          : null,
      scoreMajorite: json['score_majorite'] != null
          ? (json['score_majorite'] is String ? double.tryParse(json['score_majorite']) : (json['score_majorite'] as num).toDouble())
          : null,
      active: json['active'] as int?,
      dateMaj: json['date_maj'] != null
          ? DateTime.parse(json['date_maj'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'legislature': legislature,
      'libelle': libelle,
      'libelle_abrev': libelleAbrev,
      'libelle_abrege': libelleAbrege,
      'date_debut': dateDebut?.toIso8601String(),
      'date_fin': dateFin?.toIso8601String(),
      'position_politique': positionPolitique,
      'couleur_associee': couleurAssociee,
      'effectif': effectif,
      'women': women,
      'age': age,
      'score_rose': scoreRose,
      'socre_cohesion': scoreCohesion,
      'score_participation': scoreParticipation,
      'score_majorite': scoreMajorite,
      'active': active,
      'date_maj': dateMaj?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
