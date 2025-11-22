import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../services/database_service.dart';
import '../services/admin_auth_service.dart';
import 'login_page.dart';
import 'edit_circonscription_page.dart';

class AccountPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const AccountPage({super.key, required this.user});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _changingPassword = false;
  String? _error;
  bool _notificationsEnabled = false;
  bool _loadingNotifications = false;
  bool _circonscriptionModified = false; // Flag pour tracker les modifications
  
  // Variables admin
  final AdminAuthService _adminAuthService = AdminAuthService();
  bool? _isAdmin;
  bool _checkingAdminStatus = false;
  String? _adminToken;

  final DatabaseService _databaseService = DatabaseService();
  final SessionService _sessionService = SessionService();

  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadNotificationSettings() async {
    if (!mounted) return;
    
    setState(() => _loadingNotifications = true);
    try {
      final enabled = await _databaseService.getNotificationSettings(widget.user['username']);
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = enabled;
        _loadingNotifications = false;
      });
    } catch (e) {
      print('Erreur lors de la récupération des paramètres de notification: $e');
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = false; // Valeur par défaut en cas d'erreur
        _loadingNotifications = false;
      });
    }
  }

  // 🔍 Vérifier le statut admin au chargement
  Future<void> _checkAdminStatus() async {
    if (!mounted) return;
    
    setState(() {
      _checkingAdminStatus = true;
    });

    try {
      final isAdmin = await _adminAuthService.isAdminAuthenticated();
      final token = await _adminAuthService.getAdminToken();

      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
        _adminToken = token;
        _checkingAdminStatus = false;
      });
    } catch (e) {
      print('Erreur lors de la vérification admin: $e');
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
        _adminToken = null;
        _checkingAdminStatus = false;
      });
    }
  }

  // 🔐 Afficher le dialog de connexion admin
  void _showAdminLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext dialogContext) => AdminLoginDialog(
        onSuccess: (String message) async {
          await _checkAdminStatus();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: const Color(0xFF556B2F),
              ),
            );
          }
        },
        onError: (String error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        adminAuthService: _adminAuthService,
      ),
    );
  }

  // 🚪 Déconnexion admin
  void _logoutAdmin() async {
    try {
      await _adminAuthService.clearAdminSession();
      await _checkAdminStatus();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Déconnecté du mode admin'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la déconnexion'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _loadingNotifications = true);
    try {
      final success = await _databaseService.updateNotificationSettings(widget.user['username'], value);
      if (success) {
        setState(() {
          _notificationsEnabled = value;
          _loadingNotifications = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  value ? 'Notifications activées' : 'Notifications désactivées'),
              backgroundColor: value ? Colors.green : Colors.orange,
            ),
          );
        }
      } else {
        setState(() => _loadingNotifications = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors de la sauvegarde des paramètres'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _loadingNotifications = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la sauvegarde des paramètres'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startChangingPassword() {
    setState(() {
      _changingPassword = true;
      _error = null;
    });
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  Future<void> _changePassword() async {
    setState(() => _error = null);

    // Validation
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() => _error = 'Tous les champs sont obligatoires.');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Les nouveaux mots de passe ne correspondent pas.');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      setState(() => _error = 'Le nouveau mot de passe doit contenir au moins 6 caractères.');
      return;
    }

    try {
      final success = await _databaseService.changePassword(
        username: widget.user['username'],
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (success) {
        setState(() {
          _changingPassword = false;
          _error = null;
        });

        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mot de passe modifié avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => _error = 'Mot de passe actuel incorrect');
      }
    } catch (e) {
      setState(() => _error = 'Erreur lors de la modification du mot de passe');
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('⚠️ Supprimer le compte'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cette action est irréversible !',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 12),
              Text('En supprimant votre compte :'),
              SizedBox(height: 8),
              Text('• Toutes vos données seront définitivement effacées'),
              Text('• Vous perdrez l\'accès à votre compte'),
              Text('• Cette action ne peut pas être annulée'),
              SizedBox(height: 12),
              Text('Êtes-vous absolument certain(e) de vouloir continuer ?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Supprimer définitivement'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _error = null);

    try {
      await _databaseService.deleteUser(widget.user['username']);
      await _sessionService.clearSession();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Votre compte a été supprimé définitivement'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _error = 'Erreur lors de la suppression du compte');
    }
  }

  Future<void> _clearCache() async {
    try {
      // Vider le cache de la base de données locale
      await _databaseService.clearCache();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cache vidé avec succès'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Erreur lors du vidage du cache: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erreur lors du vidage du cache'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          print('DEBUG: AccountPage ferme avec _circonscriptionModified = $_circonscriptionModified');
          Navigator.pop(context, _circonscriptionModified);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
        child: Column(
          children: [
            // Header avec icône de retour
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      print('DEBUG: Bouton retour cliqué avec _circonscriptionModified = $_circonscriptionModified');
                      Navigator.pop(context, _circonscriptionModified);
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE8F4F8), Color(0xFFF0F8FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF556B2F),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Mon Compte',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Profile card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE8F4F8), Color(0xFFF0F8FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              size: 40,
                              color: Color(0xFF556B2F),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.user['username'] ?? 'Utilisateur',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF556B2F).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              widget.user['circonscription'] ?? 'Circonscription non définie',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF556B2F),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Password change section
                    if (_changingPassword) ...[
                      _buildModernCard(
                        title: 'Changer le mot de passe',
                        icon: Icons.lock,
                        color: const Color(0xFF556B2F),
                        child: Column(
                          children: [
                            _buildModernTextField(
                              controller: _currentPasswordController,
                              label: 'Mot de passe actuel',
                              icon: Icons.lock_outline,
                              obscureText: true,
                            ),
                            const SizedBox(height: 16),
                            _buildModernTextField(
                              controller: _newPasswordController,
                              label: 'Nouveau mot de passe',
                              icon: Icons.lock,
                              obscureText: true,
                            ),
                            const SizedBox(height: 16),
                            _buildModernTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirmer le nouveau mot de passe',
                              icon: Icons.lock,
                              obscureText: true,
                            ),
                            const SizedBox(height: 20),
                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: _buildModernButton(
                                    text: 'Annuler',
                                    onPressed: () {
                                      setState(() {
                                        _changingPassword = false;
                                        _error = null;
                                      });
                                      _currentPasswordController.clear();
                                      _newPasswordController.clear();
                                      _confirmPasswordController.clear();
                                    },
                                    isOutlined: true,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildModernButton(
                                    text: 'Modifier',
                                    onPressed: _changePassword,
                                    color: const Color(0xFF556B2F),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Action buttons
                      _buildActionCard(
                        title: 'Circonscription',
                        subtitle: widget.user['circonscription'] ?? 'Non définie',
                        icon: Icons.location_on_rounded,
                        color: const Color(0xFF8FBC8F),
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditCirconscriptionPage(
                                user: widget.user,
                                onUpdate: (newCirconscription) {
                                  print('DEBUG: Circonscription mise à jour: $newCirconscription');
                                  setState(() {
                                    widget.user['circonscription'] = newCirconscription;
                                    _circonscriptionModified = true; // Marquer comme modifié
                                  });
                                },
                              ),
                            ),
                          );
                          // Si la circonscription a été modifiée, on met à jour le flag
                          if (result == true) {
                            setState(() {
                              _circonscriptionModified = true;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildActionCard(
                        title: 'Mot de passe',
                        subtitle: 'Modifier votre mot de passe',
                        icon: Icons.lock_rounded,
                        color: const Color(0xFF556B2F),
                        onTap: _startChangingPassword,
                      ),
                      const SizedBox(height: 16),
                      // Carte Notifications
                      _buildNotificationCard(),
                      const SizedBox(height: 16),
                      // Carte Statut Admin
                      _buildAdminStatusCard(),
                      const SizedBox(height: 16),
                      _buildActionCard(
                        title: 'Déconnexion',
                        subtitle: 'Se déconnecter de l\'application',
                        icon: Icons.logout_rounded,
                        color: const Color(0xFFDEB887),
                        onTap: () async {
                          await _sessionService.clearSession();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginPage()),
                              (route) => false,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 32),

                      // Danger zone
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Icon(
                                    Icons.warning_rounded,
                                    color: Colors.red,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Zone dangereuse',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildModernButton(
                              text: 'Supprimer définitivement mon compte',
                              onPressed: _showDeleteAccountDialog,
                              color: Colors.red,
                              isOutlined: true,
                              icon: Icons.delete_forever_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Cache Management
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Icon(
                                    Icons.cleaning_services_rounded,
                                    color: Colors.grey,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Maintenance',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF666666),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Videz le cache pour libérer de l\'espace et actualiser les données',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildModernButton(
                              text: 'Vider le cache',
                              onPressed: _clearCache,
                              color: Colors.grey[700]!,
                              isOutlined: true,
                              icon: Icons.delete_sweep_rounded,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ), // SafeArea
    ), // Scaffold
    ); // PopScope
  }

  Widget _buildModernCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
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
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: color,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: _notificationsEnabled
              ? Colors.blue.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  _notificationsEnabled
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  color: Colors.blue[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _notificationsEnabled
                          ? 'Activées - Vous recevrez les alertes'
                          : 'Désactivées - Aucune alerte',
                      style: TextStyle(
                        fontSize: 14,
                        color: _notificationsEnabled
                            ? Colors.blue[700]
                            : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (_loadingNotifications)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                  activeThumbColor: Colors.blue[700],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Types de notifications',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Mises à jour importantes de l\'application\n'
                  '• Nouvelles fonctionnalités disponibles\n'
                  '• Alertes de sécurité et maintenance',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: _isAdmin == true
              ? const Color(0xFF556B2F).withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_isAdmin == true ? const Color(0xFF556B2F) : Colors.orange).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  _isAdmin == true ? Icons.admin_panel_settings : Icons.person,
                  color: _isAdmin == true ? const Color(0xFF556B2F) : Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Statut Administrateur',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_checkingAdminStatus)
                      Text(
                        'Vérification en cours...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      )
                    else
                      Text(
                        _isAdmin == true ? 'Admin - Accès complet' : 'Utilisateur standard',
                        style: TextStyle(
                          fontSize: 14,
                          color: _isAdmin == true ? const Color(0xFF556B2F) : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (_checkingAdminStatus)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isAdmin == true
                        ? const Color(0xFF556B2F).withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isAdmin == true
                          ? const Color(0xFF556B2F).withOpacity(0.3)
                          : Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _isAdmin == true ? 'Admin' : 'Pas Admin',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isAdmin == true ? const Color(0xFF556B2F) : Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildModernButton(
                  text: _isAdmin == true ? 'Se déconnecter' : 'Se connecter comme admin',
                  onPressed: _checkingAdminStatus ? () {} : () {
                    if (_isAdmin == true) {
                      _logoutAdmin();
                    } else {
                      _showAdminLoginDialog();
                    }
                  },
                  color: _isAdmin == true ? Colors.red : const Color(0xFF556B2F),
                  icon: _isAdmin == true ? Icons.logout : Icons.login,
                ),
              ),
            ],
          ),
          // Info token (si admin connecté)
          if (_isAdmin == true && _adminToken != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.security,
                    color: Colors.green.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Token JWT actif (expire dans 6h max)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF556B2F).withOpacity(0.2),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF556B2F)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          labelStyle: const TextStyle(color: Color(0xFF666666)),
        ),
      ),
    );
  }

  Widget _buildModernButton({
    required String text,
    required VoidCallback onPressed,
    required Color color,
    bool isOutlined = false,
    IconData? icon,
  }) {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: isOutlined ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: color,
          width: isOutlined ? 2 : 0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: isOutlined ? color : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: TextStyle(
                    color: isOutlined ? color : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

// Dialog séparé pour l'authentification admin
class AdminLoginDialog extends StatefulWidget {
  final Function(String) onSuccess;
  final Function(String) onError;
  final AdminAuthService adminAuthService;

  const AdminLoginDialog({
    super.key,
    required this.onSuccess,
    required this.onError,
    required this.adminAuthService,
  });

  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_passwordController.text.isEmpty) {
      widget.onError('Veuillez entrer un mot de passe');
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final result = await widget.adminAuthService.authenticateAdmin(
        _passwordController.text
      );

      if (mounted) {
        setState(() { _isLoading = false; });

        if (result.success && result.isAdmin) {
          Navigator.of(context).pop();
          widget.onSuccess(result.message ?? 'Connecté en tant qu\'admin');
        } else {
          widget.onError(result.message ?? 'Échec de l\'authentification');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        widget.onError('Erreur de connexion');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.admin_panel_settings,
            color: Color(0xFF556B2F),
            size: 28,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Authentification Admin',
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Entrez le mot de passe administrateur pour accéder aux fonctions avancées.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[50],
                hintText: 'Mot de passe admin',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(
                  Icons.lock,
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
              ),
              onSubmitted: (_) => _authenticate(),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF556B2F),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () {
            Navigator.of(context).pop();
          },
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _authenticate,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF556B2F),
            foregroundColor: Colors.white,
          ),
          child: const Text('Se connecter'),
        ),
      ],
    );
  }
}