import Foundation

public struct CapabilityContext: Sendable {
    public var wordConversionAvailable: Bool
    public var enabledImageOutputs: Set<FileFormat>

    public init(
        wordConversionAvailable: Bool = false,
        enabledImageOutputs: Set<FileFormat> = Set(FileFormat.imageOutputs)
    ) {
        self.wordConversionAvailable = wordConversionAvailable
        self.enabledImageOutputs = enabledImageOutputs
    }
}

public struct CapabilityRegistry: Sendable {
    public init() {}

    public func outputs(for input: FileFormat, context: CapabilityContext = .init()) -> [FileFormat] {
        switch input.family {
        case .image:
            ordered(context.enabledImageOutputs.subtracting([input]).union([.pdf]))
        case .pdf:
            ordered(context.enabledImageOutputs)
        case .document:
            context.wordConversionAvailable || input == .rtf
                ? ordered(context.enabledImageOutputs.union([.pdf]))
                : []
        case .text:
            ordered(context.enabledImageOutputs.union([.pdf]))
        case .audio:
            [.m4a, .wav, .aiff].filter { $0 != input }
        case .video:
            [.mp4, .mov, .m4v, .m4a].filter { $0 != input }
        case .unsupported:
            []
        }
    }

    public func commonOutputs(
        for inputs: [FileFormat],
        context: CapabilityContext = .init()
    ) -> [FileFormat] {
        guard let first = inputs.first else { return [] }
        let common = inputs.dropFirst().reduce(Set(outputs(for: first, context: context))) {
            $0.intersection(outputs(for: $1, context: context))
        }
        return ordered(common)
    }

    public func supports(
        input: FileFormat,
        output: FileFormat,
        context: CapabilityContext = .init()
    ) -> Bool {
        outputs(for: input, context: context).contains(output)
    }

    private func ordered(_ formats: Set<FileFormat>) -> [FileFormat] {
        let preference: [FileFormat] = [
            .png, .jpeg, .webp, .pdf, .heic, .tiff, .gif, .bmp,
            .m4a, .wav, .aiff, .mp4, .mov, .m4v,
        ]
        return preference.filter(formats.contains)
    }
}

public extension FileFormat {
    static let imageOutputs: [FileFormat] = [
        .png, .jpeg, .webp, .tiff, .heic, .gif, .bmp,
    ]
}
