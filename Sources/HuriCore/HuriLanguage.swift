import Foundation

public enum HuriLanguage: String, CaseIterable, Identifiable, Sendable {
  case french = "fr"
  case english = "en"

  public static let storageKey = "dev.pacificknowledge.huri.language"

  public var id: String { rawValue }

  public var locale: Locale {
    Locale(identifier: rawValue)
  }

  public var nativeName: String {
    switch self {
    case .french: "Français"
    case .english: "English"
    }
  }

  public static func detect(
    preferredLanguages: [String] = Locale.preferredLanguages
  ) -> HuriLanguage {
    guard let preferredLanguage = preferredLanguages.first else {
      return .english
    }

    let languageCode =
      Locale(identifier: preferredLanguage)
      .language.languageCode?.identifier.lowercased()

    return languageCode == HuriLanguage.french.rawValue ? .french : .english
  }

  public static func current(
    in defaults: UserDefaults = .standard,
    preferredLanguages: [String] = Locale.preferredLanguages
  ) -> HuriLanguage {
    if let storedValue = defaults.string(forKey: storageKey),
      let storedLanguage = HuriLanguage(rawValue: storedValue)
    {
      return storedLanguage
    }

    return detect(preferredLanguages: preferredLanguages)
  }

  @discardableResult
  public static func installInitialPreference(
    in defaults: UserDefaults = .standard,
    preferredLanguages: [String] = Locale.preferredLanguages
  ) -> HuriLanguage {
    if let storedValue = defaults.string(forKey: storageKey),
      let storedLanguage = HuriLanguage(rawValue: storedValue)
    {
      return storedLanguage
    }

    let detectedLanguage = detect(preferredLanguages: preferredLanguages)
    defaults.set(detectedLanguage.rawValue, forKey: storageKey)
    return detectedLanguage
  }
}
