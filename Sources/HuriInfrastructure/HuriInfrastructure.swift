import HuriCore
import WebP

public struct HuriInfrastructureStatus: Sendable {
    public let isReady: Bool

    public init(isReady: Bool = true) {
        self.isReady = isReady
    }
}

public struct HuriServices: Sendable {
    public let inspector: LocalFileInspector
    public let converter: LocalConversionCoordinator
    public let pdfEditor: PDFEngine
    public let preview: QuickLookPreviewService
    public let capabilities: CapabilityRegistry
    public let capabilityContext: CapabilityContext

    public init() {
        let imageEngine = ImageEngine()
        let inspector = LocalFileInspector()
        let pdfEngine = PDFEngine(imageEngine: imageEngine)
        let backgroundRemovalEngine = BackgroundRemovalEngine(imageEngine: imageEngine)
        let documentProvider = LibreOfficeProvider()

        self.inspector = inspector
        self.pdfEditor = pdfEngine
        self.preview = QuickLookPreviewService()
        self.capabilities = CapabilityRegistry()
        self.capabilityContext = CapabilityContext(
            wordConversionAvailable: documentProvider.isAvailable,
            enabledImageOutputs: ImageEngine.supportedOutputFormats
        )
        self.converter = LocalConversionCoordinator(
            inspector: inspector,
            imageEngine: imageEngine,
            backgroundRemovalEngine: backgroundRemovalEngine,
            pdfEngine: pdfEngine,
            documentProvider: documentProvider
        )
    }
}
