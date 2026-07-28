import PDFKit
import HuriCore
import SwiftUI

struct PDFDocumentPreview: NSViewRepresentable {
    let reference: PDFPageReference?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.backgroundColor = .clear
        return view
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        guard let reference else {
            pdfView.document = nil
            context.coordinator.loadedURL = nil
            return
        }
        if context.coordinator.loadedURL != reference.sourceURL {
            pdfView.document = PDFDocument(url: reference.sourceURL)
            context.coordinator.loadedURL = reference.sourceURL
        }
        guard let page = pdfView.document?.page(at: reference.sourcePageIndex) else { return }
        page.rotation = reference.rotation
        pdfView.go(to: page)
    }

    final class Coordinator {
        var loadedURL: URL?
    }
}

struct PDFPageThumbnail: View {
    let reference: PDFPageReference
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    Color.secondary.opacity(0.08)
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .frame(width: 50, height: 64)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(.separator.opacity(0.6), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        .task(id: thumbnailIdentity) {
            image = renderThumbnail()
        }
    }

    private var thumbnailIdentity: String {
        "\(reference.sourceURL.path())#\(reference.sourcePageIndex)#\(reference.rotation)"
    }

    private func renderThumbnail() -> NSImage? {
        guard let document = PDFDocument(url: reference.sourceURL),
              let page = document.page(at: reference.sourcePageIndex)
        else { return nil }
        page.rotation = reference.rotation
        return page.thumbnail(of: NSSize(width: 100, height: 128), for: .cropBox)
    }
}
