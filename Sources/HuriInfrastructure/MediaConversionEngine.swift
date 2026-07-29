@preconcurrency import AVFoundation
import Foundation
import HuriCore

struct MediaConversionEngine: Sendable {
  func convert(
    source: URL,
    sourceFamily: FileFamily,
    format: FileFormat,
    destination: URL
  ) async throws -> URL {
    if sourceFamily == .audio, format == .wav || format == .aiff {
      return try convertPCM(
        source: source,
        format: format,
        destination: destination
      )
    }
    let outputType = try fileType(for: format)
    let asset = AVURLAsset(url: source)
    let preset: String
    if format == .m4a {
      preset = AVAssetExportPresetAppleM4A
    } else if sourceFamily == .video {
      preset = AVAssetExportPresetHighestQuality
    } else {
      preset = AVAssetExportPresetPassthrough
    }
    guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
      throw ConversionError.unsupported(
        HuriL10n.text("error.media.prepare")
      )
    }
    guard session.supportedFileTypes.contains(outputType) else {
      throw ConversionError.unsupported(
        HuriL10n.text("error.media.combination")
      )
    }

    try InfrastructureSupport.prepareDestination(destination)
    let temporaryURL = destination.deletingLastPathComponent()
      .appendingPathComponent(".huri-media-\(UUID().uuidString)")
      .appendingPathExtension(format.preferredExtension)
    defer { try? FileManager.default.removeItem(at: temporaryURL) }
    session.outputURL = temporaryURL
    session.outputFileType = outputType
    session.shouldOptimizeForNetworkUse = sourceFamily == .video

    await withCheckedContinuation { continuation in
      session.exportAsynchronously {
        continuation.resume()
      }
    }
    try Task.checkCancellation()
    guard session.status == .completed else {
      if session.status == .cancelled {
        throw ConversionError.cancelled
      }
      throw ConversionError.conversionFailed(
        session.error?.localizedDescription
          ?? HuriL10n.text("error.media.conversion")
      )
    }
    do {
      try FileManager.default.moveItem(at: temporaryURL, to: destination)
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

  private func convertPCM(
    source: URL,
    format: FileFormat,
    destination: URL
  ) throws -> URL {
    try InfrastructureSupport.prepareDestination(destination)
    let temporaryURL = destination.deletingLastPathComponent()
      .appendingPathComponent(".huri-audio-\(UUID().uuidString)")
      .appendingPathExtension(format.preferredExtension)
    defer { try? FileManager.default.removeItem(at: temporaryURL) }

    do {
      try writePCM(source: source, format: format, temporaryURL: temporaryURL)
    } catch is CancellationError {
      throw ConversionError.cancelled
    } catch {
      throw ConversionError.conversionFailed(
        HuriL10n.format(
          "error.media.pcm",
          arguments: error.localizedDescription
        )
      )
    }
    do {
      try FileManager.default.moveItem(at: temporaryURL, to: destination)
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

  private func writePCM(
    source: URL,
    format: FileFormat,
    temporaryURL: URL
  ) throws {
    let input = try AVAudioFile(forReading: source)
    let processingFormat = input.processingFormat
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: processingFormat.sampleRate,
      AVNumberOfChannelsKey: processingFormat.channelCount,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: format == .aiff,
      AVLinearPCMIsNonInterleaved: false,
    ]
    let output = try AVAudioFile(
      forWriting: temporaryURL,
      settings: settings,
      commonFormat: processingFormat.commonFormat,
      interleaved: processingFormat.isInterleaved
    )
    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: processingFormat,
        frameCapacity: 32_768
      )
    else {
      throw ConversionError.conversionFailed(HuriL10n.text("error.media.buffer"))
    }

    while input.framePosition < input.length {
      try Task.checkCancellation()
      let remaining = input.length - input.framePosition
      let count = AVAudioFrameCount(min(Int64(buffer.frameCapacity), remaining))
      try input.read(into: buffer, frameCount: count)
      guard buffer.frameLength > 0 else { break }
      try output.write(from: buffer)
    }
  }

  private func fileType(for format: FileFormat) throws -> AVFileType {
    switch format {
    case .m4a: .m4a
    case .wav: .wav
    case .aiff: .aiff
    case .mp4: .mp4
    case .mov: .mov
    case .m4v: .m4v
    default:
      throw ConversionError.unsupported(
        HuriL10n.format(
          "error.media.formatUnavailable",
          arguments: format.displayName
        )
      )
    }
  }
}
