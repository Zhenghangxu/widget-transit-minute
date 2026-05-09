import SwiftUI
import TransitMinuteCore

struct AddressPicker: View {
    @EnvironmentObject private var model: AppModel
    let label: PlaceLabel

    @State private var query = ""
    @State private var suggestions: [PlaceSuggestion] = []
    @State private var isLoading = false
    @State private var showingSuggestions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsRow(title: label.title) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let place = savedPlace {
                            Text(place.formattedAddress)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Not set")
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    Button {
                        model.useCurrentLocation(as: label)
                    } label: {
                        Label("Use current location", systemImage: "location")
                    }
                    .settingsButtonStyle(.secondary)
                }
            }

            SettingsRow(title: "\(label.title) address") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("\(label.title) address", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            Task { await loadSuggestions() }
                        }
                        .onChange(of: query) {
                            Task { await loadSuggestions() }
                        }
                        .popover(isPresented: $showingSuggestions, arrowEdge: .bottom) {
                            SuggestionsPopover(
                                suggestions: suggestions,
                                selectSuggestion: selectSuggestion
                            )
                            .frame(width: 420)
                            .settingsSuggestionsSurface()
                        }

                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    private var savedPlace: SavedPlace? {
        switch label {
        case .home:
            model.settings.home
        case .work:
            model.settings.work
        }
    }

    private func loadSuggestions() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            suggestions = []
            showingSuggestions = false
            return
        }

        isLoading = true
        suggestions = await model.suggestions(for: trimmed)
        isLoading = false
        showingSuggestions = !suggestions.isEmpty
    }

    private func selectSuggestion(_ suggestion: PlaceSuggestion) {
        Task {
            await model.saveSuggestion(suggestion, as: label)
            query = ""
            suggestions = []
            showingSuggestions = false
        }
    }
}

private struct SuggestionsPopover: View {
    var suggestions: [PlaceSuggestion]
    var selectSuggestion: (PlaceSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions.prefix(5)) { suggestion in
                Button {
                    selectSuggestion(suggestion)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(suggestion.primaryText)
                            .font(.callout.weight(.medium))
                        if !suggestion.secondaryText.isEmpty {
                            Text(suggestion.secondaryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)

                if suggestion.id != suggestions.prefix(5).last?.id {
                    Divider()
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private extension View {
    @ViewBuilder
    func settingsSuggestionsSurface() -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        if #available(macOS 26.0, *) {
            self
                .padding(4)
                .background(.regularMaterial, in: shape)
        } else {
            self
                .background(.regularMaterial, in: shape)
        }
    }
}
