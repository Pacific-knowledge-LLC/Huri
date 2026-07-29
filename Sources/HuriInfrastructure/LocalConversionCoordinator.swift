import Foundation
import HuriCore

public actor LocalConversionCoordinator: ConversionExecuting {
  private let inspector: LocalFileInspector
  private let imageEngine: ImageEngine
  private let backgroundRemovalEngine: any BackgroundRemoving
  private let pdfEngine: PDFEngine
  private let documentProvider: LibreOfficeProvider
  private let textEngine = TextDocumentEngine()
  private let mediaEngine = MediaConversionEngine()
  private let capabilities = CapabilityRegistry()

  public init(
    inspector: LocalFileInspector = .init(),
    imageEngine: ImageEngine = .init(),
    backgroundRemovalEngine: any BackgroundRemoving = BackgroundRemovalEngine(),
    pdfEngine: PDFEngine = .init(),
    documentProvider: LibreOfficeProvider = .init()
  ) {
    self.inspector = inspector
    self.imageEngine = imageEngine
    self.backgroundRemovalEngine = backgroundRemovalEngine
    self.pdfEngine = pdfEngine
    self.documentProvider = documentProvider
  }

  public func convert(
    plan: ConversionPlan,
    progress: @escaping @Sendable (ConversionProgress) -> Void
  ) async throws -> ConversionResult {
    guard !plan.assets.isEmpty else {
      throw ConversionError.invalidPlan(HuriL10n.text("error.conversion.empty"))
    }
    guard plan.destinationDirectory.isFileURL else {
      throw ConversionError.invalidPlan(
        HuriL10n.text("error.conversion.destination")
      )
    }
    guard plan.outputFormat != .unknown else {
      throw ConversionError.invalidPlan(HuriL10n.text("error.conversion.format"))
    }
    if plan.options.removeBackground, plan.outputFormat != .png {
      throw ConversionError.invalidPlan(
        HuriL10n.text("error.conversion.backgroundPNG")
      )
    }

    let context = CapabilityContext(
      wordConversionAvailable: documentProvider.isAvailable,
      enabledImageOutputs: ImageEngine.supportedOutputFormats
    )
    for asset in plan.assets {
      guard
        capabilities.supports(
          input: asset.format,
          output: plan.outputFormat,
          context: context
        )
      else {
        throw ConversionError.unsupported(
          HuriL10n.format(
            "error.conversion.unsupportedPair",
            arguments:
              asset.format.displayName,
            plan.outputFormat.displayName
          )
        )
      }
    }

    try FileManager.default.createDirectory(
      at: plan.destinationDirectory,
      withIntermediateDirectories: true
    )
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("huri-conversion-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: temporaryDirectory,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let startedAt = ContinuousClock.now
    var artifacts: [OutputArtifact] = []
    var warnings = plan.assets.compactMap(\.detectionWarning)
    progress(
      ConversionProgress(
        completedUnitCount: 0,
        totalUnitCount: plan.assets.count,
        message: HuriL10n.text("conversion.progress.preparing")
      )
    )

    for (index, asset) in plan.assets.enumerated() {
      try Task.checkCancellation()
      progress(
        ConversionProgress(
          completedUnitCount: index,
          totalUnitCount: plan.assets.count,
          message: HuriL10n.format(
            "progress.convertingFile",
            arguments: asset.filename
          )
        )
      )
      let converted = try await convert(
        asset: asset,
        outputFormat: plan.outputFormat,
        destinationDirectory: plan.destinationDirectory,
        temporaryDirectory: temporaryDirectory,
        options: plan.options
      )
      artifacts.append(
        contentsOf: converted.map {
          OutputArtifact(url: $0, sourceID: asset.id)
        }
      )
      if converted.count > 1 {
        warnings.append(
          HuriL10n.format(
            "warning.conversion.multiplePages",
            arguments: asset.filename, converted.count
          )
        )
      }
      progress(
        ConversionProgress(
          completedUnitCount: index + 1,
          totalUnitCount: plan.assets.count,
          message: HuriL10n.format(
            "progress.fileComplete",
            arguments: asset.filename
          )
        )
      )
      await Task.yield()
    }

    let duration = ContinuousClock.now - startedAt
    return ConversionResult(
      artifacts: artifacts,
      warnings: warnings,
      duration: Double(duration.components.seconds)
        + Double(duration.components.attoseconds) / 1_000_000_000_000_000_000
    )
  }

  private func convert(
    asset: FileAsset,
    outputFormat: FileFormat,
    destinationDirectory: URL,
    temporaryDirectory: URL,
    options: ConversionOptions
  ) async throws -> [URL] {
    switch asset.family {
    case .image:
      if outputFormat == .pdf {
        let destination = outputURL(
          for: asset,
          format: .pdf,
          directory: destinationDirectory
        )
        return [
          try await pdfEngine.imageToPDF(
            source: asset.sourceURL,
            destination: destination
          )
        ]
      }
      let destination = outputURL(
        for: asset,
        format: outputFormat,
        directory: destinationDirectory
      )
      if options.removeBackground {
        return [
          try await backgroundRemovalEngine.removeBackground(
            from: asset.sourceURL,
            to: destination
          )
        ]
      }
      return [
        try imageEngine.convert(
          source: asset.sourceURL,
          to: outputFormat,
          destination: destination,
          options: options
        )
      ]

    case .pdf:
      return try await renderPDFToImages(
        source: asset.sourceURL,
        outputFormat: outputFormat,
        destinationDirectory: destinationDirectory,
        temporaryDirectory: temporaryDirectory,
        options: options
      )

    case .text:
      return try await convertTextLikeAsset(
        asset,
        outputFormat: outputFormat,
        destinationDirectory: destinationDirectory,
        temporaryDirectory: temporaryDirectory,
        options: options,
        useLibreOffice: false
      )

    case .document:
      return try await convertTextLikeAsset(
        asset,
        outputFormat: outputFormat,
        destinationDirectory: destinationDirectory,
        temporaryDirectory: temporaryDirectory,
        options: options,
        useLibreOffice: asset.format != .rtf
      )

    case .audio, .video:
      let destination = outputURL(
        for: asset,
        format: outputFormat,
        directory: destinationDirectory
      )
      return [
        try await mediaEngine.convert(
          source: asset.sourceURL,
          sourceFamily: asset.family,
          format: outputFormat,
          destination: destination
        )
      ]

    case .unsupported:
      throw ConversionError.unsupported(
        HuriL10n.format(
          "error.conversion.typeUnknown",
          arguments: asset.filename
        )
      )
    }
  }

  private func convertTextLikeAsset(
    _ asset: FileAsset,
    outputFormat: FileFormat,
    destinationDirectory: URL,
    temporaryDirectory: URL,
    options: ConversionOptions,
    useLibreOffice: Bool
  ) async throws -> [URL] {
    let finalPDF =
      outputFormat == .pdf
      ? outputURL(for: asset, format: .pdf, directory: destinationDirectory)
      : temporaryDirectory
        .appendingPathComponent(asset.sourceURL.deletingPathExtension().lastPathComponent)
        .appendingPathExtension("pdf")

    if useLibreOffice {
      try documentProvider.convertToPDF(source: asset.sourceURL, destination: finalPDF)
    } else {
      _ = try textEngine.renderToPDF(
        source: asset.sourceURL,
        format: asset.format,
        destination: finalPDF
      )
    }
    if outputFormat == .pdf {
      return [finalPDF]
    }
    return try await renderPDFToImages(
      source: finalPDF,
      outputFormat: outputFormat,
      destinationDirectory: destinationDirectory,
      temporaryDirectory: temporaryDirectory,
      options: options
    )
  }

  private func renderPDFToImages(
    source: URL,
    outputFormat: FileFormat,
    destinationDirectory: URL,
    temporaryDirectory: URL,
    options: ConversionOptions
  ) async throws -> [URL] {
    let renderDirectory: URL
    if options.removeBackground {
      renderDirectory =
        temporaryDirectory
        .appendingPathComponent("raster-\(UUID().uuidString)", isDirectory: true)
    } else {
      renderDirectory = destinationDirectory
    }
    let rendered = try await pdfEngine.pdfToImages(
      source: source,
      format: outputFormat,
      directory: renderDirectory,
      options: options
    )
    guard options.removeBackground else { return rendered }

    var cutouts: [URL] = []
    for rasterURL in rendered {
      try Task.checkCancellation()
      let destination = InfrastructureSupport.uniqueDestination(
        in: destinationDirectory,
        basename: rasterURL.deletingPathExtension().lastPathComponent,
        extension: FileFormat.png.preferredExtension
      )
      cutouts.append(
        try await backgroundRemovalEngine.removeBackground(
          from: rasterURL,
          to: destination
        )
      )
    }
    return cutouts
  }

  private func outputURL(
    for asset: FileAsset,
    format: FileFormat,
    directory: URL
  ) -> URL {
    InfrastructureSupport.uniqueDestination(
      in: directory,
      basename: asset.sourceURL.deletingPathExtension().lastPathComponent,
      extension: format.preferredExtension
    )
  }
}
