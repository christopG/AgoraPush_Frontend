# 📱 Configuration Frontend - Variables d'environnement

## 🎯 **Configuration automatique réalisée**

Votre app Flutter utilise maintenant les variables d'environnement pour se connecter au backend Railway.

### ✅ **Ce qui a été configuré :**

1. **📄 Fichier `.env` créé** avec votre URL Railway
2. **📦 Dépendance `flutter_dotenv`** ajoutée
3. **🔧 Service modifié** pour lire les variables d'environnement
4. **🚀 Main.dart mis à jour** pour charger la config au démarrage

---

## 🔧 **Configuration actuelle**

### **Fichier `.env` :**
```env
API_BASE_URL=https://agorapushbackend-production.up.railway.app
```

### **Avantages de cette approche :**
- ✅ **Facile à modifier** sans recompiler l'app
- ✅ **Différents environnements** (dev/prod/test)  
- ✅ **Sécurisé** (ne pas hardcoder les URLs)
- ✅ **Maintenable** pour l'équipe

---

## 🎮 **Comment changer d'environnement**

### **🏠 Pour tester en local :**
Modifiez `.env` :
```env
API_BASE_URL=http://localhost:3000
```

### **🚀 Pour la production Railway :**
Modifiez `.env` :
```env
API_BASE_URL=https://agorapushbackend-production.up.railway.app
```

### **🧪 Pour un autre serveur de test :**
```env
API_BASE_URL=https://mon-autre-serveur.com
```

---

## 📋 **Structure des fichiers**

```
frontend/
├── .env                 # Configuration active (ignoré par git)
├── .env.example        # Template de configuration
├── lib/
│   ├── main.dart       # Charge les variables au démarrage
│   └── services/
│       └── admin_auth_service.dart  # Utilise les variables
└── pubspec.yaml        # Dépendances incluant flutter_dotenv
```

---

## 🚨 **Important : Sécurité**

### **✅ Bonnes pratiques :**
- Le fichier `.env` est **ignoré par git** (déjà configuré)
- Utilisez `.env.example` comme template pour l'équipe
- Ne jamais committer d'URLs de production dans le code

### **🔄 Pour l'équipe :**
1. Copiez `.env.example` vers `.env`
2. Modifiez l'URL selon votre environnement
3. Partagez le template, pas la config

---

## 🧪 **Test de la configuration**

### **1. Vérifier que l'app démarre :**
```bash
flutter run
```

### **2. Tester la connexion admin :**
1. Lancez l'app
2. Connectez-vous avec un utilisateur local
3. Cliquez sur "Se connecter comme admin"  
4. Testez avec le mot de passe admin Railway

### **3. Debug en cas de problème :**
- Vérifiez que le fichier `.env` existe
- Vérifiez l'URL Railway (sans trailing slash)
- Consultez les logs Flutter pour les erreurs réseau

---

## 🎯 **Prêt à utiliser !**

Votre app Flutter est maintenant configurée pour :
- ✅ Se connecter automatiquement à Railway
- ✅ Basculer facilement entre environnements
- ✅ Être maintenue par l'équipe
- ✅ Respecter les bonnes pratiques de sécurité

**🎉 Testez dès maintenant la connexion admin !**