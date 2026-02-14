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

    @ObservedObject private var entitlementManager = EntitlementManager.shared
    @ObservedObject private var authManager = AuthManager.shared

    @State private var showPaywall: Bool = false
    @State private var automationGranted: Bool = false

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
                    Text("Plan actuel")
                        .font(.system(size: 13, weight: .medium))

                    Text(entitlementManager.currentTier.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(entitlementManager.isPaid ? .green : .secondary)
                }

                Spacer()

                if entitlementManager.isPaid {
                    Label("Actif", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        Text("S'abonner")
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
                }
            }

            HStack {
                Text("Utilisation aujourd'hui")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Spacer()

                let tracker = UsageTracker.shared
                Text("\(tracker.todayCount) / \(tracker.dailyLimit)")
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
                    Text("Se deconnecter")
                        .font(.system(size: 13))
                }
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        } header: {
            Text("Compte")
        }
    }

    // MARK: - Translation Section

    private var translationSection: some View {
        Section {
            Picker("Ma langue", selection: $userLanguageCode) {
                HStack(spacing: 6) {
                    Text("🇫🇷")
                    Text("Francais")
                }.tag("fr")
                HStack(spacing: 6) {
                    Text("🇬🇧")
                    Text("English")
                }.tag("en")
            }
            .font(.system(size: 13))

            Picker("Langue cible par defaut", selection: selectedLanguage) {
                ForEach(SupportedLanguage.allCases) { language in
                    HStack(spacing: 6) {
                        Text(language.flag)
                        Text(language.displayName)
                    }
                    .tag(language)
                }
            }
            .font(.system(size: 13))
        } header: {
            Text("Langues")
        }
    }

    // MARK: - Shortcuts Section

    private var shortcutsSection: some View {
        Section {
            shortcutRow(
                label: "Corriger le texte",
                shortcut: "\u{2325}\u{21E7}C",
                description: "Option + Shift + C"
            )
            shortcutRow(
                label: "Traduire le texte",
                shortcut: "\u{2325}\u{21E7}T",
                description: "Option + Shift + T"
            )

            if !entitlementManager.isPaid {
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("Personnalisation disponible avec un abonnement")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Raccourcis clavier")
        }
    }

    private func shortcutRow(label: String, shortcut: String, description: String) -> some View {
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

            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Auto-Paste Section

    private var autoPasteSection: some View {
        Section {
            Toggle(isOn: $autoPasteEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Collage automatique")
                        .font(.system(size: 13))
                    Text("Coller automatiquement le resultat apres correction/traduction")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Collage automatique")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                    .font(.system(size: 13))
                Spacer()
                Text(appVersion)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://poli.app/privacy")!) {
                HStack {
                    Text("Politique de confidentialite")
                        .font(.system(size: 13))
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Link(destination: URL(string: "https://poli.app/terms")!) {
                HStack {
                    Text("Conditions d'utilisation")
                        .font(.system(size: 13))
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("A propos")
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
