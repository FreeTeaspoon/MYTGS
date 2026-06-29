import AppKit
import SwiftUI
import MYTGSCore

@MainActor
final class FloatingClockPanelController: ObservableObject {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<FloatingClockView>?
    private var hideTimer: Timer?

    func update(schedule: [TimetablePeriod], settings: ClockSettings) {
        hideTimer?.invalidate()
        hideTimer = nil

        guard settings.showFloatingClock else {
            panel?.orderOut(nil)
            return
        }

        if settings.hideOnFinish, scheduleFinished(schedule) {
            panel?.orderOut(nil)
            return
        }

        let view = FloatingClockView(schedule: schedule, settings: settings)
        if let hostingController {
            hostingController.rootView = view
        } else {
            hostingController = NSHostingController(rootView: view)
        }

        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 292, height: 128),
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

        if settings.hideOnFinish {
            scheduleHideTimer(for: schedule)
        }
    }

    private func position(settings: ClockSettings) {
        guard let panel, let screen = selectedScreen(settings: settings) else { return }
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

        panel.setFrameOrigin(clamped(origin: origin, size: size, visible: visible, margin: margin))
    }

    private func selectedScreen(settings: ClockSettings) -> NSScreen? {
        if settings.screenPreference > 0 {
            return NSScreen.screens[safe: settings.screenPreference - 1] ?? NSScreen.main
        }
        return NSScreen.main
    }

    private func clamped(origin: NSPoint, size: NSSize, visible: NSRect, margin: CGFloat) -> NSPoint {
        NSPoint(
            x: min(max(origin.x, visible.minX + margin), visible.maxX - size.width - margin),
            y: min(max(origin.y, visible.minY + margin), visible.maxY - size.height - margin)
        )
    }

    private func scheduleFinished(_ schedule: [TimetablePeriod]) -> Bool {
        guard let last = schedule.map(\.end).max() else { return false }
        return Date() > last
    }

    private func scheduleHideTimer(for schedule: [TimetablePeriod]) {
        guard let last = schedule.map(\.end).max(), last > Date() else { return }
        hideTimer = Timer.scheduledTimer(withTimeInterval: last.timeIntervalSinceNow, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.panel?.orderOut(nil)
            }
        }
    }
}

struct FloatingClockView: View {
    var schedule: [TimetablePeriod]
    var settings: ClockSettings
    @State private var isHovering = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let current = currentPeriod(at: context.date)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .foregroundStyle(.blue)
                    Text(current?.displayClass ?? "MYTGS")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 8)
                    if current?.hasChanges == true {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.orange)
                    }
                }

                Text(current?.displayRoom ?? "No period loaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let current {
                    ProgressView(value: progress(for: current, at: context.date))
                    HStack {
                        Text(current.timeRange)
                        Spacer()
                        Text(timeRemaining(for: current, at: context.date))
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                } else {
                    ProgressView(value: 0)
                    Text(schedule.isEmpty ? "Refresh to load timetable" : "Day complete")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(width: 292, height: 128, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .glassEffect(in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.separator.opacity(0.35))
            }
            .opacity(settings.fadeOnHover && isHovering ? 0.42 : 1)
            .animation(.snappy(duration: 0.18), value: isHovering)
            .onHover { isHovering = $0 }
        }
    }

    private func currentPeriod(at date: Date) -> TimetablePeriod? {
        schedule.first { $0.start <= date && $0.end >= date } ?? schedule.first { $0.start > date }
    }

    private func progress(for period: TimetablePeriod, at date: Date) -> Double {
        let total = period.end.timeIntervalSince(period.start)
        guard total > 0 else { return 0 }
        return min(max(date.timeIntervalSince(period.start) / total, 0), 1)
    }

    private func timeRemaining(for period: TimetablePeriod, at date: Date) -> String {
        let remaining = max(period.end.timeIntervalSince(date), 0)
        let minutes = Int(remaining / 60)
        return "\(minutes)m left"
    }
}

private extension TimetablePeriod {
    var displayClass: String {
        classCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? description : classCode
    }

    var displayRoom: String {
        roomCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? description : roomCode
    }

    var timeRange: String {
        "\(start.formatted(date: .omitted, time: .shortened))-\(end.formatted(date: .omitted, time: .shortened))"
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
