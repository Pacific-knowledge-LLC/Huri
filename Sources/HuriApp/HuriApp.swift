import SwiftUI

@main
struct HuriApplication: App {
    var body: some Scene {
        WindowGroup {
            HuriRootView()
                .frame(minWidth: 940, minHeight: 640)
        }
        .defaultSize(width: 1180, height: 760)
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            HuriCommands()
        }
    }
}

private struct HuriCommands: Commands {
    @FocusedValue(\.openFilesAction) private var openFiles
    @FocusedValue(\.startConversionAction) private var startConversion

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Importer des fichiers…") {
                openFiles?()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(openFiles == nil)
        }

        CommandMenu("Conversion") {
            Button("Lancer la conversion") {
                startConversion?()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(startConversion == nil)
        }
    }
}

private struct OpenFilesActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct StartConversionActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var openFilesAction: (() -> Void)? {
        get { self[OpenFilesActionKey.self] }
        set { self[OpenFilesActionKey.self] = newValue }
    }

    var startConversionAction: (() -> Void)? {
        get { self[StartConversionActionKey.self] }
        set { self[StartConversionActionKey.self] = newValue }
    }
}
