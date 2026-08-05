import Foundation

public enum ConversionBackend: String, CaseIterable, Codable, Sendable {
  case native
  case imageMagick
  case ffmpeg
  case libreOffice
  case pandoc
  case calibre
  case archive
  case fontForge
  case inkscape

  public var displayName: String {
    switch self {
    case .native: "Huri Native"
    case .imageMagick: "ImageMagick"
    case .ffmpeg: "FFmpeg"
    case .libreOffice: "LibreOffice"
    case .pandoc: "Pandoc"
    case .calibre: "Calibre"
    case .archive: "7-Zip / outils macOS"
    case .fontForge: "FontForge"
    case .inkscape: "Inkscape"
    }
  }
}

public struct CapabilityContext: Sendable {
  public var wordConversionAvailable: Bool
  public var enabledImageOutputs: Set<FileFormat>
  public var availableBackends: Set<ConversionBackend>

  public init(
    wordConversionAvailable: Bool = false,
    enabledImageOutputs: Set<FileFormat> = Set(FileFormat.nativeImageOutputs),
    availableBackends: Set<ConversionBackend> = [.native]
  ) {
    self.wordConversionAvailable = wordConversionAvailable
    self.enabledImageOutputs = enabledImageOutputs
    self.availableBackends = availableBackends.union([.native])
    if wordConversionAvailable {
      self.availableBackends.insert(.libreOffice)
    }
  }
}

public struct CapabilityRegistry: Sendable {
  public init() {}

  public func outputs(for input: FileFormat, context: CapabilityContext = .init()) -> [FileFormat] {
    guard input != .unknown, input.access.canRead else { return [] }

    var outputs = nativeOutputs(for: input, context: context)
    let backends = context.availableBackends

    if backends.contains(.imageMagick), [.image, .vector].contains(input.family) {
      outputs.formUnion(writableFormats(in: [.image, .vector]))
      outputs.insert(.pdf)
    }

    if backends.contains(.ffmpeg) {
      if input.family == .audio {
        outputs.formUnion(ffmpegAudioFormats)
      } else if input.family == .video {
        outputs.formUnion(ffmpegAudioFormats)
        outputs.formUnion(ffmpegVideoFormats)
      }
    }

    if backends.contains(.libreOffice),
      libreOfficeReadableFormats.contains(input)
    {
      outputs.formUnion(libreOfficeOutputs(for: input))
      outputs.insert(.pdf)
    }

    if backends.contains(.pandoc),
      [.document, .ebook, .text].contains(input.family)
    {
      outputs.formUnion(pandocFormats)
    }

    if backends.contains(.calibre),
      [.document, .ebook, .text].contains(input.family)
    {
      outputs.formUnion(writableFormats(in: [.ebook]))
    }

    if backends.contains(.archive), input.family == .archive {
      outputs.formUnion(systemArchiveFormats)
    }

    if backends.contains(.fontForge), input.family == .font {
      outputs.formUnion(writableFormats(in: [.font]))
    }

    if backends.contains(.inkscape), input.family == .vector {
      outputs.formUnion(writableFormats(in: [.vector]))
      outputs.formUnion(context.enabledImageOutputs)
      outputs.insert(.pdf)
    }

    outputs.remove(input)
    outputs.remove(.unknown)
    return ordered(outputs)
  }

  public func commonOutputs(
    for inputs: [FileFormat],
    context: CapabilityContext = .init()
  ) -> [FileFormat] {
    guard let first = inputs.first else { return [] }
    let common = inputs.dropFirst().reduce(Set(outputs(for: first, context: context))) {
      $0.intersection(outputs(for: $1, context: context))
    }
    return ordered(common)
  }

  public func supports(
    input: FileFormat,
    output: FileFormat,
    context: CapabilityContext = .init()
  ) -> Bool {
    outputs(for: input, context: context).contains(output)
  }

  public func availableFormats(context: CapabilityContext = .init()) -> Set<FileFormat> {
    var available = Set(FileFormat.nativeImageOutputs).union([.pdf, .txt, .markdown, .rtf])
    for descriptor in FormatCatalog.entries {
      let formatOutputs = outputs(for: descriptor.format, context: context)
      if !formatOutputs.isEmpty {
        available.insert(descriptor.format)
        available.formUnion(formatOutputs)
      }
    }
    return available
  }

  private func nativeOutputs(
    for input: FileFormat,
    context: CapabilityContext
  ) -> Set<FileFormat> {
    switch input.family {
    case .image:
      guard FileFormat.nativeImageOutputs.contains(input) else { return [] }
      return context.enabledImageOutputs.subtracting([input]).union([.pdf])
    case .pdf:
      return context.enabledImageOutputs
    case .document:
      guard input == .rtf else { return [] }
      return context.enabledImageOutputs.union([.pdf])
    case .text:
      guard [.txt, .markdown].contains(input) else { return [] }
      return context.enabledImageOutputs.union([.pdf])
    case .audio:
      guard [.mp3, .m4a, .wav, .aiff].contains(input) else { return [] }
      return Set([FileFormat.m4a, .wav, .aiff]).subtracting([input])
    case .video:
      guard [.mp4, .mov, .m4v].contains(input) else { return [] }
      return Set([FileFormat.mp4, .mov, .m4v, .m4a]).subtracting([input])
    case .archive, .cad, .ebook, .font, .presentation, .vector, .unsupported:
      return []
    }
  }

  private func writableFormats(in families: Set<FileFamily>) -> Set<FileFormat> {
    Set(
      FormatCatalog.entries
        .filter { families.contains($0.format.family) && $0.access.canWrite }
        .map(\.format)
    )
  }

  private var pandocFormats: Set<FileFormat> {
    [
      .docx, .odt, .rtf, .txt, .markdown, .html, .epub,
      FileFormat("dbk"),
    ]
  }

  private var libreOfficeReadableFormats: Set<FileFormat> {
    libreOfficeWordFormats
      .union(libreOfficeSpreadsheetFormats)
      .union(libreOfficePresentationFormats)
  }

  private func libreOfficeOutputs(for input: FileFormat) -> Set<FileFormat> {
    if libreOfficeSpreadsheetFormats.contains(input) {
      return libreOfficeSpreadsheetFormats
    }
    if libreOfficePresentationFormats.contains(input) {
      return libreOfficePresentationFormats
    }
    return libreOfficeWordFormats
  }

  private var libreOfficeWordFormats: Set<FileFormat> {
    [
      .doc, .docx, .odt, .rtf, .txt, .html,
      FileFormat("abw"), FileFormat("docm"), FileFormat("dot"),
      FileFormat("dotm"), FileFormat("dotx"), FileFormat("sxw"),
      FileFormat("wps"),
    ]
  }

  private var libreOfficeSpreadsheetFormats: Set<FileFormat> {
    [.csv, FileFormat("xls"), FileFormat("xlsx")]
  }

  private var libreOfficePresentationFormats: Set<FileFormat> {
    [
      FileFormat("odp"), FileFormat("pot"), FileFormat("potm"),
      FileFormat("potx"), FileFormat("pps"), FileFormat("ppsm"),
      FileFormat("ppsx"), FileFormat("ppt"), FileFormat("pptm"),
      FileFormat("pptx"),
    ]
  }

  private var ffmpegAudioFormats: Set<FileFormat> {
    [
      .mp3, .m4a, .wav, .aiff, .flac, .ogg, .opus,
      FileFormat("aac"), FileFormat("ac3"), FileFormat("au"),
      FileFormat("caf"), FileFormat("m4r"), FileFormat("mp2"),
      FileFormat("oga"), FileFormat("w64"), FileFormat("wma"),
    ]
  }

  private var ffmpegVideoFormats: Set<FileFormat> {
    [
      .mp4, .mov, .m4v, .webm, .mkv, .avi, .mpeg,
      FileFormat("3g2"), FileFormat("3gp"), FileFormat("asf"),
      FileFormat("f4v"), FileFormat("flv"), FileFormat("m2ts"),
      FileFormat("mxf"), FileFormat("ogv"), FileFormat("ts"),
      FileFormat("vob"), FileFormat("wmv"),
    ]
  }

  private var systemArchiveFormats: Set<FileFormat> {
    [.zip, .tar, .tarGzip, .tarBzip2, .tarXz]
  }

  private func ordered(_ formats: Set<FileFormat>) -> [FileFormat] {
    let preference: [FileFormat] = [
      .pdf, .png, .jpeg, .webp, .avif, .heic, .tiff, .gif, .bmp, .svg,
      .docx, .odt, .rtf, .txt, .markdown, .html, .epub,
      .mp3, .m4a, .wav, .aiff, .flac, .ogg, .opus,
      .mp4, .mov, .m4v, .webm, .mkv, .avi, .mpeg,
      .zip, .sevenZip, .tar, .tarGzip, .tarBzip2, .tarXz,
    ]
    let ranks = Dictionary(uniqueKeysWithValues: preference.enumerated().map { ($1, $0) })
    return formats.sorted { lhs, rhs in
      let lhsRank = ranks[lhs] ?? Int.max
      let rhsRank = ranks[rhs] ?? Int.max
      if lhsRank != rhsRank { return lhsRank < rhsRank }
      if lhs.family != rhs.family {
        return (FileFamily.allCases.firstIndex(of: lhs.family) ?? .max)
          < (FileFamily.allCases.firstIndex(of: rhs.family) ?? .max)
      }
      return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
    }
  }
}
