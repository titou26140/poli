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
    private var loadTask: Task<Void, Never>?
    private var pendingTasks: [Task<Void, Never>] = []

    func cancelAllTasks() {
        reloadTask?.cancel()
        reloadTask = nil
        loadTask?.cancel()
        loadTask = nil
        pendingTasks.forEach { $0.cancel() }
        pendingTasks.removeAll()
        isLoading = false
    }

    // MARK: - Load

    func loadHistory() async {
        loadTask?.cancel()
        isLoading = true
        errorMessage = nil

        do {
            let result = try await HistoryManager.shared.fetchHistory(
                type: filter.apiType,
                search: searchText.isEmpty ? nil : searchText
            )
            guard !Task.isCancelled else { return }
            items = result
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
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

        let task = Task {
            do {
                let serverValue = try await HistoryManager.shared.toggleFavorite(type: type, id: serverId)
                guard !Task.isCancelled else { return }
                if let idx = items.firstIndex(where: { $0.id == entry.id }) {
                    items[idx].isFavorite = serverValue
                }
            } catch {
                guard !Task.isCancelled else { return }
                // Rollback
                if let idx = items.firstIndex(where: { $0.id == entry.id }) {
                    items[idx].isFavorite.toggle()
                }
            }
        }
        pendingTasks.append(task)
    }

    // MARK: - Delete

    func deleteEntry(_ entry: HistoryEntry) {
        // Optimistic removal
        let snapshot = items
        items.removeAll { $0.id == entry.id }

        let task = Task {
            do {
                try await HistoryManager.shared.deleteEntry(type: entry.type, id: entry.serverId)
            } catch {
                guard !Task.isCancelled else { return }
                // Rollback
                items = snapshot
            }
        }
        pendingTasks.append(task)
    }
}
