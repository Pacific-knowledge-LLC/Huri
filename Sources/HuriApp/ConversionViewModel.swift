import AppKit
import Foundation
import HuriCore
import HuriInfrastructure

struct ImportedAsset: Identifiable {
    let asset: FileAsset
    let preview: NSImage?

    var id: UUID { asset.id }
}

enum ConversionUIState {
    case idle
    case converting(ConversionProgress)
    case success(ConversionResult)
    case failure(String)

    var isConverting: Bool {
        if case .converting = self { true } else { false }
    }
}

@MainActor
final class ConversionViewModel: ObservableObject {
    @Published private(set) var items: [ImportedAsset] = []
    @Published var selectedOutput: FileFormat?
    @Published var quality = 0.88
    @Published var scale = 1.0
    @Published var pdfDPI = 144
    @Published var removeBackground = false
    @Published var preserveMetadata = true
    @Published var destinationDirectory: URL
    @Published private(set) var isImporting = false
    @Published private(set) var state: ConversionUIState = .idle
    @Published var dropIsTargeted = false
    @Published var importWarning: String?

    private let services: HuriServices
    private var conversionTask: Task<Void, Never>?

    init(services: HuriServices) {
        self.services = services
        destinationDirectory = FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
    }

    var supportedOutputs: [FileFormat] {
        services.capabilities.commonOutputs(
            for: items.map(\.asset.format),
            context: services.capabilityContext
        )
    }

    var canConvert: Bool {
        !items.isEmpty
            && selectedOutput != nil
            && !state.isConverting
            && !supportedOutputs.isEmpty
    }

    var acceptsBackgroundRemoval: Bool {
        selectedOutput == .png
            && items.allSatisfy { [.image, .pdf, .document, .text].contains($0.asset.family) }
    }

    func importFiles(_ urls: [URL]) {
        let existing = Set(items.map { $0.asset.sourceURL.standardizedFileURL })
        let candidates = urls
            .map(\.standardizedFileURL)
            .filter { !existing.contains($0) }
        guard !candidates.isEmpty else { return }

        isImporting = true
        importWarning = nil
        state = .idle
        let inspector = services.inspector
        let previewer = services.preview

        Task {
            let payloads = await withTaskGroup(
                of: ImportPayload.self,
                returning: [ImportPayload].self
            ) { group in
                for (index, url) in candidates.enumerated() {
                    group.addTask {
                        do {
                            let asset = try await inspector.inspect(url: url)
                            let data = try? await previewer.previewData(
                                for: asset,
                                maximumPixelSize: 240
                            )
                            return .success(index: index, asset: asset, previewData: data)
                        } catch {
                            return .failure(
                                index: index,
                                filename: url.lastPathComponent,
                                message: error.localizedDescription
                            )
                        }
                    }
                }

                var results: [ImportPayload] = []
                for await result in group {
                    results.append(result)
                }
                return results.sorted { $0.index < $1.index }
            }

            var failures: [String] = []
            for payload in payloads {
                switch payload {
                case let .success(_, asset, previewData):
                    let image = previewData.flatMap(NSImage.init(data:))
                    items.append(ImportedAsset(asset: asset, preview: image))
                case let .failure(_, filename, message):
                    failures.append("\(filename) — \(message)")
                }
            }
            importWarning = failures.isEmpty
                ? nil
                : "Certains fichiers n’ont pas pu être ajoutés :\n" + failures.joined(separator: "\n")
            isImporting = false
            normalizeOutputSelection()
        }
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        state = .idle
        normalizeOutputSelection()
    }

    func removeAll() {
        items.removeAll()
        selectedOutput = nil
        removeBackground = false
        state = .idle
    }

    func selectOutput(_ output: FileFormat) {
        selectedOutput = output
        if output != .png {
            removeBackground = false
        }
        state = .idle
    }

    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.title = "Choisir le dossier de destination"
        panel.prompt = "Choisir"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = destinationDirectory
        if panel.runModal() == .OK, let url = panel.url {
            destinationDirectory = url
        }
    }

    func startConversion() {
        guard canConvert, let output = selectedOutput else { return }
        let plan = ConversionPlan(
            assets: items.map(\.asset),
            outputFormat: output,
            destinationDirectory: destinationDirectory,
            options: ConversionOptions(
                quality: quality,
                removeBackground: acceptsBackgroundRemoval && removeBackground,
                preserveMetadata: preserveMetadata,
                scale: scale,
                pdfDPI: pdfDPI
            )
        )
        let converter = services.converter
        state = .converting(
            ConversionProgress(
                completedUnitCount: 0,
                totalUnitCount: max(items.count, 1),
                message: "Préparation…"
            )
        )

        let progressRelay = ConversionProgressRelay { [weak self] progress in
            guard self?.state.isConverting == true else { return }
            self?.state = .converting(progress)
        }
        conversionTask = Task { [weak self] in
            do {
                let result = try await converter.convert(plan: plan) { progress in
                    progressRelay.send(progress)
                }
                guard !Task.isCancelled else { return }
                self?.state = .success(result)
            } catch is CancellationError {
                self?.state = .idle
            } catch {
                guard !Task.isCancelled else {
                    self?.state = .idle
                    return
                }
                self?.state = .failure(error.localizedDescription)
            }
        }
    }

    func cancelConversion() {
        conversionTask?.cancel()
        conversionTask = nil
        state = .idle
    }

    func revealResult() {
        guard case let .success(result) = state else { return }
        let urls = result.artifacts.map(\.url)
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func dismissStatus() {
        state = .idle
    }

    private func normalizeOutputSelection() {
        let outputs = supportedOutputs
        if let selectedOutput, outputs.contains(selectedOutput) {
            return
        }
        selectedOutput = outputs.first
        if selectedOutput != .png {
            removeBackground = false
        }
    }
}

private final class ConversionProgressRelay: Sendable {
    private let delivery: @MainActor @Sendable (ConversionProgress) -> Void

    init(delivery: @escaping @MainActor @Sendable (ConversionProgress) -> Void) {
        self.delivery = delivery
    }

    func send(_ progress: ConversionProgress) {
        Task { @MainActor [delivery] in
            delivery(progress)
        }
    }
}

private enum ImportPayload: @unchecked Sendable {
    case success(index: Int, asset: FileAsset, previewData: Data?)
    case failure(index: Int, filename: String, message: String)

    var index: Int {
        switch self {
        case let .success(index, _, _), let .failure(index, _, _):
            index
        }
    }
}
