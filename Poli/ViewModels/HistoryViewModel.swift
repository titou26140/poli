import Foundation

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all
    case corrections
    case translations

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:          return String(localized: "history.filter.all")
        case .corrections:  return String(localized: "history.filter.corrections")
        case .translations: return String(localized: "history.filter.translations")
        }
    }

    var apiType: String? {
        switch self {
        case .all: return nil
        case .corrections: return "corrections"
        case .translations: return "translations"
        }
    }
}

@Observable
@MainActor
final class HistoryViewModel {

    var searchText: String = ""
    var filter: HistoryFilter = .all
    var selectedEntry: HistoryEntry?
    var items: [HistoryEntry] = []
    var isLoading: Bool = false
    var errorMessage: String?

    private var reloadTask: Task<Void, Never>?

    // MARK: - Load

    func loadHistory() async {
        isLoading = true
        errorMessage = nil

        do {
            items = try await HistoryManager.shared.fetchHistory(
                type: filter.apiType,
                search: searchText.isEmpty ? nil : searchText
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await loadHistory()
        }
    }

    // MARK: - Toggle Favorite

    func toggleFavorite(for entry: HistoryEntry) {
        guard let index = items.firstIndex(where: { $0.id == entry.id }) else { return }

        // Optimistic update
        items[index].isFavorite.toggle()
        let type = entry.type
        let serverId = entry.serverId

        Task {
            do {
                let serverValue = try await HistoryManager.shared.toggleFavorite(type: type, id: serverId)
                if let idx = items.firstIndex(where: { $0.id == entry.id }) {
                    items[idx].isFavorite = serverValue
                }
            } catch {
                // Rollback
                if let idx = items.firstIndex(where: { $0.id == entry.id }) {
                    items[idx].isFavorite.toggle()
                }
            }
        }
    }

    // MARK: - Delete

    func deleteEntry(_ entry: HistoryEntry) {
        // Optimistic removal
        let snapshot = items
        items.removeAll { $0.id == entry.id }

        Task {
            do {
                try await HistoryManager.shared.deleteEntry(type: entry.type, id: entry.serverId)
            } catch {
                // Rollback
                items = snapshot
            }
        }
    }
}
