import HuriCore
import SwiftUI

@main
struct HuriApplication: App {
  private var qualityAssuranceColorScheme: ColorScheme? {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("--qa-dark-mode") {
      return .dark
    }
    if arguments.contains("--qa-light-mode") {
      return .light
    }
    return nil
  }

  var body: some Scene {
    WindowGroup {
      HuriRootView()
        .frame(minWidth: 940, minHeight: 640)
        .preferredColorScheme(qualityAssuranceColorScheme)
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
      Button(HuriL10n.text("command.import")) {
        openFiles?()
      }
      .keyboardShortcut("o", modifiers: .command)
      .disabled(openFiles == nil)
    }

    CommandMenu(HuriL10n.text("command.conversion")) {
      Button(HuriL10n.text("command.startConversion")) {
        startConversion?()
      }
      .keyboardShortcut(.return, modifiers: [.command])
      .disabled(startConversion == nil)
    }

    CommandGroup(replacing: .help) {
      Link(destination: HuriCore.websiteURL) {
        Label(HuriL10n.text("about.website"), systemImage: "globe")
      }
      Link(destination: URL(string: "mailto:\(HuriCore.supportEmail)")!) {
        Label(HuriL10n.text("about.contact"), systemImage: "envelope")
      }
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
