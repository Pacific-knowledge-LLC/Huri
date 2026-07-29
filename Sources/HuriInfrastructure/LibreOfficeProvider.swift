import Foundation
import HuriCore

public final class LibreOfficeProvider: @unchecked Sendable {
  public let executableURL: URL?

  public var isAvailable: Bool { executableURL != nil }

  public init(executableURL: URL? = nil) {
    self.executableURL = executableURL ?? Self.discoverExecutable()
  }

  @discardableResult
  public func convertToPDF(source: URL, destination: URL) throws -> URL {
    guard let executableURL else {
      throw ConversionError.unsupported(
        HuriL10n.text("error.libreOffice.missing")
      )
    }
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("huri-libreoffice-\(UUID().uuidString)", isDirectory: true)
    let outputDirectory = temporaryDirectory.appendingPathComponent("output", isDirectory: true)
    let profileDirectory = temporaryDirectory.appendingPathComponent("profile", isDirectory: true)
    try FileManager.default.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: profileDirectory,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let standardError = Pipe()
    let process = Process()
    process.executableURL = executableURL
    process.arguments = [
      "-env:UserInstallation=\(profileDirectory.absoluteString)",
      "--headless",
      "--nologo",
      "--nodefault",
      "--nolockcheck",
      "--convert-to", "pdf",
      "--outdir", outputDirectory.path,
      source.path,
    ]
    process.standardOutput = Pipe()
    process.standardError = standardError

    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      throw ConversionError.conversionFailed(
        HuriL10n.format(
          "error.libreOffice.start",
          arguments: error.localizedDescription
        )
      )
    }

    let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
    let diagnostic = String(data: errorData, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard process.terminationStatus == 0 else {
      throw ConversionError.conversionFailed(
        diagnostic?.isEmpty == false
          ? HuriL10n.format(
            "error.libreOffice.diagnostic",
            arguments: diagnostic!
          )
          : HuriL10n.format(
            "error.libreOffice.exit",
            arguments: process.terminationStatus
          )
      )
    }
    let generated =
      outputDirectory
      .appendingPathComponent(source.deletingPathExtension().lastPathComponent)
      .appendingPathExtension("pdf")
    guard let data = try? Data(contentsOf: generated), !data.isEmpty else {
      throw ConversionError.conversionFailed(
        HuriL10n.format(
          "error.libreOffice.noOutput",
          arguments: source.lastPathComponent
        )
      )
    }
    try InfrastructureSupport.writeAtomically(data, to: destination)
    return destination
  }

  public static func discoverExecutable() -> URL? {
    let candidates = [
      "/Applications/LibreOffice.app/Contents/MacOS/soffice",
      "/opt/homebrew/bin/soffice",
      "/usr/local/bin/soffice",
      "/usr/bin/soffice",
    ]
    return
      candidates
      .map(URL.init(fileURLWithPath:))
      .first { FileManager.default.isExecutableFile(atPath: $0.path) }
  }
}
