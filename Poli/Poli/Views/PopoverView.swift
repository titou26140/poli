import SwiftUI

/// The main popover view displayed when the user clicks the menu bar icon.
///
/// Contains four tabs: Correction, Translation, History, and Settings.
/// Pre-fills text from the clipboard on appearance.
struct PopoverView: View {

    var appState: AppState

    @ObservedObject private var authManager = AuthManager.shared
    @State private var selectedTab: Tab = .correct

    // MARK: - Tab Enum

    enum Tab: Hashable {
        case correct
        case translate
        case history
    }

    // MARK: - Colors

    private let primaryColor = Color(red: 0.357, green: 0.373, blue: 0.902) // #5B5FE6

    // MARK: - Body

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                VStack(spacing: 0) {
                    header
                    Divider()
                    tabContent
                }
            } else {
                AuthView()
            }
        }
        .frame(width: 360, height: 480)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            tabButton(tab: .correct, icon: "textformat.abc", label: "Corriger")
            tabButton(tab: .translate, icon: "globe", label: "Traduire")
            tabButton(tab: .history, icon: "clock", label: "Historique")

            Spacer()

            // Settings gear icon — opens a separate Settings window.
            Button {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Reglages")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Tab Button

    private func tabButton(tab: Tab, icon: String, label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selectedTab == tab ? primaryColor : .secondary)
            .frame(width: 72, height: 42)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == tab ? primaryColor.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .correct:
            CorrectionTabView(appState: appState)

        case .translate:
            TranslationTabView(appState: appState)

        case .history:
            HistoryView()
        }
    }
}

// MARK: - Preview

#Preview {
    PopoverView(appState: AppState())
        .frame(width: 360, height: 480)
}
