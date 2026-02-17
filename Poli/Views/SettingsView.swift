import HotKey
import ServiceManagement
import SwiftUI

/// Application settings / preferences view.
///
/// Organized into sections for account status, translation defaults,
/// keyboard shortcuts, accessibility, and about information.
struct SettingsView: View {

    // MARK: - State

    @AppStorage(Constants.UserDefaultsKey.targetLanguage)
    private var targetLanguageCode: String = Constants.defaultTargetLanguage.rawValue

    @AppStorage(Constants.UserDefaultsKey.userLanguage)
    private var userLanguageCode: String = "fr"

    @AppStorage("autoPasteEnabled")
    private var autoPasteEnabled: Bool = true

    @AppStorage(Constants.UserDefaultsKey.appLanguage)
    private var appLanguageCode: String = AppLanguage.detected.rawValue

    @ObservedObject private var entitlementManager = EntitlementManager.shared
    @ObservedObject private var authManager = AuthManager.shared

    @State private var showPaywall: Bool = false
    @State private var automationGranted: Bool = false
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var showRestartAlert: Bool = false

    // MARK: - Computed

    private var selectedLanguage: Binding<SupportedLanguage> {
        Binding<SupportedLanguage>(
            get: {
                SupportedLanguage(rawValue: targetLanguageCode) ?? Constants.defaultTargetLanguage
            },
            set: { newValue in
                targetLanguageCode = newValue.rawValue
            }
        )
    }

    // MARK: - Body

    var body: some View {
        Form {
            // Account section
            accountSection

            // Translation section
            translationSection

            // Shortcuts section
            shortcutsSection

            // Auto-paste section
            autoPasteSection

            // About section
            aboutSection
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 500)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert(String(localized: "settings.languages.app_language"), isPresented: $showRestartAlert) {
            Button("OK") {}
        } message: {
            Text("settings.languages.restart_message")
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            // User info
            if let user = authManager.currentUser {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0x5B / 255.0, green: 0x5F / 255.0, blue: 0xE6 / 255.0).opacity(0.15))
                            .frame(width: 36, height: 36)
                        Text(String(user.name.prefix(1)).uppercased())
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(red: 0x5B / 255.0, green: 0x5F / 255.0, blue: 0xE6 / 255.0))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name)
                            .font(.system(size: 13, weight: .medium))
                        Text(user.email)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Plan
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("settings.account.current_plan")
                        .font(.system(size: 13, weight: .medium))

                    Text(entitlementManager.currentTier.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(entitlementManager.isPaid ? .green : .secondary)
                }

                Spacer()

                if entitlementManager.isPaid {
                    subscriptionStatusBadge
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        Text("settings.account.subscribe")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0x5B / 255.0, green: 0x5F / 255.0, blue: 0xE6 / 255.0),
                                        Color(red: 0x9B / 255.0, green: 0x6F / 255.0, blue: 0xE8 / 255.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }

            // Contextual message for grace period or cancelled status
            if entitlementManager.isInGracePeriod {
                Text("settings.account.grace_period_message")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            } else if entitlementManager.isCancelledButActive {
                Text(String(format: String(localized: "settings.account.cancelled_message"), entitlementManager.expiresAtFormatted ?? ""))
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow)
            }

            HStack {
                Text(entitlementManager.currentTier.isLifetimeLimit
                     ? String(localized: "settings.account.usage")
                     : String(localized: "settings.account.usage_today"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Spacer()

                let tracker = UsageTracker.shared
                Text("\(tracker.usedCount) / \(tracker.limit)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // Logout button
            Button(role: .destructive) {
                Task { await authManager.logout() }
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 12))
                    Text("settings.account.logout")
                        .font(.system(size: 13))
                }
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .focusable(false)
        } header: {
            Text("settings.account.header")
        }
    }

    // MARK: - Translation Section

    private var selectedUserLanguage: Binding<SupportedLanguage> {
        Binding<SupportedLanguage>(
            get: {
                SupportedLanguage(rawValue: userLanguageCode) ?? .french
            },
            set: { newValue in
                userLanguageCode = newValue.rawValue
            }
        )
    }

    private var selectedAppLanguage: Binding<AppLanguage> {
        Binding<AppLanguage>(
            get: {
                AppLanguage(rawValue: appLanguageCode) ?? .detected
            },
            set: { newValue in
                appLanguageCode = newValue.rawValue
                UserDefaults.standard.set([newValue.rawValue], forKey: "AppleLanguages")
                UserDefaults.standard.synchronize()
                showRestartAlert = true
            }
        )
    }

    private var translationSection: some View {
        Section {
            Picker(String(localized: "settings.languages.app_language"), selection: selectedAppLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    HStack(spacing: 6) {
                        Text(language.flag)
                        Text(language.displayName)
                    }
                    .tag(language)
                }
            }
            .font(.system(size: 13))
            .focusable(false)

            Picker(String(localized: "settings.languages.spoken"), selection: selectedUserLanguage) {
                ForEach(SupportedLanguage.allCases) { language in
                    HStack(spacing: 6) {
                        Text(language.flag)
                        Text(language.displayName)
                    }
                    .tag(language)
                }
            }
            .font(.system(size: 13))
            .focusable(false)

            Picker(String(localized: "settings.languages.target"), selection: selectedLanguage) {
                ForEach(SupportedLanguage.allCases) { language in
                    HStack(spacing: 6) {
                        Text(language.flag)
                        Text(language.displayName)
                    }
                    .tag(language)
                }
            }
            .font(.system(size: 13))
            .focusable(false)
        } header: {
            Text("settings.languages.header")
        } footer: {
            Text("settings.languages.footer")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Shortcuts Section

    @State private var correctionKeyCode: UInt32 = HotKeyService.shared.correctionCombo.carbonKeyCode
    @State private var correctionModifiers: UInt32 = HotKeyService.shared.correctionCombo.carbonModifiers
    @State private var translationKeyCode: UInt32 = HotKeyService.shared.translationCombo.carbonKeyCode
    @State private var translationModifiers: UInt32 = HotKeyService.shared.translationCombo.carbonModifiers

    private var shortcutsSection: some View {
        Section {
            if entitlementManager.isPaid {
                // Editable shortcuts for paid users
                HStack {
                    Text("settings.shortcuts.correct")
                        .font(.system(size: 13))
                    Spacer()
                    ShortcutRecorderView(
                        keyCode: correctionKeyCode,
                        modifiers: correctionModifiers
                    ) { newKeyCode, newModifiers in
                        correctionKeyCode = newKeyCode
                        correctionModifiers = newModifiers
                        HotKeyService.shared.register(
                            correctionKeyCode: newKeyCode,
                            correctionModifiers: newModifiers,
                            translationKeyCode: translationKeyCode,
                            translationModifiers: translationModifiers
                        )
                    }
                }

                HStack {
                    Text("settings.shortcuts.translate")
                        .font(.system(size: 13))
                    Spacer()
                    ShortcutRecorderView(
                        keyCode: translationKeyCode,
                        modifiers: translationModifiers
                    ) { newKeyCode, newModifiers in
                        translationKeyCode = newKeyCode
                        translationModifiers = newModifiers
                        HotKeyService.shared.register(
                            correctionKeyCode: correctionKeyCode,
                            correctionModifiers: correctionModifiers,
                            translationKeyCode: newKeyCode,
                            translationModifiers: newModifiers
                        )
                    }
                }

                // Reset button
                Button {
                    HotKeyService.shared.resetToDefaults()
                    correctionKeyCode = HotKeyService.defaultCorrectionCombo.carbonKeyCode
                    correctionModifiers = HotKeyService.defaultCorrectionCombo.carbonModifiers
                    translationKeyCode = HotKeyService.defaultTranslationCombo.carbonKeyCode
                    translationModifiers = HotKeyService.defaultTranslationCombo.carbonModifiers
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11))
                        Text("settings.shortcuts.reset")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .focusable(false)
            } else {
                // Read-only shortcuts for free users
                shortcutRow(
                    label: String(localized: "settings.shortcuts.correct"),
                    shortcut: KeyCombo(
                        carbonKeyCode: correctionKeyCode,
                        carbonModifiers: correctionModifiers
                    ).description
                )
                shortcutRow(
                    label: String(localized: "settings.shortcuts.translate"),
                    shortcut: KeyCombo(
                        carbonKeyCode: translationKeyCode,
                        carbonModifiers: translationModifiers
                    ).description
                )

                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("settings.shortcuts.locked")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("settings.shortcuts.header")
        }
    }

    private func shortcutRow(label: String, shortcut: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))

            Spacer()

            Text(shortcut)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    // MARK: - General Section

    private var autoPasteSection: some View {
        Section {
            Toggle(isOn: $launchAtLogin) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.general.launch_title")
                        .font(.system(size: 13))
                    Text("settings.general.launch_description")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .focusable(false)
            .onChange(of: launchAtLogin) {
                toggleLaunchAtLogin(launchAtLogin)
            }

            Toggle(isOn: $autoPasteEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.general.auto_paste_title")
                        .font(.system(size: 13))
                    Text("settings.general.auto_paste_description")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .focusable(false)
        } header: {
            Text("settings.general.header")
        }
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            #if DEBUG
            print("[Settings] Launch at login error: \(error)")
            #endif
            // Revert le toggle si l'operation a echoue.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack(spacing: 12) {
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Poli")
                        .font(.system(size: 15, weight: .bold))
                    Text(String(format: String(localized: "settings.about.version"), appVersion))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)

            Link(destination: URL(string: "https://poli-app.com/en/privacy")!) {
                HStack {
                    Text("settings.about.privacy")
                        .font(.system(size: 13))
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .focusable(false)

            Link(destination: URL(string: "https://poli-app.com/en/terms")!) {
                HStack {
                    Text("settings.about.terms")
                        .font(.system(size: 13))
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .focusable(false)

            Link(destination: URL(string: "mailto:contact@poli-app.com")!) {
                HStack {
                    Text("settings.about.contact")
                        .font(.system(size: 13))
                    Spacer()
                    Image(systemName: "envelope")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .focusable(false)

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                    Text("settings.about.quit")
                        .font(.system(size: 13))
                }
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .focusable(false)
        } header: {
            Text("settings.about.header")
        }
    }

    // MARK: - Subscription Status Badge

    @ViewBuilder
    private var subscriptionStatusBadge: some View {
        switch entitlementManager.subscriptionStatus {
        case .gracePeriod:
            Label("settings.account.payment_issue", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
        case .cancelled:
            Label("settings.account.cancelled", systemImage: "xmark.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.12))
                .clipShape(Capsule())
        default:
            Label("settings.account.active", systemImage: "checkmark.seal.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
}
