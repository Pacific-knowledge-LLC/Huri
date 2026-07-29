import CoreGraphics
import Foundation
import HuriCore
import ImageIO
import UniformTypeIdentifiers
import WebP

public struct ImageEngine: Sendable {
  public init() {}

  public static var supportedOutputFormats: Set<FileFormat> {
    let identifiers = Set(
      (CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? []
    )
    var formats: Set<FileFormat> = [.webp]
    let candidates: [(FileFormat, UTType)] = [
      (.png, .png),
      (.jpeg, .jpeg),
      (.tiff, .tiff),
      (.heic, .heic),
      (.gif, .gif),
      (.bmp, .bmp),
    ]
    for (format, type) in candidates where identifiers.contains(type.identifier) {
      formats.insert(format)
    }
    return formats
  }

  @discardableResult
  public func convert(
    source: URL,
    to format: FileFormat,
    destination: URL,
    options: ConversionOptions = .init()
  ) throws -> URL {
    guard format.family == .image else {
      throw ConversionError.unsupported(
        HuriL10n.format(
          "error.image.notFormat",
          arguments: format.displayName
        )
      )
    }
    let image = try loadImage(from: source, scale: options.scale)
    try write(
      image,
      sourceURL: source,
      format: format,
      destination: destination,
      quality: options.quality,
      preserveMetadata: options.preserveMetadata
    )
    return destination
  }

  func loadImage(from url: URL, scale: Double = 1) throws -> CGImage {
    if FileFormat.from(filenameExtension: url.pathExtension) == .webp {
      do {
        var decoderOptions = WebPDecoderOptions()
        decoderOptions.useThreads = true
        let decoded = try WebPDecoder().decodeCGImage(
          from: Data(contentsOf: url),
          options: decoderOptions
        )
        return try scaledImage(decoded, scale: scale)
      } catch {
        throw ConversionError.unreadable(
          HuriL10n.format(
            "error.image.decodeWebP",
            arguments: url.lastPathComponent, error.localizedDescription
          )
        )
      }
    }

    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(
        source,
        0,
        [kCGImageSourceShouldCache: false] as CFDictionary
      )
    else {
      throw ConversionError.unreadable(
        HuriL10n.format(
          "error.image.decode",
          arguments: url.lastPathComponent
        )
      )
    }
    return try scaledImage(image, scale: scale)
  }

  func write(
    _ image: CGImage,
    sourceURL: URL? = nil,
    format: FileFormat,
    destination: URL,
    quality: Double,
    preserveMetadata: Bool = false
  ) throws {
    guard format.family == .image else {
      throw ConversionError.unsupported(
        HuriL10n.text("error.image.outputUnsupported")
      )
    }

    if format == .webp {
      do {
        let rgbaImage = try normalizedRGBAImage(image)
        var config = WebPEncoderConfig.preset(
          .picture,
          quality: Float(InfrastructureSupport.clampedQuality(quality) * 100)
        )
        config.threadLevel = 1
        let data = try WebPEncoder().encode(rgbaImage, config: config)
        try InfrastructureSupport.writeAtomically(data, to: destination)
        return
      } catch let error as ConversionError {
        throw error
      } catch {
        throw ConversionError.conversionFailed(
          HuriL10n.format(
            "error.image.webpEncode",
            arguments: error.localizedDescription
          )
        )
      }
    }

    guard let type = destinationType(for: format) else {
      throw ConversionError.unsupported(
        HuriL10n.format(
          "error.image.encodeUnavailable",
          arguments: format.displayName
        )
      )
    }
    let buffer = NSMutableData()
    guard
      let imageDestination = CGImageDestinationCreateWithData(
        buffer,
        type.identifier as CFString,
        1,
        nil
      )
    else {
      throw ConversionError.unsupported(
        HuriL10n.format(
          "error.image.imageIOCreate",
          arguments: format.displayName
        )
      )
    }

    var properties: [CFString: Any] = [:]
    if preserveMetadata,
      let sourceURL,
      let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let original = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    {
      properties = original
    }
    if format.isLossy {
      properties[kCGImageDestinationLossyCompressionQuality] =
        InfrastructureSupport.clampedQuality(quality)
    }
    CGImageDestinationAddImage(imageDestination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(imageDestination) else {
      throw ConversionError.conversionFailed(
        HuriL10n.format(
          "error.image.finalize",
          arguments: destination.lastPathComponent
        )
      )
    }
    try InfrastructureSupport.writeAtomically(buffer as Data, to: destination)
  }

  private func destinationType(for format: FileFormat) -> UTType? {
    switch format {
    case .png: .png
    case .jpeg: .jpeg
    case .tiff: .tiff
    case .heic: .heic
    case .gif: .gif
    case .bmp: .bmp
    default: nil
    }
  }

  private func scaledImage(_ image: CGImage, scale: Double) throws -> CGImage {
    let safeScale = min(max(scale, 0.1), 4)
    guard abs(safeScale - 1) > 0.001 else { return image }
    let width = max(Int((Double(image.width) * safeScale).rounded()), 1)
    let height = max(Int((Double(image.height) * safeScale).rounded()), 1)
    guard
      let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      throw ConversionError.conversionFailed(HuriL10n.text("error.image.resizeMemory"))
    }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let result = context.makeImage() else {
      throw ConversionError.conversionFailed(HuriL10n.text("error.image.resize"))
    }
    return result
  }

  private func normalizedRGBAImage(_ image: CGImage) throws -> CGImage {
    guard
      let context = CGContext(
        data: nil,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: image.width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
          | CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      throw ConversionError.conversionFailed(HuriL10n.text("error.image.prepareWebP"))
    }
    context.draw(
      image,
      in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    guard let result = context.makeImage() else {
      throw ConversionError.conversionFailed(HuriL10n.text("error.image.prepareWebP"))
    }
    return result
  }
}
