import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../services/session_service.dart';
import '../utils/bubble_indication_painter.dart';
import 'circonscription_map_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();
  final _recoveryFormKey = GlobalKey<FormState>();

  // Contrôleurs pour la connexion (changé de email à username)
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // Contrôleurs pour l'inscription
  final _signupUsernameController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _recoveryPhraseController = TextEditingController();

  // Contrôleurs pour la récupération
  final _recoveryUsernameController = TextEditingController();
  final _recoveryPhraseInputController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isSignupPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late PageController _pageController;

  // Animation controllers pour le bouton de connexion
  late AnimationController _buttonController;
  late AnimationController _checkController;
  late Animation<double> _buttonAnimation;
  late Animation<double> _checkAnimation;
  bool _isAnimating = false;

  // Colors for tab indication
  Color _leftTabColor = Colors.black;
  Color _rightTabColor = Colors.white;

  // Signup specific fields
  String? _selectedIdcirco;
  String? _selectedDep;
  String? _selectedLibelle;

  // Services
  final DatabaseService _databaseService = DatabaseService();
  final SessionService _sessionService = SessionService();

  // Timer for delayed animation
  Timer? _delayedAnimationTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800), // Réduit de 1500 à 800
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut, // Courbe plus simple
    ));

    // Animation controllers pour le bouton de connexion
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 600), // Réduit de 1000 à 600
      vsync: this,
    );

    _checkController = AnimationController(
      duration: const Duration(milliseconds: 200), // Réduit de 300 à 200
      vsync: this,
    );

    _buttonAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeOut, // Courbe plus simple
    ));

    _checkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeOut, // Courbe plus simple que elasticOut
    ));

    _pageController = PageController();
    
    // Démarrage différé pour éviter les animations simultanées
    _delayedAnimationTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _delayedAnimationTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _signupUsernameController.dispose();
    _signupPasswordController.dispose();
    _confirmPasswordController.dispose();
    _recoveryPhraseController.dispose();
    _recoveryUsernameController.dispose();
    _recoveryPhraseInputController.dispose();
    _animationController.dispose();
    _buttonController.dispose();
    _checkController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isAnimating) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      // Marquer comme en cours et démarrer l'animation en parallèle
      setState(() {
        _isAnimating = true;
      });

      // Lancer la connexion et l'animation en parallèle
      final Future<Map<String, dynamic>?> loginFuture =
          _databaseService.authenticateUser(username: username, password: password);
      final Future<void> animationFuture = _buttonController.forward();

      // Attendre que la connexion soit terminée
      final user = await loginFuture;

      if (mounted) {
        if (user != null) {
          // Sauvegarder la session
          await _sessionService.saveUserSession(user);
          
          // Attendre que l'animation soit terminée si elle ne l'est pas déjà
          await animationFuture;

          // Animation de succès
          await _checkController.forward();

          // Attendre un peu avant de naviguer
          await Future.delayed(const Duration(milliseconds: 800));

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage(user: user),
              ),
            );
          }
        } else {
          // Erreur de connexion
          _showLoginError('Nom d\'utilisateur ou mot de passe incorrect');
        }
      }
    } catch (e) {
      if (mounted) {
        _showLoginError(e.toString());
      }
    }
  }

  void _showLoginError(String error) {
    // Réinitialiser les animations en cas d'erreur
    _buttonController.reset();
    _checkController.reset();
    setState(() {
      _isAnimating = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF8B4513), // Saddle brown harmonieux
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    );
  }

  Future<void> _signup() async {
    if (!_signupFormKey.currentState!.validate()) return;

    if (_selectedIdcirco == null || _selectedDep == null || _selectedLibelle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez sélectionner votre circonscription',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Color(0xFF8B4513), // Saddle brown harmonieux
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      );
      return;
    }

    try {
      final success = await _databaseService.createUser(
        username: _signupUsernameController.text.trim(),
        password: _signupPasswordController.text,
        recoveryPhrase: _recoveryPhraseController.text.trim(),
        circonscription: _selectedLibelle!,
        idcirco: _selectedIdcirco,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Compte créé avec succès ! Vous pouvez maintenant vous connecter.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Color(0xFF228B22), // Forest green harmonieux
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          );
          // Switch back to login tab
          _onSignInButtonPress();
          _clearSignupForm();
        } else {
          _showSignupError('Erreur: Ce nom d\'utilisateur existe déjà');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSignupError(e.toString());
      }
    }
  }

  void _showSignupError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF8B4513), // Saddle brown harmonieux
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    );
  }

  void _clearSignupForm() {
    _signupUsernameController.clear();
    _signupPasswordController.clear();
    _confirmPasswordController.clear();
    _recoveryPhraseController.clear();
    setState(() {
      _selectedIdcirco = null;
      _selectedDep = null;
      _selectedLibelle = null;
    });
  }

  void _onSignInButtonPress() {
    setState(() {
      _rightTabColor = Colors.white;
      _leftTabColor = Colors.black;
    });
    _pageController.animateToPage(0,
        duration: const Duration(milliseconds: 500), curve: Curves.decelerate);
  }

  void _onSignUpButtonPress() {
    setState(() {
      _rightTabColor = Colors.black;
      _leftTabColor = Colors.white;
    });
    _pageController.animateToPage(1,
        duration: const Duration(milliseconds: 500), curve: Curves.decelerate);
  }

  void _onForgotPasswordPress() {
    _showRecoveryDialog();
  }

  void _onCirconscriptionSelected(String idcirco, String dep, String libelle) {
    setState(() {
      _selectedIdcirco = idcirco;
      _selectedDep = dep;
      _selectedLibelle = libelle;
    });
  }

  void _showRecoveryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.lock_reset,
                color: Color(0xFF556B2F),
                size: 28,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Récupération de mot de passe',
                  style: TextStyle(
                    color: Color(0xFF556B2F),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: _recoveryFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Entrez vos informations pour récupérer votre mot de passe :',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Nom d'utilisateur
                  const Text(
                    'Nom d\'utilisateur',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF556B2F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _recoveryUsernameController,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[50],
                      hintText: 'Votre nom d\'utilisateur',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: const Icon(
                        Icons.person,
                        color: Color(0xFF556B2F),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF556B2F),
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 1,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre nom d\'utilisateur';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Phrase de récupération
                  const Text(
                    'Phrase de récupération',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF556B2F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _recoveryPhraseInputController,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[50],
                      hintText: 'Votre phrase de récupération secrète',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: const Icon(
                        Icons.key,
                        color: Color(0xFF556B2F),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF556B2F),
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 1,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre phrase de récupération';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Un nouveau mot de passe temporaire sera généré pour vous.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _recoveryUsernameController.clear();
                _recoveryPhraseInputController.clear();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Annuler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                if (_recoveryFormKey.currentState!.validate()) {
                  try {
                    final newPassword = await _databaseService.recoverPassword(
                      username: _recoveryUsernameController.text.trim(),
                      recoveryPhrase: _recoveryPhraseInputController.text.trim(),
                    );

                    if (newPassword != null) {
                      await _databaseService.changePassword(
                        username: _recoveryUsernameController.text.trim(),
                        newPassword: newPassword,
                      );

                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          title: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF556B2F),
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Mot de passe récupéré',
                                  style: TextStyle(
                                    color: Color(0xFF556B2F),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Votre nouveau mot de passe temporaire est :',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  newPassword,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: Color(0xFF556B2F),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  border: Border.all(color: Colors.orange.shade200),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber,
                                      color: Colors.orange.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Veuillez noter ce mot de passe et le changer après connexion.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF556B2F),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text(
                                'Compris',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      
                      _recoveryUsernameController.clear();
                      _recoveryPhraseInputController.clear();
                    } else {
                      _showLoginError('Nom d\'utilisateur ou phrase de récupération incorrect');
                    }
                  } catch (e) {
                    _showLoginError('Erreur lors de la récupération: ${e.toString()}');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF556B2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Récupérer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRecoveryPhraseInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Color(0xFF556B2F),
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Phrase de récupération',
                  style: const TextStyle(
                    color: Color(0xFF556B2F),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text(
                '🔒 Sécurité locale',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF556B2F),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Toutes vos données (nom d\'utilisateur et mot de passe) sont stockées uniquement sur votre appareil.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                '🔐 Mot de passe crypté',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF556B2F),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Votre mot de passe est crypté et peut être récupéré uniquement avec cette phrase de récupération.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          color: Colors.orange.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Aucune récupération possible par l\'administrateur',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Comme vos identifiants sont stockés uniquement en local, l\'administrateur n\'a aucun moyen de récupérer votre phrase de passe en cas de perte.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.privacy_tip,
                          color: Colors.green.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Respect de la vie privée - Aucune collecte de données',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cette application ne récupère aucune donnée (même pas anonymisée) de la part des utilisateurs. Aucune demande RGPD n\'est nécessaire car tout reste strictement local.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'IMPORTANT: Ne perdez JAMAIS cette phrase de récupération !',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sans cette phrase, il sera impossible de récupérer votre mot de passe.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF556B2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'J\'ai compris',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenuBar(BuildContext context) {
    return Container(
      width: 300.0,
      height: 50.0,
      decoration: BoxDecoration(
        color: const Color(0x552B2B2B),
        borderRadius: BorderRadius.circular(25.0),
      ),
      child: CustomPaint(
        painter: TabIndicationPainter(pageController: _pageController),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: TextButton(
                onPressed: _onSignInButtonPress,
                style: TextButton.styleFrom(
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: Colors.transparent,
                ),
                child: Text(
                  'Se connecter',
                  style: TextStyle(
                    color: _leftTabColor,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: _onSignUpButtonPress,
                style: TextButton.styleFrom(
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: Colors.transparent,
                ),
                child: Text(
                  "S'inscrire",
                  style: TextStyle(
                    color: _rightTabColor,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignIn(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 10.0, bottom: 20.0),
      child: Column(
        children: [
          // Login Form Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 25),
            child: Card(
              elevation: 15,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(25),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Username field (changé de email)
                      Theme(
                        data: Theme.of(context).copyWith(
                          textSelectionTheme: TextSelectionThemeData(
                            selectionColor:
                                const Color(0xFF8FBC8F).withOpacity(0.3),
                            selectionHandleColor: const Color(0xFF556B2F),
                          ),
                        ),
                        child: TextFormField(
                          controller: _usernameController,
                          cursorColor: const Color(0xFF3D5A3D),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            prefixIcon: Container(
                              margin: const EdgeInsets.only(right: 15),
                              child: const Icon(
                                Icons.person_outline,
                                color: Color(0xFF556B2F),
                                size: 22,
                              ),
                            ),
                            hintText: 'Nom d\'utilisateur',
                            hintStyle: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer votre nom d\'utilisateur';
                            }
                            return null;
                          },
                        ),
                      ),

                      Container(
                        width: double.infinity,
                        height: 1,
                        color: Colors.grey[300],
                      ),

                      const SizedBox(height: 20),

                      // Password field
                      Theme(
                        data: Theme.of(context).copyWith(
                          textSelectionTheme: TextSelectionThemeData(
                            selectionColor:
                                const Color(0xFF8FBC8F).withOpacity(0.3),
                            selectionHandleColor: const Color(0xFF556B2F),
                          ),
                        ),
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          cursorColor: const Color(0xFF3D5A3D),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            prefixIcon: Container(
                              margin: const EdgeInsets.only(right: 15),
                              child: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF556B2F),
                                size: 22,
                              ),
                            ),
                            hintText: 'Mot de passe',
                            hintStyle: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            suffixIcon: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                              child: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey,
                                size: 20,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer votre mot de passe';
                            }
                            return null;
                          },
                        ),
                      ),

                      Container(
                        width: double.infinity,
                        height: 1,
                        color: Colors.grey[300],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Login Button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 25),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF556B2F).withOpacity(0.5),
                  offset: const Offset(0, 12),
                  blurRadius: 30,
                ),
                BoxShadow(
                  color: const Color(0xFF8FBC8F).withOpacity(0.4),
                  offset: const Offset(0, 6),
                  blurRadius: 15,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF556B2F),
                  Color(0xFF8FBC8F),
                ],
                begin: FractionalOffset(0.2, 0.2),
                end: FractionalOffset(1.0, 1.0),
                stops: [0.0, 1.0],
                tileMode: TileMode.clamp,
              ),
            ),
            child: AnimatedBuilder(
              animation: _buttonAnimation,
              builder: (context, child) {
                if (!_isAnimating) {
                  // Pas d'animation, rendu statique pour les performances
                  return Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF8FBC8F),
                          Color(0xFF556B2F),
                        ],
                        begin: FractionalOffset(0.2, 0.2),
                        end: FractionalOffset(1.0, 1.0),
                        stops: [0.0, 1.0],
                        tileMode: TileMode.clamp,
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: MaterialButton(
                      onPressed: _isAnimating ? null : _login,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Text(
                        'SE CONNECTER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                
                // Calculer la largeur dynamique du bouton seulement pendant l'animation
                final progress = _buttonAnimation.value;
                final screenWidth = MediaQuery.of(context).size.width;
                final availableWidth = screenWidth - 60;
                final buttonWidth = availableWidth * (1 - progress) + 55.0 * progress;

                return Center(
                  child: Container(
                    width: buttonWidth,
                    height: 55,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF8FBC8F),
                          Color(0xFF556B2F),
                        ],
                        begin: FractionalOffset(0.2, 0.2),
                        end: FractionalOffset(1.0, 1.0),
                        stops: [0.0, 1.0],
                        tileMode: TileMode.clamp,
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: MaterialButton(
                      onPressed: _isAnimating ? null : _login,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: _isAnimating
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                // Loading circle pendant l'animation
                                if (progress < 1.0)
                                  const SizedBox(
                                    width: 25,
                                    height: 25,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                // Check icon quand l'animation de check commence
                                if (_checkAnimation.value > 0)
                                  ScaleTransition(
                                    scale: _checkAnimation,
                                    child: const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                              ],
                            )
                          : const Text(
                              'SE CONNECTER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Forgot password
          TextButton(
            onPressed: _onForgotPasswordPress,
            child: const Text(
              'Mot de passe oublié ?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUp(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 10.0, bottom: 20.0),
      child: Column(
        children: [
          // Signup Form Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 25),
            child: Card(
              elevation: 15,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(25),
                child: Form(
                  key: _signupFormKey,
                  child: Column(
                    children: [
                      // Username field
                      Theme(
                        data: Theme.of(context).copyWith(
                          textSelectionTheme: TextSelectionThemeData(
                            selectionColor:
                                const Color(0xFF8FBC8F).withOpacity(0.3),
                            selectionHandleColor: const Color(0xFF556B2F),
                          ),
                        ),
                        child: TextFormField(
                          controller: _signupUsernameController,
                          cursorColor: const Color(0xFF3D5A3D),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            prefixIcon: Container(
                              margin: const EdgeInsets.only(right: 15),
                              child: const Icon(
                                Icons.person_outline,
                                color: Color(0xFF556B2F),
                                size: 22,
                              ),
                            ),
                            hintText: 'Nom d\'utilisateur',
                            hintStyle: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer un nom d\'utilisateur';
                            }
                            if (value.length < 3) {
                              return 'Le nom d\'utilisateur doit contenir au moins 3 caractères';
                            }
                            return null;
                          },
                        ),
                      ),

                      Container(
                        width: double.infinity,
                        height: 1,
                        color: Colors.grey[300],
                      ),

                      const SizedBox(height: 12),

                      // Password field
                      Theme(
                        data: Theme.of(context).copyWith(
                          textSelectionTheme: TextSelectionThemeData(
                            selectionColor:
                                const Color(0xFF8FBC8F).withOpacity(0.3),
                            selectionHandleColor: const Color(0xFF556B2F),
                          ),
                        ),
                        child: TextFormField(
                          controller: _signupPasswordController,
                          obscureText: !_isSignupPasswordVisible,
                          cursorColor: const Color(0xFF3D5A3D),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            prefixIcon: Container(
                              margin: const EdgeInsets.only(right: 15),
                              child: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF556B2F),
                                size: 22,
                              ),
                            ),
                            hintText: 'Mot de passe',
                            hintStyle: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            suffixIcon: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isSignupPasswordVisible =
                                      !_isSignupPasswordVisible;
                                });
                              },
                              child: Icon(
                                _isSignupPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey,
                                size: 20,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer un mot de passe';
                            }
                            if (value.length < 6) {
                              return 'Le mot de passe doit contenir au moins 6 caractères';
                            }
                            return null;
                          },
                        ),
                      ),

                      Container(
                        width: double.infinity,
                        height: 1,
                        color: Colors.grey[300],
                      ),

                      const SizedBox(height: 12),

                      // Confirm Password field
                      Theme(
                        data: Theme.of(context).copyWith(
                          textSelectionTheme: TextSelectionThemeData(
                            selectionColor:
                                const Color(0xFF8FBC8F).withOpacity(0.3),
                            selectionHandleColor: const Color(0xFF556B2F),
                          ),
                        ),
                        child: TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_isConfirmPasswordVisible,
                          cursorColor: const Color(0xFF3D5A3D),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            prefixIcon: Container(
                              margin: const EdgeInsets.only(right: 15),
                              child: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF556B2F),
                                size: 22,
                              ),
                            ),
                            hintText: 'Confirmer le mot de passe',
                            hintStyle: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            suffixIcon: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isConfirmPasswordVisible =
                                      !_isConfirmPasswordVisible;
                                });
                              },
                              child: Icon(
                                _isConfirmPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey,
                                size: 20,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez confirmer votre mot de passe';
                            }
                            if (value != _signupPasswordController.text) {
                              return 'Les mots de passe ne correspondent pas';
                            }
                            return null;
                          },
                        ),
                      ),

                      Container(
                        width: double.infinity,
                        height: 1,
                        color: Colors.grey[300],
                      ),

                      const SizedBox(height: 12),

                      // Phrase de récupération
                      Theme(
                        data: Theme.of(context).copyWith(
                          textSelectionTheme: TextSelectionThemeData(
                            selectionColor:
                                const Color(0xFF8FBC8F).withOpacity(0.3),
                            selectionHandleColor: const Color(0xFF556B2F),
                          ),
                        ),
                        child: TextFormField(
                          controller: _recoveryPhraseController,
                          cursorColor: const Color(0xFF3D5A3D),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            prefixIcon: Container(
                              margin: const EdgeInsets.only(right: 15),
                              child: const Icon(
                                Icons.key,
                                color: Color(0xFF556B2F),
                                size: 22,
                              ),
                            ),
                            hintText: 'Phrase de récupération',
                            hintStyle: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            suffixIcon: GestureDetector(
                              onTap: _showRecoveryPhraseInfo,
                              child: const Icon(
                                Icons.help_outline,
                                color: Color(0xFF556B2F),
                                size: 20,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer une phrase de récupération';
                            }
                            if (value.length < 5) {
                              return 'La phrase doit contenir au moins 5 caractères';
                            }
                            return null;
                          },
                        ),
                      ),

                      Container(
                        width: double.infinity,
                        height: 1,
                        color: Colors.grey[300],
                      ),

                      const SizedBox(height: 12),

                      // Avertissement important
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(
                            color: Colors.orange.shade200,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Colors.orange.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ATTENTION',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Ne perdez JAMAIS votre phrase de récupération ! C\'est le seul moyen de récupérer votre mot de passe.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Circonscription selection
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CirconscriptionMapPage(
                                onCirconscriptionSelected: _onCirconscriptionSelected,
                                initialIdcirco: _selectedIdcirco,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _selectedLibelle != null
                                ? const Color(0xFF556B2F).withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedLibelle != null
                                  ? const Color(0xFF556B2F).withOpacity(0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.map_outlined,
                                color: _selectedLibelle != null
                                    ? const Color(0xFF556B2F)
                                    : Colors.grey,
                                size: 22,
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Text(
                                  _selectedLibelle ??
                                      'Sélectionner votre circonscription sur la carte',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _selectedLibelle != null
                                        ? Colors.black87
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.grey,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),

                      Container(
                        width: double.infinity,
                        height: 1,
                        color: Colors.grey[300],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          // Signup Button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 25),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF556B2F).withOpacity(0.5),
                  offset: const Offset(0, 12),
                  blurRadius: 30,
                ),
                BoxShadow(
                  color: const Color(0xFF8FBC8F).withOpacity(0.4),
                  offset: const Offset(0, 6),
                  blurRadius: 15,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF556B2F),
                  Color(0xFF8FBC8F),
                ],
                begin: FractionalOffset(0.2, 0.2),
                end: FractionalOffset(1.0, 1.0),
                stops: [0.0, 1.0],
                tileMode: TileMode.clamp,
              ),
            ),
            child: Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: MaterialButton(
                onPressed: _signup,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Text(
                  'CRÉER UN COMPTE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF8FBC8F), // Vert olive clair
              Color(0xFF556B2F), // Vert olive foncé
            ],
            begin: FractionalOffset(0.0, 0.0),
            end: FractionalOffset(1.0, 1.0),
            stops: [0.0, 1.0],
            tileMode: TileMode.clamp,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: Column(
              children: [
                // Section fixe du haut
                Flexible(
                  flex: 2,
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height * 0.25,
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                // Logo section
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.campaign,
                    size: 32,
                    color: Color(0xFF556B2F),
                  ),
                ),

                const SizedBox(height: 10),

                // Welcome text
                const Text(
                  'AgoraPush',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'La politique dévoilée, pour un vote éclairé',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 15),

                // Menu Bar (Tabs)
                _buildMenuBar(context),
                    ],
                  ),
                ),
                ),

                // Section scrollable du bas
                Flexible(
                  flex: 3,
                  child: PageView(
                    controller: _pageController,
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: (i) {
                      setState(() {
                        if (i == 0) {
                          _rightTabColor = Colors.white;
                          _leftTabColor = Colors.black;
                        } else if (i == 1) {
                          _rightTabColor = Colors.black;
                          _leftTabColor = Colors.white;
                        }
                      });
                    },
                    children: [
                      _buildSignIn(context),
                      _buildSignUp(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}