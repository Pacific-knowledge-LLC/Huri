import AppKit
import HuriCore
import SwiftUI
import UniformTypeIdentifiers

struct ConversionWorkspaceView: View {
  @ObservedObject var model: ConversionViewModel

  var body: some View {
    scrollContent
      .navigationTitle(HuriL10n.text("nav.convert"))
      .toolbar {
        ToolbarItemGroup {
          Button {
            openFilePanel()
          } label: {
            Label(HuriL10n.text("common.add"), systemImage: "plus")
          }
          .help(HuriL10n.text("conversion.addHelp"))

          if !model.items.isEmpty {
            Button(role: .destructive) {
              model.removeAll()
            } label: {
              Label(HuriL10n.text("conversion.removeAll"), systemImage: "trash")
            }
            .help(HuriL10n.text("conversion.removeAllHelp"))
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
        HuriL10n.text("import.alert.title"),
        isPresented: Binding(
          get: { model.importWarning != nil },
          set: { if !$0 { model.importWarning = nil } }
        )
      ) {
        Button(HuriL10n.text("common.understood"), role: .cancel) {}
      } message: {
        Text(model.importWarning ?? "")
      }
  }

  private var scrollContent: some View {
    ScrollView(.vertical, showsIndicators: true) {
      VStack(alignment: .leading, spacing: 22) {
        HStack(alignment: .top) {
          HuriSectionTitle(
            eyebrow: HuriL10n.text("conversion.eyebrow"),
            title: HuriL10n.text("conversion.title"),
            subtitle: HuriL10n.text("conversion.subtitle")
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
      .huriTourTarget(.settings)
    }
  }

  private var privacyPill: some View {
    Label(HuriL10n.text("conversion.privacy.badge"), systemImage: "lock.fill")
      .font(.caption.weight(.medium))
      .foregroundStyle(HuriTheme.successText)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(HuriTheme.mint.opacity(0.1), in: Capsule())
      .accessibilityLabel(HuriL10n.text("conversion.privacy.accessibility"))
      .huriTourTarget(.privacy)
  }

  private var emptyWorkspace: some View {
    DropZoneView(
      isTargeted: $model.dropIsTargeted,
      isLoading: model.isImporting,
      title: HuriL10n.text("conversion.drop.title"),
      subtitle: HuriL10n.text("conversion.drop.subtitle"),
      actionTitle: HuriL10n.text("conversion.drop.choose"),
      action: openFilePanel,
      onDrop: model.importFiles
    )
    .frame(minHeight: 390)
    .huriTourTarget(.importZone)
  }

  private var populatedWorkspace: some View {
    VStack(spacing: 18) {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: 18) {
          fileList
            .frame(minWidth: 470, maxWidth: .infinity)
          settings
            .frame(width: 310)
        }
        VStack(spacing: 18) {
          fileList
          settings
        }
      }
      statusAndAction
    }
  }

  private var fileList: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(HuriL10n.text("conversion.files"))
            .font(.headline)
          Text(
            HuriL10n.plural(
              singular: "conversion.items.one",
              plural: "conversion.items.other",
              count: model.items.count
            )
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        Spacer()
        Button {
          openFilePanel()
        } label: {
          Label(HuriL10n.text("common.add"), systemImage: "plus")
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
            Text(HuriL10n.text("conversion.analyzing"))
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
      Text(
        model.dropIsTargeted
          ? HuriL10n.text("conversion.drop.release")
          : HuriL10n.text("conversion.drop.addMore")
      )
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
        Text(HuriL10n.text("conversion.outputFormat"))
          .font(.headline)
        if model.supportedOutputs.isEmpty {
          Label(
            HuriL10n.text("conversion.noCommonFormat"),
            systemImage: "exclamationmark.triangle"
          )
          .font(.callout)
          .foregroundStyle(HuriTheme.warningText)
        } else {
          if model.supportedOutputs.count > 9 {
            TextField(
              HuriL10n.text("conversion.output.search"),
              text: $model.outputSearch
            )
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(HuriL10n.text("conversion.output.search"))
          }
          if model.filteredSupportedOutputs.isEmpty {
            Label(
              HuriL10n.text("conversion.output.noResult"),
              systemImage: "magnifyingglass"
            )
            .font(.callout)
            .foregroundStyle(.secondary)
          }
          LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 70), spacing: 8)],
            alignment: .leading,
            spacing: 8
          ) {
            ForEach(model.filteredSupportedOutputs) { format in
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
        Text(HuriL10n.text("conversion.settings"))
          .font(.headline)

        if model.showsQualityOption {
          LabeledContent(
            HuriL10n.text("conversion.quality"),
            value: "\(Int(model.quality * 100)) %"
          )
          .font(.callout)
          Slider(value: $model.quality, in: 0.35...1, step: 0.01)
            .accessibilityLabel(HuriL10n.text("conversion.quality"))
        }

        if model.showsScaleOption {
          Picker(HuriL10n.text("conversion.size"), selection: $model.scale) {
            Text("50 %").tag(0.5)
            Text("100 %").tag(1.0)
            Text("200 %").tag(2.0)
            Text("400 %").tag(4.0)
          }
          .pickerStyle(.menu)
          .accessibilityLabel(HuriL10n.text("conversion.size"))
        }

        if model.showsPDFResolutionOption {
          Picker(HuriL10n.text("conversion.pdfResolution"), selection: $model.pdfDPI) {
            ForEach([72, 144, 300, 600], id: \.self) { dpi in
              Text(HuriL10n.format("conversion.dpi", arguments: dpi))
                .tag(dpi)
            }
          }
          .pickerStyle(.menu)
        }

        if model.showsMetadataOption {
          Toggle(
            HuriL10n.text("conversion.preserveMetadata"),
            isOn: $model.preserveMetadata
          )
          .font(.callout)
        }

        if model.selectedOutput == .png {
          VStack(alignment: .leading, spacing: 5) {
            Toggle(isOn: $model.removeBackground) {
              Label(
                HuriL10n.text("conversion.background.remove"),
                systemImage: "wand.and.stars"
              )
            }
            .font(.callout.weight(.medium))
            .disabled(!model.acceptsBackgroundRemoval)
            Text(HuriL10n.text("conversion.background.help"))
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          .padding(10)
          .background(HuriTheme.coral.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
        }
      }

      Divider()

      VStack(alignment: .leading, spacing: 7) {
        Text(HuriL10n.text("conversion.destination"))
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
        .accessibilityLabel(HuriL10n.text("conversion.destination.change"))
        Text(model.destinationDirectory.path(percentEncoded: false))
          .font(.caption2)
          .foregroundStyle(.tertiary)
          .lineLimit(2)
          .truncationMode(.middle)
      }
    }
    .huriCard()
    .huriTourTarget(.settings)
  }

  @ViewBuilder
  private var statusAndAction: some View {
    switch model.state {
    case .idle:
      HStack {
        Label(
          HuriL10n.plural(
            singular: "conversion.ready.one",
            plural: "conversion.ready.other",
            count: model.items.count
          ),
          systemImage: "checkmark.circle"
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        Spacer()
        Button {
          model.startConversion()
        } label: {
          Label(
            HuriL10n.text("conversion.start"),
            systemImage: "arrow.right.circle.fill"
          )
        }
        .buttonStyle(HuriPrimaryButtonStyle())
        .disabled(!model.canConvert)
        .accessibilityHint(HuriL10n.text("conversion.startHint"))
      }
      .huriCard()

    case .converting(let progress):
      VStack(alignment: .leading, spacing: 11) {
        HStack {
          VStack(alignment: .leading, spacing: 3) {
            Text(HuriL10n.text("conversion.progress.title"))
              .font(.headline)
            Text(progress.message)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Text("\(Int(progress.fraction * 100)) %")
            .font(.title3.monospacedDigit().weight(.semibold))
          Button(HuriL10n.text("common.cancel"), role: .cancel) {
            model.cancelConversion()
          }
          .buttonStyle(.bordered)
        }
        ProgressView(value: progress.fraction)
          .tint(HuriTheme.indigo)
      }
      .huriCard()

    case .success(let result):
      HStack(spacing: 13) {
        Image(systemName: "checkmark.circle.fill")
          .font(.title2)
          .foregroundStyle(HuriTheme.successText)
        VStack(alignment: .leading, spacing: 3) {
          Text(HuriL10n.text("conversion.success.title"))
            .font(.headline)
          Text(
            HuriL10n.format(
              result.artifacts.count == 1
                ? "conversion.success.detail.one"
                : "conversion.success.detail.other",
              arguments:
                result.artifacts.count,
              result.duration.formatted(
                .number.precision(.fractionLength(1))
              )
            )
          )
          .font(.caption)
          .foregroundStyle(.secondary)
          if !result.warnings.isEmpty {
            Text(result.warnings.joined(separator: "\n"))
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(3)
          }
        }
        Spacer()
        Button(HuriL10n.text("common.close")) {
          model.dismissStatus()
        }
        Button {
          model.revealResult()
        } label: {
          Label(HuriL10n.text("common.showInFinder"), systemImage: "finder")
        }
        .buttonStyle(HuriPrimaryButtonStyle())
      }
      .huriCard()

    case .failure(let message):
      HStack(spacing: 13) {
        Image(systemName: "exclamationmark.octagon.fill")
          .font(.title2)
          .foregroundStyle(HuriTheme.warningText)
        VStack(alignment: .leading, spacing: 3) {
          Text(HuriL10n.text("conversion.failure.title"))
            .font(.headline)
          Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
        Spacer()
        Button(HuriL10n.text("common.close")) {
          model.dismissStatus()
        }
        Button(HuriL10n.text("common.retry")) {
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
    panel.title = HuriL10n.text("conversion.panel.title")
    panel.prompt = HuriL10n.text("common.add")
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
        Text(isTargeted ? HuriL10n.text("conversion.drop.release") : title)
          .font(.title2.weight(.semibold))
        Text(subtitle)
          .foregroundStyle(.secondary)
      }
      Button(actionTitle, action: action)
        .buttonStyle(HuriPrimaryButtonStyle())
      HStack(spacing: 14) {
        Label(HuriL10n.text("conversion.drop.detection"), systemImage: "sparkles")
        Label(HuriL10n.text("conversion.drop.private"), systemImage: "lock")
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
    .accessibilityLabel(HuriL10n.text("conversion.drop.zone"))
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
      .help(
        HuriL10n.format(
          "conversion.accessibility.removeFile",
          arguments: item.asset.filename
        )
      )
      .accessibilityLabel(
        HuriL10n.format(
          "conversion.accessibility.removeFile",
          arguments: item.asset.filename
        )
      )
    }
    .padding(10)
    .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 11))
    .accessibilityElement(children: .combine)
  }

  private var symbol: String {
    switch item.asset.family {
    case .archive: "archivebox"
    case .cad: "ruler"
    case .ebook: "books.vertical"
    case .font: "textformat"
    case .image: "photo"
    case .pdf: "doc.richtext"
    case .document, .text: "doc.text"
    case .presentation: "rectangle.on.rectangle.angled"
    case .vector: "point.3.connected.trianglepath.dotted"
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
      )
    ]
    if let width = item.asset.metadata.width, let height = item.asset.metadata.height {
      parts.append("\(width) × \(height)")
    }
    if let pages = item.asset.metadata.pageCount {
      parts.append(
        HuriL10n.plural(
          singular: "conversion.metadata.pages.one",
          plural: "conversion.metadata.pages.other",
          count: pages
        )
      )
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
    .accessibilityLabel(
      HuriL10n.format(
        "conversion.accessibility.format",
        arguments: format.displayName
      )
    )
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private var symbol: String {
    switch format.family {
    case .archive: "archivebox"
    case .cad: "ruler"
    case .document, .text: "doc.text"
    case .ebook: "books.vertical"
    case .font: "textformat"
    case .image: "photo"
    case .pdf: "doc.richtext"
    case .presentation: "rectangle.on.rectangle.angled"
    case .vector: "point.3.connected.trianglepath.dotted"
    case .audio: "waveform"
    case .video: "film"
    case .unsupported: "questionmark.square.dashed"
    }
  }
}
