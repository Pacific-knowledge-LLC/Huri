import CoreGraphics
import Foundation
import HuriCore
import ImageIO
import XCTest

@testable import HuriInfrastructure

@MainActor
final class HuriInfrastructureTests: XCTestCase {
  func testDefaultStatusAndServiceAssemblyAreReady() {
    XCTAssertTrue(HuriInfrastructureStatus().isReady)
    let services = HuriServices()
    XCTAssertTrue(
      services.capabilities.supports(
        input: .png,
        output: .webp,
        context: services.capabilityContext
      )
    )
  }

  func testInspectorUsesMagicBytesBeforeMisleadingExtension() async throws {
    let temporaryDirectory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let misleadingURL = temporaryDirectory.appendingPathComponent("actually-png.jpg")
    try makePNG(width: 37, height: 23).write(to: misleadingURL, options: .atomic)

    let asset = try await LocalFileInspector().inspect(url: misleadingURL)

    XCTAssertEqual(asset.format, .png)
    XCTAssertEqual(asset.metadata.width, 37)
    XCTAssertEqual(asset.metadata.height, 23)
    XCTAssertGreaterThan(asset.metadata.byteCount, 0)
    XCTAssertNotNil(asset.detectionWarning)
  }

  func testMagicByteDetectionCoversCommonFamilies() {
    XCTAssertEqual(LocalFileInspector.formatFromMagicBytes(Data("%PDF-1.7".utf8)), .pdf)
    XCTAssertEqual(
      LocalFileInspector.formatFromMagicBytes(
        Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00])
      ),
      .jpeg
    )
    XCTAssertEqual(
      LocalFileInspector.formatFromMagicBytes(Data("RIFF1234WEBP".utf8)),
      .webp
    )
    XCTAssertEqual(
      LocalFileInspector.formatFromMagicBytes(Data("RIFF1234WAVE".utf8)),
      .wav
    )
    XCTAssertNil(LocalFileInspector.formatFromMagicBytes(Data([0x01, 0x02, 0x03])))
  }

  func testImageEngineRoundTripsJPEGAndWebP() async throws {
    let temporaryDirectory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let source = temporaryDirectory.appendingPathComponent("source.png")
    try makePNG(width: 48, height: 32).write(to: source, options: .atomic)
    let engine = ImageEngine()

    let jpeg = temporaryDirectory.appendingPathComponent("converted.jpg")
    try engine.convert(
      source: source,
      to: .jpeg,
      destination: jpeg,
      options: ConversionOptions(quality: 0.8)
    )
    let jpegAsset = try await LocalFileInspector().inspect(url: jpeg)
    XCTAssertEqual(jpegAsset.format, .jpeg)
    XCTAssertEqual(jpegAsset.metadata.width, 48)
    XCTAssertEqual(jpegAsset.metadata.height, 32)

    let webp = temporaryDirectory.appendingPathComponent("converted.webp")
    try engine.convert(source: source, to: .webp, destination: webp)
    let webPAsset = try await LocalFileInspector().inspect(url: webp)
    XCTAssertEqual(webPAsset.format, .webp)
    XCTAssertEqual(webPAsset.metadata.width, 48)
    XCTAssertEqual(webPAsset.metadata.height, 32)

    let roundTrip = temporaryDirectory.appendingPathComponent("roundtrip.png")
    try engine.convert(source: webp, to: .png, destination: roundTrip)
    XCTAssertTrue(FileManager.default.fileExists(atPath: roundTrip.path))
  }

  func testCorruptedImageProducesAUsefulError() throws {
    let temporaryDirectory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let source = temporaryDirectory.appendingPathComponent("corrupted.png")
    try Data("not an image".utf8).write(to: source, options: .atomic)

    XCTAssertThrowsError(
      try ImageEngine().convert(
        source: source,
        to: .jpeg,
        destination: temporaryDirectory.appendingPathComponent("output.jpg")
      )
    ) { error in
      XCTAssertFalse(error.localizedDescription.isEmpty)
    }
  }

  func testConversionNeverOverwritesTheSource() async throws {
    let temporaryDirectory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let source = temporaryDirectory.appendingPathComponent("source.png")
    let original = try makePNG(width: 24, height: 16)
    try original.write(to: source, options: .atomic)
    let asset = try await LocalFileInspector().inspect(url: source)

    let result = try await LocalConversionCoordinator().convert(
      plan: ConversionPlan(
        assets: [asset],
        outputFormat: .jpeg,
        destinationDirectory: temporaryDirectory
      ),
      progress: { _ in }
    )

    XCTAssertEqual(try Data(contentsOf: source), original)
    XCTAssertNotEqual(result.artifacts.first?.url, source)
  }

  func testPDFCreateMergeSplitRotateAndRender() async throws {
    let temporaryDirectory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let firstImage = temporaryDirectory.appendingPathComponent("first.png")
    let secondImage = temporaryDirectory.appendingPathComponent("second.png")
    try makePNG(width: 60, height: 40, color: (0.9, 0.2, 0.2, 1))
      .write(to: firstImage, options: .atomic)
    try makePNG(width: 40, height: 60, color: (0.2, 0.4, 0.9, 1))
      .write(to: secondImage, options: .atomic)

    let engine = PDFEngine()
    let firstPDF = temporaryDirectory.appendingPathComponent("first.pdf")
    let secondPDF = temporaryDirectory.appendingPathComponent("second.pdf")
    try await engine.imageToPDF(source: firstImage, destination: firstPDF)
    try await engine.imageToPDF(source: secondImage, destination: secondPDF)

    let mergedPDF = temporaryDirectory.appendingPathComponent("merged.pdf")
    try await engine.merge(urls: [firstPDF, secondPDF], to: mergedPDF)
    let mergedAsset = try await LocalFileInspector().inspect(url: mergedPDF)
    XCTAssertEqual(mergedAsset.format, .pdf)
    XCTAssertEqual(mergedAsset.metadata.pageCount, 2)

    var pageReferences = try await engine.pages(in: [mergedPDF])
    pageReferences[0].rotation = 90
    let rotatedPDF = temporaryDirectory.appendingPathComponent("rotated.pdf")
    try await engine.export(plan: PDFEditorPlan(pages: pageReferences), to: rotatedPDF)
    let rotatedAsset = try await LocalFileInspector().inspect(url: rotatedPDF)
    XCTAssertEqual(rotatedAsset.metadata.pageCount, 2)

    let splitDirectory = temporaryDirectory.appendingPathComponent("split", isDirectory: true)
    let split = try await engine.split(
      url: mergedPDF,
      mode: .everyPage,
      to: splitDirectory
    )
    XCTAssertEqual(split.count, 2)
    for url in split {
      let splitAsset = try await LocalFileInspector().inspect(url: url)
      XCTAssertEqual(splitAsset.metadata.pageCount, 1)
    }

    let renderedDirectory = temporaryDirectory.appendingPathComponent(
      "rendered",
      isDirectory: true
    )
    let rendered = try await engine.pdfToImages(
      source: mergedPDF,
      format: .png,
      directory: renderedDirectory,
      options: ConversionOptions(pdfDPI: 72)
    )
    XCTAssertEqual(rendered.count, 2)
    XCTAssertTrue(rendered.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
  }

  func testCoordinatorConvertsTextToPDFAndReportsArtifact() async throws {
    let temporaryDirectory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let textURL = temporaryDirectory.appendingPathComponent("notes.txt")
    try Data("Huri\nConversion locale et privée.".utf8)
      .write(to: textURL, options: .atomic)
    let asset = try await LocalFileInspector().inspect(url: textURL)
    let outputDirectory = temporaryDirectory.appendingPathComponent("output", isDirectory: true)

    let result = try await LocalConversionCoordinator().convert(
      plan: ConversionPlan(
        assets: [asset],
        outputFormat: .pdf,
        destinationDirectory: outputDirectory
      ),
      progress: { _ in }
    )

    XCTAssertEqual(result.artifacts.count, 1)
    let pdf = try await LocalFileInspector().inspect(url: result.artifacts[0].url)
    XCTAssertEqual(pdf.format, .pdf)
    XCTAssertEqual(pdf.metadata.pageCount, 1)
  }

  func testCoordinatorAppliesBackgroundRemovalToEveryPDFPage() async throws {
    let temporaryDirectory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let firstImage = temporaryDirectory.appendingPathComponent("page-one.png")
    let secondImage = temporaryDirectory.appendingPathComponent("page-two.png")
    try makePNG(width: 40, height: 30).write(to: firstImage, options: .atomic)
    try makePNG(width: 30, height: 40).write(to: secondImage, options: .atomic)
    let sourcePDF = temporaryDirectory.appendingPathComponent("document.pdf")
    try await PDFEngine().imagesToPDF(
      sources: [firstImage, secondImage],
      destination: sourcePDF
    )
    let asset = try await LocalFileInspector().inspect(url: sourcePDF)
    let remover = RecordingBackgroundRemover()
    let coordinator = LocalConversionCoordinator(backgroundRemovalEngine: remover)

    let result = try await coordinator.convert(
      plan: ConversionPlan(
        assets: [asset],
        outputFormat: .png,
        destinationDirectory: temporaryDirectory.appendingPathComponent("cutouts"),
        options: ConversionOptions(removeBackground: true, pdfDPI: 72)
      ),
      progress: { _ in }
    )

    XCTAssertEqual(result.artifacts.count, 2)
    let removalCallCount = await remover.callCount
    XCTAssertEqual(removalCallCount, 2)
    for artifact in result.artifacts {
      let outputAsset = try await LocalFileInspector().inspect(url: artifact.url)
      XCTAssertEqual(outputAsset.format, .png)
    }
  }

  private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "huri-infrastructure-tests-\(UUID().uuidString)",
        isDirectory: true
      )
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    return directory
  }

  private func makePNG(
    width: Int,
    height: Int,
    color: (CGFloat, CGFloat, CGFloat, CGFloat) = (0.1, 0.7, 0.35, 1)
  ) throws -> Data {
    guard
      let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
          | CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      XCTFail("Impossible de créer l’image synthétique.")
      return Data()
    }
    context.setFillColor(
      red: color.0,
      green: color.1,
      blue: color.2,
      alpha: color.3
    )
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let image = context.makeImage() else {
      XCTFail("Impossible de finaliser l’image synthétique.")
      return Data()
    }
    let data = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        data,
        "public.png" as CFString,
        1,
        nil
      )
    else {
      XCTFail("Impossible de créer l’encodeur PNG.")
      return Data()
    }
    CGImageDestinationAddImage(destination, image, nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return data as Data
  }
}

private actor RecordingBackgroundRemover: BackgroundRemoving {
  private(set) var callCount = 0

  func removeBackground(from source: URL, to destination: URL) async throws -> URL {
    callCount += 1
    try FileManager.default.createDirectory(
      at: destination.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data(contentsOf: source).write(to: destination, options: .atomic)
    return destination
  }
}
