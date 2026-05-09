import SwiftUI
import TransitMinuteCore

struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.countdown.menuBarTitle)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.22), value: model.countdown.menuBarTitle)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.22), value: subtitle)
                }
                Spacer()
                RouteBadgeView(plan: model.lastPlan)
            }

            if let plan = model.lastPlan {
                Divider()
                PlanSummaryView(plan: plan)
            }

            if model.alertActive {
                Button {
                    model.dismissAlert()
                } label: {
                    Label("Dismiss Alert", systemImage: "bell.slash")
                }
            }

            HStack {
                Button {
                    Task { await model.refreshPlan() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.isPlanning)

                Button {
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private var subtitle: String {
        switch model.countdown.mode {
        case .setupNeeded:
            "Finish setup to start planning"
        case .locating:
            model.locationStatus.message
        case .planning:
            "Finding the best transit route"
        case .ready:
            model.lastPlan.map { "Leave for \($0.destination.label.title)" } ?? "Ready"
        case .leaveNow:
            "Go to the stop now"
        case .missed:
            "Refreshing for the next route"
        case .error(let message):
            message
        }
    }
}

private struct PlanSummaryView: View {
    var plan: TransitPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PlanSummaryRow(
                systemImage: "arrow.triangle.turn.up.right.diamond",
                text: "\(plan.origin.label.title) to \(plan.destination.label.title)"
            )
            PlanSummaryRow(
                systemImage: "figure.walk",
                text: plan.departureStopName
            )
            PlanSummaryRow(
                systemImage: "clock",
                text: plan.arrivalAt.formatted(date: .omitted, time: .shortened)
            )
        }
        .font(.callout)
    }
}

private struct PlanSummaryRow: View {
    var systemImage: String
    var text: String

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 18, height: 18, alignment: .center)

            Text(text)
                .lineLimit(1)
        }
    }
}

private struct RouteBadgeView: View {
    var plan: TransitPlan?

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: RouteDisplay.systemImage(for: plan?.transitMode ?? .bus))
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.blue)

            if let plan {
                Text(RouteDisplay.badgeText(from: plan.routeSummary))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(.blue, in: Capsule())
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .frame(minWidth: 54)
        .animation(.easeInOut(duration: 0.2), value: plan?.routeSummary)
        .animation(.easeInOut(duration: 0.2), value: plan?.transitMode)
    }
}
