import AppKit
import SwiftUI
import TransitMinuteCore

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .setup
    @State private var showingHelp = false

    var body: some View {
        VStack(spacing: 0) {
            SettingsHeader(selection: $selectedTab)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .setup:
                        SetupSettingsContent(showingHelp: $showingHelp)
                    case .alerts:
                        AlertSettingsContent()
                    case .diagnostics:
                        DiagnosticsSettingsContent()
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 22)
                .padding(.bottom, 30)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .settingsWindowBackground()
        .sheet(isPresented: $showingHelp) {
            GoogleAPIHelpView()
                .frame(width: 620, height: 620)
        }
    }
}

private struct SettingsHeader: View {
    @Binding var selection: SettingsTab

    var body: some View {
        VStack(spacing: 0) {
            LiquidGlassTabPicker(selection: $selection)
                .frame(width: 330, height: 40)
                .padding(.top, 32)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity)
    }
}

private enum SettingsTab: CaseIterable, Hashable {
    case setup
    case alerts
    case diagnostics
}

private struct LiquidGlassTabPicker: View {
    @Binding var selection: SettingsTab
    @Namespace private var animation // Added for native sliding animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button {
                    // Added a native-feeling spring animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selection = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 13, weight: .medium)) // 13pt is standard for macOS controls
                        .foregroundStyle(selection == tab ? .primary : .secondary) // Adapts to light/dark mode
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .background {
                    if selection == tab {
                        Capsule()
                            // Uses the native window background color for the selection pill
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .padding(2)
                            // Connects the capsules for a smooth slide
                            .matchedGeometryEffect(id: "TabSelection", in: animation)
                    }
                }
            }
        }
        .padding(2)
        .frame(height: 28) // Keeps the control from stretching too tall

        // --- The Core Glass Effect ---
        // .regularMaterial or .thinMaterial pulls in the native macOS background blur
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                // A subtle, adaptive border typical of macOS UI
                .strokeBorder(.quaternary, lineWidth: 0.5)
        }
    }
}

private extension SettingsTab {
    init(segment: Int) {
        switch segment {
        case 1:
            self = .alerts
        case 2:
            self = .diagnostics
        default:
            self = .setup
        }
    }

    var segment: Int {
        switch self {
        case .setup:
            0
        case .alerts:
            1
        case .diagnostics:
            2
        }
    }

    var title: String {
        switch self {
        case .setup:
            "Setup"
        case .alerts:
            "Alerts"
        case .diagnostics:
            "Diagnostics"
        }
    }
}

private struct SetupSettingsContent: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showingHelp: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            SettingsSection(title: "Google API") {
                SettingsRow(title: "Google API key") {
                    SecureField("Google API key", text: $model.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            model.saveAPIKey()
                        }
                }

                SettingsDivider()

                SettingsRow(title: "") {
                    HStack(spacing: 10) {
                        Button {
                            model.saveAPIKey()
                        } label: {
                            Label("Save Key", systemImage: "key")
                        }
                        .settingsButtonStyle(.primary)

                        Button {
                            showingHelp = true
                        } label: {
                            Label("How to create a key", systemImage: "questionmark.circle")
                        }
                        .settingsButtonStyle(.secondary)
                    }
                }
            }

            if let error = model.setupError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 18)
            }

            SettingsSection(title: "Places") {
                LocationControlView()

                SettingsDivider()

                AddressPicker(label: .home)

                SettingsDivider()

                AddressPicker(label: .work)
            }
        }
    }
}

private struct AlertSettingsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PreferencesFormView()
        }
    }
}

private struct DiagnosticsSettingsContent: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSection(title: "Route Request") {
                SettingsRow(title: "Origin") {
                    DiagnosticsText(model.diagnostics.lastRequest?.origin.formattedAddress ?? "None")
                }

                SettingsDivider()

                SettingsRow(title: "Destination") {
                    DiagnosticsText(model.diagnostics.lastRequest?.destination.formattedAddress ?? "None")
                }

                SettingsDivider()

                SettingsRow(title: "Requested") {
                    DiagnosticsText(formatted(model.diagnostics.lastRequest?.requestedAt))
                }
            }

            SettingsSection(title: "Refresh") {
                SettingsRow(title: "Last completed") {
                    DiagnosticsText(formatted(model.diagnostics.lastRefreshCompletedAt))
                }

                SettingsDivider()

                SettingsRow(title: "Next refresh") {
                    DiagnosticsText(formatted(model.diagnostics.nextRefreshAt))
                }
            }

            SettingsSection(title: "Last Error") {
                SettingsRow(title: "Routes") {
                    if let error = model.diagnostics.lastRouteError {
                        DiagnosticsText(error, color: .red)
                    } else {
                        DiagnosticsText("None")
                    }
                }
            }
        }
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else {
            return "Never"
        }
        return date.formatted(date: .abbreviated, time: .standard)
    }
}

private struct DiagnosticsText: View {
    var value: String
    var color: Color

    init(_ value: String, color: Color = .secondary) {
        self.value = value
        self.color = color
    }

    var body: some View {
        Text(value)
            .font(.callout.monospacedDigit())
            .foregroundStyle(color)
            .lineLimit(2)
            .textSelection(.enabled)
    }
}

struct LocationControlView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            SettingsRow(title: "") {
                HStack(spacing: 12) {
                    Image(systemName: locationIcon)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Text(model.locationStatus.message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)

                    Spacer(minLength: 12)

                    Button {
                        model.requestCurrentLocation()
                    } label: {
                        Label("Request Location", systemImage: "location")
                    }
                    .settingsButtonStyle(.primary)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .settingsAlertSurface()
            }

            SettingsRow(title: "Manual origin") {
                Picker("Manual origin", selection: $model.manualOrigin) {
                    Text("At Home").tag(PlaceLabel.home)
                    Text("At Work").tag(PlaceLabel.work)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 220)
                .onChange(of: model.manualOrigin) {
                    Task { await model.refreshPlan() }
                }
            }
        }
    }

    private var locationIcon: String {
        switch model.locationStatus {
        case .denied, .failed, .unavailable:
            "location.slash"
        case .located:
            "location.fill"
        default:
            "location"
        }
    }
}

struct PreferencesFormView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSection(title: "Departure Alert") {
                SettingsRow(title: "Alert") {
                    Toggle("Notify and play a sound when it is time to leave", isOn: $model.settings.alertsEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: model.settings.alertsEnabled) {
                            model.saveSettings()
                        }
                }

                SettingsDivider()

                SettingsRow(title: "Buffer") {
                    Stepper(value: $model.settings.bufferMinutes, in: 0...15) {
                        Text("\(model.settings.bufferMinutes) min")
                            .monospacedDigit()
                    }
                    .onChange(of: model.settings.bufferMinutes) {
                        model.saveSettings()
                    }
                }
            }

            SettingsSection(title: "Refresh") {
                SettingsRow(title: "Route refresh") {
                    Picker("Route refresh", selection: refreshBinding) {
                        Text("Adaptive").tag(RefreshChoice.adaptive)
                        Text("Every 1 min").tag(RefreshChoice.oneMinute)
                        Text("Every 5 min").tag(RefreshChoice.fiveMinutes)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                }
            }
        }
    }

    private var refreshBinding: Binding<RefreshChoice> {
        Binding {
            RefreshChoice(policy: model.settings.refreshPolicy)
        } set: { choice in
            model.settings.refreshPolicy = choice.policy
            model.saveSettings()
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                content
            }
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            if !title.isEmpty {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 130, alignment: .leading)
            } else {
                Spacer()
                    .frame(width: 130)
            }

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
    }
}

struct SettingsDivider: View {
    var body: some View {
        SettingsHairline()
            .padding(.leading, 148)
    }
}

private struct SettingsHairline: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.09))
            .frame(height: 1)
    }
}

enum SettingsButtonProminence {
    case primary
    case secondary
}

extension View {
    @ViewBuilder
    func settingsWindowBackground() -> some View {
        self
            .background(
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea(.container, edges: .top)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
            }
    }

    @ViewBuilder
    func settingsAlertSurface() -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        self
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.58), in: shape)
            .overlay {
                shape
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }

    @ViewBuilder
    func settingsButtonStyle(_ prominence: SettingsButtonProminence) -> some View {
        if #available(macOS 26.0, *) {
            switch prominence {
            case .primary:
                self.buttonStyle(.glass)
            case .secondary:
                self.buttonStyle(.glass)
            }
        } else {
            switch prominence {
            case .primary:
                self.buttonStyle(.borderedProminent)
            case .secondary:
                self.buttonStyle(.bordered)
            }
        }
    }
}

private enum RefreshChoice: Hashable {
    case adaptive
    case oneMinute
    case fiveMinutes

    init(policy: RefreshPolicy) {
        switch policy {
        case .adaptive:
            self = .adaptive
        case .fixed(let interval) where interval <= 60:
            self = .oneMinute
        case .fixed:
            self = .fiveMinutes
        }
    }

    var policy: RefreshPolicy {
        switch self {
        case .adaptive:
            .adaptive
        case .oneMinute:
            .fixed(60)
        case .fiveMinutes:
            .fixed(300)
        }
    }
}
