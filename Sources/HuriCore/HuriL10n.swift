import Foundation

public enum HuriL10n {
  private static let resourceBundle: Bundle = {
    let bundleName = "Huri_HuriCore.bundle"
    let candidates = [
      Bundle.main.resourceURL?.appendingPathComponent(bundleName, isDirectory: true),
      Bundle.main.bundleURL.appendingPathComponent(bundleName, isDirectory: true),
      Bundle.main.bundleURL.deletingLastPathComponent()
        .appendingPathComponent(bundleName, isDirectory: true),
      Bundle.main.executableURL?.deletingLastPathComponent()
        .appendingPathComponent(bundleName, isDirectory: true),
    ]

    for case let candidate? in candidates {
      if let bundle = Bundle(url: candidate) {
        return bundle
      }
    }

    #if DEBUG
      return Bundle.module
    #else
      // A missing resource must never terminate a distributed application.
      // String(localized:) will return the key when the table is unavailable.
      return Bundle.main
    #endif
  }()

  public static func text(_ key: String, locale: Locale? = nil) -> String {
    let requestedLocale = locale ?? HuriLanguage.current().locale
    let requestedLocalization =
      requestedLocale.identifier
      .split(whereSeparator: { $0 == "_" || $0 == "-" })
      .first
      .map(String.init)
      ?? requestedLocale.identifier
    let localization =
      [HuriLanguage.french.rawValue, HuriLanguage.english.rawValue]
        .contains(requestedLocalization)
      ? requestedLocalization
      : HuriLanguage.french.rawValue

    if let path = resourceBundle.path(
      forResource: "Localizable",
      ofType: "strings",
      inDirectory: nil,
      forLocalization: localization
    ),
      let values = NSDictionary(contentsOfFile: path) as? [String: String],
      let translated = values[key]
    {
      return translated
    }

    let value = String.LocalizationValue(key)
    return String(localized: value, table: "Localizable", bundle: resourceBundle)
  }

  public static func format(
    _ key: String,
    locale: Locale? = nil,
    arguments: CVarArg...
  ) -> String {
    String(
      format: text(key, locale: locale),
      locale: locale ?? HuriLanguage.current().locale,
      arguments: arguments
    )
  }

  public static func plural(
    singular singularKey: String,
    plural pluralKey: String,
    count: Int,
    locale: Locale? = nil
  ) -> String {
    format(
      count == 1 ? singularKey : pluralKey,
      locale: locale,
      arguments: count
    )
  }
}
