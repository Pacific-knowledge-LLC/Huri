import AppKit
import Foundation
import HuriCore
import PDFKit

public actor PDFEngine: PDFEditing {
    private let imageEngine: ImageEngine

    public init(imageEngine: ImageEngine = .init()) {
        self.imageEngine = imageEngine
    }

    public func pages(in urls: [URL]) async throws -> [PDFPageReference] {
        var references: [PDFPageReference] = []
        for url in urls {
            try Task.checkCancellation()
            guard let document = PDFDocument(url: url) else {
                throw ConversionError.unreadable(
                    "Impossible d’ouvrir le PDF « \(url.lastPathComponent) »."
                )
            }
            references.append(
                contentsOf: (0 ..< document.pageCount).map {
                    PDFPageReference(sourceURL: url, sourcePageIndex: $0)
                }
            )
        }
        return references
    }

    public func export(plan: PDFEditorPlan, to destination: URL) async throws {
        guard !plan.pages.isEmpty else {
            throw ConversionError.invalidPlan("Le PDF exporté doit contenir au moins une page.")
        }
        let output = PDFDocument()
        var loadedDocuments: [URL: PDFDocument] = [:]

        for (outputIndex, reference) in plan.pages.enumerated() {
            try Task.checkCancellation()
            let document: PDFDocument
            if let existing = loadedDocuments[reference.sourceURL] {
                document = existing
            } else if let loaded = PDFDocument(url: reference.sourceURL) {
                loadedDocuments[reference.sourceURL] = loaded
                document = loaded
            } else {
                throw ConversionError.unreadable(
                    "Impossible d’ouvrir « \(reference.sourceURL.lastPathComponent) »."
                )
            }
            guard reference.sourcePageIndex >= 0,
                  let sourcePage = document.page(at: reference.sourcePageIndex)
            else {
                throw ConversionError.invalidPlan(
                    "La page \(reference.sourcePageIndex + 1) n’existe plus dans « \(reference.sourceURL.lastPathComponent) »."
                )
            }

            let page = (sourcePage.copy() as? PDFPage) ?? sourcePage
            page.rotation = normalizedRotation(sourcePage.rotation + reference.rotation)
            output.insert(page, at: outputIndex)
        }
        try write(output, to: destination)
    }

    public func split(
        url: URL,
        mode: PDFSplitMode,
        to directory: URL
    ) async throws -> [URL] {
        guard let source = PDFDocument(url: url) else {
            throw ConversionError.unreadable(
                "Impossible d’ouvrir le PDF « \(url.lastPathComponent) »."
            )
        }
        guard source.pageCount > 0 else {
            throw ConversionError.invalidPlan("Ce PDF ne contient aucune page.")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let ranges: [ClosedRange<Int>]
        switch mode {
        case .everyPage:
            ranges = (0 ..< source.pageCount).map { $0 ... $0 }
        case let .ranges(requested):
            guard !requested.isEmpty else {
                throw ConversionError.invalidPlan("Ajoutez au moins une plage de pages.")
            }
            ranges = requested
        }

        var outputs: [URL] = []
        let basename = url.deletingPathExtension().lastPathComponent
        for (rangeIndex, range) in ranges.enumerated() {
            try Task.checkCancellation()
            guard range.lowerBound >= 0, range.upperBound < source.pageCount else {
                throw ConversionError.invalidPlan(
                    "La plage \(range.lowerBound + 1)–\(range.upperBound + 1) dépasse les \(source.pageCount) pages du PDF."
                )
            }
            let output = PDFDocument()
            for sourceIndex in range {
                guard let sourcePage = source.page(at: sourceIndex) else { continue }
                output.insert((sourcePage.copy() as? PDFPage) ?? sourcePage, at: output.pageCount)
            }
            let label: String
            if range.lowerBound == range.upperBound {
                label = "\(basename)-page-\(range.lowerBound + 1)"
            } else {
                label = "\(basename)-pages-\(range.lowerBound + 1)-\(range.upperBound + 1)"
            }
            let destination = InfrastructureSupport.uniqueDestination(
                in: directory,
                basename: label,
                extension: "pdf"
            )
            try write(output, to: destination)
            outputs.append(destination)

            if rangeIndex.isMultiple(of: 8) {
                await Task.yield()
            }
        }
        return outputs
    }

    @discardableResult
    public func merge(urls: [URL], to destination: URL) async throws -> URL {
        let references = try await pages(in: urls)
        try await export(plan: PDFEditorPlan(pages: references), to: destination)
        return destination
    }

    @discardableResult
    public func imageToPDF(source: URL, destination: URL) async throws -> URL {
        try await imagesToPDF(sources: [source], destination: destination)
    }

    @discardableResult
    public func imagesToPDF(sources: [URL], destination: URL) async throws -> URL {
        guard !sources.isEmpty else {
            throw ConversionError.invalidPlan("Ajoutez au moins une image au PDF.")
        }
        try Task.checkCancellation()
        let document = PDFDocument()
        for source in sources {
            try Task.checkCancellation()
            guard let image = NSImage(contentsOf: source),
                  let page = PDFPage(image: image)
            else {
                throw ConversionError.unreadable(
                    "Impossible d’ajouter « \(source.lastPathComponent) » au PDF."
                )
            }
            document.insert(page, at: document.pageCount)
        }
        try write(document, to: destination)
        return destination
    }

    @discardableResult
    public func rotate(
        url: URL,
        pageIndices: [Int],
        by degrees: Int,
        to destination: URL
    ) async throws -> URL {
        let selected = Set(pageIndices)
        var references = try await pages(in: [url])
        for index in references.indices where selected.contains(index) {
            references[index].rotation = normalizedRotation(degrees)
        }
        try await export(plan: PDFEditorPlan(pages: references), to: destination)
        return destination
    }

    public func pdfToImages(
        source: URL,
        format: FileFormat,
        directory: URL,
        options: ConversionOptions = .init()
    ) async throws -> [URL] {
        guard format.family == .image else {
            throw ConversionError.unsupported("La sortie demandée n’est pas une image.")
        }
        guard let document = PDFDocument(url: source) else {
            throw ConversionError.unreadable(
                "Impossible d’ouvrir le PDF « \(source.lastPathComponent) »."
            )
        }
        guard document.pageCount > 0 else {
            throw ConversionError.invalidPlan("Ce PDF ne contient aucune page.")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var outputs: [URL] = []
        let basename = source.deletingPathExtension().lastPathComponent
        for pageIndex in 0 ..< document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: pageIndex) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let scale = CGFloat(options.pdfDPI) / 72
            let targetSize = NSSize(
                width: max(bounds.width * scale, 1),
                height: max(bounds.height * scale, 1)
            )
            let thumbnail = page.thumbnail(of: targetSize, for: .mediaBox)
            var rect = NSRect(origin: .zero, size: thumbnail.size)
            guard let image = thumbnail.cgImage(
                forProposedRect: &rect,
                context: nil,
                hints: nil
            ) else {
                throw ConversionError.conversionFailed(
                    "Le rendu de la page \(pageIndex + 1) a échoué."
                )
            }
            let destination = InfrastructureSupport.uniqueDestination(
                in: directory,
                basename: "\(basename)-page-\(String(format: "%03d", pageIndex + 1))",
                extension: format.preferredExtension
            )
            try imageEngine.write(
                image,
                format: format,
                destination: destination,
                quality: options.quality
            )
            outputs.append(destination)
            await Task.yield()
        }
        return outputs
    }

    private func normalizedRotation(_ rotation: Int) -> Int {
        let normalized = ((rotation % 360) + 360) % 360
        return (normalized / 90) * 90
    }

    private func write(_ document: PDFDocument, to destination: URL) throws {
        guard let data = document.dataRepresentation() else {
            throw ConversionError.conversionFailed("PDFKit n’a pas pu générer le document.")
        }
        try InfrastructureSupport.writeAtomically(data, to: destination)
    }
}
