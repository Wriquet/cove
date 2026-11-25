import SwiftUI
import UniformTypeIdentifiers

struct ConnectionDialog: View {
    @Environment(AppState.self) private var state
    @State private var name = ""
    @State private var backend: BackendType = .postgres
    @State private var host = "localhost"
    @State private var port = BackendType.postgres.defaultPort
    @State private var user = ""
    @State private var password = ""
    @State private var database = ""
    @State private var selectedColor = CoveTheme.accent
    @State private var selectedEnvironment: ConnectionEnvironment = .local

    // SSH tunnel
    @State private var sshEnabled = false
    @State private var sshHost = ""
    @State private var sshPort = "22"
    @State private var sshUser = ""
    @State private var sshAuthMethod: SSHAuthMethod = .password
    @State private var sshPassword = ""
    @State private var sshPrivateKeyPath = ""
    @State private var sshPassphrase = ""

    var body: some View {
        let dialog = state.dialog
        let capabilities = backend.capabilities

        VStack(spacing: 12) {
            Text(dialog.isEditing ? L10n.tr("Edit Connection") : L10n.tr("New Connection"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            formField("Name") {
                HStack(spacing: 8) {
                    TextField(L10n.tr("Name"), text: $name)
                        .textFieldStyle(.roundedBorder)
                    ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                        .labelsHidden()
                        .fixedSize()
                }
            }

            formField("Backend") {
                Picker("", selection: $backend) {
                    ForEach(BackendType.allCases, id: \.self) { type in
                        Label {
                            Text(type.displayName)
                        } icon: {
                            Image(nsImage: scaledIcon(type.iconAsset))
                        }
                        .tag(type)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let notice = backend.connectionNotice {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text(notice)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }

            formField("Environment") {
                Picker("", selection: $selectedEnvironment) {
                    ForEach(ConnectionEnvironment.allCases, id: \.self) { env in
                        Label {
                            Text(env.displayName)
                        } icon: {
                            Image(nsImage: coloredDot(env.color))
                        }
                        .tag(env)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if capabilities.usesFilePath {
                formField("Database File") {
                    HStack(spacing: 8) {
                        TextField(L10n.tr("Path to database file"), text: $database)
                            .textFieldStyle(.roundedBorder)
                        if !sshEnabled {
                            Button(L10n.tr("Browse...")) {
                                browseForDatabaseFile()
                            }
                        }
                    }
                }
            }

            if capabilities.usesHostPort {
                HStack(spacing: 8) {
                    formField("Host") {
                        TextField(L10n.tr("Host"), text: $host)
                            .textFieldStyle(.roundedBorder)
                    }
                    formField("Port") {
                        TextField(L10n.tr("Port"), text: $port)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(width: 80)
                }
            }

            if capabilities.usesCredentials {
                formField("User") {
                    TextField(L10n.tr("User"), text: $user)
                        .textFieldStyle(.roundedBorder)
                }

                formField("Password") {
                    SecureField(L10n.tr("Password"), text: $password)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if capabilities.usesDatabaseName {
                formField("Database") {
                    TextField(L10n.tr("Database"), text: $database)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if capabilities.supportsSSH {
                Divider()

                sshSection
            }

            if !dialog.error.isEmpty {
                Text(dialog.error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button(L10n.tr("Test")) {
                    syncToDialog()
                    state.dialogTest()
                }
                .disabled(dialog.testing || dialog.connecting)

                if dialog.testing {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
                Button(L10n.tr("Cancel")) {
                    state.dialogCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                if dialog.isEditing {
                    Button(L10n.tr("Save")) {
                        syncToDialog()
                        state.dialogSaveEdit()
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(dialog.connecting ? L10n.tr("Connecting...") : L10n.tr("Connect")) {
                        syncToDialog()
                        state.dialogConnect()
                    }
                    .disabled(dialog.connecting)
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(width: 400)
        .presentationBackground(.regularMaterial)
        .onAppear {
            name = dialog.name
            backend = dialog.backend
            host = dialog.host
            port = dialog.port
            user = dialog.user
            password = dialog.password
            database = dialog.database
            selectedColor = Color(hex: dialog.colorHex)
            selectedEnvironment = dialog.environment
            sshEnabled = dialog.sshEnabled
            sshHost = dialog.sshHost
            sshPort = dialog.sshPort
            sshUser = dialog.sshUser
            sshAuthMethod = dialog.sshAuthMethod
            sshPassword = dialog.sshPassword
            sshPrivateKeyPath = dialog.sshPrivateKeyPath
            sshPassphrase = dialog.sshPassphrase
        }
        .onDisappear {
            NSColorPanel.shared.close()
        }
        .onChange(of: backend) { _, newBackend in
            port = newBackend.defaultPort
            if !newBackend.capabilities.supportsSSH {
                sshEnabled = false
            }
        }
        .onChange(of: dialog.testResult?.message) {
            guard let result = dialog.testResult else { return }
            let alert = NSAlert()
            alert.alertStyle = result.success ? .informational : .critical
            alert.messageText = result.success ? L10n.tr("Test Successful") : L10n.tr("Test Failed")
            alert.informativeText = result.message
            alert.addButton(withTitle: L10n.tr("OK"))
            alert.runModal()
            dialog.testResult = nil
        }
    }

    @ViewBuilder
    private var sshSection: some View {
        Toggle(L10n.tr("SSH Tunnel"), isOn: $sshEnabled)
            .toggleStyle(.switch)
            .frame(maxWidth: .infinity, alignment: .leading)

        if sshEnabled {
            HStack(spacing: 8) {
                formField("SSH Host") {
                    TextField(L10n.tr("SSH Host"), text: $sshHost)
                        .textFieldStyle(.roundedBorder)
                }
                formField("SSH Port") {
                    TextField(L10n.tr("Port"), text: $sshPort)
                        .textFieldStyle(.roundedBorder)
                }
                .frame(width: 80)
            }

            formField("SSH User") {
                TextField(L10n.tr("SSH User"), text: $sshUser)
                    .textFieldStyle(.roundedBorder)
            }

            formField("Auth Method") {
                HStack {
                    Picker(L10n.tr("Auth Method"), selection: $sshAuthMethod) {
                        ForEach(SSHAuthMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    Spacer(minLength: 0)
                }
            }

            if sshAuthMethod == .password {
                formField("SSH Password") {
                    SecureField(L10n.tr("SSH Password"), text: $sshPassword)
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                formField("Private Key") {
                    HStack(spacing: 8) {
                        TextField("~/.ssh/id_ed25519", text: $sshPrivateKeyPath)
                            .textFieldStyle(.roundedBorder)
                        Button(L10n.tr("Browse...")) {
                            browseForKeyFile()
                        }
                    }
                }

                formField("Passphrase") {
                    SecureField(L10n.tr("Passphrase (if any)"), text: $sshPassphrase)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private func browseForDatabaseFile() {
        let panel = NSOpenPanel()
        panel.title = L10n.tr("Select Database File")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .init(filenameExtension: "sqlite")!,
            .init(filenameExtension: "db")!,
            .init(filenameExtension: "sqlite3")!,
            .init(filenameExtension: "duckdb")!,
        ]
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK, let url = panel.url {
            database = url.path
        }
    }

    private func browseForKeyFile() {
        let panel = NSOpenPanel()
        panel.title = L10n.tr("Select SSH Private Key")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        if panel.runModal() == .OK, let url = panel.url {
            sshPrivateKeyPath = url.path
        }
    }

    private func syncToDialog() {
        let dialog = state.dialog
        dialog.name = name
        dialog.backend = backend
        dialog.host = host
        dialog.port = port
        dialog.user = user
        dialog.password = password
        dialog.database = database
        dialog.colorHex = selectedColor.hexString
        dialog.environment = selectedEnvironment
        dialog.sshEnabled = sshEnabled
        dialog.sshHost = sshHost
        dialog.sshPort = sshPort
        dialog.sshUser = sshUser
        dialog.sshAuthMethod = sshAuthMethod
        dialog.sshPassword = sshPassword
        dialog.sshPrivateKeyPath = sshPrivateKeyPath
        dialog.sshPassphrase = sshPassphrase
    }

    private func scaledIcon(_ assetName: String) -> NSImage {
        guard let source = NSImage(named: assetName) else { return NSImage() }
        let size: CGFloat = 16
        let sourceSize = source.size
        let aspect = sourceSize.width / sourceSize.height
        let drawSize: NSSize
        if aspect > 1 {
            drawSize = NSSize(width: size, height: size / aspect)
        } else {
            drawSize = NSSize(width: size * aspect, height: size)
        }
        let origin = NSPoint(x: (size - drawSize.width) / 2, y: (size - drawSize.height) / 2)
        let result = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            source.draw(in: NSRect(origin: origin, size: drawSize))
            return true
        }
        result.isTemplate = false
        return result
    }

    private func coloredDot(_ color: Color) -> NSImage {
        let dot: CGFloat = 8
        let image = NSImage(size: NSSize(width: dot, height: dot), flipped: false) { _ in
            let oval = NSRect(x: 0, y: 0, width: dot, height: dot)
            NSColor(color).setFill()
            NSBezierPath(ovalIn: oval).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.tr(label))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            content()
        }
    }
}
