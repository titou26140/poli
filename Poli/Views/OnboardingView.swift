import ApplicationServices
import SwiftUI
import UserNotifications

/// First-launch onboarding flow that introduces the user to Poli.
///
/// Friendly, casual tone inspired by Alan / Duolingo. Each permission
/// is explained with context ("permission priming") before the system
/// dialog appears.
struct OnboardingView: View {

    // MARK: - Configuration

    /// The step to start on (e.g. jump to permissions if re-showing).
    var initialStep: Int = 0

    // MARK: - Constants

    private let primaryColor = Color(red: 0x5B / 255.0, green: 0x5F / 255.0, blue: 0xE6 / 255.0)
    private let secondaryColor = Color(red: 0x9B / 255.0, green: 0x6F / 255.0, blue: 0xE8 / 255.0)
    private let successColor = Color(red: 0x34 / 255.0, green: 0xC7 / 255.0, blue: 0x59 / 255.0)
    private let warningColor = Color(red: 0xF5 / 255.0, green: 0xA6 / 255.0, blue: 0x23 / 255.0)
    private let totalSteps = 6

    // MARK: - State

    @State private var currentStep: Int = 0
    @State private var selectedUserLanguage: SupportedLanguage = .french
    @State private var selectedTargetLanguage: SupportedLanguage = .english
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()
    @State private var notificationsGranted: Bool = false

    @AppStorage(Constants.UserDefaultsKey.targetLanguage)
    private var targetLanguageCode: String = Constants.defaultTargetLanguage.rawValue

    @AppStorage(Constants.UserDefaultsKey.userLanguage)
    private var userLanguageCode: String = "fr"

    @AppStorage(Constants.UserDefaultsKey.hasCompletedOnboarding)
    private var hasCompletedOnboarding: Bool = false

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Content — scrollable so the nav bar is never pushed off-screen
            ScrollView {
                Group {
                    switch currentStep {
                    case 0: welcomeStep
                    case 1: howItWorksStep
                    case 2: accessibilityStep
                    case 3: notificationsStep
                    case 4: userLanguageStep
                    case 5: targetLanguageStep
                    default: welcomeStep
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            navigationBar
        }
        .frame(width: 520, height: 620)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        primaryColor.opacity(0.06),
                        secondaryColor.opacity(0.03),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Decorative blobs
                Circle()
                    .fill(primaryColor.opacity(0.05))
                    .frame(width: 300, height: 300)
                    .offset(x: -180, y: -150)
                    .blur(radius: 60)

                Circle()
                    .fill(secondaryColor.opacity(0.04))
                    .frame(width: 250, height: 250)
                    .offset(x: 200, y: 180)
                    .blur(radius: 50)
            }
        )
        .task {
            currentStep = initialStep
            // Restore saved preferences when re-showing onboarding.
            if let saved = SupportedLanguage(rawValue: userLanguageCode) {
                selectedUserLanguage = saved
            }
            if let saved = SupportedLanguage(rawValue: targetLanguageCode) {
                selectedTargetLanguage = saved
            }
            await checkNotificationStatus()
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 28) {
            Spacer()

            // Mascot
            ZStack {
                Circle()
                    .fill(primaryColor.opacity(0.08))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(primaryColor.opacity(0.04))
                    .frame(width: 190, height: 190)

                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
            }

            VStack(spacing: 10) {
                Text("onboarding.welcome.title")
                    .font(.system(size: 30, weight: .bold))

                HStack(spacing: 0) {
                    Text("onboarding.welcome.subtitle_prefix")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                    Text("Poli")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(primaryColor)
                }
            }

            Text("onboarding.welcome.description")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Step 2: How It Works

    private var howItWorksStep: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("onboarding.how.title")
                .font(.system(size: 24, weight: .bold))

            Text("onboarding.how.subtitle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                stepCard(
                    emoji: "\u{1F4CB}",
                    number: "1",
                    title: String(localized: "onboarding.how.step1.title"),
                    subtitle: String(localized: "onboarding.how.step1.subtitle"),
                    color: .blue
                )

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.quaternary)

                stepCard(
                    emoji: "\u{26A1}",
                    number: "2",
                    title: String(localized: "onboarding.how.step2.title"),
                    subtitle: String(localized: "onboarding.how.step2.subtitle"),
                    color: primaryColor
                )

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.quaternary)

                stepCard(
                    emoji: "\u{2705}",
                    number: "3",
                    title: String(localized: "onboarding.how.step3.title"),
                    subtitle: String(localized: "onboarding.how.step3.subtitle"),
                    color: successColor
                )
            }

            Spacer()
        }
        .padding(40)
    }

    private func stepCard(emoji: String, number: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 26))
                .frame(width: 50, height: 50)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.5))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Step 3: Accessibility Permission

    private var accessibilityStep: some View {
        VStack(spacing: 24) {
            Spacer()

            // Status badge
            permissionStatusBadge(
                granted: accessibilityGranted,
                emoji: "\u{1F50F}",
                grantedText: String(localized: "onboarding.accessibility.enabled"),
                missingText: String(localized: "onboarding.accessibility.required")
            )

            VStack(spacing: 10) {
                Text("onboarding.accessibility.needed")
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("onboarding.accessibility.explanation")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            // Explanation cards
            VStack(spacing: 10) {
                reasonCard(
                    emoji: "\u{1F4C4}",
                    text: String(localized: "onboarding.accessibility.read_text")
                )
                reasonCard(
                    emoji: "\u{1F4CB}",
                    text: String(localized: "onboarding.accessibility.auto_paste")
                )
                reasonCard(
                    emoji: "\u{1F512}",
                    text: String(localized: "onboarding.accessibility.no_data")
                )
            }

            if accessibilityGranted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(successColor)
                    Text("onboarding.accessibility.granted")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(successColor)
                }
                .padding(.top, 4)
            } else {
                Button {
                    requestAccessibility()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open")
                            .font(.system(size: 13, weight: .semibold))
                        Text("onboarding.accessibility.authorize")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: primaryColor.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }

            Text("onboarding.accessibility.changeable")
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Step 4: Notifications Permission

    private var notificationsStep: some View {
        VStack(spacing: 24) {
            Spacer()

            // Status badge
            permissionStatusBadge(
                granted: notificationsGranted,
                emoji: "\u{1F514}",
                grantedText: String(localized: "onboarding.notifications.granted"),
                missingText: String(localized: "onboarding.notifications.missing")
            )

            VStack(spacing: 10) {
                Text("onboarding.notifications.title")
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("onboarding.notifications.description")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            VStack(spacing: 10) {
                reasonCard(
                    emoji: "\u{2705}",
                    text: String(localized: "onboarding.notifications.confirmation")
                )
                reasonCard(
                    emoji: "\u{1F4A1}",
                    text: String(localized: "onboarding.notifications.tips")
                )
                reasonCard(
                    emoji: "\u{1F6AB}",
                    text: String(localized: "onboarding.notifications.no_spam")
                )
            }

            if notificationsGranted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(successColor)
                    Text("onboarding.notifications.enabled")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(successColor)
                }
                .padding(.top, 4)
            } else {
                Button {
                    requestNotifications()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 13, weight: .semibold))
                        Text("onboarding.notifications.activate")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: primaryColor.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .focusable(false)

                Button {
                    withAnimation { currentStep += 1 }
                } label: {
                    Text("onboarding.notifications.later")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Step 5: User Language (Langue parlee)

    private var userLanguageStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("\u{1F5E3}\u{FE0F}")
                .font(.system(size: 56))

            VStack(spacing: 10) {
                Text("onboarding.language.user.title")
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("onboarding.language.user.description")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            languageGrid(
                selection: $selectedUserLanguage,
                showLockIcons: false
            )

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Step 6: Target Language (Langue cible)

    private var targetLanguageStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("\u{1F30D}")
                .font(.system(size: 56))

            VStack(spacing: 10) {
                Text("onboarding.language.target.title")
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("onboarding.language.target.description")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            languageGrid(
                selection: $selectedTargetLanguage,
                showLockIcons: true
            )

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Language Grid

    private func languageGrid(selection: Binding<SupportedLanguage>, showLockIcons: Bool) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 10) {
            ForEach(SupportedLanguage.allCases) { language in
                languageButton(language, selection: selection, showLockIcons: showLockIcons)
            }
        }
        .padding(.horizontal, 8)
    }

    private func languageButton(_ language: SupportedLanguage, selection: Binding<SupportedLanguage>, showLockIcons: Bool) -> some View {
        let isSelected = selection.wrappedValue == language
        let isFree = SupportedLanguage.freeTierLanguages.contains(language)

        return Button {
            withAnimation(.spring(duration: 0.2)) {
                selection.wrappedValue = language
            }
        } label: {
            VStack(spacing: 6) {
                Text(language.flag)
                    .font(.system(size: 24))
                Text(language.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? primaryColor.opacity(0.12) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? primaryColor : Color.clear, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                if showLockIcons && !isFree {
                    Text("\u{1F512}")
                        .font(.system(size: 8))
                        .padding(4)
                }
            }
            .scaleEffect(isSelected ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    // MARK: - Shared Components

    private func permissionStatusBadge(granted: Bool, emoji: String, grantedText: String, missingText: String) -> some View {
        ZStack {
            Circle()
                .fill(granted ? successColor.opacity(0.1) : warningColor.opacity(0.1))
                .frame(width: 100, height: 100)

            VStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 36))

                HStack(spacing: 4) {
                    Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(granted ? grantedText : missingText)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(granted ? successColor : warningColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background((granted ? successColor : warningColor).opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }

    private func reasonCard(emoji: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 18))
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.8))

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.4))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            if currentStep > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { currentStep -= 1 }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("onboarding.nav.back")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .focusable(false)
            } else {
                Button {
                    completeOnboarding()
                } label: {
                    Text("onboarding.nav.skip")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }

            Spacer()

            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index == currentStep ? primaryColor : Color.primary.opacity(0.12))
                        .frame(width: index == currentStep ? 20 : 7, height: 7)
                        .animation(.spring(duration: 0.3), value: currentStep)
                }
            }

            Spacer()

            if currentStep < totalSteps - 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { currentStep += 1 }
                } label: {
                    HStack(spacing: 6) {
                        Text("onboarding.nav.next")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(primaryColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .focusable(false)
            } else {
                Button {
                    completeOnboarding()
                } label: {
                    HStack(spacing: 6) {
                        Text("onboarding.nav.start")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: primaryColor.opacity(0.3), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - Actions

    private func completeOnboarding() {
        userLanguageCode = selectedUserLanguage.rawValue
        targetLanguageCode = selectedTargetLanguage.rawValue
        hasCompletedOnboarding = true
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
        dismiss()
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        // Poll for the user granting permission in System Preferences.
        Task {
            for _ in 0..<30 {
                try? await Task.sleep(for: .seconds(1))
                if AXIsProcessTrusted() {
                    await MainActor.run {
                        withAnimation { accessibilityGranted = true }
                    }
                    return
                }
            }
        }
    }

    private func requestNotifications() {
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                await MainActor.run {
                    withAnimation { notificationsGranted = granted }
                    if granted {
                        // Auto-advance after a short delay.
                        Task {
                            try? await Task.sleep(for: .milliseconds(800))
                            await MainActor.run {
                                withAnimation(.easeInOut(duration: 0.25)) { currentStep += 1 }
                            }
                        }
                    }
                }
            } catch {
                print("[Onboarding] Notification permission error: \(error)")
            }
        }
    }

    private func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            notificationsGranted = settings.authorizationStatus == .authorized
        }
    }
}

#Preview {
    OnboardingView()
}
