import AppKit
import SwiftUI
import TransitMinuteCore

@main
struct TransitMinuteApp: App {
    @StateObject private var model = AppModel()
    @State private var settingsWindowPresenter = SettingsWindowPresenter()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView {
                settingsWindowPresenter.open(model: model)
            }
                .environmentObject(model)
        } label: {
            MenuBarLabelView(
                title: model.countdown.menuBarTitle,
                transitMode: model.lastPlan?.transitMode ?? .bus,
                urgency: model.countdown.urgency
            )
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabelView: View {
    var title: String
    var transitMode: TransitMode
    var urgency: CountdownUrgency

    var body: some View {
        if urgency == .normal {
            standardLabel
        } else {
            Image(
                nsImage: MenuBarLabelRenderer.image(
                    title: title,
                    systemImageName: RouteDisplay.systemImage(for: transitMode),
                    urgency: urgency
                )
            )
            .renderingMode(.original)
        }
    }

    private var standardLabel: some View {
        HStack(alignment: .center, spacing: 5) {
            Image(systemName: RouteDisplay.systemImage(for: transitMode))
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 18, height: 18, alignment: .center)

            Text(title)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .animation(.easeInOut(duration: 0.2), value: title)
        .animation(.easeInOut(duration: 0.2), value: transitMode)
        .animation(.easeInOut(duration: 0.2), value: urgency)
    }
}

private enum MenuBarLabelRenderer {
    static func image(
        title: String,
        systemImageName: String,
        urgency: CountdownUrgency
    ) -> NSImage {
        let font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        let textSize = (title as NSString).size(withAttributes: [.font: font])
        let imageSize = NSSize(width: ceil(textSize.width) + 42, height: 22)
        let image = NSImage(size: imageSize)

        image.lockFocus()
        defer {
            image.unlockFocus()
            image.isTemplate = false
        }

        backgroundColor(for: urgency).setFill()
        NSBezierPath(
            roundedRect: NSRect(origin: .zero, size: imageSize),
            xRadius: imageSize.height / 2,
            yRadius: imageSize.height / 2
        ).fill()

        drawSymbol(named: systemImageName, in: NSRect(x: 8, y: 3, width: 16, height: 16))

        (title as NSString).draw(
            at: NSPoint(x: 28, y: (imageSize.height - textSize.height) / 2),
            withAttributes: [
                .font: font,
                .foregroundColor: NSColor.white
            ]
        )

        return image
    }

    private static func backgroundColor(for urgency: CountdownUrgency) -> NSColor {
        switch urgency {
        case .warning:
            return .systemOrange
        case .critical:
            return .systemRed
        case .normal:
            return .clear
        }
    }

    private static func drawSymbol(named systemImageName: String, in rect: NSRect) {
        let symbol = NSImage(
            systemSymbolName: systemImageName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(.init(pointSize: 16, weight: .semibold))

        guard let symbol else {
            return
        }

        symbol.withTintColor(.white).draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
    }
}

private extension NSImage {
    func withTintColor(_ color: NSColor) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer {
            image.unlockFocus()
            image.isTemplate = false
        }

        color.set()
        let rect = NSRect(origin: .zero, size: size)
        draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        rect.fill(using: .sourceAtop)
        return image
    }
}
