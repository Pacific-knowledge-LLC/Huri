import Foundation

public protocol FileTypeDetecting: Sendable {
    func inspect(url: URL) async throws -> FileAsset
}

public protocol FilePreviewGenerating: Sendable {
    func previewData(for asset: FileAsset, maximumPixelSize: Int) async throws -> Data
}

public protocol ConversionExecuting: Sendable {
    func convert(
        plan: ConversionPlan,
        progress: @escaping @Sendable (ConversionProgress) -> Void
    ) async throws -> ConversionResult
}

public protocol PDFEditing: Sendable {
    func pages(in urls: [URL]) async throws -> [PDFPageReference]
    func export(plan: PDFEditorPlan, to destination: URL) async throws
    func split(url: URL, mode: PDFSplitMode, to directory: URL) async throws -> [URL]
}
