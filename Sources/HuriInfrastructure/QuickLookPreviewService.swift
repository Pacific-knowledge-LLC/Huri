import Foundation
import HuriCore
import ImageIO
import QuickLookThumbnailing
import UniformTypeIdentifiers

public final class QuickLookPreviewService: FilePreviewGenerating, @unchecked Sendable {
  public init() {}

  public func previewData(
    for asset: FileAsset,
    maximumPixelSize: Int
  ) async throws -> Data {
    let pixelSize = min(max(maximumPixelSize, 64), 4_096)
    let request = QLThumbnailGenerator.Request(
      fileAt: asset.sourceURL,
      size: CGSize(width: pixelSize, height: pixelSize),
      scale: 1,
      representationTypes: [.thumbnail, .lowQualityThumbnail]
    )

    let representation: QLThumbnailRepresentation
    do {
      representation = try await QLThumbnailGenerator.shared
        .generateBestRepresentation(for: request)
    } catch {
      throw ConversionError.conversionFailed(
        HuriL10n.format(
          "error.preview.quickLook",
          arguments: asset.filename, error.localizedDescription
        )
      )
    }

    let data = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        data,
        UTType.png.identifier as CFString,
        1,
        nil
      )
    else {
      throw ConversionError.conversionFailed(HuriL10n.text("error.preview.create"))
    }
    CGImageDestinationAddImage(destination, representation.cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw ConversionError.conversionFailed(HuriL10n.text("error.preview.finalize"))
    }
    return data as Data
  }
}
