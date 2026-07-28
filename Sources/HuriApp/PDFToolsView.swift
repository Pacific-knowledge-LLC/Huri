import AppKit
import HuriCore
import SwiftUI
import UniformTypeIdentifiers

struct PDFToolsView: View {
    @ObservedObject var model: PDFToolsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                HuriSectionTitle(
                    eyebrow: "Atelier PDF",
                    title: "Composez votre document",
                    subtitle: "Fusionnez, réordonnez, pivotez, extrayez ou découpez vos pages."
                )
                Spacer()
                Label("\(model.pages.count) pages", systemImage: "doc.text")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.5), in: Capsule())
            }

            if model.pages.isEmpty {
                pdfEmptyState
            } else {
                editor
                operationBanner
            }
        }
        .padding(28)
        .navigationTitle("Outils PDF")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    openPDFPanel()
                } label: {
                    Label("Ajouter des PDF", systemImage: "plus")
                }
                .help("Ajouter des documents PDF")
                Button(role: .destructive) {
                    model.removeAll()
                } label: {
                    Label("Vider", systemImage: "trash")
                }
                .disabled(model.pages.isEmpty)
            }
        }
        .focusedValue(\.openFilesAction, openPDFPanel)
    }

    private var pdfEmptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(HuriTheme.coral.opacity(model.dropIsTargeted ? 0.2 : 0.1))
                    .frame(width: 82, height: 82)
                if model.isImporting {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    Image(systemName: model.dropIsTargeted ? "arrow.down.doc.fill" : "doc.on.doc")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(HuriTheme.coral)
                }
            }
            VStack(spacing: 6) {
                Text(model.dropIsTargeted ? "Relâchez les PDF" : "Créez votre espace de travail")
                    .font(.title2.weight(.semibold))
                Text("Ajoutez un ou plusieurs PDF pour commencer.")
                    .foregroundStyle(.secondary)
            }
            Button("Choisir des PDF", action: openPDFPanel)
                .buttonStyle(HuriPrimaryButtonStyle())
            Text("Astuce : maintenez ⇧ ou ⌘ pour sélectionner plusieurs pages.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(36)
        .background(
            LinearGradient(
                colors: [
                    HuriTheme.coral.opacity(0.04),
                    HuriTheme.indigo.opacity(0.04),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    HuriTheme.coral.opacity(model.dropIsTargeted ? 0.7 : 0.25),
                    style: StrokeStyle(lineWidth: 1.2, dash: [8, 6])
                )
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.importPDFs(urls)
            return !urls.isEmpty
        } isTargeted: { targeted in
            model.dropIsTargeted = targeted
        }
        .accessibilityLabel("Zone d’import de documents PDF")
    }

    private var editor: some View {
        HStack(spacing: 14) {
            pageList
                .frame(width: 310)
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            actionPanel
                .frame(width: 252)
        }
        .frame(minHeight: 450)
    }

    private var pageList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pages")
                        .font(.headline)
                    Text("\(model.uniqueDocumentCount) document\(model.uniqueDocumentCount > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if model.isImporting {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    openPDFPanel()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .help("Ajouter un PDF")
            }

            List(selection: $model.selection) {
                ForEach(model.pages) { page in
                    PDFPageRow(page: page)
                        .tag(page.id)
                        .contextMenu {
                            Button("Pivoter à gauche") {
                                model.selectOnly(page)
                                model.rotateSelection(clockwise: false)
                            }
                            Button("Pivoter à droite") {
                                model.selectOnly(page)
                                model.rotateSelection(clockwise: true)
                            }
                            Divider()
                            Button("Supprimer", role: .destructive) {
                                model.selectOnly(page)
                                model.deleteSelection()
                            }
                        }
                }
                .onMove(perform: model.move)
            }
            .listStyle(.inset)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text("Glissez les lignes pour réordonner.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .huriCard()
        .dropDestination(for: URL.self) { urls, _ in
            model.importPDFs(urls)
            return !urls.isEmpty
        } isTargeted: { targeted in
            model.dropIsTargeted = targeted
        }
    }

    private var preview: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Aperçu", systemImage: "eye")
                    .font(.headline)
                Spacer()
                if let page = model.primarySelection {
                    Text("\(page.sourceURL.lastPathComponent) · page \(page.sourcePageIndex + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            PDFDocumentPreview(reference: model.primarySelection)
                .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 11))
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(.separator.opacity(0.5), lineWidth: 0.7)
                }
        }
        .huriCard()
    }

    private var actionPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Modifier")
                    .font(.headline)
                HStack(spacing: 8) {
                    toolButton("rotate.left", label: "Gauche") {
                        model.rotateSelection(clockwise: false)
                    }
                    toolButton("rotate.right", label: "Droite") {
                        model.rotateSelection(clockwise: true)
                    }
                }
                HStack(spacing: 8) {
                    toolButton("arrow.up", label: "Monter") {
                        model.moveSelection(by: -1)
                    }
                    toolButton("arrow.down", label: "Descendre") {
                        model.moveSelection(by: 1)
                    }
                }
                Button(role: .destructive) {
                    model.deleteSelection()
                } label: {
                    Label("Supprimer la sélection", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(model.selection.isEmpty)

                Divider()

                Text("Assembler")
                    .font(.headline)
                Button {
                    model.exportMerged()
                } label: {
                    Label("Fusionner et exporter", systemImage: "square.stack.3d.up.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HuriPrimaryButtonStyle())
                .disabled(model.operation.isWorking)

                Button {
                    model.exportSelection()
                } label: {
                    Label("Extraire la sélection", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(model.selection.isEmpty || model.operation.isWorking)

                Divider()

                Text("Découper le document")
                    .font(.headline)
                if let source = model.selectedSourceURL {
                    Text(source.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Picker("Mode", selection: $model.splitEveryPage) {
                    Text("Chaque page").tag(true)
                    Text("Plages").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if !model.splitEveryPage {
                    TextField("1-3, 5, 8-10", text: $model.rangeExpression)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Plages de pages")
                    Text("Exemple : 1-3, 5, 8-10")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Button {
                    model.splitSelectedDocument()
                } label: {
                    Label("Découper…", systemImage: "scissors")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(model.selectedSourceURL == nil || model.operation.isWorking)
            }
            .padding(16)
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: HuriTheme.radius))
        .overlay {
            RoundedRectangle(cornerRadius: HuriTheme.radius)
                .stroke(.separator.opacity(0.55), lineWidth: 0.7)
        }
    }

    @ViewBuilder
    private var operationBanner: some View {
        switch model.operation {
        case .idle:
            EmptyView()
        case let .working(message):
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                Text(message)
                    .font(.callout.weight(.medium))
                Spacer()
                Button("Annuler") {
                    model.cancelOperation()
                }
            }
            .huriCard()
        case let .success(message, _):
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(HuriTheme.mint)
                Text(message)
                    .font(.callout.weight(.medium))
                Spacer()
                Button("Fermer") {
                    model.dismissOperation()
                }
                Button {
                    model.revealOperationResults()
                } label: {
                    Label("Afficher dans le Finder", systemImage: "finder")
                }
                .buttonStyle(.borderedProminent)
                .tint(HuriTheme.indigo)
            }
            .huriCard()
        case let .failure(message):
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .foregroundStyle(HuriTheme.coral)
                Text(message)
                    .font(.callout)
                    .lineLimit(2)
                Spacer()
                Button("Fermer") {
                    model.dismissOperation()
                }
            }
            .huriCard()
        }
    }

    private func toolButton(
        _ symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.bordered)
        .disabled(model.selection.isEmpty)
    }

    private func openPDFPanel() {
        let panel = NSOpenPanel()
        panel.title = "Ajouter des documents PDF"
        panel.prompt = "Ajouter"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.pdf]
        if panel.runModal() == .OK {
            model.importPDFs(panel.urls)
        }
    }
}

private struct PDFPageRow: View {
    let page: PDFPageReference

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            PDFPageThumbnail(reference: page)
            VStack(alignment: .leading, spacing: 4) {
                Text("Page \(page.sourcePageIndex + 1)")
                    .font(.callout.weight(.medium))
                Text(page.sourceURL.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if page.rotation != 0 {
                    Label("\(page.rotation)°", systemImage: "rotate.right")
                        .font(.caption2)
                        .foregroundStyle(HuriTheme.coral)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Page \(page.sourcePageIndex + 1), \(page.sourceURL.lastPathComponent), rotation \(page.rotation) degrés"
        )
    }
}
