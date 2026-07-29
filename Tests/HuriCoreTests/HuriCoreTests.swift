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
}
