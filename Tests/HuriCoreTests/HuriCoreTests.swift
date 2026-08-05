import XCTest

@testable import HuriCore

final class HuriCoreTests: XCTestCase {
  func testApplicationName() {
    XCTAssertEqual(HuriCore.applicationName, "Huri")
  }

  func testImageConversionsStayCoherent() {
    let outputs = CapabilityRegistry().outputs(for: .png)
    XCTAssertTrue(outputs.contains(.jpeg))
    XCTAssertTrue(outputs.contains(.webp))
    XCTAssertTrue(outputs.contains(.pdf))
    XCTAssertFalse(outputs.contains(.png))
    XCTAssertFalse(outputs.contains(.mp3))
  }

  func testImpossibleConversionsAreNeverOffered() {
    let registry = CapabilityRegistry()
    XCTAssertFalse(registry.supports(input: .mp3, output: .png))
    XCTAssertTrue(registry.supports(input: .mp3, output: .wav))
    XCTAssertTrue(registry.outputs(for: .unknown).isEmpty)
  }

  func testHeterogeneousBatchUsesOnlyCommonOutputs() {
    let registry = CapabilityRegistry()
    XCTAssertTrue(registry.commonOutputs(for: [.png, .jpeg]).contains(.webp))
    XCTAssertTrue(registry.commonOutputs(for: [.png, .pdf]).contains(.jpeg))
    XCTAssertTrue(registry.commonOutputs(for: [.png, .mp3]).isEmpty)
  }

  func testWordOutputsDependOnProvider() {
    let registry = CapabilityRegistry()
    XCTAssertTrue(registry.outputs(for: .docx).isEmpty)
    XCTAssertTrue(
      registry.outputs(
        for: .docx,
        context: .init(wordConversionAvailable: true)
      ).contains(.pdf))
  }

  func testCompetitorCatalogIncludesEveryPublishedFamilyAndAccessRule() {
    XCTAssertGreaterThanOrEqual(FormatCatalog.entries.count, 300)
    XCTAssertEqual(
      Set(FormatCatalog.entries.map(\.format)).count,
      FormatCatalog.entries.count
    )
    XCTAssertEqual(FileFormat("cr2").family, .image)
    XCTAssertEqual(FileFormat("cr2").access, .readOnly)
    XCTAssertEqual(FileFormat("afm").access, .writeOnly)
    XCTAssertEqual(FileFormat("dxf").family, .cad)
    XCTAssertEqual(FileFormat("epub").family, .ebook)
  }

  func testFFmpegCapabilitiesStayWithinMediaFamilies() {
    let registry = CapabilityRegistry()
    let context = CapabilityContext(availableBackends: [.native, .ffmpeg])

    XCTAssertTrue(registry.supports(input: .flac, output: .mp3, context: context))
    XCTAssertTrue(registry.supports(input: .mkv, output: .webm, context: context))
    XCTAssertTrue(registry.supports(input: .mkv, output: .mp3, context: context))
    XCTAssertFalse(registry.supports(input: .flac, output: .png, context: context))
  }

  func testArchiveAndDocumentBackendsExposeOnlyExecutableTargets() {
    let registry = CapabilityRegistry()
    let context = CapabilityContext(
      availableBackends: [.native, .archive, .pandoc]
    )

    XCTAssertTrue(registry.supports(input: .sevenZip, output: .zip, context: context))
    XCTAssertTrue(registry.supports(input: .markdown, output: .docx, context: context))
    XCTAssertFalse(registry.supports(input: FileFormat("cr2"), output: .png, context: context))
  }

  func testLibreOfficeDoesNotInventCrossSuiteConversions() {
    let registry = CapabilityRegistry()
    let context = CapabilityContext(
      wordConversionAvailable: true,
      availableBackends: [.native, .libreOffice]
    )

    XCTAssertTrue(registry.supports(input: .docx, output: .odt, context: context))
    XCTAssertTrue(
      registry.supports(
        input: FileFormat("pptx"),
        output: FileFormat("odp"),
        context: context
      )
    )
    XCTAssertFalse(
      registry.supports(
        input: .docx,
        output: FileFormat("xlsx"),
        context: context
      )
    )
  }
}
