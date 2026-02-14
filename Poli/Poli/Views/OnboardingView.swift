import SwiftUI
import UserNotifications

/// First-launch onboarding flow that introduces the user to Poli.
///
/// The flow consists of five steps: Welcome, Shortcuts, Permissions,
/// Language selection, and a Ready screen. Completion is persisted
/// in UserDefaults so the onboarding is only shown once.
struct OnboardingView: View {

    // MARK: - Constants

    private let primaryColor = Color(red: 0x5B / 255.0, green: 0x5F / 255.0, blue: 0xE6 / 255.0)
    private let secondaryColor = Color(red: 0x9B / 255.0, green: 0x6F / 255.0, blue: 0xE8 / 255.0)
    private let totalSteps = 5

    // MARK: - State

    @State private var currentStep: Int = 0
    @State private var selectedLanguage: SupportedLanguage = Constants.defaultTargetLanguage
    @State private var automationGranted: Bool = false

    @AppStorage(Constants.UserDefaultsKey.targetLanguage)
    private var targetLanguageCode: String = Constants.defaultTargetLanguage.rawValue

    @AppStorage(Constants.UserDefaultsKey.hasCompletedOnboarding)
    private var hasCompletedOnboarding: Bool = false

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Content
            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                shortcutsStep.tag(1)
                permissionsStep.tag(2)
                languageStep.tag(3)
                readyStep.tag(4)
            }
            .tabViewStyle(.automatic)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Navigation
            navigationBar
        }
        .frame(width: 500, height: 480)
        .background(
            LinearGradient(
                colors: [
                    primaryColor.opacity(0.04),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: primaryColor.opacity(0.3), radius: 12, y: 6)

                Text("P")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("Bienvenue sur Poli")
                    .font(.system(size: 26, weight: .bold))

                Text("Polissez votre texte instantanement")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            Text("Corrigez votre grammaire et traduisez\nen un raccourci clavier.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(32)
    }

    // MARK: - Step 2: Shortcuts

    private var shortcutsStep: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("Raccourcis clavier")
                .font(.system(size: 22, weight: .bold))

            Text("Deux raccourcis pour tout faire")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            VStack(spacing: 20) {
                shortcutDemo(
                    keys: ["\u{2325} Option", "\u{21E7} Shift", "C"],
                    label: "Corriger le texte",
                    description: "Corrige la grammaire et l'orthographe du texte copie",
                    icon: "checkmark.circle",
                    color: .green
                )

                shortcutDemo(
                    keys: ["\u{2325} Option", "\u{21E7} Shift", "T"],
                    label: "Traduire le texte",
                    description: "Traduit le texte copie dans la langue de votre choix",
                    icon: "globe",
                    color: .blue
                )
            }

            Spacer()
        }
        .padding(32)
    }

    private func shortcutDemo(
        keys: [String],
        label: String,
        description: String,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 16) {
            // Keys visualization
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 5))

                    if key != keys.last {
                        Text("+")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(minWidth: 200, alignment: .center)

            // Label
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(color)
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                }

                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Step 3: Permissions

    private var permissionsStep: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "shield.checkered")
                .font(.system(size: 44))
                .foregroundStyle(primaryColor)

            VStack(spacing: 8) {
                Text("Autorisations")
                    .font(.system(size: 22, weight: .bold))

                Text("Poli a besoin de quelques permissions pour fonctionner")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                permissionRow(
                    icon: "gearshape.2",
                    title: "Automation",
                    description: "Permet de copier le texte selectionne et coller le resultat",
                    isGranted: automationGranted,
                    action: {
                        let script = NSAppleScript(source: """
                            tell application "System Events" to return ""
                        """)
                        var error: NSDictionary?
                        script?.executeAndReturnError(&error)
                        automationGranted = (error == nil)
                    }
                )

                permissionRow(
                    icon: "bell",
                    title: "Notifications",
                    description: "Recevez des confirmations apres chaque action",
                    isGranted: nil,
                    action: {
                        requestNotificationPermission()
                    }
                )
            }

            Text("Ces permissions peuvent etre modifiees\ndans les Preferences Systeme.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(32)
    }

    private func permissionRow(
        icon: String,
        title: String,
        description: String,
        isGranted: Bool?,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(primaryColor)
                .frame(width: 36, height: 36)
                .background(primaryColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let granted = isGranted, granted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.green)
            } else {
                Button("Autoriser") {
                    action()
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .tint(primaryColor)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Step 4: Language

    private var languageStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "globe")
                .font(.system(size: 44))
                .foregroundStyle(primaryColor)

            VStack(spacing: 8) {
                Text("Langue de traduction")
                    .font(.system(size: 22, weight: .bold))

                Text("Choisissez votre langue cible par defaut")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            // Language grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(SupportedLanguage.allCases) { language in
                    languageButton(language)
                }
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .padding(32)
    }

    private func languageButton(_ language: SupportedLanguage) -> some View {
        let isSelected = selectedLanguage == language
        let isFree = SupportedLanguage.freeTierLanguages.contains(language)

        return Button {
            selectedLanguage = language
        } label: {
            VStack(spacing: 4) {
                Text(language.flag)
                    .font(.system(size: 20))
                Text(language.displayName)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? primaryColor.opacity(0.15) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? primaryColor : Color.clear, lineWidth: 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if !isFree {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 5: Ready

    private var readyStep: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 8) {
                Text("Vous etes pret !")
                    .font(.system(size: 26, weight: .bold))

                Text("Poli est maintenant configure et pret a l'emploi.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                instructionRow(
                    step: "1",
                    text: "Copiez du texte dans n'importe quelle application"
                )
                instructionRow(
                    step: "2",
                    text: "Appuyez sur \u{2325}\u{21E7}C pour corriger ou \u{2325}\u{21E7}T pour traduire"
                )
                instructionRow(
                    step: "3",
                    text: "Le resultat est automatiquement copie dans le presse-papier"
                )
            }
            .padding(16)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
        .padding(32)
    }

    private func instructionRow(step: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(step)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(primaryColor)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            // Back / Skip
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    Label("Precedent", systemImage: "chevron.left")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if currentStep == 0 {
                Button {
                    completeOnboarding()
                } label: {
                    Text("Passer")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Page indicator
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? primaryColor : Color.primary.opacity(0.15))
                        .frame(width: 7, height: 7)
                }
            }

            Spacer()

            // Next / Done
            if currentStep < totalSteps - 1 {
                Button {
                    withAnimation { currentStep += 1 }
                } label: {
                    Text("Suivant")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 7)
                        .background(primaryColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    completeOnboarding()
                } label: {
                    Text("Commencer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(
                                colors: [primaryColor, secondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - Actions

    private func completeOnboarding() {
        targetLanguageCode = selectedLanguage.rawValue
        hasCompletedOnboarding = true
        dismiss()
    }

    private func requestNotificationPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                print("[Onboarding] Notification permission error: \(error)")
            }
        }
    }
}

#Preview {
    OnboardingView()
}
