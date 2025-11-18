import 'package:flutter/material.dart';
import 'account_page.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header avec profil et navigation
            SliverToBoxAdapter(
              child: _buildHeader(context),
            ),

            // Message d'actualité
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'Contenu à développer',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Message de bienvenue à gauche
          Text(
            'Bienvenue ${widget.user['username'] ?? 'Utilisateur'} !',
            style: TextStyle(
              fontSize: 24,
              color: const Color(0xFF556B2F).withOpacity(0.8),
              fontWeight: FontWeight.bold,
            ),
          ),

          // Profil utilisateur avec style Art1Gallery
          GestureDetector(
            onTap: () {
              // Navigation vers la page de compte
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AccountPage(user: widget.user),
                ),
              );
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
                Icons.person_rounded,
                color: Color(0xFF556B2F),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }


}