class ThemeModel {
  final String id;
  final String name;
  final int? count;

  ThemeModel({
    required this.id,
    required this.name,
    this.count,
  });

  factory ThemeModel.fromJson(Map<String, dynamic> json) {
    return ThemeModel(
      id: json['id'] as String,
      name: json['name'] as String,
      count: json['count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'count': count,
    };
  }

  // Palette de couleurs pour les thèmes
  static const Map<String, int> themeColors = {
    'Agriculture': 0xFF8BC34A, // Vert clair
    'Autre': 0xFF9E9E9E, // Gris
    'Culture': 0xFFE91E63, // Rose
    'Défense': 0xFF795548, // Marron
    'Démocratie': 0xFF2196F3, // Bleu
    'Écologie': 0xFF4CAF50, // Vert
    'Économie': 0xFFFFC107, // Jaune
    'Éducation': 0xFFFF5722, // Rouge-orange
    'Fiscalité': 0xFF9C27B0, // Violet
    'Fonction publique': 0xFF673AB7, // Violet foncé
    'Immigration': 0xFFFF5722, // Rouge
    'International': 0xFF009688, // Teal
    'Justice': 0xFF3F51B5, // Indigo
    'Logement': 0xFFCDDC39, // Lime
    'Numérique': 0xFF00BCD4, // Cyan
    'Outre-mer': 0xFF4CAF50, // Vert
    'Santé': 0xFFF44336, // Rouge
    'Sécurité': 0xFF607D8B, // Bleu gris
    'Social': 0xFFE91E63, // Rose
    'Transport': 0xFF795548, // Marron
    'Travail': 0xFF9E9E9E, // Gris
  };

  // Obtenir la couleur du thème
  int getColor() {
    return themeColors[name] ?? 0xFF757575; // Gris par défaut
  }
}
