class DeputyModel {
  final String id;
  final String? civ;
  final String nom;
  final String prenom;
  final String? dep;
  final String? codeCirco;
  final String? idcirco;
  final String? libelle;
  final String? libelleAb;
  final String? groupePolitiqueRef;
  final String? famillePolLibelle;
  final String? qualitePrincipal;
  final String? organesRefs;
  final String? mandatsResume;
  final String? profession;
  final String? villeNaissance;
  final String? mail;
  final String? twitter;
  final String? facebook;
  final String? website;
  final String? collaborateurs;
  final DateTime? datePriseFonction;
  final DateTime? dateFin;
  final DateTime? dateNaissance;
  final double? scoreLoyaute;
  final double? scoreMajorite;
  final double? scoreParticipation;
  final double? scoreParticipationSpectialite;
  final String? experienceDepute;
  final int? nombreMandats;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? catSocPro;
  final String? uriHatvp;
  final String? placeHemicycle;
  final String? famillesPol;
  final String? famillePolLibelleDb;
  final String? legislature;
  final int? active;
  final String? typeOrganeMandats;
  final String? organeRefMandats;
  final String? codeQualite;

  DeputyModel({
    required this.id,
    this.civ,
    required this.nom,
    required this.prenom,
    this.dep,
    this.codeCirco,
    this.idcirco,
    this.libelle,
    this.libelleAb,
    this.groupePolitiqueRef,
    this.famillePolLibelle,
    this.qualitePrincipal,
    this.organesRefs,
    this.mandatsResume,
    this.profession,
    this.villeNaissance,
    this.mail,
    this.twitter,
    this.facebook,
    this.website,
    this.collaborateurs,
    this.datePriseFonction,
    this.dateFin,
    this.dateNaissance,
    this.scoreLoyaute,
    this.scoreMajorite,
    this.scoreParticipation,
    this.scoreParticipationSpectialite,
    this.experienceDepute,
    this.nombreMandats,
    this.createdAt,
    this.updatedAt,
    this.catSocPro,
    this.uriHatvp,
    this.placeHemicycle,
    this.famillesPol,
    this.famillePolLibelleDb,
    this.legislature,
    this.active,
    this.typeOrganeMandats,
    this.organeRefMandats,
    this.codeQualite,
  });

  // Nom complet pour l'affichage
  String get fullName => '$prenom $nom'.trim();
  
  // Nom complet alternatif utilisé dans le code existant
  String get nomComplet => '$prenom $nom'.trim();
  
  // Age calculé
  int? get age {
    if (dateNaissance == null) return null;
    final now = DateTime.now();
    final age = now.year - dateNaissance!.year;
    if (now.month < dateNaissance!.month || 
        (now.month == dateNaissance!.month && now.day < dateNaissance!.day)) {
      return age - 1;
    }
    return age;
  }

  // Circonscription complète pour l'affichage
  String get circonscriptionComplete {
    if (libelle != null && libelle!.isNotEmpty) {
      return libelle!;
    }
    if (dep != null && codeCirco != null) {
      return '$dep - $codeCirco';
    }
    if (idcirco != null) {
      return 'Circonscription $idcirco';
    }
    return 'Circonscription non définie';
  }

  // Circonscription avec numéro formaté
  String get circonscriptionAvecNumero {
    String base = '';
    if (libelle != null && libelle!.isNotEmpty) {
      base = libelle!;
    } else if (dep != null) {
      base = dep!;
    }
    
    if (codeCirco != null && codeCirco!.isNotEmpty) {
      return '$base (Circonscription n°$codeCirco)';
    }
    return base.isNotEmpty ? base : 'Circonscription non définie';
  }

  // Convertir experienceDepute string en int (années) pour les filtres
  int? get experienceDeputeAsInt {
    if (experienceDepute == null || experienceDepute!.isEmpty) return null;
    
    // Extraire le nombre du string
    final match = RegExp(r'\d+').firstMatch(experienceDepute!);
    if (match == null) return null;
    
    final value = int.tryParse(match.group(0)!);
    if (value == null) return null;
    
    // Si c'est en mois, convertir en années (arrondi à l'inférieur)
    if (experienceDepute!.toLowerCase().contains('mois')) {
      return (value / 12).floor();
    }
    
    // Sinon c'est en années
    return value;
  }

  // Parser les listes de mandats
  List<String> get typeOrganeMandatsList {
    if (typeOrganeMandats == null || typeOrganeMandats!.isEmpty) return [];
    // Format: ['PARPOL', 'GP', 'COMPER'] ou "{PARPOL,GP,COMPER}"
    final cleaned = typeOrganeMandats!.replaceAll('{', '').replaceAll('}', '');
    return cleaned.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  List<String> get organeRefMandatsList {
    if (organeRefMandats == null || organeRefMandats!.isEmpty) return [];
    final cleaned = organeRefMandats!.replaceAll('{', '').replaceAll('}', '');
    return cleaned.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  List<String> get codeQualiteList {
    if (codeQualite == null || codeQualite!.isEmpty) return [];
    final cleaned = codeQualite!.replaceAll('{', '').replaceAll('}', '');
    return cleaned.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  factory DeputyModel.fromJson(Map<String, dynamic> json) {
    return DeputyModel(
      id: json['id']?.toString() ?? '',
      civ: json['civ']?.toString(),
      nom: json['nom']?.toString() ?? '',
      prenom: json['prenom']?.toString() ?? '',
      dep: json['dep']?.toString(),
      codeCirco: json['codeCirco']?.toString() ?? json['code_circo']?.toString() ?? json['num_circo']?.toString(),
      idcirco: json['idcirco_complet']?.toString() ??  // Priorité au champ calculé avec padding
               json['code_circo_complet']?.toString() ?? 
               json['idcirco']?.toString() ?? 
               json['id_circo']?.toString() ??
               _buildIdCirco(json['dep']?.toString(), json['codeCirco']?.toString()),
      libelle: json['libelle']?.toString() ?? json['libelle_crico']?.toString(),
      libelleAb: json['libelleAb']?.toString() ?? 
                 json['libelle_abrege']?.toString() ?? 
                 json['groupe_abrev']?.toString(),
      groupePolitiqueRef: json['groupePolitiqueRef']?.toString() ?? json['groupe_politique_ref']?.toString(),
      famillePolLibelle: json['famillePolLibelle']?.toString() ?? 
                         json['famille_pol_libelle']?.toString() ?? 
                         json['groupe']?.toString(),
      qualitePrincipal: json['qualitePrincipal']?.toString() ?? json['qualite_principale']?.toString(),
      organesRefs: json['organesRefs']?.toString() ?? json['organes_refs']?.toString(),
      mandatsResume: json['mandatsResume']?.toString() ?? json['mandats_resume']?.toString(),
      profession: json['profession']?.toString() ?? json['job']?.toString(),
      villeNaissance: json['villeNaissance']?.toString() ?? json['ville_naissance']?.toString(),
      mail: json['mail']?.toString(),
      twitter: json['twitter']?.toString(),
      facebook: json['facebook']?.toString(),
      website: json['website']?.toString(),
      collaborateurs: json['collaborateurs']?.toString(),
      datePriseFonction: _parseDate(json['datePriseFonction'] ?? json['date_prise_fonction']),
      dateFin: _parseDate(json['dateFin'] ?? json['date_fin']),
      dateNaissance: _parseDate(json['dateNaissance'] ?? json['date_naissance']),
      scoreLoyaute: _parseDouble(json['scoreLoyaute'] ?? json['score_loyaute']),
      scoreMajorite: _parseDouble(json['scoreMajorite'] ?? json['score_majorite']),
      scoreParticipation: _parseDouble(json['scoreParticipation'] ?? json['score_participation']),
      scoreParticipationSpectialite: _parseDouble(json['scoreParticipationSpectialite'] ?? json['score_participation_spectialite']),
      experienceDepute: json['experienceDepute']?.toString() ?? json['experience_depute']?.toString(),
      nombreMandats: _parseInt(json['nombreMandats'] ?? json['nombre_mandats']),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
      catSocPro: json['catSocPro']?.toString() ?? json['cat_soc_pro']?.toString(),
      uriHatvp: json['uriHatvp']?.toString() ?? json['uri_hatvp']?.toString(),
      placeHemicycle: json['placeHemicycle']?.toString() ?? json['place_hemicycle']?.toString(),
      famillesPol: json['famillesPol']?.toString() ?? json['familles_pol']?.toString(),
      famillePolLibelleDb: json['famillePolLibelleDb']?.toString() ?? 
                           json['famille_pol_libelle_db']?.toString() ?? 
                           json['groupe']?.toString(),
      legislature: json['legislature']?.toString(),
      active: _parseInt(json['active']),
      typeOrganeMandats: json['typeOrganeMandats']?.toString() ?? json['type_organe_mandats']?.toString(),
      organeRefMandats: json['organeRefMandats']?.toString() ?? json['organe_ref_mandats']?.toString(),
      codeQualite: json['codeQualite']?.toString() ?? json['code_qualite']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'civ': civ,
      'nom': nom,
      'prenom': prenom,
      'dep': dep,
      'codeCirco': codeCirco,
      'idcirco': idcirco,
      'libelle': libelle,
      'libelleAb': libelleAb,
      'groupePolitiqueRef': groupePolitiqueRef,
      'famillePolLibelle': famillePolLibelle,
      'qualitePrincipal': qualitePrincipal,
      'organesRefs': organesRefs,
      'mandatsResume': mandatsResume,
      'profession': profession,
      'villeNaissance': villeNaissance,
      'mail': mail,
      'collaborateurs': collaborateurs,
      'datePriseFonction': datePriseFonction?.toIso8601String(),
      'dateFin': dateFin?.toIso8601String(),
      'dateNaissance': dateNaissance?.toIso8601String(),
      'scoreLoyaute': scoreLoyaute,
      'scoreMajorite': scoreMajorite,
      'scoreParticipation': scoreParticipation,
      'scoreParticipationSpectialite': scoreParticipationSpectialite,
      'experienceDepute': experienceDepute,
      'nombreMandats': nombreMandats,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'catSocPro': catSocPro,
      'uriHatvp': uriHatvp,
      'placeHemicycle': placeHemicycle,
      'famillesPol': famillesPol,
      'famillePolLibelleDb': famillePolLibelleDb,
      'legislature': legislature,
      'active': active,
      'typeOrganeMandats': typeOrganeMandats,
      'organeRefMandats': organeRefMandats,
      'codeQualite': codeQualite,
    };
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

  static String? _buildIdCirco(String? dep, String? codeCirco) {
    if (dep == null || codeCirco == null || dep.isEmpty || codeCirco.isEmpty) {
      return null;
    }
    try {
      // Construire l'idcirco au format DDCC (département sur 2 chiffres + circonscription sur 2 chiffres)
      final depPadded = dep.padLeft(2, '0');
      final circoPadded = codeCirco.padLeft(2, '0');
      return '$depPadded$circoPadded';
    } catch (e) {
      return null;
    }
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String && value.isNotEmpty) {
      try {
        return double.parse(value);
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

  @override
  String toString() {
    return 'DeputyModel(id: $id, fullName: $fullName, circonscription: $circonscriptionComplete)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeputyModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}