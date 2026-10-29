import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            FolderSettings()
                .tabItem { Label("Folders", systemImage: "folder") }
            ShortenerSettings()
                .tabItem { Label("Short URL", systemImage: "link") }
        }
        .frame(width: 520, height: 360)
    }
}

@MainActor
private struct GeneralSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Toggle("Also open the shelf whenever I start dragging a file or link", isOn: $settings.showOnDrag)

            Toggle("Open Raf at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                        loginError = nil
                    } catch {
                        loginError = error.localizedDescription
                    }
                }

            if let loginError {
                Text(loginError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Text("Click the Raf menu bar icon to open the shelf, or drag files onto the icon. Right-click the icon for the menu.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}

@MainActor
private struct FolderSettings: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Each folder shows up as a drop target on the shelf.")
                .foregroundStyle(.secondary)

            List {
                ForEach($settings.folders) { $folder in
                    HStack(spacing: 10) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("Name", text: $folder.name)
                                .textFieldStyle(.plain)
                            Text(folder.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Picker("", selection: $folder.mode) {
                            Text("Copy").tag(FolderTarget.Mode.copy)
                            Text("Move").tag(FolderTarget.Mode.move)
                        }
                        .labelsHidden()
                        .frame(width: 90)
                        Button {
                            settings.folders.removeAll { $0.id == folder.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove folder")
                    }
                    .padding(.vertical, 2)
                }
                .onMove { settings.folders.move(fromOffsets: $0, toOffset: $1) }
            }

            Button("Add Folder…", action: chooseFolders)
        }
        .padding(20)
    }

    private func chooseFolders() {
        FolderPicker.chooseFolders().forEach(settings.addFolder(at:))
    }
}

@MainActor
private struct ShortenerSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var apiKey = ""
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            Picker("Service", selection: $settings.shortener) {
                ForEach(ShortenerProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }

            if settings.shortener.needsBaseURL {
                TextField("Server address", text: $settings.shortenerBaseURL, prompt: Text("https://sho.rt"))
            }

            if settings.shortener.needsAPIKey {
                SecureField(settings.shortener.apiKeyLabel, text: $apiKey)
                    .onSubmit(saveKey)
                    .onChange(of: apiKey) { _ in saveKey() }
            } else {
                Text("TinyURL works without an account.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Test", action: test)
                    .disabled(isTesting)
                if isTesting {
                    ProgressView().controlSize(.small)
                }
                if let testResult {
                    Text(testResult)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(20)
        .onAppear(perform: loadKey)
        .onChange(of: settings.shortener) { _ in
            loadKey()
            testResult = nil
        }
    }

    private func loadKey() {
        apiKey = settings.apiKey(for: settings.shortener)
    }

    private func saveKey() {
        settings.setAPIKey(apiKey, for: settings.shortener)
    }

    private func test() {
        saveKey()
        isTesting = true
        testResult = nil
        Task {
            defer { isTesting = false }
            do {
                let short = try await URLShortener.shorten(
                    URL(string: "https://www.apple.com/macos/")!,
                    config: settings.shortenerConfig()
                )
                testResult = "Works: \(short.absoluteString)"
            } catch {
                testResult = error.localizedDescription
            }
        }
    }
}
