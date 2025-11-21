import 'package:flutter/material.dart';
import '../data/models/deputy_model.dart';
import '../services/api_service.dart';

// Modèle utilisateur simple
class User {
  final String? idcirco;
  final String? username;

  User({this.idcirco, this.username});
}

// État d'authentification
class AuthState {
  final User? user;
  final bool isAuthenticated;

  AuthState({this.user, this.isAuthenticated = false});
}

// Provider d'authentification simple (sans Riverpod pour l'instant)
class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState();

  AuthState get state => _state;
  User? get user => _state.user;
  bool get isAuthenticated => _state.isAuthenticated;

  void setUser(User user) {
    _state = AuthState(user: user, isAuthenticated: true);
    notifyListeners();
  }

  void logout() {
    _state = AuthState();
    notifyListeners();
  }
}

// État des députés
class DeputyState {
  final List<DeputyModel> deputies;
  final Map<String, List<DeputyModel>> deputiesByGroup;
  final DeputyModel? myDeputy;
  final bool loading;
  final String? error;

  const DeputyState({
    this.deputies = const [],
    this.deputiesByGroup = const {},
    this.myDeputy,
    this.loading = false,
    this.error,
  });

  DeputyState copyWith({
    List<DeputyModel>? deputies,
    Map<String, List<DeputyModel>>? deputiesByGroup,
    DeputyModel? myDeputy,
    bool? loading,
    String? error,
  }) {
    return DeputyState(
      deputies: deputies ?? this.deputies,
      deputiesByGroup: deputiesByGroup ?? this.deputiesByGroup,
      myDeputy: myDeputy ?? this.myDeputy,
      loading: loading ?? this.loading,
      error: error ?? this.error,
    );
  }
}

// Repository pour les députés - maintenant connecté à l'API réelle
class DeputyRepository {
  
  /// Récupère tous les députés depuis l'API Railway
  Future<List<DeputyModel>> getAllDeputies() async {
    print('🌐 Récupération de tous les députés depuis l\'API...');
    
    try {
      final deputiesData = await ApiService.getAllDeputies();
      
      if (deputiesData == null) {
        throw Exception('Impossible de récupérer les données des députés');
      }
      
      // Convertir les données JSON en modèles DeputyModel
      final deputies = deputiesData.map((data) => DeputyModel.fromJson(data)).toList();
      
      print('✅ ${deputies.length} députés récupérés depuis l\'API');
      return deputies;
      
    } catch (e) {
      print('❌ Erreur lors de la récupération des députés: $e');
      throw Exception('Erreur réseau: Impossible de charger les députés. Vérifiez votre connexion.');
    }
  }

  /// Récupère un député par circonscription depuis l'API
  Future<DeputyModel?> getDeputyByCirconscription(String idcirco) async {
    print('🌐 Recherche du député pour la circonscription: $idcirco');
    
    try {
      // Tenter d'abord une recherche directe via l'API
      final deputyData = await ApiService.getDeputyByCirconscription(idcirco);
      
      if (deputyData != null) {
        final deputy = DeputyModel.fromJson(deputyData);
        print('✅ Député trouvé: ${deputy.fullName}');
        return deputy;
      }
      
      // Si pas trouvé directement, chercher dans la liste complète
      print('🔍 Recherche alternative dans la liste complète...');
      final allDeputies = await getAllDeputies();
      
      // Normaliser l'idcirco pour la recherche
      final normalizedIdcirco = _normalizeIdcirco(idcirco);
      
      for (final deputy in allDeputies) {
        final deputyIdcirco = deputy.idcirco;
        final deputyCodeCirco = deputy.codeCirco;
        
        // Vérifications multiples pour maximiser les chances de match
        if (deputyIdcirco == idcirco ||
            deputyIdcirco == normalizedIdcirco ||
            deputyCodeCirco == idcirco ||
            deputyCodeCirco == normalizedIdcirco) {
          print('✅ Député trouvé par recherche alternative: ${deputy.fullName}');
          return deputy;
        }
      }
      
      print('⚠️ Aucun député trouvé pour la circonscription: $idcirco');
      return null;
      
    } catch (e) {
      print('❌ Erreur lors de la recherche du député: $e');
      throw Exception('Erreur réseau: Impossible de trouver le député pour cette circonscription.');
    }
  }

  /// Récupère les députés groupés par groupe politique
  Future<Map<String, List<DeputyModel>>> getDeputiesByGroup() async {
    print('🌐 Récupération des députés par groupe politique...');
    
    try {
      final groupsData = await ApiService.getDeputiesByGroup();
      
      final Map<String, List<DeputyModel>> deputiesByGroup = {};
      
      groupsData.forEach((groupName, deputiesData) {
        final List<dynamic> deputiesList = deputiesData as List<dynamic>;
        final List<DeputyModel> deputies = deputiesList
            .map((data) => DeputyModel.fromJson(data as Map<String, dynamic>))
            .toList();
        deputiesByGroup[groupName] = deputies;
      });
      
      print('✅ ${deputiesByGroup.length} groupes politiques récupérés');
      return deputiesByGroup;
      
    } catch (e) {
      print('❌ Erreur lors de la récupération des groupes: $e');
      throw Exception('Erreur réseau: Impossible de charger les groupes politiques.');
    }
  }
  
  /// Récupère tous les organes politiques avec leurs couleurs
  Future<List<dynamic>> getAllOrganes() async {
    print('🌐 Récupération des organes politiques...');
    
    try {
      final organes = await ApiService.getAllOrganes();
      print('✅ ${organes.length} organes récupérés');
      return organes;
    } catch (e) {
      print('❌ Erreur lors de la récupération des organes: $e');
      throw Exception('Erreur réseau: Impossible de charger les organes politiques.');
    }
  }
  
  /// Normalise l'idcirco pour améliorer les recherches
  String _normalizeIdcirco(String idcirco) {
    // Si l'idcirco est déjà au format XX-XX, on le retourne tel quel
    if (idcirco.contains('-')) {
      return idcirco;
    }

    // Sinon, on convertit XXXX vers XX-XX
    if (idcirco.length >= 4) {
      final dep = idcirco.substring(0, 2);
      final circo = idcirco.substring(2);
      return '$dep-$circo';
    }

    return idcirco; // Retour par défaut si le format n'est pas reconnu
  }
  
  /// Test de connectivité avec l'API
  Future<bool> testConnection() async {
    return await ApiService.checkHealth();
  }
}

// Provider des députés
class DeputyProvider extends ChangeNotifier {
  final DeputyRepository _repository = DeputyRepository();
  DeputyState _state = const DeputyState();

  DeputyState get state => _state;
  List<DeputyModel> get deputies => _state.deputies;
  Map<String, List<DeputyModel>> get deputiesByGroup => _state.deputiesByGroup;
  DeputyModel? get myDeputy => _state.myDeputy;
  bool get loading => _state.loading;
  String? get error => _state.error;

  Future<void> loadAllDeputies() async {
    print('📋 Chargement de tous les députés...');
    _state = _state.copyWith(loading: true, error: null);
    notifyListeners();
    
    try {
      final deputies = await _repository.getAllDeputies();
      _state = _state.copyWith(
        deputies: deputies,
        loading: false,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        loading: false,
        error: e.toString(),
      );
      notifyListeners();
    }
  }

  Future<void> loadDeputiesByGroup() async {
    print('🏛️ Chargement des députés par groupe...');
    _state = _state.copyWith(loading: true, error: null);
    notifyListeners();
    
    try {
      final deputiesByGroup = await _repository.getDeputiesByGroup();
      _state = _state.copyWith(
        deputiesByGroup: deputiesByGroup,
        loading: false,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        loading: false,
        error: e.toString(),
      );
      notifyListeners();
    }
  }

  void setMyDeputy(DeputyModel deputy) {
    _state = _state.copyWith(myDeputy: deputy);
    notifyListeners();
  }

  void clearError() {
    _state = _state.copyWith(error: null);
    notifyListeners();
  }
  
  /// Test de connectivité
  Future<bool> testApiConnection() async {
    return await _repository.testConnection();
  }
  
  /// Mise à jour locale des groupes (pour optimisation)
  void updateDeputiesByGroupLocal(Map<String, List<DeputyModel>> deputiesByGroup) {
    _state = _state.copyWith(
      deputiesByGroup: deputiesByGroup,
      loading: false,
      error: null,
    );
    notifyListeners();
  }
}

// Providers globaux
final authProvider = AuthProvider();
final deputyProvider = DeputyProvider();
final deputyRepositoryProvider = DeputyRepository();