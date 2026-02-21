# Poli — App Store Connect

## 1. Description (English)

### Subtitle (max 30 chars)

```
AI Grammar & Translation Tool
```

### Promotional Text (max 170 chars)

```
Correct your grammar and translate text in 20 languages — instantly, from any app. Just select text and press a shortcut.
```

### Description

```
Poli lives in your menu bar and helps you write better, in any language.

Select any text in any app, press a keyboard shortcut, and Poli instantly corrects your grammar or translates your text — then pastes the result right back. No copy-paste, no switching apps.

HOW IT WORKS
1. Select text in any application
2. Press Option+Shift+C to correct grammar, or Option+Shift+T to translate
3. Poli corrects or translates your text using AI and pastes the result automatically

GRAMMAR CORRECTION
- Fixes spelling, grammar, punctuation and style
- Provides clear explanations for each correction
- Detects your language automatically

TRANSLATION
- 20 languages supported: English, French, Spanish, German, Italian, Portuguese, Dutch, Russian, Chinese, Japanese, Korean, Arabic, Polish, Turkish, Swedish, Norwegian, Danish, Finnish, Czech and Romanian
- Pedagogical tips on false friends, idioms and grammar rules

DESIGNED FOR YOUR WORKFLOW
- Lives in the menu bar — no Dock icon, no clutter
- Global keyboard shortcuts work from any app
- Customizable shortcuts (Pro)
- Correction and translation history

PLANS
- Free: 10 corrections or translations to try Poli
- Starter ($4.99/month): 50 actions/day, all 20 languages, 30-day history
- Pro ($19.99/month): 500 actions/day, unlimited history, custom shortcuts

Poli requires the Accessibility permission to read selected text from other applications.
```

---

## 2. Description (French)

### Subtitle

```
Correction & Traduction par IA
```

### Promotional Text

```
Corrigez votre grammaire et traduisez vos textes dans 20 langues, instantanement, depuis n'importe quelle app.
```

### Description

```
Poli se loge dans votre barre de menus et vous aide a mieux ecrire, dans toutes les langues.

Selectionnez du texte dans n'importe quelle application, appuyez sur un raccourci clavier, et Poli corrige instantanement votre grammaire ou traduit votre texte, puis colle le resultat automatiquement. Pas de copier-coller, pas de changement d'app.

COMMENT CA MARCHE
1. Selectionnez du texte dans n'importe quelle application
2. Appuyez sur Option+Shift+C pour corriger, ou Option+Shift+T pour traduire
3. Poli corrige ou traduit votre texte grace a l'IA et colle le resultat automatiquement

CORRECTION GRAMMATICALE
- Corrige l'orthographe, la grammaire, la ponctuation et le style
- Fournit des explications claires pour chaque correction
- Detecte votre langue automatiquement

TRADUCTION
- 20 langues supportees : francais, anglais, espagnol, allemand, italien, portugais, neerlandais, russe, chinois, japonais, coreen, arabe, polonais, turc, suedois, norvegien, danois, finnois, tcheque et roumain
- Conseils pedagogiques sur les faux amis, expressions idiomatiques et regles de grammaire

CONCU POUR VOTRE WORKFLOW
- Se loge dans la barre de menus, pas d'icone dans le Dock
- Les raccourcis clavier globaux fonctionnent depuis n'importe quelle app
- Raccourcis personnalisables (Pro)
- Historique des corrections et traductions

ABONNEMENTS
- Gratuit : 10 corrections ou traductions pour decouvrir Poli
- Starter (4,99 $/mois) : 50 actions/jour, les 20 langues, historique 30 jours
- Pro (19,99 $/mois) : 500 actions/jour, historique illimite, raccourcis personnalises

Poli necessite la permission Accessibilite pour lire le texte selectionne dans les autres applications.
```

---

## 3. Keywords (max 100 chars each locale)

### English

```
grammar,correction,translation,spelling,writing,AI,menu bar,proofreading,language,productivity
```

### French

```
grammaire,correction,traduction,orthographe,ecriture,IA,barre de menus,relecture,langue,productivite
```

---

## 4. App Review Notes

```
WHAT POLI DOES

Poli is a macOS menu bar utility for AI-powered grammar correction and text translation. It reads selected text from the frontmost application using a global keyboard shortcut, sends it to our backend API for processing, and pastes the corrected or translated result back.

HOW POLI ACCESSES TEXT

Poli uses CGEvent with .cgAnnotatedSessionEventTap to simulate Cmd+C (copy selected text from the frontmost application) and Cmd+V (paste the corrected or translated result back). No AppleScript or Apple Events are used for text access.

Global keyboard shortcuts (Option+Shift+C for correction, Option+Shift+T for translation) are registered via the HotKey library (which uses the Carbon RegisterEventHotKey API internally).

The app is fully sandboxed.

PERMISSIONS REQUESTED

- Accessibility: Required so that CGEvent key simulation (Cmd+C / Cmd+V) can target the frontmost application, and to register global keyboard shortcuts. The user is prompted during onboarding with a clear explanation before being directed to System Settings > Privacy & Security > Accessibility.

TEST ACCOUNT

Email: review@poli-app.com
Password: fDCTgo59RAD6W5WH

TESTING STEPS

1. Launch Poli — the onboarding flow will guide you through granting Accessibility permission.
2. Open any text editor (e.g. TextEdit) and type a sentence with a grammar mistake.
3. Select the text, then press Option+Shift+C.
4. Poli will correct the text and paste the result automatically.
5. To test translation: select text and press Option+Shift+T.
6. The Poli popover (click the menu bar icon) shows correction details, translation tips, and history.

IN-APP PURCHASES

Two auto-renewable subscriptions in the "Poli" subscription group:
- com.poli.starter.monthly ($4.99/month): 50 actions per day, all 20 languages
- com.poli.pro.monthly ($19.99/month): 500 actions per day, unlimited history, custom shortcuts

The free tier allows 10 total actions (lifetime) with 4 languages (English, French, Spanish, German).
```

---

## 5. Checklist before submission

- [x] Create a test account `review@poli-app.com` on the backend and insert the password above
- [x] Verify https://poli-app.com/en/privacy is live and accessible
- [x] Verify https://poli-app.com/en/terms is live and accessible
- [x] Add the 1024x1024 App Store icon to `AppIcon.appiconset`
- [x] Set Developer Team ID in Xcode (Signing & Capabilities)
- [x] Set Developer Team ID in `Poli.storekit` (`_developerTeamID` field)
- [x] Prepare App Store screenshots (at least 1280x800 or 2560x1600) — 4 pages × 3 langues (EN, FR, ES)
- [x] Test in-app purchases in sandbox environment
- [ ] Submit a TestFlight build and verify the full flow
- [x] Create the app record in App Store Connect with all metadata above
