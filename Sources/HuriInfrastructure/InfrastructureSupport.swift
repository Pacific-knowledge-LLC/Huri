import Foundation
import HuriCore

enum InfrastructureSupport {
    static func prepareDestination(_ destination: URL) throws {
        let directory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    static func writeAtomically(_ data: Data, to destination: URL) throws {
        try prepareDestination(destination)
        do {
            try data.write(to: destination, options: [.atomic])
        } catch {
            throw ConversionError.conversionFailed(
                "Impossible d’écrire « \(destination.lastPathComponent) » : \(error.localizedDescription)"
            )
        }
    }

    static func uniqueDestination(
        in directory: URL,
        basename: String,
        extension filenameExtension: String
    ) -> URL {
        let sanitized = basename.isEmpty ? "conversion" : basename
        var candidate = directory
            .appendingPathComponent(sanitized)
            .appendingPathExtension(filenameExtension)
        var suffix = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(sanitized)-\(suffix)")
                .appendingPathExtension(filenameExtension)
            suffix += 1
        }
        return candidate
    }

    static func clampedQuality(_ quality: Double) -> Double {
        min(max(quality, 0.1), 1)
    }
}
