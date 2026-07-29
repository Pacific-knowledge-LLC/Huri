#!/usr/bin/env swift

import Foundation

enum GenerationError: LocalizedError {
    case invalidCatalog
    case missingTranslation(key: String, locale: String)

    var errorDescription: String? {
        switch self {
        case .invalidCatalog:
            "The String Catalog structure is invalid."
        case let .missingTranslation(key, locale):
            "Missing \(locale) translation for \(key)."
        }
    }
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let catalogURL = projectRoot
    .appendingPathComponent("Sources/HuriCore/Resources/Localizable.xcstrings")
let resourcesURL = catalogURL.deletingLastPathComponent()
let data = try Data(contentsOf: catalogURL)

guard
    let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
    let strings = root["strings"] as? [String: Any]
else {
    throw GenerationError.invalidCatalog
}

func escaped(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
}

for locale in ["fr", "en"] {
    var lines = [
        "/* Generated from Localizable.xcstrings. Do not edit manually. */",
        "",
    ]

    for key in strings.keys.sorted() {
        guard
            let entry = strings[key] as? [String: Any],
            let localizations = entry["localizations"] as? [String: Any],
            let localization = localizations[locale] as? [String: Any],
            let stringUnit = localization["stringUnit"] as? [String: Any],
            let value = stringUnit["value"] as? String
        else {
            throw GenerationError.missingTranslation(key: key, locale: locale)
        }
        lines.append("\"\(escaped(key))\" = \"\(escaped(value))\";")
    }

    lines.append("")
    let localeDirectory = resourcesURL.appendingPathComponent("\(locale).lproj")
    try FileManager.default.createDirectory(
        at: localeDirectory,
        withIntermediateDirectories: true
    )
    try lines.joined(separator: "\n").write(
        to: localeDirectory.appendingPathComponent("Localizable.strings"),
        atomically: true,
        encoding: .utf8
    )
}

print("Generated French and English localization tables.")
