# Poli

**Poli** est une application macOS qui vit dans la barre de menus et offre de la **correction grammaticale** et de la **traduction** propulsées par l'IA — directement depuis n'importe quelle application.

Sélectionnez du texte, appuyez sur un raccourci clavier, et le texte corrigé ou traduit est automatiquement collé en place.

## Fonctionnalités

### Correction grammaticale
- Corrige l'orthographe, la grammaire et le style via un backend IA
- Affiche les erreurs détaillées avec les règles appliquées
- Raccourci global : **Option + Shift + C**

### Traduction
- 20 langues supportées (français, anglais, espagnol, allemand, italien, portugais, néerlandais, russe, chinois, japonais, coréen, arabe, polonais, turc, suédois, norvégien, danois, finnois, tchèque, roumain)
- Détection automatique de la langue source
- Conseils pédagogiques (faux amis, expressions idiomatiques)
- Raccourci global : **Option + Shift + T**

### Interface menu bar
- Popover accessible depuis l'icône dans la barre de menus
- 4 onglets : Correction, Traduction, Historique, Réglages
- Collage automatique du résultat dans le champ actif
- Bannière de résultat avec diff visuel et conseils

### Historique
- Toutes les corrections et traductions sont sauvegardées
- Recherche, filtres par type, favoris
- Synchronisé avec le backend

### Abonnements
| | Free | Starter | Pro |
|---|---|---|---|
| Actions | 10 (à vie) | 50/jour | 500/jour |
| Langues | 4 | 20 | 20 |
| Longueur max | 5 000 car. | 20 000 car. | 20 000 car. |
| Prix | Gratuit | 4,99 $/mois | 19,99 $/mois |

## Prérequis

- macOS 13.0+
- Xcode 16.2+
- Un backend Laravel fonctionnel (voir la configuration de l'URL dans `Poli/Utils/Constants.swift`)

## Installation

```bash
git clone <repo-url>
cd poli-app
open Poli.xcodeproj
```

Les dépendances SPM (HotKey) sont résolues automatiquement par Xcode.

Build et run avec **Cmd+B** puis **Cmd+R**. Le scheme **Poli-Local** est sélectionné par défaut pour le développement.

## Environnements

Le projet dispose de 3 schemes Xcode, chacun pointant vers un backend différent :

| Scheme | Environnement | URL Backend |
|---|---|---|
| **Poli-Local** | Développement local | `https://poli.test` |
| **Poli-Staging** | Staging | `https://staging.poli-app.com` |
| **Poli-Prod** | Production | `https://poli-app.com` |

La sélection se fait via le sélecteur de scheme dans Xcode (à gauche du bouton Run). La configuration est gérée par des flags de compilation Swift (`DEBUG`, `STAGING`) dans `Poli/Utils/Constants.swift`.

## Permissions requises

L'application demande deux permissions au premier lancement via un onboarding guidé :

1. **Accessibilité** — Permet de lire le texte sélectionné dans d'autres applications (simulation de Cmd+C via AppleScript)
2. **Notifications** — Affiche les confirmations de correction/traduction et les messages d'erreur

## Stack technique

- **SwiftUI** — Interface déclarative
- **AppKit** — Intégration menu bar (NSStatusItem, NSPopover)
- **StoreKit 2** — Gestion des abonnements in-app
- **HotKey** (SPM) — Raccourcis clavier globaux
- **URLSession** — Communication avec le backend REST
- **Keychain** — Stockage sécurisé du token d'authentification

## Localisation

L'application est entièrement localisée en **anglais** et **français** via le format `.xcstrings`.

## Licence

Propriétaire. Tous droits réservés.
