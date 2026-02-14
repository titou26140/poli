# Poli — Guide d'implémentation pour Claude Code

## Projet

**Poli** est une application macOS menu bar de correction grammaticale et traduction instantanée, propulsée par l'API Claude (Anthropic).

## Architecture

### App macOS (`Poli/`)
- **Langage** : Swift 5.9+
- **UI** : SwiftUI + AppKit (NSStatusItem, NSPopover)
- **Architecture** : MVVM + Services
- **Persistence** : SwiftData
- **OS minimum** : macOS 14 Sonoma
- **Bundle ID** : `com.poli`
- **Distribution** : Mac App Store (sandboxed)

### Backend (`backend/`)
- **Framework** : Laravel (PHP)
- **AI Pipeline** : deepset Haystack (Python microservice)
- **Rôle** : Proxy API Claude, gestion comptes/abonnements, historique, rate limiting
- **L'app macOS ne contacte JAMAIS directement l'API Anthropic** — tout passe par le backend

## Fichiers clés

### App macOS
- `Poli/App/PoliApp.swift` — Point d'entrée (@main), pas de WindowGroup (menu bar only)
- `Poli/App/AppDelegate.swift` — NSStatusItem + NSPopover + raccourcis globaux
- `Poli/App/AppState.swift` — État global @Observable
- `Poli/Services/` — Services métier (Clipboard, HotKey, AI, Paste, Notification)
- `Poli/Models/` — Modèles SwiftData + enums
- `Poli/Views/` — Vues SwiftUI (Popover, History, Settings, Paywall, Onboarding)
- `Poli/Subscription/` — StoreKit 2 (StoreManager, EntitlementManager)

### Backend Laravel
- `backend/routes/api.php` — Routes API
- `backend/app/Http/Controllers/` — Controllers (Auth, Correction, Translation, Subscription)
- `backend/app/Services/` — Services métier (AnthropicService, HaystackService)

## Conventions de code

### Swift
- Utiliser `async/await` partout (pas de callbacks/Combine)
- Services en singleton via `static let shared`
- État partagé via `@Observable` (pas ObservableObject, on est sur macOS 14+)
- Erreurs typées avec `enum PoliError: LocalizedError`
- Clé API dans le Keychain via `KeychainHelper`
- Localisation : FR + EN via `Localizable.xcstrings`

### Laravel/PHP
- PSR-12 coding standard
- Form Requests pour la validation
- Resources pour les réponses API
- Sanctum pour l'authentification API

## Raccourcis clavier globaux
- `Option+Shift+C` (⌥⇧C) — Correction grammaticale
- `Option+Shift+T` (⌥⇧T) — Traduction

## Flux principal
1. Utilisateur copie du texte (Cmd+C)
2. Appuie sur raccourci Poli
3. App lit le presse-papier
4. Envoie au backend Laravel → Haystack → API Claude
5. Résultat copié dans le presse-papier
6. Auto-paste si champ texte actif (Accessibility API)
7. Notification de confirmation

## Modèle économique
- **Free** : 10 actions/jour, 4 langues (FR/EN/ES/DE), historique 7 jours
- **Pro** (4.99/mois ou 29.99/an) : illimité, 20+ langues, historique illimité, modèle Sonnet

## Phases d'implémentation
1. Fondations (Menu Bar + Clipboard + Raccourcis)
2. Moteur IA (API Claude via backend)
3. UX Complète (Popover + Notifications + Auto-paste)
4. Historique & Persistence (SwiftData)
5. Monétisation (StoreKit 2)
6. Polish, Localisation & Soumission

## Couleurs
- Primaire : `#5B5FE6` (indigo)
- Secondaire : `#9B6FE8` (violet)
- Succès : `#34C759` (vert)
- Erreur : `#FF3B30` (rouge)
- Warning : `#F5A623` (orange)

## Points d'attention
- `LSUIElement = YES` dans Info.plist (pas d'icône Dock)
- Sandbox obligatoire pour le Mac App Store
- Entitlement `com.apple.security.network.client` pour les appels réseau
- L'auto-paste via CGEvent nécessite les permissions Accessibility
- Ne JAMAIS hardcoder de clé API dans le binaire
- Tester sur macOS 14 Sonoma ET macOS 15 Sequoia
