import SwiftUI
import MYTGSCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var updates: UpdateController
    @State private var savedAt: Date?

    var body: some View {
        TabView {
            application
                .tabItem { Label("Application", systemImage: "app.badge") }
            clock
                .tabItem { Label("Clock", systemImage: "clock") }
            bell
                .tabItem { Label("Bell", systemImage: "speaker.wave.2") }
            integrations
                .tabItem { Label("Integrations", systemImage: "network") }
            account
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .frame(width: 760, height: 560)
        .safeAreaInset(edge: .bottom) {
            SettingsFooter(savedAt: savedAt, status: model.statusMessage) {
                save()
            }
        }
    }

    private var application: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: $model.settings.launchAtLogin)
                Toggle("Start Minimized", isOn: $model.settings.startMinimized)
            }

            Section("Updates") {
                Toggle("Silent Updates", isOn: $model.settings.silentUpdates)
                LabeledContent("Status") {
                    Text(updates.statusMessage)
                        .foregroundStyle(.secondary)
                }
                Button {
                    updates.checkForUpdates()
                    model.statusMessage = updates.statusMessage
                } label: {
                    Label("Check for Updates", systemImage: "arrow.down.circle")
                }
            }

            Section("Today") {
                Picker("Early Finish", selection: earlyFinishBinding) {
                    Text("Automatic").tag(Optional<Bool>.none)
                    Text("Yes").tag(Optional(true))
                    Text("No").tag(Optional(false))
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private var clock: some View {
        Form {
            Section("Floating Clock") {
                Toggle("Show Floating Clock", isOn: $model.settings.clock.showFloatingClock)
                Toggle("Fade on Hover", isOn: $model.settings.clock.fadeOnHover)
                Toggle("Hide on Finish", isOn: $model.settings.clock.hideOnFinish)
                Toggle("Combine Double Periods", isOn: $model.settings.clock.combineDoubles)
            }

            Section("Placement") {
                Stepper(displayNameForScreen, value: $model.settings.clock.screenPreference, in: 0...8)
                Picker("Corner", selection: $model.settings.clock.placementMode) {
                    Text("Bottom Right").tag(0)
                    Text("Bottom Left").tag(1)
                    Text("Top Right").tag(2)
                    Text("Top Left").tag(3)
                    Text("Custom").tag(4)
                }
                HStack {
                    TextField("Horizontal Offset", value: $model.settings.clock.horizontalOffset, format: .number)
                    TextField("Vertical Offset", value: $model.settings.clock.verticalOffset, format: .number)
                }
                Toggle("Prefer Table Position", isOn: $model.settings.clock.tablePositionPreference)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private var bell: some View {
        Form {
            Section("Bell") {
                Toggle("Bell Enabled", isOn: $model.settings.bell.enabled)
                Slider(value: $model.settings.bell.volume, in: 0...100) {
                    Text("Volume")
                } minimumValueLabel: {
                    Image(systemName: "speaker")
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3")
                }
                TextField("Output Device ID", text: Binding(
                    get: { model.settings.bell.outputDeviceID ?? "" },
                    set: { model.settings.bell.outputDeviceID = $0.isEmpty ? nil : $0 }
                ))
                Button {
                    model.playBellPreview()
                } label: {
                    Label("Preview Bell", systemImage: "play.circle")
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private var integrations: some View {
        Form {
            Section("Local API") {
                Toggle("Enable Local API", isOn: $model.settings.localAPI.enabled)
                Toggle("Hide Name and ID", isOn: $model.settings.localAPI.hideName)
                Toggle("Open Network Access", isOn: $model.settings.localAPI.openNetwork)
                TextField("Port", value: $model.settings.localAPI.port, format: .number)
                TextField("CORS Origins", text: Binding(
                    get: { model.settings.localAPI.corsOrigins.joined(separator: ", ") },
                    set: {
                        model.settings.localAPI.corsOrigins = $0
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                    }
                ))
                LabeledContent("Status") {
                    StatusPill(text: model.localAPIRunning ? "Running" : "Stopped", symbol: "network", tint: model.localAPIRunning ? .green : .gray)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private var account: some View {
        Form {
            Section("Firefly") {
                LabeledContent("User", value: model.session?.user.name ?? "Not signed in")
                LabeledContent("Email", value: model.session?.user.email ?? "-")
                LabeledContent("School", value: model.session?.school.url.absoluteString ?? "-")
                HStack {
                    Button {
                        model.beginLogin()
                    } label: {
                        Label("Sign In", systemImage: "person.badge.key")
                    }
                    Button(role: .destructive) {
                        model.logout()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .disabled(model.session == nil)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private var displayNameForScreen: String {
        model.settings.clock.screenPreference == 0 ? "Screen: Main Display" : "Screen: \(model.settings.clock.screenPreference)"
    }

    private var earlyFinishBinding: Binding<Bool?> {
        Binding(
            get: { model.settings.todayEarlyFinishOverride },
            set: { model.settings.todayEarlyFinishOverride = $0 }
        )
    }

    private func save() {
        model.persistSettings()
        savedAt = Date()
    }
}

private struct SettingsFooter: View {
    var savedAt: Date?
    var status: String
    var save: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(savedAt.map { "Saved \($0.formatted(date: .omitted, time: .shortened))" } ?? status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button {
                save()
            } label: {
                Label("Save", systemImage: "checkmark.circle")
            }
            .keyboardShortcut("s", modifiers: [.command])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
}
