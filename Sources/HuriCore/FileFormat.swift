import Foundation

public enum FileFamily: String, CaseIterable, Codable, Sendable {
    case image
    case pdf
    case document
    case text
    case audio
    case video
    case unsupported

    public var displayName: String {
        switch self {
        case .image: "Image"
        case .pdf: "PDF"
        case .document: "Document"
        case .text: "Texte"
        case .audio: "Audio"
        case .video: "Vidéo"
        case .unsupported: "Non pris en charge"
        }
    }
}

public enum FileFormat: String, CaseIterable, Codable, Identifiable, Sendable {
    case png
    case jpeg
    case webp
    case tiff
    case heic
    case gif
    case bmp
    case pdf
    case docx
    case doc
    case rtf
    case txt
    case markdown
    case mp3
    case wav
    case m4a
    case aiff
    case mp4
    case mov
    case m4v
    case unknown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .jpeg: "JPEG"
        case .tiff: "TIFF"
        case .heic: "HEIC"
        case .docx: "Word (DOCX)"
        case .doc: "Word (DOC)"
        case .rtf: "Rich Text"
        case .txt: "Texte"
        case .markdown: "Markdown"
        case .m4a: "M4A"
        case .aiff: "AIFF"
        case .mp4: "MP4"
        case .mov: "MOV"
        case .m4v: "M4V"
        case .unknown: "Inconnu"
        default: rawValue.uppercased()
        }
    }

    public var preferredExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .tiff: "tiff"
        case .markdown: "md"
        default: rawValue
        }
    }

    public var filenameExtensions: Set<String> {
        switch self {
        case .jpeg: ["jpg", "jpeg", "jpe"]
        case .tiff: ["tif", "tiff"]
        case .heic: ["heic", "heif"]
        case .markdown: ["md", "markdown"]
        case .aiff: ["aif", "aiff", "aifc"]
        default: [preferredExtension]
        }
    }

    public var family: FileFamily {
        switch self {
        case .png, .jpeg, .webp, .tiff, .heic, .gif, .bmp: .image
        case .pdf: .pdf
        case .docx, .doc, .rtf: .document
        case .txt, .markdown: .text
        case .mp3, .wav, .m4a, .aiff: .audio
        case .mp4, .mov, .m4v: .video
        case .unknown: .unsupported
        }
    }

    public var supportsTransparency: Bool {
        switch self {
        case .png, .webp, .tiff, .heic, .gif: true
        default: false
        }
    }

    public var isLossy: Bool {
        switch self {
        case .jpeg, .webp, .heic, .mp3, .m4a, .mp4, .mov, .m4v: true
        default: false
        }
    }

    public static func from(filenameExtension: String) -> FileFormat {
        let normalized = filenameExtension.lowercased()
        return allCases.first { $0.filenameExtensions.contains(normalized) } ?? .unknown
    }
}
