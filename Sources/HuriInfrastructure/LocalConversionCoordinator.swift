import Foundation
import HuriCore

public actor LocalConversionCoordinator: ConversionExecuting {
  private let inspector: LocalFileInspector
  private let imageEngine: ImageEngine
  private let backgroundRemovalEngine: any BackgroundRemoving
  private let pdfEngine: PDFEngine
  private let documentProvider: LibreOfficeProvider
  private let toolchainEngine: LocalToolchainConversionEngine
  private let capabilityContext: CapabilityContext
  private let textEngine = TextDocumentEngine()
  private let mediaEngine = MediaConversionEngine()
  private let capabilities = CapabilityRegistry()

  public init(
    inspector: LocalFileInspector = .init(),
    imageEngine: ImageEngine = .init(),
    backgroundRemovalEngine: any BackgroundRemoving = BackgroundRemovalEngine(),
    pdfEngine: PDFEngine = .init(),
    documentProvider: LibreOfficeProvider = .init(),
    toolchain: LocalToolchain = .init()
  ) {
    self.inspector = inspector
    self.imageEngine = imageEngine
    self.backgroundRemovalEngine = backgroundRemovalEngine
    self.pdfEngine = pdfEngine
    self.documentProvider = documentProvider
    self.toolchainEngine = LocalToolchainConversionEngine(toolchain: toolchain)
    var backends = toolchain.availableBackends
    if documentProvider.isAvailable {
      backends.insert(.libreOffice)
    }
    self.capabilityContext = CapabilityContext(
      wordConversionAvailable: documentProvider.isAvailable,
      enabledImageOutputs: ImageEngine.supportedOutputFormats,
      availableBackends: backends
    )
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

    for asset in plan.assets {
      guard
        capabilities.supports(
          input: asset.format,
          output: plan.outputFormat,
          context: capabilityContext
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

    if plan.outputFormat == .pdf,
      plan.assets.count > 1,
      plan.assets.allSatisfy({
        $0.family == .image && FileFormat.nativeImageOutputs.contains($0.format)
      })
    {
      let destination = InfrastructureSupport.uniqueDestination(
        in: plan.destinationDirectory,
        basename: HuriL10n.text("conversion.combinedFilename"),
        extension: FileFormat.pdf.preferredExtension
      )
      let output = try await pdfEngine.imagesToPDF(
        sources: plan.assets.map(\.sourceURL),
        destination: destination
      )
      progress(
        ConversionProgress(
          completedUnitCount: plan.assets.count,
          totalUnitCount: plan.assets.count,
          message: HuriL10n.text("conversion.progress.complete")
        )
      )
      let duration = ContinuousClock.now - startedAt
      return ConversionResult(
        artifacts: [OutputArtifact(url: output)],
        warnings: warnings,
        duration: Double(duration.components.seconds)
          + Double(duration.components.attoseconds) / 1_000_000_000_000_000_000
      )
    }

    let basenames = uniqueOutputBasenames(
      for: plan.assets,
      outputFormat: plan.outputFormat,
      directory: plan.destinationDirectory
    )
    let indexed = try await withThrowingTaskGroup(
      of: IndexedConversion.self,
      returning: [IndexedConversion].self
    ) { group in
      var nextIndex = 0
      var completed = 0

      func enqueue(_ index: Int) {
        let asset = plan.assets[index]
        let taskDirectory =
          temporaryDirectory
          .appendingPathComponent(asset.id.uuidString, isDirectory: true)
        group.addTask { [self] in
          let urls = try await convert(
            asset: asset,
            outputFormat: plan.outputFormat,
            outputBasename: basenames[index],
            destinationDirectory: plan.destinationDirectory,
            temporaryDirectory: taskDirectory,
            options: plan.options
          )
          return IndexedConversion(index: index, asset: asset, urls: urls)
        }
      }

      while nextIndex < min(2, plan.assets.count) {
        enqueue(nextIndex)
        nextIndex += 1
      }

      var results: [IndexedConversion] = []
      for try await result in group {
        results.append(result)
        completed += 1
        progress(
          ConversionProgress(
            completedUnitCount: completed,
            totalUnitCount: plan.assets.count,
            message: HuriL10n.format(
              "progress.fileComplete",
              arguments: result.asset.filename
            )
          )
        )
        if nextIndex < plan.assets.count {
          enqueue(nextIndex)
          nextIndex += 1
        }
      }
      return results.sorted { $0.index < $1.index }
    }

    for result in indexed {
      artifacts.append(
        contentsOf: result.urls.map {
          OutputArtifact(url: $0, sourceID: result.asset.id)
        }
      )
      if result.urls.count > 1 {
        warnings.append(
          HuriL10n.format(
            "warning.conversion.multiplePages",
            arguments: result.asset.filename, result.urls.count
          )
        )
      }
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
    outputBasename: String,
    destinationDirectory: URL,
    temporaryDirectory: URL,
    options: ConversionOptions
  ) async throws -> [URL] {
    switch asset.family {
    case .image:
      let isNativeInput = FileFormat.nativeImageOutputs.contains(asset.format)
      let isNativeOutput = ImageEngine.supportedOutputFormats.contains(outputFormat)
      if outputFormat == .pdf, isNativeInput {
        let destination = outputURL(
          for: asset,
          format: .pdf,
          basename: outputBasename,
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
        basename: outputBasename,
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
      if !isNativeInput || !isNativeOutput {
        return [
          try await toolchainEngine.convert(
            source: asset.sourceURL,
            inputFormat: asset.format,
            outputFormat: outputFormat,
            destination: destination,
            options: options
          )
        ]
      }
      let engine = imageEngine
      return [
        try await Task.detached(priority: .userInitiated) {
          try engine.convert(
            source: asset.sourceURL,
            to: outputFormat,
            destination: destination,
            options: options
          )
        }.value
      ]

    case .pdf:
      return try await renderPDFToImages(
        source: asset.sourceURL,
        outputFormat: outputFormat,
        outputBasename: outputBasename,
        destinationDirectory: destinationDirectory,
        temporaryDirectory: temporaryDirectory,
        options: options
      )

    case .text:
      if ![FileFormat.txt, .markdown].contains(asset.format)
        || !ImageEngine.supportedOutputFormats.union([.pdf]).contains(outputFormat)
      {
        return [
          try await externalConversion(
            asset: asset,
            outputFormat: outputFormat,
            outputBasename: outputBasename,
            destinationDirectory: destinationDirectory,
            options: options
          )
        ]
      }
      return try await convertTextLikeAsset(
        asset,
        outputFormat: outputFormat,
        outputBasename: outputBasename,
        destinationDirectory: destinationDirectory,
        temporaryDirectory: temporaryDirectory,
        options: options,
        useLibreOffice: false
      )

    case .document:
      if asset.format != .rtf
        || !ImageEngine.supportedOutputFormats.union([.pdf]).contains(outputFormat)
      {
        return [
          try await externalConversion(
            asset: asset,
            outputFormat: outputFormat,
            outputBasename: outputBasename,
            destinationDirectory: destinationDirectory,
            options: options
          )
        ]
      }
      return try await convertTextLikeAsset(
        asset,
        outputFormat: outputFormat,
        outputBasename: outputBasename,
        destinationDirectory: destinationDirectory,
        temporaryDirectory: temporaryDirectory,
        options: options,
        useLibreOffice: false
      )

    case .audio, .video:
      let destination = outputURL(
        for: asset,
        format: outputFormat,
        basename: outputBasename,
        directory: destinationDirectory
      )
      let nativeContext = CapabilityContext(
        enabledImageOutputs: ImageEngine.supportedOutputFormats,
        availableBackends: [.native]
      )
      if capabilityContext.availableBackends.contains(.ffmpeg)
        || !capabilities.supports(
          input: asset.format,
          output: outputFormat,
          context: nativeContext
        )
      {
        return [
          try await toolchainEngine.convert(
            source: asset.sourceURL,
            inputFormat: asset.format,
            outputFormat: outputFormat,
            destination: destination,
            options: options
          )
        ]
      }
      return [
        try await mediaEngine.convert(
          source: asset.sourceURL,
          sourceFamily: asset.family,
          format: outputFormat,
          destination: destination
        )
      ]

    case .archive, .cad, .ebook, .font, .presentation, .vector:
      return [
        try await externalConversion(
          asset: asset,
          outputFormat: outputFormat,
          outputBasename: outputBasename,
          destinationDirectory: destinationDirectory,
          options: options
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

  private func externalConversion(
    asset: FileAsset,
    outputFormat: FileFormat,
    outputBasename: String,
    destinationDirectory: URL,
    options: ConversionOptions
  ) async throws -> URL {
    let destination = outputURL(
      for: asset,
      format: outputFormat,
      basename: outputBasename,
      directory: destinationDirectory
    )
    return try await toolchainEngine.convert(
      source: asset.sourceURL,
      inputFormat: asset.format,
      outputFormat: outputFormat,
      destination: destination,
      options: options
    )
  }

  private func convertTextLikeAsset(
    _ asset: FileAsset,
    outputFormat: FileFormat,
    outputBasename: String,
    destinationDirectory: URL,
    temporaryDirectory: URL,
    options: ConversionOptions,
    useLibreOffice: Bool
  ) async throws -> [URL] {
    let finalPDF =
      outputFormat == .pdf
      ? outputURL(
        for: asset,
        format: .pdf,
        basename: outputBasename,
        directory: destinationDirectory
      )
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
      outputBasename: outputBasename,
      destinationDirectory: destinationDirectory,
      temporaryDirectory: temporaryDirectory,
      options: options
    )
  }

  private func renderPDFToImages(
    source: URL,
    outputFormat: FileFormat,
    outputBasename: String,
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
      options: options,
      outputBasename: outputBasename
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
    basename: String? = nil,
    directory: URL
  ) -> URL {
    InfrastructureSupport.uniqueDestination(
      in: directory,
      basename: basename ?? asset.sourceURL.deletingPathExtension().lastPathComponent,
      extension: format.preferredExtension
    )
  }

  private func uniqueOutputBasenames(
    for assets: [FileAsset],
    outputFormat: FileFormat,
    directory: URL
  ) -> [String] {
    var reserved: Set<String> = []
    return assets.map { asset in
      let basename = asset.sourceURL.deletingPathExtension().lastPathComponent
      var candidate = basename
      var suffix = 2
      while reserved.contains(candidate.lowercased())
        || FileManager.default.fileExists(
          atPath:
            directory
            .appendingPathComponent(candidate)
            .appendingPathExtension(outputFormat.preferredExtension)
            .path
        )
      {
        candidate = "\(basename)-\(suffix)"
        suffix += 1
      }
      reserved.insert(candidate.lowercased())
      return candidate
    }
  }
}

private struct IndexedConversion: Sendable {
  let index: Int
  let asset: FileAsset
  let urls: [URL]
}
