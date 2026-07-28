import AppKit
import HuriCore
import SwiftUI
import UniformTypeIdentifiers

struct ConversionWorkspaceView: View {
    @ObservedObject var model: ConversionViewModel

    var body: some View {
        scrollContent
            .navigationTitle("Convertir")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        openFilePanel()
                    } label: {
                        Label("Ajouter", systemImage: "plus")
                    }
                    .help("Ajouter des fichiers (⌘O)")

                    if !model.items.isEmpty {
                        Button(role: .destructive) {
                            model.removeAll()
                        } label: {
                            Label("Tout retirer", systemImage: "trash")
                        }
                        .help("Retirer tous les fichiers")
                    }
                }
            }
            .focusedValue(\.openFilesAction, openFilePanel)
            .focusedValue(\.startConversionAction) {
                if model.canConvert {
                    model.startConversion()
                }
            }
            .alert(
                "Import incomplet",
                isPresented: Binding(
                    get: { model.importWarning != nil },
                    set: { if !$0 { model.importWarning = nil } }
                )
            ) {
                Button("Compris", role: .cancel) {}
            } message: {
                Text(model.importWarning ?? "")
            }
    }

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    HuriSectionTitle(
                        eyebrow: "Conversion intelligente",
                        title: "Transformez sans compromis",
                        subtitle: "Huri détecte vos fichiers et ne propose que les formats compatibles."
                    )
                    Spacer()
                    privacyPill
                }

                if model.items.isEmpty {
                    emptyWorkspace
                } else {
                    populatedWorkspace
                }
            }
            .padding(28)
            .frame(maxWidth: 1180, alignment: .leading)
        }
    }

    private var privacyPill: some View {
        Label("100 % local", systemImage: "lock.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(HuriTheme.mint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(HuriTheme.mint.opacity(0.1), in: Capsule())
            .accessibilityLabel("Traitement entièrement local")
    }

    private var emptyWorkspace: some View {
        DropZoneView(
            isTargeted: $model.dropIsTargeted,
            isLoading: model.isImporting,
            title: "Déposez vos fichiers ici",
            subtitle: "Images, PDF, documents, audio ou vidéo",
            actionTitle: "Choisir des fichiers",
            action: openFilePanel,
            onDrop: model.importFiles
        )
        .frame(minHeight: 390)
    }

    private var populatedWorkspace: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                fileList
                    .frame(maxWidth: .infinity)
                settings
                    .frame(width: 300)
            }
            statusAndAction
        }
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fichiers")
                        .font(.headline)
                    Text("\(model.items.count) élément\(model.items.count > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    openFilePanel()
                } label: {
                    Label("Ajouter", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            VStack(spacing: 8) {
                ForEach(model.items) { item in
                    ImportedAssetRow(item: item) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            model.remove(item.id)
                        }
                    }
                }
                if model.isImporting {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Analyse des nouveaux fichiers…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(12)
                }
            }

            compactDropTarget
        }
        .huriCard()
    }

    private var compactDropTarget: some View {
        HStack {
            Image(systemName: model.dropIsTargeted ? "arrow.down.doc.fill" : "arrow.down.doc")
                .foregroundStyle(HuriTheme.indigo)
            Text(model.dropIsTargeted ? "Relâchez pour ajouter" : "Vous pouvez déposer d’autres fichiers")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(10)
        .background(
            HuriTheme.indigo.opacity(model.dropIsTargeted ? 0.12 : 0.045),
            in: RoundedRectangle(cornerRadius: 9)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(
                    HuriTheme.indigo.opacity(model.dropIsTargeted ? 0.65 : 0.2),
                    style: StrokeStyle(lineWidth: 1, dash: [5])
                )
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.importFiles(urls)
            return !urls.isEmpty
        } isTargeted: { targeted in
            withAnimation(.easeOut(duration: 0.15)) {
                model.dropIsTargeted = targeted
            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Format de sortie")
                    .font(.headline)
                if model.supportedOutputs.isEmpty {
                    Label(
                        "Aucun format commun pour ce lot.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.callout)
                    .foregroundStyle(HuriTheme.coral)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 70), spacing: 8)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(model.supportedOutputs) { format in
                            FormatChoice(
                                format: format,
                                selected: model.selectedOutput == format
                            ) {
                                model.selectOutput(format)
                            }
                        }
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 13) {
                Text("Réglages")
                    .font(.headline)

                if model.selectedOutput?.isLossy == true {
                    LabeledContent("Qualité", value: "\(Int(model.quality * 100)) %")
                        .font(.callout)
                    Slider(value: $model.quality, in: 0.35...1, step: 0.01)
                        .accessibilityLabel("Qualité de sortie")
                }

                Picker("Taille", selection: $model.scale) {
                    Text("50 %").tag(0.5)
                    Text("100 %").tag(1.0)
                    Text("200 %").tag(2.0)
                    Text("400 %").tag(4.0)
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Échelle de sortie")

                if model.items.contains(where: { $0.asset.family == .pdf }) {
                    Picker("Résolution PDF", selection: $model.pdfDPI) {
                        Text("72 ppp").tag(72)
                        Text("144 ppp").tag(144)
                        Text("300 ppp").tag(300)
                        Text("600 ppp").tag(600)
                    }
                    .pickerStyle(.menu)
                }

                Toggle("Conserver les métadonnées", isOn: $model.preserveMetadata)
                    .font(.callout)

                if model.selectedOutput == .png {
                    VStack(alignment: .leading, spacing: 5) {
                        Toggle(isOn: $model.removeBackground) {
                            Label("Retirer l’arrière-plan", systemImage: "wand.and.stars")
                        }
                        .font(.callout.weight(.medium))
                        .disabled(!model.acceptsBackgroundRemoval)
                        Text("Analyse intelligente sur l’appareil.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(HuriTheme.coral.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Text("Destination")
                    .font(.headline)
                Button {
                    model.chooseDestination()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .foregroundStyle(HuriTheme.indigo)
                        Text(model.destinationDirectory.lastPathComponent)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Changer le dossier de destination")
                Text(model.destinationDirectory.path(percentEncoded: false))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .huriCard()
    }

    @ViewBuilder
    private var statusAndAction: some View {
        switch model.state {
        case .idle:
            HStack {
                Label(
                    "\(model.items.count) fichier\(model.items.count > 1 ? "s" : "") prêt\(model.items.count > 1 ? "s" : "")",
                    systemImage: "checkmark.circle"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                Spacer()
                Button {
                    model.startConversion()
                } label: {
                    Label("Convertir maintenant", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(HuriPrimaryButtonStyle())
                .disabled(!model.canConvert)
                .accessibilityHint("Lance la conversion vers le format sélectionné")
            }
            .huriCard()

        case let .converting(progress):
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Conversion en cours")
                            .font(.headline)
                        Text(progress.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int(progress.fraction * 100)) %")
                        .font(.title3.monospacedDigit().weight(.semibold))
                    Button("Annuler", role: .cancel) {
                        model.cancelConversion()
                    }
                    .buttonStyle(.bordered)
                }
                ProgressView(value: progress.fraction)
                    .tint(HuriTheme.indigo)
            }
            .huriCard()

        case let .success(result):
            HStack(spacing: 13) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(HuriTheme.mint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Conversion terminée")
                        .font(.headline)
                    Text(
                        "\(result.artifacts.count) fichier\(result.artifacts.count > 1 ? "s" : "") créé\(result.artifacts.count > 1 ? "s" : "") en \(result.duration.formatted(.number.precision(.fractionLength(1)))) s"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Fermer") {
                    model.dismissStatus()
                }
                Button {
                    model.revealResult()
                } label: {
                    Label("Afficher dans le Finder", systemImage: "finder")
                }
                .buttonStyle(HuriPrimaryButtonStyle())
            }
            .huriCard()

        case let .failure(message):
            HStack(spacing: 13) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.title2)
                    .foregroundStyle(HuriTheme.coral)
                VStack(alignment: .leading, spacing: 3) {
                    Text("La conversion a échoué")
                        .font(.headline)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Spacer()
                Button("Réessayer") {
                    model.startConversion()
                }
                .buttonStyle(.borderedProminent)
                .tint(HuriTheme.indigo)
            }
            .huriCard()
        }
    }

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.title = "Choisir les fichiers à convertir"
        panel.prompt = "Ajouter"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.data, .content]
        if panel.runModal() == .OK {
            model.importFiles(panel.urls)
        }
    }
}

private struct DropZoneView: View {
    @Binding var isTargeted: Bool
    let isLoading: Bool
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void
    let onDrop: ([URL]) -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(HuriTheme.indigo.opacity(isTargeted ? 0.18 : 0.09))
                    .frame(width: 82, height: 82)
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    Image(systemName: isTargeted ? "arrow.down.doc.fill" : "doc.badge.plus")
                        .font(.system(size: 34, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(HuriTheme.indigo)
                }
            }
            VStack(spacing: 6) {
                Text(isTargeted ? "Relâchez pour importer" : title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            Button(actionTitle, action: action)
                .buttonStyle(HuriPrimaryButtonStyle())
            HStack(spacing: 14) {
                Label("Détection automatique", systemImage: "sparkles")
                Label("Traitement privé", systemImage: "lock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(36)
        .background(
            LinearGradient(
                colors: [
                    HuriTheme.indigo.opacity(isTargeted ? 0.12 : 0.045),
                    HuriTheme.coral.opacity(isTargeted ? 0.07 : 0.018),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    HuriTheme.indigo.opacity(isTargeted ? 0.75 : 0.24),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.2, dash: [8, 6])
                )
        }
        .animation(.easeOut(duration: 0.15), value: isTargeted)
        .dropDestination(for: URL.self) { urls, _ in
            onDrop(urls)
            return !urls.isEmpty
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zone d’import de fichiers")
    }
}

private struct ImportedAssetRow: View {
    let item: ImportedAsset
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let preview = item.preview {
                    Image(nsImage: preview)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: symbol)
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(HuriTheme.indigo)
                }
            }
            .frame(width: 48, height: 48)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.asset.filename)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 7) {
                    FormatBadge(text: item.asset.format.displayName)
                    Text(metadataText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let warning = item.asset.detectionWarning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(HuriTheme.coral)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button(role: .destructive, action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Retirer \(item.asset.filename)")
            .accessibilityLabel("Retirer \(item.asset.filename)")
        }
        .padding(10)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 11))
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch item.asset.family {
        case .image: "photo"
        case .pdf: "doc.richtext"
        case .document, .text: "doc.text"
        case .audio: "waveform"
        case .video: "film"
        case .unsupported: "questionmark.square.dashed"
        }
    }

    private var metadataText: String {
        var parts: [String] = [
            ByteCountFormatter.string(
                fromByteCount: item.asset.metadata.byteCount,
                countStyle: .file
            ),
        ]
        if let width = item.asset.metadata.width, let height = item.asset.metadata.height {
            parts.append("\(width) × \(height)")
        }
        if let pages = item.asset.metadata.pageCount {
            parts.append("\(pages) page\(pages > 1 ? "s" : "")")
        }
        if let duration = item.asset.metadata.duration {
            parts.append(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond)))
        }
        return parts.joined(separator: " · ")
    }
}

private struct FormatChoice: View {
    let format: FileFormat
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.body)
                Text(format.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(
                selected ? HuriTheme.indigo : Color.secondary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 9)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(selected ? Color.clear : Color.secondary.opacity(0.14))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Convertir en \(format.displayName)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var symbol: String {
        switch format.family {
        case .image: "photo"
        case .pdf: "doc.richtext"
        case .audio: "waveform"
        case .video: "film"
        default: "doc"
        }
    }
}
