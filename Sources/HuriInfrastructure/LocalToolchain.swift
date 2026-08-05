import Foundation
import HuriCore

public struct LocalToolchain: Sendable {
  public let executables: [ConversionBackend: URL]

  public init(executables: [ConversionBackend: URL]? = nil) {
    if let executables {
      self.executables = executables
      return
    }

    var discovered: [ConversionBackend: URL] = [:]
    discovered[.ffmpeg] = CommandLocator.find(
      names: ["ffmpeg"],
      additionalPaths: ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
    )
    discovered[.imageMagick] = CommandLocator.find(
      names: ["magick"],
      additionalPaths: ["/opt/homebrew/bin/magick", "/usr/local/bin/magick"]
    )
    discovered[.libreOffice] = CommandLocator.find(
      names: ["soffice"],
      additionalPaths: [
        "/Applications/LibreOffice.app/Contents/MacOS/soffice",
        "/opt/homebrew/bin/soffice",
        "/usr/local/bin/soffice",
      ]
    )
    discovered[.pandoc] = CommandLocator.find(
      names: ["pandoc"],
      additionalPaths: ["/opt/homebrew/bin/pandoc", "/usr/local/bin/pandoc"]
    )
    discovered[.calibre] = CommandLocator.find(
      names: ["ebook-convert"],
      additionalPaths: [
        "/Applications/calibre.app/Contents/MacOS/ebook-convert",
        "/opt/homebrew/bin/ebook-convert",
        "/usr/local/bin/ebook-convert",
      ]
    )
    discovered[.fontForge] = CommandLocator.find(
      names: ["fontforge"],
      additionalPaths: [
        "/Applications/FontForge.app/Contents/MacOS/FontForge",
        "/opt/homebrew/bin/fontforge",
        "/usr/local/bin/fontforge",
      ]
    )
    discovered[.inkscape] = CommandLocator.find(
      names: ["inkscape"],
      additionalPaths: [
        "/Applications/Inkscape.app/Contents/MacOS/inkscape",
        "/opt/homebrew/bin/inkscape",
        "/usr/local/bin/inkscape",
      ]
    )
    discovered[.archive] =
      CommandLocator.find(
        names: ["7zz", "7z"],
        additionalPaths: [
          "/opt/homebrew/bin/7zz", "/usr/local/bin/7zz",
          "/opt/homebrew/bin/7z", "/usr/local/bin/7z",
        ]
      )
      ?? CommandLocator.find(
        names: ["tar"],
        additionalPaths: ["/usr/bin/tar"]
      )

    self.executables = discovered.compactMapValues { $0 }
  }

  public var availableBackends: Set<ConversionBackend> {
    Set(executables.keys).union([.native])
  }

  public func executable(for backend: ConversionBackend) -> URL? {
    executables[backend]
  }
}

struct LocalToolchainConversionEngine: Sendable {
  let toolchain: LocalToolchain

  init(toolchain: LocalToolchain = .init()) {
    self.toolchain = toolchain
  }

  func convert(
    source: URL,
    inputFormat: FileFormat,
    outputFormat: FileFormat,
    destination: URL,
    options: ConversionOptions
  ) async throws -> URL {
    let backend = try backend(
      inputFormat: inputFormat,
      outputFormat: outputFormat
    )
    guard let executable = toolchain.executable(for: backend) else {
      throw ConversionError.unsupported(
        HuriL10n.format(
          "error.tool.missing",
          arguments: backend.displayName
        )
      )
    }

    switch backend {
    case .ffmpeg:
      return try await convertWithFFmpeg(
        executable: executable,
        source: source,
        inputFormat: inputFormat,
        outputFormat: outputFormat,
        destination: destination,
        options: options
      )
    case .imageMagick:
      return try await convertWithImageMagick(
        executable: executable,
        source: source,
        outputFormat: outputFormat,
        destination: destination,
        options: options
      )
    case .libreOffice:
      return try await LibreOfficeProvider(executableURL: executable)
        .convert(
          source: source,
          to: outputFormat,
          destination: destination
        )
    case .pandoc:
      return try await convertWithPandoc(
        executable: executable,
        source: source,
        inputFormat: inputFormat,
        outputFormat: outputFormat,
        destination: destination
      )
    case .calibre:
      return try await convertWithCalibre(
        executable: executable,
        source: source,
        destination: destination
      )
    case .archive:
      return try await convertArchive(
        executable: executable,
        source: source,
        inputFormat: inputFormat,
        outputFormat: outputFormat,
        destination: destination
      )
    case .fontForge:
      return try await convertWithFontForge(
        executable: executable,
        source: source,
        destination: destination
      )
    case .inkscape:
      return try await convertWithInkscape(
        executable: executable,
        source: source,
        destination: destination
      )
    case .native:
      throw ConversionError.unsupported(
        HuriL10n.text("error.tool.nativeRouting")
      )
    }
  }

  private func backend(
    inputFormat: FileFormat,
    outputFormat: FileFormat
  ) throws -> ConversionBackend {
    let inputFamily = inputFormat.family
    let outputFamily = outputFormat.family

    if [.audio, .video].contains(inputFamily),
      [.audio, .video].contains(outputFamily),
      toolchain.executable(for: .ffmpeg) != nil
    {
      return .ffmpeg
    }
    if [.image, .vector].contains(inputFamily),
      [.image, .vector, .pdf].contains(outputFamily),
      toolchain.executable(for: .imageMagick) != nil
    {
      return .imageMagick
    }
    if [.document, .ebook, .text].contains(inputFamily),
      [.document, .ebook, .text].contains(outputFamily),
      toolchain.executable(for: .pandoc) != nil,
      inputFormat == .markdown || inputFamily == .ebook || outputFamily == .ebook
    {
      return .pandoc
    }
    if [.document, .presentation, .text].contains(inputFamily),
      [.document, .presentation, .text, .pdf].contains(outputFamily),
      toolchain.executable(for: .libreOffice) != nil
    {
      return .libreOffice
    }
    if [.document, .ebook, .text].contains(inputFamily),
      [.document, .ebook, .text].contains(outputFamily),
      toolchain.executable(for: .pandoc) != nil
    {
      return .pandoc
    }
    if [.document, .ebook, .text].contains(inputFamily),
      outputFamily == .ebook,
      toolchain.executable(for: .calibre) != nil
    {
      return .calibre
    }
    if inputFamily == .archive, outputFamily == .archive {
      return .archive
    }
    if inputFamily == .font, outputFamily == .font {
      return .fontForge
    }
    if inputFamily == .vector,
      [.image, .vector, .pdf].contains(outputFamily),
      toolchain.executable(for: .inkscape) != nil
    {
      return .inkscape
    }
    throw ConversionError.unsupported(
      HuriL10n.format(
        "error.conversion.unsupportedPair",
        arguments: inputFormat.displayName, outputFormat.displayName
      )
    )
  }

  private func convertWithFFmpeg(
    executable: URL,
    source: URL,
    inputFormat: FileFormat,
    outputFormat: FileFormat,
    destination: URL,
    options: ConversionOptions
  ) async throws -> URL {
    let temporary = try temporaryOutput(for: destination)
    defer { try? FileManager.default.removeItem(at: temporary) }

    var arguments = [
      "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
      "-i", source.path,
    ]
    if outputFormat.family == .audio {
      arguments.append(contentsOf: ["-vn"])
      arguments.append(contentsOf: audioCodecArguments(for: outputFormat, quality: options.quality))
    } else {
      arguments.append(
        contentsOf: videoCodecArguments(for: outputFormat, quality: options.quality)
      )
      if abs(options.scale - 1) > 0.001 {
        arguments.append(
          contentsOf: [
            "-vf",
            "scale=trunc(iw*\(options.scale)/2)*2:trunc(ih*\(options.scale)/2)*2",
          ]
        )
      }
    }
    arguments.append(
      contentsOf: options.preserveMetadata ? ["-map_metadata", "0"] : ["-map_metadata", "-1"])
    arguments.append(temporary.path)

    _ = try await ProcessRunner.run(executable: executable, arguments: arguments)
    return try finalize(temporary: temporary, destination: destination)
  }

  private func audioCodecArguments(for format: FileFormat, quality: Double) -> [String] {
    let bitrate = "\(Int(96 + quality * 160))k"
    switch format {
    case .mp3: return ["-c:a", "libmp3lame", "-b:a", bitrate]
    case .flac: return ["-c:a", "flac"]
    case .wav: return ["-c:a", "pcm_s16le"]
    case .aiff: return ["-c:a", "pcm_s16be"]
    case .opus: return ["-c:a", "libopus", "-b:a", bitrate]
    case .ogg, FileFormat("oga"):
      return ["-c:a", "libvorbis", "-q:a", "\(Int(quality * 8 + 1))"]
    case FileFormat("wma"): return ["-c:a", "wmav2", "-b:a", bitrate]
    case FileFormat("ac3"): return ["-c:a", "ac3", "-b:a", bitrate]
    case FileFormat("mp2"): return ["-c:a", "mp2", "-b:a", bitrate]
    case FileFormat("au"): return ["-c:a", "pcm_s16be"]
    case FileFormat("caf"), FileFormat("w64"): return ["-c:a", "pcm_s16le"]
    default: return ["-c:a", "aac", "-b:a", bitrate]
    }
  }

  private func videoCodecArguments(for format: FileFormat, quality: Double) -> [String] {
    let crf = "\(Int(36 - quality * 20))"
    switch format {
    case .webm:
      return ["-c:v", "libvpx-vp9", "-crf", crf, "-b:v", "0", "-c:a", "libopus"]
    case .mkv:
      return ["-c:v", "libx264", "-preset", "medium", "-crf", crf, "-c:a", "aac"]
    case .avi:
      return ["-c:v", "mpeg4", "-q:v", "\(Int(12 - quality * 9))", "-c:a", "libmp3lame"]
    case FileFormat("flv"):
      return ["-c:v", "flv", "-q:v", "\(Int(12 - quality * 9))", "-c:a", "aac"]
    case FileFormat("wmv"), FileFormat("asf"):
      return ["-c:v", "wmv2", "-q:v", "\(Int(12 - quality * 9))", "-c:a", "wmav2"]
    case FileFormat("ogv"):
      return ["-c:v", "libtheora", "-q:v", "\(Int(quality * 7 + 2))", "-c:a", "libvorbis"]
    case .mpeg, FileFormat("vob"):
      return ["-c:v", "mpeg2video", "-q:v", "\(Int(12 - quality * 9))", "-c:a", "mp2"]
    case FileFormat("3gp"), FileFormat("3g2"):
      return ["-c:v", "h263", "-c:a", "aac"]
    case FileFormat("mxf"):
      return ["-c:v", "mpeg2video", "-c:a", "pcm_s16le"]
    case FileFormat("ts"), FileFormat("m2ts"):
      return [
        "-c:v", "libx264", "-preset", "medium", "-crf", crf,
        "-c:a", "aac", "-f", "mpegts",
      ]
    default:
      return [
        "-c:v", "libx264", "-preset", "medium", "-crf", crf,
        "-c:a", "aac", "-movflags", "+faststart",
      ]
    }
  }

  private func convertWithImageMagick(
    executable: URL,
    source: URL,
    outputFormat: FileFormat,
    destination: URL,
    options: ConversionOptions
  ) async throws -> URL {
    let temporary = try temporaryOutput(for: destination)
    defer { try? FileManager.default.removeItem(at: temporary) }
    var arguments = [source.path, "-auto-orient"]
    if abs(options.scale - 1) > 0.001 {
      arguments.append(contentsOf: ["-resize", "\(Int(options.scale * 100))%"])
    }
    if outputFormat.isLossy {
      arguments.append(contentsOf: ["-quality", "\(Int(options.quality * 100))"])
    }
    if !options.preserveMetadata {
      arguments.append("-strip")
    }
    if !outputFormat.supportsTransparency {
      arguments.append(contentsOf: ["-background", "white", "-alpha", "remove", "-alpha", "off"])
    }
    arguments.append(temporary.path)
    _ = try await ProcessRunner.run(executable: executable, arguments: arguments)
    return try finalize(temporary: temporary, destination: destination)
  }

  private func convertWithPandoc(
    executable: URL,
    source: URL,
    inputFormat: FileFormat,
    outputFormat: FileFormat,
    destination: URL
  ) async throws -> URL {
    let temporary = try temporaryOutput(for: destination)
    defer { try? FileManager.default.removeItem(at: temporary) }
    let arguments = [
      "--from", pandocName(for: inputFormat),
      "--to", pandocName(for: outputFormat),
      "--wrap=preserve",
      "--output", temporary.path,
      source.path,
    ]
    _ = try await ProcessRunner.run(executable: executable, arguments: arguments)
    return try finalize(temporary: temporary, destination: destination)
  }

  private func pandocName(for format: FileFormat) -> String {
    switch format {
    case .txt: "plain"
    case .markdown: "markdown"
    case .html: "html5"
    case FileFormat("dbk"): "docbook"
    default: format.rawValue
    }
  }

  private func convertWithCalibre(
    executable: URL,
    source: URL,
    destination: URL
  ) async throws -> URL {
    let temporary = try temporaryOutput(for: destination)
    defer { try? FileManager.default.removeItem(at: temporary) }
    _ = try await ProcessRunner.run(
      executable: executable,
      arguments: [source.path, temporary.path]
    )
    return try finalize(temporary: temporary, destination: destination)
  }

  private func convertWithFontForge(
    executable: URL,
    source: URL,
    destination: URL
  ) async throws -> URL {
    let temporary = try temporaryOutput(for: destination)
    defer { try? FileManager.default.removeItem(at: temporary) }
    _ = try await ProcessRunner.run(
      executable: executable,
      arguments: [
        "-lang=ff", "-c", "Open($1); Generate($2)",
        source.path, temporary.path,
      ]
    )
    return try finalize(temporary: temporary, destination: destination)
  }

  private func convertWithInkscape(
    executable: URL,
    source: URL,
    destination: URL
  ) async throws -> URL {
    let temporary = try temporaryOutput(for: destination)
    defer { try? FileManager.default.removeItem(at: temporary) }
    _ = try await ProcessRunner.run(
      executable: executable,
      arguments: [
        "--export-filename=\(temporary.path)",
        source.path,
      ]
    )
    return try finalize(temporary: temporary, destination: destination)
  }

  private func convertArchive(
    executable: URL,
    source: URL,
    inputFormat: FileFormat,
    outputFormat: FileFormat,
    destination: URL
  ) async throws -> URL {
    let workspace = FileManager.default.temporaryDirectory
      .appendingPathComponent("huri-archive-\(UUID().uuidString)", isDirectory: true)
    let extracted = workspace.appendingPathComponent("contents", isDirectory: true)
    try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workspace) }

    try await extractArchive(
      executable: executable,
      source: source,
      format: inputFormat,
      directory: extracted
    )
    try validateExtractedArchive(root: extracted)

    let temporary = workspace.appendingPathComponent("output")
      .appendingPathExtension(outputFormat.preferredExtension)
    try await createArchive(
      executable: executable,
      directory: extracted,
      format: outputFormat,
      destination: temporary
    )
    return try finalize(temporary: temporary, destination: destination)
  }

  private func extractArchive(
    executable: URL,
    source: URL,
    format: FileFormat,
    directory: URL
  ) async throws {
    try await preflightArchive(
      executable: executable,
      source: source,
      format: format
    )

    if format == .zip, FileManager.default.isExecutableFile(atPath: "/usr/bin/ditto") {
      _ = try await ProcessRunner.run(
        executable: URL(fileURLWithPath: "/usr/bin/ditto"),
        arguments: ["-x", "-k", source.path, directory.path]
      )
      return
    }
    if executable.lastPathComponent == "7z" || executable.lastPathComponent == "7zz" {
      _ = try await ProcessRunner.run(
        executable: executable,
        arguments: ["x", "-y", "-o\(directory.path)", source.path]
      )
      return
    }
    guard [.tar, .tarGzip, .tarBzip2, .tarXz].contains(format) else {
      throw ConversionError.unsupported(HuriL10n.text("error.archive.requires7zip"))
    }
    _ = try await ProcessRunner.run(
      executable: URL(fileURLWithPath: "/usr/bin/tar"),
      arguments: ["-xf", source.path, "-C", directory.path]
    )
  }

  private func createArchive(
    executable: URL,
    directory: URL,
    format: FileFormat,
    destination: URL
  ) async throws {
    if format == .zip, FileManager.default.isExecutableFile(atPath: "/usr/bin/zip") {
      _ = try await ProcessRunner.run(
        executable: URL(fileURLWithPath: "/usr/bin/zip"),
        arguments: ["-q", "-r", destination.path, "."],
        currentDirectory: directory
      )
      return
    }
    if executable.lastPathComponent == "7z" || executable.lastPathComponent == "7zz" {
      _ = try await ProcessRunner.run(
        executable: executable,
        arguments: ["a", "-y", destination.path, "."],
        currentDirectory: directory
      )
      return
    }
    let compressionFlag: String
    switch format {
    case .tar: compressionFlag = "-cf"
    case .tarGzip: compressionFlag = "-czf"
    case .tarBzip2: compressionFlag = "-cjf"
    case .tarXz: compressionFlag = "-cJf"
    default:
      throw ConversionError.unsupported(HuriL10n.text("error.archive.requires7zip"))
    }
    _ = try await ProcessRunner.run(
      executable: URL(fileURLWithPath: "/usr/bin/tar"),
      arguments: [compressionFlag, destination.path, "-C", directory.path, "."]
    )
  }

  private func preflightArchive(
    executable: URL,
    source: URL,
    format: FileFormat
  ) async throws {
    let listing: String
    let verboseListing: String

    if format == .zip,
      FileManager.default.isExecutableFile(atPath: "/usr/bin/unzip")
    {
      listing = try await ProcessRunner.run(
        executable: URL(fileURLWithPath: "/usr/bin/unzip"),
        arguments: ["-Z1", source.path]
      )
      verboseListing = try await ProcessRunner.run(
        executable: URL(fileURLWithPath: "/usr/bin/unzip"),
        arguments: ["-Z", "-l", source.path]
      )
    } else if [.tar, .tarGzip, .tarBzip2, .tarXz].contains(format) {
      listing = try await ProcessRunner.run(
        executable: URL(fileURLWithPath: "/usr/bin/tar"),
        arguments: ["-tf", source.path]
      )
      verboseListing = try await ProcessRunner.run(
        executable: URL(fileURLWithPath: "/usr/bin/tar"),
        arguments: ["-tvf", source.path]
      )
    } else if executable.lastPathComponent == "7z"
      || executable.lastPathComponent == "7zz"
    {
      let detailed = try await ProcessRunner.run(
        executable: executable,
        arguments: ["l", "-slt", source.path]
      )
      listing =
        detailed
        .components(separatedBy: "----------")
        .dropFirst()
        .joined(separator: "\n")
        .split(separator: "\n")
        .compactMap { line -> String? in
          let prefix = "Path = "
          guard line.hasPrefix(prefix) else { return nil }
          return String(line.dropFirst(prefix.count))
        }
        .joined(separator: "\n")
      verboseListing = detailed
    } else {
      throw ConversionError.unsupported(HuriL10n.text("error.archive.requires7zip"))
    }

    let entries = listing.split(whereSeparator: \.isNewline).map(String.init)
    guard entries.count <= 50_000 else {
      throw ConversionError.conversionFailed(HuriL10n.text("error.archive.bomb"))
    }
    for entry in entries {
      try validateArchiveEntryPath(entry)
    }

    let containsLink = verboseListing.split(whereSeparator: \.isNewline)
      .contains { line in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("l")
          || trimmed.hasPrefix("h")
          || trimmed.hasPrefix("Symbolic Link =")
      }
    if containsLink {
      throw ConversionError.conversionFailed(HuriL10n.text("error.archive.symlink"))
    }
  }

  private func validateArchiveEntryPath(_ entry: String) throws {
    let normalized = entry.replacingOccurrences(of: "\\", with: "/")
    let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
    let hasDrivePrefix =
      normalized.count >= 2
      && normalized.dropFirst().first == ":"
      && normalized.first?.isLetter == true
    guard
      !normalized.isEmpty,
      !normalized.hasPrefix("/"),
      !normalized.contains("\0"),
      !hasDrivePrefix,
      !components.contains("..")
    else {
      throw ConversionError.conversionFailed(HuriL10n.text("error.archive.unsafePath"))
    }
  }

  private func validateExtractedArchive(root: URL) throws {
    let rootPath = root.standardizedFileURL.path
    let keys: [URLResourceKey] = [.isSymbolicLinkKey, .fileSizeKey]
    guard
      let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: keys,
        options: []
      )
    else { return }

    var fileCount = 0
    var totalBytes: Int64 = 0
    for case let url as URL in enumerator {
      let standardized = url.standardizedFileURL.path
      guard standardized == rootPath || standardized.hasPrefix(rootPath + "/") else {
        throw ConversionError.conversionFailed(HuriL10n.text("error.archive.unsafePath"))
      }
      let values = try url.resourceValues(forKeys: Set(keys))
      if values.isSymbolicLink == true {
        throw ConversionError.conversionFailed(HuriL10n.text("error.archive.symlink"))
      }
      fileCount += 1
      totalBytes += Int64(values.fileSize ?? 0)
      if fileCount > 50_000 || totalBytes > 20_000_000_000 {
        throw ConversionError.conversionFailed(HuriL10n.text("error.archive.bomb"))
      }
    }
  }

  private func temporaryOutput(for destination: URL) throws -> URL {
    try InfrastructureSupport.prepareDestination(destination)
    return destination.deletingLastPathComponent()
      .appendingPathComponent(".huri-\(UUID().uuidString)")
      .appendingPathExtension(destination.pathExtension)
  }

  private func finalize(temporary: URL, destination: URL) throws -> URL {
    let fileSize =
      (try? temporary.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
    guard
      FileManager.default.fileExists(atPath: temporary.path),
      fileSize > 0
    else {
      throw ConversionError.conversionFailed(
        HuriL10n.format(
          "error.tool.noOutput",
          arguments: destination.lastPathComponent
        )
      )
    }
    try InfrastructureSupport.prepareDestination(destination)
    do {
      try FileManager.default.moveItem(at: temporary, to: destination)
    } catch {
      throw ConversionError.conversionFailed(
        HuriL10n.format(
          "error.media.finalize",
          arguments: destination.lastPathComponent, error.localizedDescription
        )
      )
    }
    return destination
  }
}

enum CommandLocator {
  static func find(names: [String], additionalPaths: [String]) -> URL? {
    var candidates = additionalPaths
    let environmentPaths =
      ProcessInfo.processInfo.environment["PATH"]?
      .split(separator: ":")
      .map(String.init) ?? []
    for directory in environmentPaths {
      candidates.append(
        contentsOf: names.map {
          URL(fileURLWithPath: directory).appendingPathComponent($0).path
        }
      )
    }
    candidates.append(
      contentsOf: names.flatMap { name in
        [
          "/opt/homebrew/bin/\(name)",
          "/usr/local/bin/\(name)",
          "/usr/bin/\(name)",
        ]
      }
    )
    return
      candidates
      .map(URL.init(fileURLWithPath:))
      .first { FileManager.default.isExecutableFile(atPath: $0.path) }
  }
}

enum ProcessRunner {
  static func run(
    executable: URL,
    arguments: [String],
    currentDirectory: URL? = nil
  ) async throws -> String {
    try Task.checkCancellation()
    let processBox = CancellableProcessBox()
    let result = try await withTaskCancellationHandler {
      try await Task.detached(priority: .userInitiated) {
        let captureDirectory = FileManager.default.temporaryDirectory
          .appendingPathComponent("huri-process-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
          at: captureDirectory,
          withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: captureDirectory) }

        let outputURL = captureDirectory.appendingPathComponent("stdout")
        let errorURL = captureDirectory.appendingPathComponent("stderr")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        defer {
          try? outputHandle.close()
          try? errorHandle.close()
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        process.standardOutput = outputHandle
        process.standardError = errorHandle
        processBox.install(process)
        do {
          try process.run()
        } catch {
          throw ConversionError.conversionFailed(
            HuriL10n.format(
              "error.tool.start",
              arguments: executable.lastPathComponent, error.localizedDescription
            )
          )
        }
        process.waitUntilExit()
        try outputHandle.close()
        try errorHandle.close()
        let outputData = try Data(contentsOf: outputURL)
        let errorData = try Data(contentsOf: errorURL)
        let standardOutput = String(data: outputData, encoding: .utf8) ?? ""
        let standardError = String(data: errorData, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
          if processBox.wasCancelled {
            throw ConversionError.cancelled
          }
          let diagnostic = standardError.trimmingCharacters(in: .whitespacesAndNewlines)
          throw ConversionError.conversionFailed(
            diagnostic.isEmpty
              ? HuriL10n.format(
                "error.tool.exit",
                arguments: executable.lastPathComponent, process.terminationStatus
              )
              : diagnostic
          )
        }
        return standardOutput
      }.value
    } onCancel: {
      processBox.cancel()
    }
    try Task.checkCancellation()
    return result
  }
}

private final class CancellableProcessBox: @unchecked Sendable {
  private let lock = NSLock()
  private var process: Process?
  private var cancelled = false

  var wasCancelled: Bool {
    lock.withLock { cancelled }
  }

  func install(_ process: Process) {
    let shouldCancel = lock.withLock {
      self.process = process
      return cancelled
    }
    if shouldCancel, process.isRunning {
      process.terminate()
    }
  }

  func cancel() {
    let process = lock.withLock {
      cancelled = true
      return self.process
    }
    if process?.isRunning == true {
      process?.terminate()
    }
  }
}
