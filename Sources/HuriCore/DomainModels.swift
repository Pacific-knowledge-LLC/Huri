import Foundation

public struct AssetMetadata: Hashable, Sendable {
  public var byteCount: Int64
  public var width: Int?
  public var height: Int?
  public var pageCount: Int?
  public var duration: TimeInterval?

  public init(
    byteCount: Int64 = 0,
    width: Int? = nil,
    height: Int? = nil,
    pageCount: Int? = nil,
    duration: TimeInterval? = nil
  ) {
    self.byteCount = byteCount
    self.width = width
    self.height = height
    self.pageCount = pageCount
    self.duration = duration
  }
}

public struct FileAsset: Identifiable, Hashable, Sendable {
  public let id: UUID
  public let sourceURL: URL
  public let format: FileFormat
  public let metadata: AssetMetadata
  public let detectionWarning: String?

  public init(
    id: UUID = UUID(),
    sourceURL: URL,
    format: FileFormat,
    metadata: AssetMetadata = .init(),
    detectionWarning: String? = nil
  ) {
    self.id = id
    self.sourceURL = sourceURL
    self.format = format
    self.metadata = metadata
    self.detectionWarning = detectionWarning
  }

  public var filename: String { sourceURL.lastPathComponent }
  public var family: FileFamily { format.family }
}

public struct ConversionOptions: Hashable, Sendable {
  public var quality: Double
  public var removeBackground: Bool
  public var preserveMetadata: Bool
  public var scale: Double
  public var pdfDPI: Int

  public init(
    quality: Double = 0.88,
    removeBackground: Bool = false,
    preserveMetadata: Bool = true,
    scale: Double = 1,
    pdfDPI: Int = 144
  ) {
    self.quality = min(max(quality, 0.1), 1)
    self.removeBackground = removeBackground
    self.preserveMetadata = preserveMetadata
    self.scale = min(max(scale, 0.1), 4)
    self.pdfDPI = min(max(pdfDPI, 72), 600)
  }
}

public struct ConversionPlan: Hashable, Sendable {
  public let assets: [FileAsset]
  public let outputFormat: FileFormat
  public let destinationDirectory: URL
  public let options: ConversionOptions

  public init(
    assets: [FileAsset],
    outputFormat: FileFormat,
    destinationDirectory: URL,
    options: ConversionOptions = .init()
  ) {
    self.assets = assets
    self.outputFormat = outputFormat
    self.destinationDirectory = destinationDirectory
    self.options = options
  }
}

public struct OutputArtifact: Identifiable, Hashable, Sendable {
  public let id: UUID
  public let url: URL
  public let sourceID: UUID?

  public init(id: UUID = UUID(), url: URL, sourceID: UUID? = nil) {
    self.id = id
    self.url = url
    self.sourceID = sourceID
  }
}

public struct ConversionResult: Sendable {
  public let artifacts: [OutputArtifact]
  public let warnings: [String]
  public let duration: TimeInterval

  public init(artifacts: [OutputArtifact], warnings: [String] = [], duration: TimeInterval) {
    self.artifacts = artifacts
    self.warnings = warnings
    self.duration = duration
  }
}

public enum ConversionError: LocalizedError, Sendable {
  case unsupported(String)
  case unreadable(String)
  case invalidPlan(String)
  case conversionFailed(String)
  case cancelled

  public var errorDescription: String? {
    switch self {
    case .unsupported(let message),
      .unreadable(let message),
      .invalidPlan(let message),
      .conversionFailed(let message):
      message
    case .cancelled:
      HuriL10n.text("error.conversion.cancelled")
    }
  }
}

public struct ConversionProgress: Sendable {
  public let completedUnitCount: Int
  public let totalUnitCount: Int
  public let message: String

  public init(completedUnitCount: Int, totalUnitCount: Int, message: String) {
    self.completedUnitCount = completedUnitCount
    self.totalUnitCount = max(totalUnitCount, 1)
    self.message = message
  }

  public var fraction: Double {
    min(max(Double(completedUnitCount) / Double(totalUnitCount), 0), 1)
  }
}
