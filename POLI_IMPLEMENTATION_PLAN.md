# 🟣 POLI — Plan d'Implémentation Complet

> **Ce document est le plan de référence pour construire Poli, une application macOS menu bar de correction grammaticale et de traduction instantanée.**
> Il est conçu pour être exécuté phase par phase par un développeur ou un agent de code (Claude Code).

---

## Table des matières

1. [Vision produit](#1-vision-produit)
2. [Décisions techniques validées](#2-décisions-techniques-validées)
3. [Architecture du projet](#3-architecture-du-projet)
4. [Phase 1 — Fondations (Menu Bar + Clipboard + Raccourcis)](#4-phase-1--fondations)
5. [Phase 2 — Moteur IA (API Claude)](#5-phase-2--moteur-ia)
6. [Phase 3 — UX Complète (Popover + Notifications + Auto-paste)](#6-phase-3--ux-complète)
7. [Phase 4 — Historique & Persistence](#7-phase-4--historique--persistence)
8. [Phase 5 — Monétisation (StoreKit 2)](#8-phase-5--monétisation)
9. [Phase 6 — Polish, Localisation & Soumission App Store](#9-phase-6--polish-localisation--soumission)
10. [Prompts IA (correction & traduction)](#10-prompts-ia)
11. [Direction artistique](#11-direction-artistique)
12. [Modèle économique](#12-modèle-économique)
13. [Contraintes App Store & Sandboxing](#13-contraintes-app-store--sandboxing)
14. [Checklist finale avant soumission](#14-checklist-finale)

---

## 1. Vision Produit

**Poli** est une application macOS qui vit dans la barre de menus. Elle permet à l'utilisateur de corriger la grammaire ou de traduire n'importe quel texte instantanément, depuis n'importe quelle application, via des raccourcis clavier globaux.

### Flux principal

```
1. L'utilisateur sélectionne du texte dans n'importe quelle app
2. Il copie le texte (Cmd+C)
3. Il appuie sur un raccourci Poli :
   - ⌥⇧C → Correction grammaticale
   - ⌥⇧T → Traduction
4. Poli lit le presse-papier
5. Poli envoie le texte à l'API Claude
6. Le résultat est copié dans le presse-papier
7. Si un champ texte est actif → Poli colle automatiquement (Cmd+V simulé)
8. Une notification discrète confirme l'action
9. L'entrée est sauvegardée dans l'historique
```

### Flux alternatif — Via le popover

```
1. L'utilisateur clique sur l'icône Poli dans la barre de menus
2. Le popover s'ouvre avec le texte du presse-papier pré-rempli
3. L'utilisateur choisit : Corriger ou Traduire
4. Pour la traduction : sélection de la langue cible
5. Le résultat s'affiche avec un diff visuel (pour les corrections)
6. Bouton "Copier" pour mettre dans le presse-papier
```

---

## 2. Décisions Techniques Validées

| Décision | Choix |
|----------|-------|
| **Moteur IA** | API Claude (Anthropic). Haiku 4.5 pour les requêtes rapides, Sonnet 4.5 en option Pro |
| **Auto-paste** | Copie toujours dans le presse-papier + auto-colle si un champ texte est actif (Accessibility API) |
| **Marché cible** | Bilingue FR + EN dès le lancement |
| **Nom** | Poli |
| **OS minimum** | macOS 14 Sonoma |
| **Distribution** | Mac App Store (sandboxed) |
| **Monétisation** | Freemium avec abonnement StoreKit 2 |

---

## 3. Architecture du Projet

### Stack technique

- **Langage** : Swift 5.9+
- **UI** : SwiftUI + AppKit (NSStatusItem pour la menu bar, NSPopover pour le popover)
- **Architecture** : MVVM + Services
- **Persistence** : SwiftData (Core Data moderne, natif Apple)
- **Raccourcis globaux** : `CGEvent` tap via `CGEvent.tapCreate` ou `HotKey` package Swift
- **Clipboard** : `NSPasteboard.general`
- **API** : URLSession async/await vers l'API Anthropic Messages
- **Paiements** : StoreKit 2 (async/await natif)
- **Auto-paste** : `CGEvent` pour simuler Cmd+V (nécessite Accessibility)

### Arborescence du projet Xcode

```
Poli/
├── Poli.xcodeproj
├── Poli/
│   ├── App/
│   │   ├── PoliApp.swift                    // @main, AppDelegate injection
│   │   ├── AppDelegate.swift                // NSApplicationDelegate, menu bar setup
│   │   └── AppState.swift                   // @Observable, état global partagé
│   │
│   ├── Services/
│   │   ├── ClipboardService.swift           // Lecture/écriture NSPasteboard
│   │   ├── HotKeyService.swift              // Raccourcis clavier globaux
│   │   ├── AIService.swift                  // Client API Claude (Anthropic)
│   │   ├── TranslationService.swift         // Logique traduction (appelle AIService)
│   │   ├── GrammarService.swift             // Logique correction (appelle AIService)
│   │   ├── LanguageDetectionService.swift   // NLLanguageRecognizer (Apple natif)
│   │   ├── PasteService.swift               // Simulation Cmd+V via Accessibility
│   │   ├── NotificationService.swift        // UNUserNotificationCenter
│   │   └── UsageTracker.swift               // Compteur quotidien (free tier)
│   │
│   ├── Models/
│   │   ├── HistoryEntry.swift               // SwiftData @Model
│   │   ├── TranslationEntry.swift           // SwiftData @Model
│   │   ├── CorrectionEntry.swift            // SwiftData @Model
│   │   ├── SupportedLanguage.swift          // Enum des langues
│   │   └── AppError.swift                   // Enum d'erreurs typées
│   │
│   ├── ViewModels/
│   │   ├── PopoverViewModel.swift           // Logique du popover principal
│   │   ├── HistoryViewModel.swift           // Logique de l'historique
│   │   └── SettingsViewModel.swift          // Logique des préférences
│   │
│   ├── Views/
│   │   ├── PopoverView.swift                // Vue principale du popover
│   │   ├── ResultView.swift                 // Affichage du résultat avec diff
│   │   ├── HistoryView.swift                // Liste historique avec filtres
│   │   ├── HistoryDetailView.swift          // Détail d'une entrée
│   │   ├── SettingsView.swift               // Préférences (raccourcis, langues, compte)
│   │   ├── PaywallView.swift                // Écran d'upgrade Pro
│   │   ├── OnboardingView.swift             // Premier lancement
│   │   └── Components/
│   │       ├── DiffTextView.swift           // Texte avec corrections surlignées
│   │       ├── LanguagePicker.swift         // Sélecteur de langue
│   │       ├── ShortcutRecorder.swift       // Enregistrement de raccourci
│   │       └── UsageMeter.swift             // Jauge d'utilisation quotidienne
│   │
│   ├── Subscription/
│   │   ├── StoreManager.swift               // StoreKit 2 : products, purchase, restore
│   │   └── EntitlementManager.swift         // Vérification free vs pro
│   │
│   ├── Resources/
│   │   ├── Assets.xcassets                  // Icônes, couleurs
│   │   ├── Localizable.xcstrings            // Localisation FR + EN
│   │   └── Config.plist                     // Configuration (API endpoint, etc.)
│   │
│   └── Utils/
│       ├── Constants.swift                  // Raccourcis par défaut, limites, etc.
│       ├── KeychainHelper.swift             // Stockage sécurisé de la clé API
│       └── Extensions/
│           ├── String+Extensions.swift
│           ├── Date+Extensions.swift
│           └── View+Extensions.swift
│
├── PoliTests/
│   ├── AIServiceTests.swift
│   ├── ClipboardServiceTests.swift
│   ├── GrammarServiceTests.swift
│   ├── TranslationServiceTests.swift
│   └── UsageTrackerTests.swift
│
└── PoliUITests/
    └── PoliUITests.swift
```

---

## 4. Phase 1 — Fondations

**Objectif** : Avoir une app menu bar fonctionnelle qui lit le presse-papier via un raccourci global.

### 4.1 — Créer le projet Xcode

- Nouveau projet macOS > App
- Interface : SwiftUI
- Langage : Swift
- Storage : SwiftData
- Bundle ID : `com.astronautagency.poli` (ou ton choix)
- Deployment Target : macOS 14.0
- Cocher "Sandbox" dans Signing & Capabilities
- **IMPORTANT** : Dans Info.plist, ajouter `LSUIElement = YES` pour que l'app ne montre PAS d'icône dans le Dock (app menu bar uniquement)

### 4.2 — AppDelegate et Menu Bar (NSStatusItem)

Créer `AppDelegate.swift` :

```swift
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Créer le status item dans la barre de menus
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            // Utiliser un SF Symbol ou une image custom
            button.image = NSImage(systemSymbolName: "textformat.abc", accessibilityDescription: "Poli")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Créer le popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.behavior = .transient // Se ferme quand on clique ailleurs
        popover.contentViewController = NSHostingController(rootView: PopoverView())
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Activer le focus sur le popover
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
```

Modifier `PoliApp.swift` :

```swift
import SwiftUI
import SwiftData

@main
struct PoliApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Pas de WindowGroup — c'est une app menu bar only
        Settings {
            SettingsView()
        }
    }
}
```

### 4.3 — ClipboardService

```swift
import AppKit

class ClipboardService {
    static let shared = ClipboardService()
    private let pasteboard = NSPasteboard.general

    /// Lit le contenu texte du presse-papier
    func read() -> String? {
        return pasteboard.string(forType: .string)
    }

    /// Écrit du texte dans le presse-papier
    func write(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Lit et retourne le contenu, nil si vide ou non-texte
    func readIfAvailable() -> String? {
        guard let text = read(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }
}
```

### 4.4 — HotKeyService (Raccourcis Clavier Globaux)

> **Approche recommandée** : Utiliser le package Swift `HotKey` (https://github.com/soffes/HotKey) qui encapsule proprement les Carbon APIs.
> Alternative : `CGEvent.tapCreate` mais plus complexe à gérer.

Ajouter le package via SPM : `https://github.com/soffes/HotKey`

```swift
import HotKey
import Carbon

class HotKeyService {
    static let shared = HotKeyService()

    private var correctionHotKey: HotKey?
    private var translationHotKey: HotKey?

    var onCorrectionTriggered: (() -> Void)?
    var onTranslationTriggered: (() -> Void)?

    func register() {
        // ⌥⇧C pour la correction
        correctionHotKey = HotKey(key: .c, modifiers: [.option, .shift])
        correctionHotKey?.keyDownHandler = { [weak self] in
            self?.onCorrectionTriggered?()
        }

        // ⌥⇧T pour la traduction
        translationHotKey = HotKey(key: .t, modifiers: [.option, .shift])
        translationHotKey?.keyDownHandler = { [weak self] in
            self?.onTranslationTriggered?()
        }
    }

    func unregister() {
        correctionHotKey = nil
        translationHotKey = nil
    }
}
```

### 4.5 — Intégration dans AppDelegate

Connecter le `HotKeyService` avec le `ClipboardService` dans l'`AppDelegate` :

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // ... setup statusItem et popover (voir 4.2) ...

    // Enregistrer les raccourcis globaux
    let hotKeyService = HotKeyService.shared
    hotKeyService.onCorrectionTriggered = {
        Task {
            await self.handleCorrection()
        }
    }
    hotKeyService.onTranslationTriggered = {
        Task {
            await self.handleTranslation()
        }
    }
    hotKeyService.register()
}

@MainActor
private func handleCorrection() async {
    guard let text = ClipboardService.shared.readIfAvailable() else {
        // Notification : "Rien dans le presse-papier"
        return
    }
    // Phase 2 : envoyer à AIService pour correction
    // Pour l'instant, on log juste
    print("[Poli] Correction demandée pour : \(text.prefix(50))...")
}

@MainActor
private func handleTranslation() async {
    guard let text = ClipboardService.shared.readIfAvailable() else {
        return
    }
    print("[Poli] Traduction demandée pour : \(text.prefix(50))...")
}
```

### 4.6 — Vérifications Phase 1

- [ ] L'app se lance et apparaît uniquement dans la barre de menus (pas dans le Dock)
- [ ] Cliquer sur l'icône ouvre le popover
- [ ] Le popover se ferme quand on clique ailleurs
- [ ] ⌥⇧C déclenche la correction (log dans la console)
- [ ] ⌥⇧T déclenche la traduction (log dans la console)
- [ ] Le ClipboardService lit correctement le presse-papier
- [ ] Les raccourcis fonctionnent même quand une autre app est au premier plan

---

## 5. Phase 2 — Moteur IA

**Objectif** : Connecter l'API Claude pour corriger et traduire le texte.

### 5.1 — AIService (Client API Claude)

```swift
import Foundation

enum AIModel: String {
    case haiku = "claude-haiku-4-5-20251001"     // Rapide, économique (free tier)
    case sonnet = "claude-sonnet-4-5-20250929"   // Plus puissant (pro tier)
}

struct AIMessage: Codable {
    let role: String
    let content: String
}

struct AIRequest: Codable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [AIMessage]
}

struct AIResponse: Codable {
    struct Content: Codable {
        let type: String
        let text: String
    }
    let content: [Content]
}

class AIService {
    static let shared = AIService()

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiVersion = "2023-06-01"

    /// La clé API est stockée dans le Keychain (voir KeychainHelper)
    var apiKey: String {
        get { KeychainHelper.shared.read(key: "anthropic_api_key") ?? "" }
        set { KeychainHelper.shared.save(key: "anthropic_api_key", value: newValue) }
    }

    func send(
        system: String,
        userMessage: String,
        model: AIModel = .haiku,
        maxTokens: Int = 4096
    ) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        let body = AIRequest(
            model: model.rawValue,
            max_tokens: maxTokens,
            system: system,
            messages: [AIMessage(role: "user", content: userMessage)]
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PoliError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PoliError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let aiResponse = try JSONDecoder().decode(AIResponse.self, from: data)

        guard let text = aiResponse.content.first?.text else {
            throw PoliError.emptyResponse
        }

        return text
    }
}

enum PoliError: LocalizedError {
    case networkError(String)
    case apiError(statusCode: Int, message: String)
    case emptyResponse
    case emptyClipboard
    case dailyLimitReached
    case notSubscribed

    var errorDescription: String? {
        switch self {
        case .networkError(let msg): return "Network error: \(msg)"
        case .apiError(let code, let msg): return "API error (\(code)): \(msg)"
        case .emptyResponse: return "Empty response from API"
        case .emptyClipboard: return "Nothing in clipboard"
        case .dailyLimitReached: return "Daily limit reached"
        case .notSubscribed: return "Pro subscription required"
        }
    }
}
```

### 5.2 — KeychainHelper

```swift
import Security
import Foundation

class KeychainHelper {
    static let shared = KeychainHelper()
    private let service = "com.astronautagency.poli"

    func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

### 5.3 — GrammarService

```swift
class GrammarService {
    static let shared = GrammarService()
    private let ai = AIService.shared

    /// Corrige la grammaire du texte
    /// Retourne un tuple (texte corrigé, explication des changements)
    func correct(text: String, model: AIModel = .haiku) async throws -> (corrected: String, explanation: String) {
        let system = """
        Tu es un correcteur grammatical expert. Ta tâche est de corriger les fautes de grammaire, \
        d'orthographe, de ponctuation et de syntaxe dans le texte fourni.

        Règles :
        - Corrige UNIQUEMENT les erreurs, ne reformule pas le style
        - Préserve le ton et le registre de langue de l'utilisateur
        - Préserve la mise en forme (retours à la ligne, etc.)
        - Détecte automatiquement la langue du texte et corrige dans cette langue
        - Si le texte est déjà correct, retourne-le tel quel

        Format de réponse OBLIGATOIRE (JSON) :
        {
          "corrected": "le texte corrigé",
          "explanation": "liste courte des corrections apportées, ou 'Aucune correction nécessaire'"
        }

        Réponds UNIQUEMENT avec le JSON, sans backticks, sans texte avant ou après.
        """

        let response = try await ai.send(system: system, userMessage: text, model: model)

        // Parser le JSON de la réponse
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let corrected = json["corrected"],
              let explanation = json["explanation"] else {
            // Fallback : si le parsing échoue, retourner la réponse brute
            return (corrected: response, explanation: "")
        }

        return (corrected: corrected, explanation: explanation)
    }
}
```

### 5.4 — TranslationService

```swift
import NaturalLanguage

class TranslationService {
    static let shared = TranslationService()
    private let ai = AIService.shared

    /// Traduit le texte vers la langue cible
    func translate(
        text: String,
        targetLanguage: SupportedLanguage,
        model: AIModel = .haiku
    ) async throws -> (translated: String, sourceLanguage: String) {

        // Détection automatique de la langue source
        let detectedLanguage = LanguageDetectionService.shared.detect(text: text)

        let system = """
        Tu es un traducteur professionnel. Traduis le texte fourni vers \(targetLanguage.displayName).

        Règles :
        - Traduis de manière naturelle et idiomatique, pas mot à mot
        - Préserve le ton et le registre (formel, informel, technique, etc.)
        - Préserve la mise en forme (retours à la ligne, etc.)
        - Si le texte est déjà dans la langue cible, retourne-le tel quel
        - Ne traduis PAS les noms propres, marques, ou termes techniques reconnus

        Format de réponse OBLIGATOIRE (JSON) :
        {
          "translated": "le texte traduit",
          "source_language": "la langue source détectée (code ISO 639-1)"
        }

        Réponds UNIQUEMENT avec le JSON, sans backticks, sans texte avant ou après.
        """

        let response = try await ai.send(system: system, userMessage: text, model: model)

        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let translated = json["translated"],
              let sourceLanguage = json["source_language"] else {
            return (translated: response, sourceLanguage: detectedLanguage)
        }

        return (translated: translated, sourceLanguage: sourceLanguage)
    }
}
```

### 5.5 — LanguageDetectionService

```swift
import NaturalLanguage

class LanguageDetectionService {
    static let shared = LanguageDetectionService()
    private let recognizer = NLLanguageRecognizer()

    /// Détecte la langue du texte (code ISO 639-1)
    func detect(text: String) -> String {
        recognizer.reset()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue ?? "unknown"
    }

    /// Détecte avec un score de confiance
    func detectWithConfidence(text: String) -> (language: String, confidence: Double) {
        recognizer.reset()
        recognizer.processString(text)
        guard let dominant = recognizer.dominantLanguage else {
            return ("unknown", 0.0)
        }
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        let confidence = hypotheses[dominant] ?? 0.0
        return (dominant.rawValue, confidence)
    }
}
```

### 5.6 — SupportedLanguage Enum

```swift
enum SupportedLanguage: String, CaseIterable, Codable, Identifiable {
    case french = "fr"
    case english = "en"
    case spanish = "es"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case dutch = "nl"
    case russian = "ru"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case arabic = "ar"
    case polish = "pl"
    case turkish = "tr"
    case swedish = "sv"
    case norwegian = "no"
    case danish = "da"
    case finnish = "fi"
    case czech = "cs"
    case romanian = "ro"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .french: return "Français"
        case .english: return "English"
        case .spanish: return "Español"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .dutch: return "Nederlands"
        case .russian: return "Русский"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .arabic: return "العربية"
        case .polish: return "Polski"
        case .turkish: return "Türkçe"
        case .swedish: return "Svenska"
        case .norwegian: return "Norsk"
        case .danish: return "Dansk"
        case .finnish: return "Suomi"
        case .czech: return "Čeština"
        case .romanian: return "Română"
        }
    }

    var flag: String {
        switch self {
        case .french: return "🇫🇷"
        case .english: return "🇬🇧"
        case .spanish: return "🇪🇸"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇵🇹"
        case .dutch: return "🇳🇱"
        case .russian: return "🇷🇺"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .arabic: return "🇸🇦"
        case .polish: return "🇵🇱"
        case .turkish: return "🇹🇷"
        case .swedish: return "🇸🇪"
        case .norwegian: return "🇳🇴"
        case .danish: return "🇩🇰"
        case .finnish: return "🇫🇮"
        case .czech: return "🇨🇿"
        case .romanian: return "🇷🇴"
        }
    }

    /// Langues disponibles dans le plan gratuit
    static let freeTierLanguages: [SupportedLanguage] = [.french, .english, .spanish, .german]
}
```

### 5.7 — Connexion dans AppDelegate

Mettre à jour `handleCorrection` et `handleTranslation` :

```swift
@MainActor
private func handleCorrection() async {
    guard let text = ClipboardService.shared.readIfAvailable() else {
        NotificationService.shared.send(title: "Poli", body: "Rien dans le presse-papier")
        return
    }

    // Vérifier la limite quotidienne (free tier)
    guard EntitlementManager.shared.canPerformAction() else {
        NotificationService.shared.send(title: "Poli", body: "Limite quotidienne atteinte. Passez à Pro !")
        return
    }

    do {
        let model: AIModel = EntitlementManager.shared.isPro ? .sonnet : .haiku
        let result = try await GrammarService.shared.correct(text: text, model: model)

        // Copier dans le presse-papier
        ClipboardService.shared.write(result.corrected)

        // Auto-coller si un champ texte est actif
        PasteService.shared.pasteIfTextFieldActive()

        // Notification
        let hasChanges = result.corrected != text
        NotificationService.shared.send(
            title: hasChanges ? "✓ Texte corrigé" : "✓ Aucune correction",
            body: hasChanges ? result.explanation : "Le texte est déjà correct"
        )

        // Sauvegarder dans l'historique
        await HistoryManager.shared.saveCorrectionEntry(
            original: text,
            corrected: result.corrected,
            explanation: result.explanation
        )

        UsageTracker.shared.increment()
    } catch {
        NotificationService.shared.send(title: "Poli — Erreur", body: error.localizedDescription)
    }
}

@MainActor
private func handleTranslation() async {
    guard let text = ClipboardService.shared.readIfAvailable() else {
        NotificationService.shared.send(title: "Poli", body: "Rien dans le presse-papier")
        return
    }

    guard EntitlementManager.shared.canPerformAction() else {
        NotificationService.shared.send(title: "Poli", body: "Limite quotidienne atteinte. Passez à Pro !")
        return
    }

    do {
        let targetLanguage = UserDefaults.standard.string(forKey: "targetLanguage")
            .flatMap { SupportedLanguage(rawValue: $0) } ?? .english
        let model: AIModel = EntitlementManager.shared.isPro ? .sonnet : .haiku

        let result = try await TranslationService.shared.translate(
            text: text,
            targetLanguage: targetLanguage,
            model: model
        )

        ClipboardService.shared.write(result.translated)
        PasteService.shared.pasteIfTextFieldActive()

        let sourceLang = SupportedLanguage(rawValue: result.sourceLanguage)?.flag ?? "🌐"
        let targetLang = targetLanguage.flag
        NotificationService.shared.send(
            title: "\(sourceLang) → \(targetLang) Traduit",
            body: String(result.translated.prefix(100))
        )

        await HistoryManager.shared.saveTranslationEntry(
            original: text,
            translated: result.translated,
            sourceLanguage: result.sourceLanguage,
            targetLanguage: targetLanguage.rawValue
        )

        UsageTracker.shared.increment()
    } catch {
        NotificationService.shared.send(title: "Poli — Erreur", body: error.localizedDescription)
    }
}
```

### 5.8 — Vérifications Phase 2

- [ ] La clé API est stockée dans le Keychain
- [ ] ⌥⇧C corrige le texte du presse-papier et le remplace par le texte corrigé
- [ ] ⌥⇧T traduit le texte et le remplace
- [ ] La détection de langue fonctionne (NLLanguageRecognizer)
- [ ] Les erreurs réseau sont gérées proprement (timeout, pas de connexion, erreur API)
- [ ] Le JSON de réponse est parsé correctement
- [ ] Fallback si le JSON est malformé

---

## 6. Phase 3 — UX Complète

**Objectif** : Popover complet, notifications, auto-paste, diff visuel.

### 6.1 — PasteService (Auto-paste via Accessibility)

```swift
import ApplicationServices
import AppKit

class PasteService {
    static let shared = PasteService()

    /// Vérifie si l'app a les permissions Accessibility
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Demande les permissions Accessibility
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Simule Cmd+V pour coller le contenu du presse-papier
    func pasteIfTextFieldActive() {
        guard hasAccessibilityPermission else { return }

        // Petit délai pour que le presse-papier soit prêt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Créer l'événement Cmd+V (keyDown)
            let source = CGEventSource(stateID: .hidSystemState)

            // Key down Cmd+V
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 0x09 = V
            keyDown?.flags = .maskCommand

            // Key up Cmd+V
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            keyUp?.flags = .maskCommand

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }
}
```

> **Note sandboxing** : L'auto-paste via `CGEvent.post` nécessite l'entitlement `com.apple.security.temporary-exception.apple-events` ET que l'utilisateur autorise Poli dans Préférences Système > Confidentialité > Accessibilité. Si Apple refuse cet entitlement, le fallback est de ne copier que dans le presse-papier.

### 6.2 — NotificationService

```swift
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    func setup() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immédiat
        )

        UNUserNotificationCenter.current().add(request)
    }
}
```

### 6.3 — PopoverView (Vue principale)

```swift
import SwiftUI

struct PopoverView: View {
    @State private var inputText: String = ""
    @State private var resultText: String = ""
    @State private var isLoading = false
    @State private var selectedTab: Tab = .correct
    @State private var targetLanguage: SupportedLanguage = .english

    enum Tab {
        case correct, translate, history, settings
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header avec tabs
            HStack(spacing: 16) {
                TabButton(title: "Corriger", icon: "textformat.abc", isSelected: selectedTab == .correct) {
                    selectedTab = .correct
                }
                TabButton(title: "Traduire", icon: "globe", isSelected: selectedTab == .translate) {
                    selectedTab = .translate
                }
                TabButton(title: "Historique", icon: "clock", isSelected: selectedTab == .history) {
                    selectedTab = .history
                }
                Spacer()
                Button(action: { selectedTab = .settings }) {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Contenu selon l'onglet
            switch selectedTab {
            case .correct:
                CorrectionTabView()
            case .translate:
                TranslationTabView()
            case .history:
                HistoryView()
            case .settings:
                SettingsView()
            }
        }
        .frame(width: 360, height: 480)
        .onAppear {
            // Pré-remplir avec le contenu du presse-papier
            if let clipboardText = ClipboardService.shared.readIfAvailable() {
                inputText = clipboardText
            }
        }
    }
}
```

### 6.4 — DiffTextView (Affichage des corrections)

Ce composant affiche le texte original et le texte corrigé avec un diff visuel (texte supprimé en rouge barré, texte ajouté en vert).

```swift
import SwiftUI

struct DiffTextView: View {
    let original: String
    let corrected: String

    var body: some View {
        // Utiliser un algorithme de diff au niveau des mots
        let diffs = computeWordDiff(original: original, corrected: corrected)

        Text(diffs.reduce(AttributedString()) { result, diff in
            var attributed = AttributedString(diff.text)
            switch diff.type {
            case .unchanged:
                break
            case .removed:
                attributed.strikethroughStyle = .single
                attributed.foregroundColor = .red.opacity(0.7)
            case .added:
                attributed.foregroundColor = .green
                attributed.backgroundColor = .green.opacity(0.1)
            }
            return result + attributed
        })
    }
}

// Types pour le diff
enum DiffType {
    case unchanged, removed, added
}

struct DiffSegment {
    let text: String
    let type: DiffType
}

/// Calcul du diff au niveau des mots (implémentation simplifiée)
/// Pour une implémentation robuste, utiliser l'algorithme de Myers ou le package swift-algorithms
func computeWordDiff(original: String, corrected: String) -> [DiffSegment] {
    // Implémentation avec l'algorithme LCS (Longest Common Subsequence)
    // au niveau des mots pour un diff lisible
    // À implémenter avec swift-algorithms ou manuellement
    // ...
    return [] // Placeholder
}
```

> **Note** : Pour le diff, utiliser le package `swift-algorithms` (https://github.com/apple/swift-algorithms) qui contient un algorithme de diff efficace, ou implémenter Myers' diff algorithm.

### 6.5 — Vérifications Phase 3

- [ ] Le popover s'ouvre avec le texte du presse-papier pré-rempli
- [ ] On peut corriger via le popover et voir le diff visuel
- [ ] On peut traduire via le popover avec sélection de la langue
- [ ] Les notifications macOS fonctionnent
- [ ] L'auto-paste fonctionne quand les permissions Accessibility sont accordées
- [ ] L'app demande proprement les permissions Accessibility au premier usage
- [ ] Le bouton "Copier" copie le résultat dans le presse-papier

---

## 7. Phase 4 — Historique & Persistence

**Objectif** : Sauvegarder toutes les corrections et traductions avec SwiftData.

### 7.1 — Modèles SwiftData

```swift
import SwiftData
import Foundation

@Model
class CorrectionEntry {
    var id: UUID
    var originalText: String
    var correctedText: String
    var explanation: String
    var language: String
    var createdAt: Date
    var isFavorite: Bool

    init(original: String, corrected: String, explanation: String, language: String) {
        self.id = UUID()
        self.originalText = original
        self.correctedText = corrected
        self.explanation = explanation
        self.language = language
        self.createdAt = Date()
        self.isFavorite = false
    }
}

@Model
class TranslationEntry {
    var id: UUID
    var originalText: String
    var translatedText: String
    var sourceLanguage: String
    var targetLanguage: String
    var createdAt: Date
    var isFavorite: Bool

    init(original: String, translated: String, sourceLanguage: String, targetLanguage: String) {
        self.id = UUID()
        self.originalText = original
        self.translatedText = translated
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.createdAt = Date()
        self.isFavorite = false
    }
}
```

### 7.2 — HistoryManager

```swift
import SwiftData
import Foundation

@MainActor
class HistoryManager {
    static let shared = HistoryManager()
    var modelContext: ModelContext?

    func saveCorrectionEntry(original: String, corrected: String, explanation: String) async {
        guard let context = modelContext else { return }
        let entry = CorrectionEntry(
            original: original,
            corrected: corrected,
            explanation: explanation,
            language: LanguageDetectionService.shared.detect(text: original)
        )
        context.insert(entry)
        try? context.save()

        // Nettoyage automatique pour le free tier (7 jours)
        if !EntitlementManager.shared.isPro {
            cleanOldEntries(olderThan: 7)
        }
    }

    func saveTranslationEntry(original: String, translated: String, sourceLanguage: String, targetLanguage: String) async {
        guard let context = modelContext else { return }
        let entry = TranslationEntry(
            original: original,
            translated: translated,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
        context.insert(entry)
        try? context.save()

        if !EntitlementManager.shared.isPro {
            cleanOldEntries(olderThan: 7)
        }
    }

    private func cleanOldEntries(olderThan days: Int) {
        guard let context = modelContext else { return }
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        // Supprimer les corrections anciennes
        let correctionPredicate = #Predicate<CorrectionEntry> { $0.createdAt < cutoffDate }
        try? context.delete(model: CorrectionEntry.self, where: correctionPredicate)

        // Supprimer les traductions anciennes
        let translationPredicate = #Predicate<TranslationEntry> { $0.createdAt < cutoffDate }
        try? context.delete(model: TranslationEntry.self, where: translationPredicate)
    }
}
```

### 7.3 — Configuration SwiftData dans PoliApp

```swift
@main
struct PoliApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .modelContainer(for: [CorrectionEntry.self, TranslationEntry.self])
    }
}
```

> **Important** : Passer le `modelContext` au `HistoryManager` depuis l'`AppDelegate` ou via l'environnement SwiftUI.

### 7.4 — HistoryView

```swift
import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \CorrectionEntry.createdAt, order: .reverse) var corrections: [CorrectionEntry]
    @Query(sort: \TranslationEntry.createdAt, order: .reverse) var translations: [TranslationEntry]
    @State private var filter: HistoryFilter = .all
    @State private var searchText = ""

    enum HistoryFilter {
        case all, corrections, translations
    }

    var body: some View {
        VStack(spacing: 0) {
            // Barre de recherche
            TextField("Rechercher...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            // Filtres
            Picker("", selection: $filter) {
                Text("Tout").tag(HistoryFilter.all)
                Text("Corrections").tag(HistoryFilter.corrections)
                Text("Traductions").tag(HistoryFilter.translations)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // Liste
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Afficher les entrées filtrées et triées par date
                    // Implémenter le filtrage par searchText et par type
                }
            }
        }
    }
}
```

### 7.5 — UsageTracker (Compteur quotidien)

```swift
class UsageTracker {
    static let shared = UsageTracker()

    private let defaults = UserDefaults.standard
    private let countKey = "dailyUsageCount"
    private let dateKey = "dailyUsageDate"

    /// Nombre d'actions aujourd'hui
    var todayCount: Int {
        resetIfNewDay()
        return defaults.integer(forKey: countKey)
    }

    /// Limite quotidienne pour le free tier
    let dailyLimit = 10

    /// Vérifie si l'utilisateur peut encore effectuer une action
    var canPerformAction: Bool {
        if EntitlementManager.shared.isPro { return true }
        return todayCount < dailyLimit
    }

    /// Incrémente le compteur
    func increment() {
        resetIfNewDay()
        defaults.set(todayCount + 1, forKey: countKey)
    }

    /// Actions restantes aujourd'hui
    var remainingActions: Int {
        if EntitlementManager.shared.isPro { return .max }
        return max(0, dailyLimit - todayCount)
    }

    private func resetIfNewDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let storedDate = defaults.object(forKey: dateKey) as? Date ?? .distantPast

        if Calendar.current.startOfDay(for: storedDate) < today {
            defaults.set(0, forKey: countKey)
            defaults.set(today, forKey: dateKey)
        }
    }
}
```

### 7.6 — Vérifications Phase 4

- [ ] Les corrections sont sauvegardées dans SwiftData
- [ ] Les traductions sont sauvegardées dans SwiftData
- [ ] L'historique s'affiche correctement (trié par date, le plus récent en premier)
- [ ] Le filtre corrections/traductions fonctionne
- [ ] La recherche dans l'historique fonctionne
- [ ] Le nettoyage automatique (7 jours) fonctionne pour le free tier
- [ ] Le compteur quotidien se remet à zéro chaque jour
- [ ] L'app bloque les actions quand la limite est atteinte (free tier)

---

## 8. Phase 5 — Monétisation

**Objectif** : Intégrer StoreKit 2 avec un abonnement auto-renouvelable.

### 8.1 — Configuration App Store Connect

Créer les produits in-app dans App Store Connect :

| Product ID | Type | Prix |
|---|---|---|
| `com.astronautagency.poli.pro.monthly` | Auto-Renewable Subscription | 4,99€/mois |
| `com.astronautagency.poli.pro.yearly` | Auto-Renewable Subscription | 29,99€/an |

Groupe d'abonnement : `Poli Pro`

### 8.2 — StoreManager (StoreKit 2)

```swift
import StoreKit

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false

    private let productIDs = [
        "com.astronautagency.poli.pro.monthly",
        "com.astronautagency.poli.pro.yearly"
    ]

    init() {
        // Écouter les mises à jour de transactions
        Task { await listenForTransactions() }
    }

    /// Charger les produits depuis l'App Store
    func loadProducts() async {
        isLoading = true
        do {
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
        isLoading = false
    }

    /// Acheter un produit
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    /// Restaurer les achats
    func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }

    /// Mettre à jour la liste des produits achetés
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                purchased.insert(transaction.productID)
            }
        }
        purchasedProductIDs = purchased
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                await updatePurchasedProducts()
                await transaction.finish()
            }
        }
    }
}
```

### 8.3 — EntitlementManager

```swift
import Foundation

@MainActor
class EntitlementManager: ObservableObject {
    static let shared = EntitlementManager()

    @Published var isPro: Bool = false

    private let storeManager = StoreManager.shared

    func checkEntitlements() async {
        await storeManager.updatePurchasedProducts()
        isPro = !storeManager.purchasedProductIDs.isEmpty
    }

    /// Vérifie si l'utilisateur peut effectuer une action (Pro ou dans la limite quotidienne)
    func canPerformAction() -> Bool {
        if isPro { return true }
        return UsageTracker.shared.canPerformAction
    }

    /// Vérifie si une langue est disponible pour l'utilisateur
    func isLanguageAvailable(_ language: SupportedLanguage) -> Bool {
        if isPro { return true }
        return SupportedLanguage.freeTierLanguages.contains(language)
    }
}
```

### 8.4 — PaywallView

```swift
import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var storeManager = StoreManager.shared
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(.indigo)

                Text("Poli Pro")
                    .font(.title.bold())

                Text("Corrections et traductions illimitées")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)

            // Avantages Pro
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "infinity", text: "Corrections & traductions illimitées")
                FeatureRow(icon: "globe", text: "Toutes les langues (20+)")
                FeatureRow(icon: "clock", text: "Historique illimité")
                FeatureRow(icon: "keyboard", text: "Raccourcis personnalisables")
                FeatureRow(icon: "text.quote", text: "Choix du ton (formel, informel...)")
                FeatureRow(icon: "doc.on.doc", text: "Export de l'historique")
            }
            .padding(.horizontal, 20)

            Spacer()

            // Plans
            if storeManager.isLoading {
                ProgressView()
            } else {
                VStack(spacing: 10) {
                    ForEach(storeManager.products) { product in
                        PlanButton(
                            product: product,
                            isSelected: selectedProduct?.id == product.id,
                            isYearly: product.id.contains("yearly")
                        ) {
                            selectedProduct = product
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Bouton d'achat
                Button(action: {
                    guard let product = selectedProduct else { return }
                    Task {
                        isPurchasing = true
                        _ = try? await storeManager.purchase(product)
                        isPurchasing = false
                    }
                }) {
                    if isPurchasing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("S'abonner")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(selectedProduct == nil || isPurchasing)
                .padding(.horizontal, 20)

                // Restore
                Button("Restaurer les achats") {
                    Task { await storeManager.restorePurchases() }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
            }
        }
        .task {
            await storeManager.loadProducts()
            // Pré-sélectionner le plan annuel
            selectedProduct = storeManager.products.first { $0.id.contains("yearly") }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.indigo)
            Text(text)
                .font(.subheadline)
        }
    }
}
```

### 8.5 — Vérifications Phase 5

- [ ] Les produits StoreKit se chargent correctement
- [ ] L'achat fonctionne (tester en sandbox)
- [ ] La restauration d'achat fonctionne
- [ ] Les fonctionnalités Pro se débloquent après achat
- [ ] Le paywall s'affiche quand la limite est atteinte
- [ ] Les transactions sont bien finalisées (`.finish()`)
- [ ] L'écoute des mises à jour de transaction fonctionne (renouvellements, annulations)

---

## 9. Phase 6 — Polish, Localisation & Soumission

### 9.1 — Localisation FR + EN

Créer le fichier `Localizable.xcstrings` (nouveau format Xcode 15+) avec toutes les chaînes :

**Clés principales à localiser :**

```
"correction_tab" = "Correct" / "Corriger"
"translation_tab" = "Translate" / "Traduire"
"history_tab" = "History" / "Historique"
"settings_tab" = "Settings" / "Réglages"
"copy_button" = "Copy" / "Copier"
"paste_button" = "Paste" / "Coller"
"nothing_in_clipboard" = "Nothing in clipboard" / "Rien dans le presse-papier"
"daily_limit_reached" = "Daily limit reached. Upgrade to Pro!" / "Limite quotidienne atteinte. Passez à Pro !"
"text_corrected" = "Text corrected" / "Texte corrigé"
"no_correction_needed" = "No correction needed" / "Aucune correction nécessaire"
"translated" = "Translated" / "Traduit"
"search_placeholder" = "Search..." / "Rechercher..."
"all_filter" = "All" / "Tout"
"corrections_filter" = "Corrections" / "Corrections"
"translations_filter" = "Translations" / "Traductions"
"subscribe_button" = "Subscribe" / "S'abonner"
"restore_purchases" = "Restore Purchases" / "Restaurer les achats"
"unlimited_corrections" = "Unlimited corrections & translations" / "Corrections & traductions illimitées"
"all_languages" = "All languages (20+)" / "Toutes les langues (20+)"
"unlimited_history" = "Unlimited history" / "Historique illimité"
"custom_shortcuts" = "Customizable shortcuts" / "Raccourcis personnalisables"
"remaining_actions" = "%d actions remaining today" / "%d actions restantes aujourd'hui"
"onboarding_title" = "Welcome to Poli" / "Bienvenue sur Poli"
"onboarding_subtitle" = "Polish your text instantly" / "Polissez votre texte instantanément"
"grant_accessibility" = "Grant Accessibility Permission" / "Autoriser l'accès Accessibilité"
"accessibility_explanation" = "Poli needs accessibility access to paste text automatically" / "Poli a besoin de l'accès Accessibilité pour coller le texte automatiquement"
```

### 9.2 — Onboarding (Premier lancement)

L'onboarding doit :

1. **Accueillir** : "Bienvenue sur Poli — Polissez votre texte instantanément"
2. **Expliquer les raccourcis** : Montrer visuellement ⌥⇧C et ⌥⇧T
3. **Demander les permissions** : Accessibility (pour l'auto-paste) et Notifications
4. **Configurer la langue cible** : Sélecteur de langue par défaut pour les traductions
5. **Optionnel** : Entrer une clé API Anthropic (si le backend n'est pas centralisé)
6. **Terminé** : "Vous êtes prêt ! Copiez du texte et essayez ⌥⇧C"

### 9.3 — Assets visuels à créer

- [ ] **Icône menu bar** : 16x16, 32x32 (template image, monochrome)
  - Design : lettre "P" stylisée avec trait de soulignement/curseur
  - Format : PDF ou SVG (template image pour s'adapter au dark/light mode)

- [ ] **Icône App Store** : 1024x1024
  - Design : "P" sur fond dégradé indigo (#5B5FE6) → violet (#9B6FE8)
  - Effet de brillance subtil (polish)

- [ ] **Screenshots App Store** (min 3) :
  1. Le popover ouvert avec une correction en cours
  2. Le flux raccourci clavier (⌥⇧C → texte corrigé)
  3. L'historique avec des entrées

- [ ] **Preview video** (optionnel, 15-30 secondes) :
  - Montrer le flux complet : copier texte → raccourci → texte corrigé/traduit

### 9.4 — Informations App Store

**Nom** : Poli — Correct & Translate

**Sous-titre** : Polish your text instantly (EN) / Polissez votre texte instantanément (FR)

**Description (EN)** :

```
Poli lives in your menu bar and polishes your text in seconds.

Copy any text, press a shortcut, and get instant grammar corrections or translations — pasted right back where you need it.

HOW IT WORKS
• Copy text from any app (⌘C)
• Press ⌥⇧C to correct grammar or ⌥⇧T to translate
• The corrected or translated text is copied to your clipboard
• If you're in a text field, Poli pastes it automatically

FEATURES
• Instant grammar correction in any language
• Translation between 20+ languages
• Automatic language detection
• Works with any app on your Mac
• History of all corrections and translations
• Visual diff showing what changed
• macOS native — lightweight and fast

POLI PRO
• Unlimited corrections & translations
• All 20+ languages
• Unlimited history with search
• Customizable keyboard shortcuts
• Tone selection (formal, casual, professional)
• History export
```

**Description (FR)** :

```
Poli vit dans votre barre de menus et polit votre texte en quelques secondes.

Copiez n'importe quel texte, appuyez sur un raccourci, et obtenez une correction grammaticale ou une traduction instantanée — collée directement là où vous en avez besoin.

COMMENT ÇA MARCHE
• Copiez du texte depuis n'importe quelle app (⌘C)
• Appuyez sur ⌥⇧C pour corriger ou ⌥⇧T pour traduire
• Le texte corrigé ou traduit est copié dans le presse-papier
• Si vous êtes dans un champ texte, Poli colle automatiquement

FONCTIONNALITÉS
• Correction grammaticale instantanée dans toutes les langues
• Traduction entre 20+ langues
• Détection automatique de la langue
• Fonctionne avec n'importe quelle app sur votre Mac
• Historique de toutes les corrections et traductions
• Diff visuel montrant les changements
• Natif macOS — léger et rapide

POLI PRO
• Corrections & traductions illimitées
• Toutes les 20+ langues
• Historique illimité avec recherche
• Raccourcis clavier personnalisables
• Choix du ton (formel, informel, professionnel)
• Export de l'historique
```

**Mots-clés** : grammar, translate, correction, clipboard, text, writing, proofread, language, spell, polish

**Catégorie primaire** : Productivity
**Catégorie secondaire** : Utilities

**Prix** : Gratuit (avec in-app purchases)

### 9.5 — Documents légaux

**Privacy Policy** — Doit inclure :
- Quelles données sont collectées (texte envoyé à l'API Claude pour traitement)
- Que les textes ne sont PAS stockés côté serveur (politique d'Anthropic)
- Que l'historique est stocké localement sur le Mac de l'utilisateur
- Que les données de paiement sont gérées par Apple
- Contact pour les demandes RGPD

**Terms of Service** — Doit inclure :
- Conditions d'utilisation de l'abonnement
- Politique d'annulation (gérée via Apple)
- Limitations de responsabilité (l'IA peut faire des erreurs)
- Interdiction d'utilisation abusive (spam, contenu illégal)

### 9.6 — Entitlements & Capabilities (Xcode)

```xml
<!-- Poli.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- Réseau (appels API Claude) -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- In-App Purchases -->
    <key>com.apple.developer.in-app-payments</key>
    <array>
        <string>merchant.com.astronautagency.poli</string>
    </array>

    <!-- Accessibility (pour auto-paste) -->
    <!-- NOTE: Cet entitlement peut nécessiter une exception sandbox -->
    <!-- Si Apple refuse, retirer l'auto-paste et ne garder que la copie dans le presse-papier -->
</dict>
</plist>
```

### 9.7 — Checklist de soumission App Store

- [ ] Bundle ID correctement configuré
- [ ] Signing avec le certificat de distribution (pas Development)
- [ ] Version et build number définis
- [ ] Icône 1024x1024 uploadée
- [ ] Screenshots uploadés (min 3)
- [ ] Description FR + EN rédigée
- [ ] Privacy Policy URL configurée
- [ ] Support URL configurée
- [ ] In-App Purchases créés et soumis pour review
- [ ] Catégories sélectionnées
- [ ] Mots-clés renseignés
- [ ] Age rating rempli
- [ ] Build uploadé via Xcode ou `xcrun altool`
- [ ] Notes pour le reviewer (expliquer les raccourcis globaux et l'Accessibility)

---

## 10. Prompts IA — Référence

### Prompt de correction grammaticale

```
SYSTEM:
Tu es un correcteur grammatical expert. Ta tâche est de corriger les fautes de grammaire,
d'orthographe, de ponctuation et de syntaxe dans le texte fourni.

Règles :
- Corrige UNIQUEMENT les erreurs, ne reformule pas le style
- Préserve le ton et le registre de langue de l'utilisateur
- Préserve la mise en forme (retours à la ligne, espaces, etc.)
- Détecte automatiquement la langue du texte et corrige dans cette langue
- Si le texte est déjà correct, retourne-le tel quel
- Ne corrige PAS les choix stylistiques volontaires

Format de réponse OBLIGATOIRE (JSON strict) :
{"corrected": "le texte corrigé", "explanation": "liste courte des corrections ou 'Aucune correction nécessaire'"}

Réponds UNIQUEMENT avec le JSON, sans backticks, sans texte avant ou après.

USER:
<texte à corriger>
```

### Prompt de traduction

```
SYSTEM:
Tu es un traducteur professionnel. Traduis le texte fourni vers [LANGUE CIBLE].

Règles :
- Traduis de manière naturelle et idiomatique
- Préserve le ton et le registre (formel, informel, technique, etc.)
- Préserve la mise en forme (retours à la ligne, etc.)
- Si le texte est déjà dans la langue cible, retourne-le tel quel
- Ne traduis PAS les noms propres, marques, ou termes techniques universels

Format de réponse OBLIGATOIRE (JSON strict) :
{"translated": "le texte traduit", "source_language": "code ISO 639-1"}

Réponds UNIQUEMENT avec le JSON, sans backticks, sans texte avant ou après.

USER:
<texte à traduire>
```

### Prompt de reformulation (Pro uniquement)

```
SYSTEM:
Tu es un rédacteur expert. Reformule le texte fourni selon le ton demandé : [TON].

Tons disponibles :
- formel : langage soutenu, professionnel
- informel : langage courant, décontracté
- professionnel : clair, concis, orienté business
- académique : précis, structuré, avec vocabulaire spécialisé

Règles :
- Préserve le sens original
- Adapte le vocabulaire et la structure au ton demandé
- Préserve la langue originale (ne traduis pas)

Format de réponse OBLIGATOIRE (JSON strict) :
{"reformulated": "le texte reformulé", "tone_applied": "le ton appliqué"}

USER:
<texte à reformuler>
```

---

## 11. Direction Artistique — Référence

### Palette de couleurs

| Rôle | Hex | Usage |
|------|-----|-------|
| Primaire | `#5B5FE6` | Boutons principaux, accents, icône |
| Secondaire | `#9B6FE8` | Dégradés, éléments secondaires |
| Succès | `#34C759` | Corrections appliquées, texte ajouté |
| Erreur | `#FF3B30` | Erreurs, texte supprimé |
| Warning | `#F5A623` | Limites, compteurs |
| Surface | Natif macOS | Utiliser `.background` material |
| Texte | Natif macOS | Utiliser `.primary` et `.secondary` |

### Typographie

- **UI** : SF Pro (système macOS)
- **Code/Diff** : SF Mono
- **Tailles** : respecter Dynamic Type

### Icône Menu Bar

- Template image (monochrome, s'adapte au thème)
- 16x16 pt (32x32 px @2x)
- Trait fin, style SF Symbols
- Lettre "P" avec curseur de texte intégré

### Icône App

- 1024x1024 px
- Fond : dégradé linéaire #5B5FE6 → #9B6FE8 (du coin inférieur gauche au coin supérieur droit)
- Symbole : "P" blanc, arrondi, avec effet de brillance subtil
- Coins arrondis macOS (superellipse)

---

## 12. Modèle Économique — Référence

### Plan Gratuit — "Poli Free"

| Feature | Limite |
|---------|--------|
| Corrections / jour | 10 |
| Traductions / jour | 10 |
| Historique | 7 jours |
| Langues | FR, EN, ES, DE |
| Raccourcis | Défaut uniquement (⌥⇧C / ⌥⇧T) |
| Auto-paste | ✓ |
| Reformulation | ✗ |
| Choix du ton | ✗ |
| Export historique | ✗ |

### Plan Pro — "Poli Pro"

| Feature | Inclus |
|---------|--------|
| Corrections / jour | Illimité |
| Traductions / jour | Illimité |
| Historique | Illimité |
| Langues | 20+ |
| Raccourcis | Personnalisables |
| Auto-paste | ✓ |
| Reformulation | ✓ |
| Choix du ton | ✓ (formel, informel, pro, académique) |
| Export historique | ✓ (CSV, JSON) |
| Modèle IA | Sonnet 4.5 (plus puissant) |

### Pricing

| Plan | Prix | Économie |
|------|------|----------|
| Mensuel | 4,99€/mois | — |
| Annuel | 29,99€/an | ~50% |

---

## 13. Contraintes App Store & Sandboxing

### Permissions sandbox requises

1. **`com.apple.security.network.client`** — Pour les appels à l'API Claude (OBLIGATOIRE)
2. **Accessibility API** — Pour l'auto-paste (CGEvent). L'utilisateur doit l'autoriser dans Préférences Système.

### Points de vigilance pour la review Apple

1. **L'app doit être utilisable sans payer** — Le plan gratuit (10 actions/jour) doit être pleinement fonctionnel
2. **Pas de paywall bloquant** — L'app ne doit jamais empêcher le lancement
3. **Raccourcis globaux** — Doivent être désactivables dans les réglages
4. **Auto-paste** — Si Apple refuse l'exception sandbox, prévoir un fallback (copie seule)
5. **Clé API** — La clé API ne doit JAMAIS être hardcodée dans le binaire. Utiliser un backend proxy ou demander à l'utilisateur de fournir sa propre clé. **Recommandation : créer un simple backend proxy** (API Gateway sur AWS, tu connais) qui authentifie les utilisateurs Poli et proxifie les appels vers l'API Claude. Ça permet de contrôler l'usage et de ne pas exposer la clé API.
6. **Privacy Nutrition Label** — Déclarer dans App Store Connect que l'app envoie du texte à un serveur tiers (Anthropic) pour traitement

### Architecture backend recommandée (pour la clé API)

```
Utilisateur Poli → HTTPS → AWS API Gateway → Lambda → API Claude (Anthropic)
                                    ↓
                           Vérification : subscription active ?
                           Rate limiting : free tier vs pro
                           Logging : usage analytics
```

Cela te permet de :
- Ne jamais exposer ta clé API Anthropic
- Contrôler le rate limiting côté serveur (en plus du côté client)
- Vérifier le statut d'abonnement côté serveur (via App Store Server API)
- Avoir des analytics d'usage réels

---

## 14. Checklist Finale

### Avant le développement

- [ ] Compte Apple Developer actif (99€/an)
- [ ] Bundle ID réservé dans App Store Connect
- [ ] Groupe d'abonnement créé dans App Store Connect
- [ ] Produits in-app créés (monthly + yearly)
- [ ] Backend proxy API configuré (optionnel mais recommandé)

### Avant la soumission

- [ ] Toutes les phases (1-6) complétées et testées
- [ ] Tests sur macOS 14 Sonoma et macOS 15 Sequoia
- [ ] Localisation FR + EN vérifiée
- [ ] Icône menu bar en template image (s'adapte dark/light)
- [ ] Icône App Store 1024x1024
- [ ] Screenshots (min 3)
- [ ] Privacy Policy hébergée et URL renseignée
- [ ] Terms of Service hébergés
- [ ] In-app purchases soumis pour review
- [ ] Notes pour le reviewer rédigées
- [ ] Archive signée avec le certificat de distribution
- [ ] Build uploadé via Xcode ou Transporter
- [ ] Toutes les métadonnées App Store remplies
- [ ] Privacy Nutrition Labels configurés
- [ ] Test de l'achat in-app en sandbox
- [ ] Test de la restauration d'achats
- [ ] Test des raccourcis globaux avec Accessibility
- [ ] Test du fallback si Accessibility est refusé
- [ ] Test sans connexion internet (message d'erreur approprié)
- [ ] Test de la limite quotidienne (free tier)
- [ ] Test du reset quotidien du compteur

---

## Notes d'implémentation importantes

### 1. Gestion de la clé API

**Option A (recommandée)** : Backend proxy sur AWS
- API Gateway + Lambda qui proxifie vers l'API Claude
- L'app s'authentifie avec un token lié au receipt Apple
- Avantages : sécurité, contrôle, analytics

**Option B** : L'utilisateur fournit sa propre clé API
- Champ dans les réglages pour entrer sa clé Anthropic
- Stockée dans le Keychain
- Avantages : pas de backend, pas de coûts serveur
- Inconvénients : friction pour l'utilisateur, cible limitée aux développeurs

**Option C** : Clé embarquée avec obfuscation
- ⚠️ NON RECOMMANDÉ — Apple peut refuser et c'est un risque de sécurité

**Décision à prendre** : Choisis A ou B. Si tu choisis A, le backend doit être implémenté avant la Phase 2.

### 2. Performances

- Utiliser `URLSession` avec `async/await` pour les appels API
- Le traitement doit être inférieur à 3 secondes pour la plupart des textes
- Afficher un spinner/état de chargement dans les notifications ou le popover
- Mettre un timeout de 15 secondes sur les appels API
- Considérer le streaming pour les textes longs (> 500 mots)

### 3. Accessibilité (a11y)

- Tous les éléments interactifs doivent avoir des labels VoiceOver
- Les raccourcis clavier doivent être annoncés par VoiceOver
- Le popover doit être navigable au clavier
- Respecter Dynamic Type pour les tailles de police

### 4. Gestion d'erreurs

| Erreur | Comportement |
|--------|-------------|
| Pas de connexion internet | Notification : "Pas de connexion internet" |
| Erreur API (500, timeout) | Notification : "Erreur de traitement. Réessayez." + retry automatique x1 |
| Presse-papier vide | Notification : "Rien dans le presse-papier" |
| Texte trop long (> 5000 caractères free, > 20000 pro) | Notification : "Texte trop long. Limite : X caractères" |
| Limite quotidienne atteinte | Notification avec CTA vers le paywall |
| Clé API invalide | Alerte dans les réglages |
| Accessibility non autorisé | Auto-paste désactivé silencieusement, copie seule |

---

*Ce document est la source de vérité pour l'implémentation de Poli. Chaque phase peut être exécutée de manière indépendante et vérifiée avec sa checklist dédiée.*
