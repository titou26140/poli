# Poli

**Poli** — Polish your text instantly.

Application macOS menu bar de correction grammaticale et de traduction instantanee, propulsee par l'IA Claude (Anthropic).

## Fonctionnalites

- **Correction grammaticale instantanee** depuis n'importe quelle app via `Option+Shift+C`
- **Traduction instantanee** entre 20+ langues via `Option+Shift+T`
- **Detection automatique** de la langue source
- **Auto-paste** : le texte corrige/traduit est colle automatiquement si un champ texte est actif
- **Historique** de toutes les corrections et traductions
- **Diff visuel** montrant les corrections apportees
- **100% natif macOS** — leger, rapide, respecte les conventions systeme

## Comment ca marche

```
1. Selectionnez du texte dans n'importe quelle app
2. Copiez-le (Cmd+C)
3. Appuyez sur le raccourci Poli :
   - Option+Shift+C  ->  Correction grammaticale
   - Option+Shift+T  ->  Traduction
4. Le texte corrige/traduit est copie et colle automatiquement
```

## Architecture

```
poli/
├── Poli/                    # App macOS (Swift/SwiftUI)
│   ├── App/                 # Point d'entree, AppDelegate, etat global
│   ├── Services/            # Services metier (Clipboard, HotKey, AI, etc.)
│   ├── Models/              # Modeles SwiftData + enums
│   ├── ViewModels/          # Logique des vues
│   ├── Views/               # Vues SwiftUI
│   ├── Subscription/        # StoreKit 2
│   ├── Resources/           # Assets, localisation
│   └── Utils/               # Helpers, extensions
├── backend/                 # Backend Laravel + Haystack
│   ├── app/                 # Code applicatif Laravel
│   ├── routes/              # Routes API
│   └── README.md            # Documentation backend
└── POLI_IMPLEMENTATION_PLAN.md
```

## Stack technique

### App macOS
| Composant | Technologie |
|-----------|-------------|
| Langage | Swift 5.9+ |
| UI | SwiftUI + AppKit |
| Architecture | MVVM + Services |
| Persistence | SwiftData |
| Raccourcis globaux | HotKey (Carbon APIs) |
| Paiements | StoreKit 2 |
| OS minimum | macOS 14 Sonoma |

### Backend
| Composant | Technologie |
|-----------|-------------|
| Framework | Laravel (PHP) |
| Pipeline IA | deepset Haystack |
| Role | Proxy API Claude, auth, abonnements, historique |

## Modele economique

### Gratuit
- 10 corrections/traductions par jour
- 4 langues (FR, EN, ES, DE)
- Historique 7 jours

### Pro (4.99/mois ou 29.99/an)
- Corrections et traductions illimitees
- 20+ langues
- Historique illimite
- Raccourcis personnalisables
- Choix du ton (formel, informel, professionnel, academique)
- Export de l'historique

## Prerequis pour le developpement

- **Xcode 15+** avec macOS 14 SDK
- **PHP 8.2+** et **Composer** pour le backend Laravel
- **Python 3.10+** pour Haystack (microservice IA)
- Cle API Anthropic (pour le backend)

## Configuration

### App macOS
1. Ouvrir `Poli.xcodeproj` dans Xcode
2. Configurer le signing (team, bundle ID `com.poli`)
3. Build & Run

### Backend
Voir [`backend/README.md`](backend/README.md) pour les instructions completes.

## Avancement

- [x] Phase 0 — Plan d'implementation
- [x] Phase 1 — Fondations (Menu Bar + Clipboard + Raccourcis)
- [x] Phase 2 — Moteur IA (API Claude via backend)
- [x] Phase 3 — UX Complete (Popover + Notifications + Auto-paste)
- [x] Phase 4 — Historique & Persistence (SwiftData)
- [x] Phase 5 — Monetisation (StoreKit 2)
- [x] Backend Laravel (API, Auth, Abonnements, Historique)
- [ ] Phase 6 — Polish, Localisation & Soumission App Store
- [ ] Creation du projet Xcode (ajout des fichiers + SPM deps)
- [ ] Integration Haystack (pipeline IA avance)

## Licence

Proprietary - All rights reserved.
