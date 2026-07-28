import Foundation

public struct PDFPageReference: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let sourceURL: URL
    public let sourcePageIndex: Int
    public var rotation: Int

    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        sourcePageIndex: Int,
        rotation: Int = 0
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.sourcePageIndex = sourcePageIndex
        self.rotation = ((rotation % 360) + 360) % 360
    }
}

public enum PDFSplitMode: Hashable, Sendable {
    case everyPage
    case ranges([ClosedRange<Int>])
}

public struct PDFEditorPlan: Hashable, Sendable {
    public var pages: [PDFPageReference]

    public init(pages: [PDFPageReference]) {
        self.pages = pages
    }
}
