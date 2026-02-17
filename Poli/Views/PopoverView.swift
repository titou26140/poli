import SwiftUI

/// The main popover view displayed when the user clicks the menu bar icon.
///
/// Contains four tabs: Correction, Translation, History, and Settings.
/// Pre-fills text from the clipboard on appearance.
struct PopoverView: View {

    var appState: AppState

    @ObservedObject private var authManager = AuthManager.shared
    @State private var selectedTab: Tab = .correct
    @State private var historyViewModel = HistoryViewModel()

    // MARK: - Tab Enum

    enum Tab: Hashable {
        case correct
        case translate
        case history
    }

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
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .padding(.trailing, 4)

            tabButton(tab: .correct, icon: "textformat.abc", label: String(localized: "tab.correct"))
            tabButton(tab: .translate, icon: "globe", label: String(localized: "tab.translate"))
            tabButton(tab: .history, icon: "clock", label: String(localized: "tab.history"))

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
            .focusable(false)
            .help(String(localized: "popover.settings_tooltip"))
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
            .foregroundStyle(selectedTab == tab ? Color.poliPrimary : Color.secondary)
            .frame(width: 72, height: 42)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == tab ? Color.poliPrimary.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
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
            HistoryView(viewModel: historyViewModel)
        }
    }
}

// MARK: - Preview

#Preview {
    PopoverView(appState: AppState())
        .frame(width: 360, height: 480)
}
