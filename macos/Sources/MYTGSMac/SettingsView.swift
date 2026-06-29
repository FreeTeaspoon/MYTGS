import SwiftUI
import MYTGSCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

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
        .frame(width: 720, height: 520)
        .padding()
    }

    private var application: some View {
        Form {
            Toggle("Launch at Login", isOn: $model.settings.launchAtLogin)
            Toggle("Start Minimized", isOn: $model.settings.startMinimized)
            Toggle("Silent Updates", isOn: $model.settings.silentUpdates)
            Picker("Today Early Finish", selection: earlyFinishBinding) {
                Text("Automatic").tag(Optional<Bool>.none)
                Text("Yes").tag(Optional(true))
                Text("No").tag(Optional(false))
            }
            Text(model.updateStatus)
                .foregroundStyle(.secondary)
            Button("Save") {
                model.persistSettings()
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var clock: some View {
        Form {
            Toggle("Show Floating Clock", isOn: $model.settings.clock.showFloatingClock)
            Toggle("Fade on Hover", isOn: $model.settings.clock.fadeOnHover)
            Toggle("Hide on Finish", isOn: $model.settings.clock.hideOnFinish)
            Toggle("Combine Double Periods", isOn: $model.settings.clock.combineDoubles)
            Stepper("Screen \(model.settings.clock.screenPreference)", value: $model.settings.clock.screenPreference, in: 0...8)
            Picker("Placement", selection: $model.settings.clock.placementMode) {
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
            Button("Save") {
                model.persistSettings()
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var bell: some View {
        Form {
            Toggle("Bell Enabled", isOn: $model.settings.bell.enabled)
            Slider(value: $model.settings.bell.volume, in: 0...100) {
                Text("Volume")
            }
            TextField("Output Device ID", text: Binding(
                get: { model.settings.bell.outputDeviceID ?? "" },
                set: { model.settings.bell.outputDeviceID = $0.isEmpty ? nil : $0 }
            ))
            Button("Save") {
                model.persistSettings()
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var integrations: some View {
        Form {
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
            Text(model.localAPIRunning ? "Local API is running." : "Local API is stopped.")
                .foregroundStyle(.secondary)
            Button("Save") {
                model.persistSettings()
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var account: some View {
        Form {
            LabeledContent("User", value: model.session?.user.name ?? "Not signed in")
            LabeledContent("School", value: model.session?.school.url.absoluteString ?? "-")
            HStack {
                Button("Sign In") {
                    model.beginLogin()
                }
                Button("Sign Out", role: .destructive) {
                    model.logout()
                }
                .disabled(model.session == nil)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var earlyFinishBinding: Binding<Bool?> {
        Binding(
            get: { model.settings.todayEarlyFinishOverride },
            set: { model.settings.todayEarlyFinishOverride = $0 }
        )
    }
}
