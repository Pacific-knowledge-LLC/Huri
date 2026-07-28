import AppKit
import CoreText
import Foundation
import HuriCore

struct TextDocumentEngine: Sendable {
    func renderToPDF(source: URL, format: FileFormat, destination: URL) throws -> URL {
        let attributedString = try loadAttributedString(source: source, format: format)
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let textRect = pageRect.insetBy(dx: 54, dy: 54)
        let outputData = NSMutableData()
        guard let consumer = CGDataConsumer(data: outputData as CFMutableData) else {
            throw ConversionError.conversionFailed("Impossible de créer le flux PDF.")
        }
        var mediaBox = pageRect
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ConversionError.conversionFailed("Impossible de créer le document PDF.")
        }

        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let stringLength = CFAttributedStringGetLength(attributedString)
        var location = 0
        repeat {
            context.beginPDFPage(nil)
            let path = CGPath(rect: textRect, transform: nil)
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: location, length: 0),
                path,
                nil
            )
            CTFrameDraw(frame, context)
            let visible = CTFrameGetVisibleStringRange(frame)
            location += visible.length
            context.endPDFPage()

            if visible.length == 0 && location < stringLength {
                throw ConversionError.conversionFailed(
                    "Une portion du document ne peut pas être mise en page."
                )
            }
        } while location < stringLength
        context.closePDF()

        try InfrastructureSupport.writeAtomically(outputData as Data, to: destination)
        return destination
    }

    private func loadAttributedString(source: URL, format: FileFormat) throws -> CFAttributedString {
        let data: Data
        do {
            data = try Data(contentsOf: source)
        } catch {
            throw ConversionError.unreadable(
                "Impossible de lire « \(source.lastPathComponent) » : \(error.localizedDescription)"
            )
        }

        if format == .rtf {
            do {
                return try NSAttributedString(
                    data: data,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                )
            } catch {
                throw ConversionError.unreadable(
                    "Le document RTF est invalide : \(error.localizedDescription)"
                )
            }
        }

        guard let string = String(
            data: data,
            encoding: .utf8
        ) ?? String(data: data, encoding: .isoLatin1) else {
            throw ConversionError.unreadable(
                "Le codage texte de « \(source.lastPathComponent) » n’est pas reconnu."
            )
        }
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 3
        style.paragraphSpacing = 8
        return NSAttributedString(
            string: string.isEmpty ? " " : string,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: style,
            ]
        )
    }
}
