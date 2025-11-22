# Script PowerShell pour Firebase App Distribution
# Version Windows du script sendToFirebase.sh

# Configuration
$ANDROID_APP_ID = "1:610457456142:android:211a0a7b5813356008765f"
$IOS_APP_ID = ""
$GROUPS = "testeursandroid"
$BuildIOS = $false

$RELEASE_NOTES = @"
Ajout page principale avec renvie vers la page utilisateur, les députés et les votes.
Page depute : Amelioration experience UI (masquage de la carte Mon député si pas de député trouvé, focus sur la recherche).
Ajout de la pages des votes a lassemblee nationale avec page de detail du vote
Possibilite dans l apage depute de parcourir les votes du député en question.
Ajout de la page de contact avec email du contact.
Ajout de la page des autres mandats du député.
"@

Write-Host "Build APK Android..." -ForegroundColor Yellow

# Build APK Android
try {
    flutter build apk --release
    if ($LASTEXITCODE -ne 0) {
        throw "Erreur lors du build Android"
    }
} catch {
    Write-Host "ERREUR lors du build APK: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Vérifier si l'APK existe
$APK_PATH = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $APK_PATH) {
    Write-Host "APK trouvé: $APK_PATH" -ForegroundColor Green
    
    Write-Host "Distribution APK Android via Firebase App Distribution..." -ForegroundColor Yellow
    
    try {
        # Distribution APK Android
        firebase appdistribution:distribute $APK_PATH `
            --app $ANDROID_APP_ID `
            --testers "christophe.goestchel@gmail.com"
            # --groups $GROUPS
            
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Distribution Android réussie !" -ForegroundColor Green
        } else {
            throw "Erreur lors de la distribution"
        }
    } catch {
        Write-Host "ERREUR lors de la distribution APK: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "ERREUR: APK non trouvé: $APK_PATH" -ForegroundColor Red
    exit 1
}

# Build iOS (optionnel et seulement si BuildIOS est activé)
if ($BuildIOS) {
    Write-Host "ATTENTION: Build iOS non supporté sur Windows - utilisez macOS pour iOS" -ForegroundColor Yellow
} else {
    Write-Host "Build et distribution iOS ignorés (BuildIOS=false ou Windows)." -ForegroundColor Cyan
}

Write-Host "Script terminé avec succès !" -ForegroundColor Green

# Optionnel: Ouvrir la console Firebase
$openConsole = Read-Host "Voulez-vous ouvrir la console Firebase ? (y/N)"
if ($openConsole -eq "y" -or $openConsole -eq "Y") {
    Start-Process "https://console.firebase.google.com/project/agorapush-610457456142/appdistribution"
}