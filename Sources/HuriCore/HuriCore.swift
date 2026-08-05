import Foundation

public enum HuriCore {
  public static let applicationName = "Huri"
  public static var tagline: String { HuriL10n.text("brand.tagline") }
  public static let publisher = "Pacific Knowledge"
  public static let websiteURL = URL(string: "https://pacificknowledge.dev")!
  public static let supportEmail = "admin@pacificknowledge.dev"
  public static let bundleIdentifier = "dev.pacificknowledge.huri"
}
