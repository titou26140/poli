# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Poli is a **macOS menu bar application** for AI-powered grammar correction and text translation. It runs as a status bar item with a floating popover UI (360x480) and global keyboard shortcuts. All AI processing happens server-side via a Laravel backend.

## Build & Run

- **Open in Xcode**: `open Poli.xcodeproj`
- **Build**: Cmd+B in Xcode, or `xcodebuild -project Poli.xcodeproj -scheme Poli-Local build`
- **Run**: Cmd+R in Xcode
- **Target**: macOS 13+ only
- **Dependencies**: SPM only — resolved automatically by Xcode (HotKey package for global shortcuts)
- **No tests exist** in the project currently

## Environments

3 Xcode schemes control the target environment via Swift compilation conditions (`#if DEBUG` / `#elseif STAGING`) in `Poli/Utils/Constants.swift`:

| Scheme | Build Config | Flag | API Base URL |
|---|---|---|---|
| **Poli-Local** | Debug | `DEBUG` | `https://poli.test` |
| **Poli-Staging** | Staging | `STAGING` | `https://staging.poli-app.com` |
| **Poli-Prod** | Release | *(none)* | `https://poli-app.com` |

## Architecture

**Service-Oriented Architecture** with SwiftUI views. Not strict MVVM — most state lives in singleton services.

### Key Layers

1. **App Layer** (`Poli/App/`): `PoliApp.swift` is the `@main` entry. `AppDelegate` orchestrates the menu bar, popover, hotkeys, and action flows (correction/translation). `AppState` is an `@Observable` class holding shared input text between tabs.

2. **Services** (`Poli/Services/`): All singletons via `static let shared`. This is where most business logic lives:
   - `AIService` — HTTP client for backend `/api/correct` and `/api/translate` endpoints. Bearer token auth from Keychain.
   - `AuthManager` — Login/register/logout, token persistence, user profile sync.
   - `GrammarService` / `TranslationService` — High-level wrappers that validate input (length, emptiness) before calling AIService.
   - `ClipboardService` — Reads/writes the system pasteboard.
   - `HotKeyService` — Global shortcuts via HotKey SPM package. Defaults: Option+Shift+C (correct), Option+Shift+T (translate).
   - `UsageTracker` — Caches `remaining_actions` from backend. Backend is source of truth; never incremented locally.
   - `HistoryManager` — CRUD operations on correction/translation history via backend API.

3. **Subscription** (`Poli/Subscription/`): StoreKit 2 integration. `StoreManager` handles purchases; `EntitlementManager` determines the active tier (free/starter/pro) by merging StoreKit and backend state. Unsynced transactions are persisted in UserDefaults and retried on launch.

4. **Views** (`Poli/Views/`): SwiftUI views. `PopoverView` is the main 4-tab interface (Correction, Translation, History, Settings). Components in `Views/Components/`.

5. **Models** (`Poli/Models/`): Codable data structures — `SupportedLanguage` (20 languages with flags), `SubscriptionTier`, `HistoryEntry`, `PoliError`.

### Important Patterns

- **`@Observable` macro** (not Combine's `@Published`) for reactive state — requires Swift 5.9+/macOS 14 observation.
- **Backend as source of truth** for usage limits and subscription tier. Local caches are only for instant UI display.
- **Keychain** for auth token storage (`com.poli` service name).
- **UserDefaults** for preferences, cached tier, hotkey bindings, onboarding state.
- **Localization**: `.xcstrings` format with English and French. Use `String(localized: "key")`.

### Action Flow (Correction/Translation via Hotkey)

`AppDelegate.handleCorrection()` → `ClipboardService.readIfAvailable()` → `EntitlementManager.canPerformAction()` → `GrammarService.correct()` → `AIService.correctGrammar()` → `ClipboardService.write()` → `ResultBanner.show()`

### Menu Bar Behavior

The app uses `.accessory` activation policy (no Dock icon) by default. It switches to `.regular` (shows in Dock) only when a settings or onboarding window is open, then back to `.accessory` when closed.

## Backend API Endpoints

All requests use Bearer token auth and JSON content type.

- `POST /api/auth/login`, `/register`, `/logout` — Auth
- `GET /api/auth/me` — Current user profile
- `POST /api/correct` — Grammar correction
- `POST /api/translate` — Translation
- `POST /api/subscription/verify` — StoreKit transaction verification
- `GET /api/history` — Fetch history
- `PATCH /api/history/{type}/{id}/favorite` — Toggle favorite
- `DELETE /api/history/{type}/{id}` — Delete entry

Every response may include `remaining_actions` which is always synced to `UsageTracker`.

## Entitlements

The app requires this entitlement (`Poli/Poli.entitlements`):
- `com.apple.security.network.client` — Network access

## StoreKit Products

Defined in `Poli.storekit`:
- `com.poli.starter.monthly` — Starter tier ($4.99/month)
- `com.poli.pro.monthly` — Pro tier ($19.99/month)
