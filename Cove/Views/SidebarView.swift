import SwiftUI
import AppKit

struct SidebarView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                VisualEffectBackground(material: .sidebar)
            }
    }

    @ViewBuilder
    private var content: some View {
        if state.connecting {
            ProgressView(L10n.tr("Connecting..."))
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.connection == nil {
            Text(L10n.tr("Connect to a database"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(20)
        } else {
            TreeView()
                .sheet(isPresented: Bindable(state).showCreateSheet) {
                    CreateChildSheet()
                        .environment(state)
                }
                .sheet(isPresented: Bindable(state).showTreeAction) {
                    DropConfirmSheet()
                        .environment(state)
                }
        }
    }
}

struct CreateChildSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String] = [:]

    private var sqlPreview: String? {
        state.connection?.generateCreateChildSQL(
            path: state.createSheetParentPath,
            values: values
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.format("New %@", L10n.tr(state.createSheetLabel)))
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Form {
                ForEach(state.createSheetFields) { field in
                    if let options = field.options {
                        Picker(L10n.tr(field.label), selection: binding(for: field)) {
                            ForEach(options, id: \.self) { option in
                                Text(L10n.optionLabel(option)).tag(option)
                            }
                        }
                    } else {
                        TextField(
                            L10n.tr(field.label),
                            text: binding(for: field),
                            prompt: Text(field.placeholder == "optional" ? L10n.tr("optional") : field.placeholder)
                        )
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .padding(.horizontal, 4)

            Text(L10n.tr("SQL Preview"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

            ScrollView {
                Text(sqlPreview ?? "")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(sqlPreview != nil ? .primary : .secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: 80)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 16)

            HStack {
                Spacer()
                Button(L10n.tr("Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(L10n.tr("Execute")) {
                    state.executeCreateChild(values: values)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(sqlPreview == nil)
            }
            .padding(16)
        }
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .background()
        .onAppear {
            for field in state.createSheetFields {
                values[field.id] = field.defaultValue
            }
        }
    }

    private func binding(for field: CreateField) -> Binding<String> {
        Binding(
            get: { values[field.id] ?? field.defaultValue },
            set: { values[field.id] = $0 }
        )
    }
}

struct DropConfirmSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.tr("Confirm Drop"))
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ScrollView {
                Text(state.treeActionSQL)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 16)

            HStack {
                Spacer()
                Button(L10n.tr("Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(L10n.tr("Execute")) {
                    state.executeTreeAction()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 520, height: 280)
        .background()
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .withinWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}
