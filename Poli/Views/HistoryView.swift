import SwiftUI

struct HistoryView: View {

    @State private var viewModel = HistoryViewModel()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterPicker
            Divider()

            if viewModel.isLoading {
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
        .onReceive(NotificationCenter.default.publisher(for: .popoverDidOpen)) { _ in
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

            TextField(String(localized: "history.search_placeholder"), text: $viewModel.searchText)
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
                .focusable(false)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        Picker(String(localized: "filter.label"), selection: $viewModel.filter) {
            ForEach(HistoryFilter.allCases) { filterOption in
                Text(filterOption.displayName).tag(filterOption)
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
        .focusable(false)
        .contextMenu {
            Button {
                viewModel.toggleFavorite(for: entry)
            } label: {
                Label(
                    entry.isFavorite
                        ? String(localized: "history.context.remove_favorite")
                        : String(localized: "history.context.add_favorite"),
                    systemImage: entry.isFavorite ? "star.slash" : "star"
                )
            }

            Button {
                ClipboardService.shared.write(entry.originalText)
            } label: {
                Label(String(localized: "history.context.copy_original"), systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                viewModel.deleteEntry(entry)
            } label: {
                Label(String(localized: "history.context.delete"), systemImage: "trash")
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .opacity(0.5)
            ProgressView()
            Text("history.loading")
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
            Button(String(localized: "history.retry")) {
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

            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .opacity(0.4)

            Text("history.empty.title")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("history.empty.description")
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
