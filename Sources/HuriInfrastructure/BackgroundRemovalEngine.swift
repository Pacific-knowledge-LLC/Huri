import CoreImage
import Foundation
import HuriCore
import Vision

public protocol BackgroundRemoving: Sendable {
  @discardableResult
  func removeBackground(from source: URL, to destination: URL) async throws -> URL
}

public actor BackgroundRemovalEngine: BackgroundRemoving {
  private let imageEngine: ImageEngine

  public init(imageEngine: ImageEngine = .init()) {
    self.imageEngine = imageEngine
  }

  @discardableResult
  public func removeBackground(
    from source: URL,
    to destination: URL
  ) async throws -> URL {
    try Task.checkCancellation()
    let image = try imageEngine.loadImage(from: source)
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: image, options: [:])

    do {
      try handler.perform([request])
    } catch {
      throw ConversionError.conversionFailed(
        HuriL10n.format(
          "error.background.detection",
          arguments: error.localizedDescription
        )
      )
    }
    guard let observation = request.results?.first else {
      throw ConversionError.conversionFailed(
        HuriL10n.text("error.background.noForeground")
      )
    }

    let maskBuffer: CVPixelBuffer
    do {
      maskBuffer = try observation.generateScaledMaskForImage(
        forInstances: observation.allInstances,
        from: handler
      )
    } catch {
      throw ConversionError.conversionFailed(
        HuriL10n.format(
          "error.background.mask",
          arguments: error.localizedDescription
        )
      )
    }

    let sourceImage = CIImage(cgImage: image)
    let maskImage = CIImage(cvPixelBuffer: maskBuffer)
    let transparent = CIImage(
      color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)
    ).cropped(to: sourceImage.extent)
    guard let filter = CIFilter(name: "CIBlendWithMask") else {
      throw ConversionError.conversionFailed(HuriL10n.text("error.background.filter"))
    }
    filter.setValue(sourceImage, forKey: kCIInputImageKey)
    filter.setValue(transparent, forKey: kCIInputBackgroundImageKey)
    filter.setValue(maskImage, forKey: kCIInputMaskImageKey)
    guard let output = filter.outputImage,
      let result = CIContext(options: [.useSoftwareRenderer: false]).createCGImage(
        output,
        from: sourceImage.extent
      )
    else {
      throw ConversionError.conversionFailed(HuriL10n.text("error.background.render"))
    }

    try imageEngine.write(
      result,
      format: .png,
      destination: destination,
      quality: 1
    )
    return destination
  }
}
