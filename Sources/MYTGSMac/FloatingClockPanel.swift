import AppKit
import SwiftUI
import MYTGSCore

@MainActor
final class FloatingClockPanelController: ObservableObject {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<FloatingClockView>?

    func update(schedule: [TimetablePeriod], settings: ClockSettings) {
        guard settings.showFloatingClock else {
            panel?.orderOut(nil)
            return
        }

        let view = FloatingClockView(schedule: schedule)
        if let hostingController {
            hostingController.rootView = view
        } else {
            hostingController = NSHostingController(rootView: view)
        }

        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 260, height: 112),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.contentViewController = hostingController
            self.panel = panel
        }

        position(settings: settings)
        panel?.orderFrontRegardless()
    }

    private func position(settings: ClockSettings) {
        guard let panel, let screen = NSScreen.screens[safe: settings.screenPreference - 1] ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let margin: CGFloat = 18
        let origin: NSPoint
        switch settings.placementMode {
        case 1:
            origin = NSPoint(x: visible.minX + margin, y: visible.minY + margin)
        case 2:
            origin = NSPoint(x: visible.maxX - size.width - margin, y: visible.maxY - size.height - margin)
        case 3:
            origin = NSPoint(x: visible.minX + margin, y: visible.maxY - size.height - margin)
        case 4:
            origin = NSPoint(x: visible.minX + settings.horizontalOffset, y: visible.minY + settings.verticalOffset)
        default:
            origin = NSPoint(x: visible.maxX - size.width - margin, y: visible.minY + margin)
        }
        panel.setFrameOrigin(origin)
    }
}

struct FloatingClockView: View {
    var schedule: [TimetablePeriod]

    private var current: TimetablePeriod? {
        let now = Date()
        return schedule.first { $0.start <= now && $0.end >= now } ?? schedule.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "clock")
                Text(current?.classCode ?? "MYTGS")
                    .font(.headline)
                Spacer()
            }
            Text(current?.description ?? "No period loaded")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let current {
                ProgressView(value: progress(for: current))
                Text("\(current.start.formatted(date: .omitted, time: .shortened)) - \(current.end.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 260, height: 112)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator.opacity(0.35))
        }
    }

    private func progress(for period: TimetablePeriod) -> Double {
        let total = period.end.timeIntervalSince(period.start)
        guard total > 0 else { return 0 }
        return min(max(Date().timeIntervalSince(period.start) / total, 0), 1)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
