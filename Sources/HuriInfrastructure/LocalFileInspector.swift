@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import HuriCore
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import WebP

public final class LocalFileInspector: FileTypeDetecting, @unchecked Sendable {
  public init() {}

  public func inspect(url: URL) async throws -> FileAsset {
    guard url.isFileURL else {
      throw ConversionError.unreadable(HuriL10n.text("error.file.localOnly"))
    }
    guard FileManager.default.isReadableFile(atPath: url.path) else {
      throw ConversionError.unreadable(
        HuriL10n.format(
          "error.file.unreadable",
          arguments: url.lastPathComponent
        )
      )
    }

    let header = try readHeader(at: url)
    let magicFormat = Self.formatFromMagicBytes(header)
    let extensionFormat = Self.formatFromFilename(url.lastPathComponent)
    let typeFormat = formatFromContentType(url: url)
    let contentFormat: FileFormat?
    if magicFormat == .doc,
      [FileFormat("xls"), FileFormat("ppt"), .doc].contains(extensionFormat)
    {
      // Legacy Office files share the same OLE container signature. The
      // extension is the only cheap discriminator before LibreOffice probes it.
      contentFormat = extensionFormat
    } else {
      contentFormat = magicFormat
    }
    let resolved =
      contentFormat ?? typeFormat ?? (extensionFormat == .unknown ? nil : extensionFormat)
      ?? .unknown

    let warning: String?
    if let contentFormat, extensionFormat != .unknown, contentFormat != extensionFormat {
      warning = HuriL10n.format(
        "error.file.warningExtension",
        arguments: contentFormat.displayName, url.pathExtension
      )
    } else {
      warning = nil
    }

    let byteCount = fileByteCount(at: url)
    let metadata = try await metadata(
      for: url,
      format: resolved,
      byteCount: byteCount
    )

    return FileAsset(
      sourceURL: url,
      format: resolved,
      metadata: metadata,
      detectionWarning: warning
    )
  }

  public static func formatFromMagicBytes(_ data: Data) -> FileFormat? {
    let bytes = [UInt8](data.prefix(32))
    guard !bytes.isEmpty else { return nil }

    if bytes.starts(with: [0x25, 0x50, 0x44, 0x46, 0x2D]) { return .pdf }
    if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return .png }
    if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return .jpeg }
    if bytes.starts(with: Array("GIF87a".utf8)) || bytes.starts(with: Array("GIF89a".utf8)) {
      return .gif
    }
    if bytes.starts(with: [0x49, 0x49, 0x2A, 0x00])
      || bytes.starts(with: [0x4D, 0x4D, 0x00, 0x2A])
    {
      return .tiff
    }
    if bytes.starts(with: [0x42, 0x4D]) { return .bmp }
    if bytes.starts(with: Array("fLaC".utf8)) { return .flac }
    if bytes.starts(with: Array("OggS".utf8)) { return .ogg }
    if bytes.starts(with: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]) { return .sevenZip }
    if bytes.starts(with: [0x1F, 0x8B]) { return .tarGzip }
    if bytes.starts(with: Array("BZh".utf8)) { return .tarBzip2 }
    if bytes.starts(with: [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]) { return .tarXz }
    if bytes.starts(with: [0x7B, 0x5C, 0x72, 0x74, 0x66]) { return .rtf }
    if bytes.starts(with: [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]) { return .doc }
    if bytes.starts(with: Array("ID3".utf8)) { return .mp3 }
    if bytes.count >= 2, bytes[0] == 0xFF, bytes[1] & 0xE0 == 0xE0 { return .mp3 }

    if ascii(bytes, offset: 0, count: 4) == "RIFF" {
      switch ascii(bytes, offset: 8, count: 4) {
      case "WEBP": return .webp
      case "WAVE": return .wav
      case "AVI ": return .avi
      default: break
      }
    }
    if ascii(bytes, offset: 0, count: 4) == "FORM" {
      let formType = ascii(bytes, offset: 8, count: 4)
      if formType == "AIFF" || formType == "AIFC" { return .aiff }
    }

    if bytes.count >= 12, ascii(bytes, offset: 4, count: 4) == "ftyp" {
      let brand = ascii(bytes, offset: 8, count: 4).lowercased()
      if ["avif", "avis"].contains(brand) { return .avif }
      if ["heic", "heix", "hevc", "hevx", "heim", "heis", "mif1", "msf1"].contains(brand) {
        return .heic
      }
      if ["qt  "].contains(brand) { return .mov }
      if ["m4a ", "m4b ", "f4a "].contains(brand) { return .m4a }
      if ["m4v ", "m4vh", "m4vp"].contains(brand) { return .m4v }
      return .mp4
    }

    return nil
  }

  private static func formatFromFilename(_ filename: String) -> FileFormat {
    let lowercased = filename.lowercased()
    let compoundExtensions: [(String, FileFormat)] = [
      (".tar.gz", .tarGzip),
      (".tar.bz2", .tarBzip2),
      (".tar.bz", .tarBzip2),
      (".tar.xz", .tarXz),
    ]
    if let match = compoundExtensions.first(where: { lowercased.hasSuffix($0.0) }) {
      return match.1
    }
    return FileFormat.from(
      filenameExtension: URL(fileURLWithPath: filename).pathExtension
    )
  }

  private static func ascii(_ bytes: [UInt8], offset: Int, count: Int) -> String {
    guard bytes.count >= offset + count else { return "" }
    return String(decoding: bytes[offset..<offset + count], as: UTF8.self)
  }

  private func readHeader(at url: URL) throws -> Data {
    do {
      let handle = try FileHandle(forReadingFrom: url)
      defer { try? handle.close() }
      return try handle.read(upToCount: 64) ?? Data()
    } catch {
      throw ConversionError.unreadable(
        HuriL10n.format(
          "error.document.read",
          arguments: url.lastPathComponent, error.localizedDescription
        )
      )
    }
  }

  private func fileByteCount(at url: URL) -> Int64 {
    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
  }

  private func formatFromContentType(url: URL) -> FileFormat? {
    if let values = try? url.resourceValues(forKeys: [.contentTypeKey]),
      let contentType = values.contentType
    {
      return Self.format(from: contentType)
    }
    guard let type = UTType(filenameExtension: url.pathExtension) else { return nil }
    return Self.format(from: type)
  }

  private static func format(from type: UTType) -> FileFormat? {
    if ["net.daringfireball.markdown", "public.markdown"].contains(type.identifier) {
      return .markdown
    }
    if type.identifier == "com.apple.m4v-video" { return .m4v }
    if type.identifier == "org.openxmlformats.wordprocessingml.document" { return .docx }
    if type.identifier == "com.microsoft.word.doc" { return .doc }
    let mappings: [(UTType, FileFormat)] = [
      (.png, .png), (.jpeg, .jpeg), (.webP, .webp), (.tiff, .tiff),
      (.heic, .heic), (.gif, .gif), (.bmp, .bmp), (.pdf, .pdf),
      (.rtf, .rtf), (.plainText, .txt),
      (.mp3, .mp3), (.wav, .wav), (.aiff, .aiff),
      (.mpeg4Movie, .mp4), (.quickTimeMovie, .mov),
    ]
    if let exact = mappings.first(where: { type.conforms(to: $0.0) }) {
      return exact.1
    }
    if type.conforms(to: .image) {
      return FileFormat.from(filenameExtension: type.preferredFilenameExtension ?? "")
    }
    let inferred = FileFormat.from(
      filenameExtension: type.preferredFilenameExtension ?? ""
    )
    return inferred == .unknown ? nil : inferred
  }

  private func metadata(
    for url: URL,
    format: FileFormat,
    byteCount: Int64
  ) async throws -> AssetMetadata {
    switch format.family {
    case .image:
      if format == .webp, let feature = try? WebPImageInspector.inspect(try Data(contentsOf: url)) {
        return AssetMetadata(
          byteCount: byteCount,
          width: feature.width,
          height: feature.height
        )
      }
      guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
      else {
        return AssetMetadata(byteCount: byteCount)
      }
      return AssetMetadata(
        byteCount: byteCount,
        width: (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
        height: (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
      )
    case .pdf:
      return AssetMetadata(
        byteCount: byteCount,
        pageCount: PDFDocument(url: url)?.pageCount
      )
    case .audio, .video:
      let asset = AVURLAsset(url: url)
      let duration = try? await asset.load(.duration)
      let seconds = duration.flatMap { value -> TimeInterval? in
        let result = value.seconds
        return result.isFinite && result >= 0 ? result : nil
      }
      var width: Int?
      var height: Int?
      if format.family == .video,
        let track = try? await asset.loadTracks(withMediaType: .video).first
      {
        let size = try? await track.load(.naturalSize)
        width = size.map { Int(abs($0.width.rounded())) }
        height = size.map { Int(abs($0.height.rounded())) }
      }
      return AssetMetadata(
        byteCount: byteCount,
        width: width,
        height: height,
        duration: seconds
      )
    default:
      return AssetMetadata(byteCount: byteCount)
    }
  }
}
