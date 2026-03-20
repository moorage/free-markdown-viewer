import SwiftUI

struct ViewerShellView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(model.files) { file in
                Button {
                    model.openFile(file.path)
                } label: {
                    HStack {
                        Text(file.name)
                            .font(.body)
                        Spacer()
                        if model.selectedPath == file.path {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityIDs.sidebarNode(file.path.rawValue))
            }
            .listStyle(.sidebar)
            .accessibilityIdentifier(AccessibilityIDs.sidebarList)
        } detail: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: model.navigateBack) {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .disabled(model.backStack.isEmpty)
                    .accessibilityIdentifier(AccessibilityIDs.backButton)

                    Button(action: model.navigateForward) {
                        Label("Forward", systemImage: "chevron.right")
                    }
                    .disabled(model.forwardStack.isEmpty)
                    .accessibilityIdentifier(AccessibilityIDs.forwardButton)

                    Text(model.selectedPath?.rawValue ?? "No file selected")
                        .font(.headline)
                        .accessibilityIdentifier(AccessibilityIDs.title)

                    Spacer()
                }

                ScrollView {
                    Text(model.documentText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.body)
                        .textSelection(.enabled)
                        .accessibilityIdentifier(AccessibilityIDs.text)
                        .padding(.bottom, 24)
                }
                .accessibilityIdentifier(AccessibilityIDs.scrollView)
            }
            .padding(20)
        }
    }
}
