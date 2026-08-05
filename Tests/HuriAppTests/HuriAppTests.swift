import Foundation
import HuriCore
import XCTest

@testable import HuriApp

final class HuriAppTests: XCTestCase {
  func testOnboardingIsOnlyPresentedForOlderCompletionVersions() {
    XCTAssertTrue(HuriOnboarding.shouldPresent(completedVersion: 0))
    XCTAssertFalse(
      HuriOnboarding.shouldPresent(
        completedVersion: HuriOnboarding.currentVersion
      )
    )
    XCTAssertFalse(
      HuriOnboarding.shouldPresent(
        completedVersion: HuriOnboarding.currentVersion + 1
      )
    )
  }

  func testFrenchAndEnglishCatalogsExposeCoreNavigation() {
    let french = Locale(identifier: "fr")
    let english = Locale(identifier: "en")

    XCTAssertEqual(HuriL10n.text("nav.convert", locale: french), "Convertir")
    XCTAssertEqual(HuriL10n.text("nav.convert", locale: english), "Convert")
    XCTAssertEqual(HuriL10n.text("nav.pdfTools", locale: french), "Outils PDF")
    XCTAssertEqual(HuriL10n.text("nav.pdfTools", locale: english), "PDF Tools")
  }

  func testPluralFormattingUsesBothCatalogForms() {
    let english = Locale(identifier: "en")

    XCTAssertEqual(
      HuriL10n.plural(
        singular: "conversion.items.one",
        plural: "conversion.items.other",
        count: 1,
        locale: english
      ),
      "1 item"
    )
    XCTAssertEqual(
      HuriL10n.plural(
        singular: "conversion.items.one",
        plural: "conversion.items.other",
        count: 2,
        locale: english
      ),
      "2 items"
    )
  }

  func testUnsupportedLocaleFallsBackToFrench() {
    XCTAssertEqual(
      HuriL10n.text("nav.convert", locale: Locale(identifier: "de")),
      "Convertir"
    )
  }

  func testProfessionalIdentityHasNoPersonalPublisherName() {
    XCTAssertEqual(HuriCore.publisher, "Pacific Knowledge")
    XCTAssertEqual(HuriCore.bundleIdentifier, "dev.pacificknowledge.huri")
    XCTAssertEqual(HuriCore.supportEmail, "admin@pacificknowledge.dev")
    XCTAssertEqual(HuriCore.websiteURL.host(), "pacificknowledge.dev")
  }
}
