import SwiftUI

struct HistoryView: View {

    @State private var viewModel = HistoryViewModel()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterPicker
            Divider()

            if viewModel.isLoading && viewModel.items.isEmpty {
                loadingState
            } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
                errorState(error)
            } else if viewModel.items.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .frame(minWidth: 360, minHeight: 400)
        .task {
            await viewModel.loadHistory()
        }
        .onChange(of: viewModel.filter) {
            viewModel.scheduleReload()
        }
        .onChange(of: viewModel.searchText) {
            viewModel.scheduleReload()
        }
        .sheet(item: $viewModel.selectedEntry) { entry in
            HistoryDetailView(
                entry: entry,
                onFavoriteToggle: {
                    viewModel.toggleFavorite(for: entry)
                },
                onDelete: {
                    viewModel.deleteEntry(entry)
                    viewModel.selectedEntry = nil
                }
            )
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))

            TextField("Rechercher dans l'historique\u{2026}", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        Picker("Filtre", selection: $viewModel.filter) {
            ForEach(HistoryFilter.allCases) { filterOption in
                Text(filterOption.rawValue).tag(filterOption)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - History List

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(viewModel.items) { entry in
                    historyRow(entry: entry)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func historyRow(entry: HistoryEntry) -> some View {
        Button {
            viewModel.selectedEntry = entry
        } label: {
            HStack(spacing: 10) {
                Image(systemName: entry.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(entry.isTranslation ? Color.blue : Color.green)
                    .frame(width: 28, height: 28)
                    .background(
                        (entry.isTranslation ? Color.blue : Color.green)
                            .opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.originalText.truncated(to: 60))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(entry.createdAt.relativeFormatted)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Text("\u{00B7}")
                            .foregroundStyle(.quaternary)

                        Text(entry.languageInfo)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if entry.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                viewModel.toggleFavorite(for: entry)
            } label: {
                Label(
                    entry.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                    systemImage: entry.isFavorite ? "star.slash" : "star"
                )
            }

            Button {
                ClipboardService.shared.write(entry.originalText)
            } label: {
                Label("Copier le texte original", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                viewModel.deleteEntry(entry)
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text("Chargement...")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.secondary.opacity(0.5))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Reessayer") {
                Task { await viewModel.loadHistory() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("Aucun historique")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Vos corrections et traductions\napparaitront ici.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    HistoryView()
}
