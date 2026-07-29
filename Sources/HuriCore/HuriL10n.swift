import Foundation

public enum HuriL10n {
  public static func text(_ key: String, locale: Locale? = nil) -> String {
    if let locale {
      let requestedLocalization =
        locale.identifier
        .split(whereSeparator: { $0 == "_" || $0 == "-" })
        .first
        .map(String.init)
        ?? locale.identifier
      let localization =
        ["fr", "en"].contains(requestedLocalization)
        ? requestedLocalization
        : "fr"
      if let path = Bundle.module.path(
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
    }
    let value = String.LocalizationValue(key)
    return String(localized: value, table: "Localizable", bundle: .module)
  }

  public static func format(
    _ key: String,
    locale: Locale? = nil,
    arguments: CVarArg...
  ) -> String {
    String(
      format: text(key, locale: locale),
      locale: locale ?? .current,
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
