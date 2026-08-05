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
          eyebrow: HuriL10n.text("pdf.eyebrow"),
          title: HuriL10n.text("pdf.title"),
          subtitle: HuriL10n.text("pdf.subtitle")
        )
        Spacer()
        Label(
          HuriL10n.format("pdf.pages.count", arguments: model.pages.count),
          systemImage: "doc.text"
        )
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
    .navigationTitle(HuriL10n.text("nav.pdfTools"))
    .toolbar {
      ToolbarItemGroup {
        Button {
          openPDFPanel()
        } label: {
          Label(HuriL10n.text("pdf.add"), systemImage: "plus")
        }
        .help(HuriL10n.text("pdf.addHelp"))
        Button(role: .destructive) {
          model.removeAll()
        } label: {
          Label(HuriL10n.text("pdf.clear"), systemImage: "trash")
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
        Text(
          model.dropIsTargeted
            ? HuriL10n.text("pdf.empty.release")
            : HuriL10n.text("pdf.empty.title")
        )
        .font(.title2.weight(.semibold))
        Text(HuriL10n.text("pdf.empty.subtitle"))
          .foregroundStyle(.secondary)
      }
      Button(HuriL10n.text("pdf.choose"), action: openPDFPanel)
        .buttonStyle(HuriPrimaryButtonStyle())
      Text(HuriL10n.text("pdf.empty.tip"))
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
    .accessibilityElement(children: .contain)
    .accessibilityAction(named: HuriL10n.text("pdf.choose"), openPDFPanel)
  }

  private var editor: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 14) {
        pageList
          .frame(width: 310)
        preview
          .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
        actionPanel
          .frame(width: 252)
      }

      HStack(spacing: 14) {
        pageList
          .frame(width: 240)
        VStack(spacing: 14) {
          preview
            .frame(minWidth: 300, maxWidth: .infinity, minHeight: 220)
          actionPanel
            .frame(maxWidth: .infinity, maxHeight: 215)
        }
      }
    }
    .frame(minHeight: 450)
  }

  private var pageList: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(HuriL10n.text("pdf.pages"))
            .font(.headline)
          Text(
            HuriL10n.plural(
              singular: "pdf.documents.one",
              plural: "pdf.documents.other",
              count: model.uniqueDocumentCount
            )
          )
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
        .help(HuriL10n.text("pdf.addHelp"))
      }

      List(selection: $model.selection) {
        ForEach(model.pages) { page in
          PDFPageRow(page: page)
            .tag(page.id)
            .contextMenu {
              Button(HuriL10n.text("pdf.action.rotateLeft")) {
                model.selectOnly(page)
                model.rotateSelection(clockwise: false)
              }
              Button(HuriL10n.text("pdf.action.rotateRight")) {
                model.selectOnly(page)
                model.rotateSelection(clockwise: true)
              }
              Divider()
              Button(HuriL10n.text("common.delete"), role: .destructive) {
                model.selectOnly(page)
                model.deleteSelection()
              }
            }
        }
        .onMove(perform: model.move)
      }
      .listStyle(.inset)
      .clipShape(RoundedRectangle(cornerRadius: 10))

      Text(HuriL10n.text("pdf.reorderHelp"))
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
        Label(HuriL10n.text("pdf.preview"), systemImage: "eye")
          .font(.headline)
        Spacer()
        if let page = model.primarySelection {
          Text(
            HuriL10n.format(
              "pdf.preview.detail",
              arguments:
                page.sourceURL.lastPathComponent,
              page.sourcePageIndex + 1
            )
          )
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
        Text(HuriL10n.text("pdf.action.modify"))
          .font(.headline)
        HStack(spacing: 8) {
          toolButton("rotate.left", label: HuriL10n.text("pdf.action.rotateLeft")) {
            model.rotateSelection(clockwise: false)
          }
          toolButton("rotate.right", label: HuriL10n.text("pdf.action.rotateRight")) {
            model.rotateSelection(clockwise: true)
          }
        }
        HStack(spacing: 8) {
          toolButton("arrow.up", label: HuriL10n.text("pdf.action.up")) {
            model.moveSelection(by: -1)
          }
          toolButton("arrow.down", label: HuriL10n.text("pdf.action.down")) {
            model.moveSelection(by: 1)
          }
        }
        Button(role: .destructive) {
          model.deleteSelection()
        } label: {
          Label(HuriL10n.text("pdf.action.deleteSelection"), systemImage: "trash")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(model.selection.isEmpty)

        Divider()

        Text(HuriL10n.text("pdf.action.assemble"))
          .font(.headline)
        Button {
          model.exportMerged()
        } label: {
          Label(
            HuriL10n.text("pdf.action.mergeExport"),
            systemImage: "square.stack.3d.up.fill"
          )
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(HuriPrimaryButtonStyle())
        .disabled(model.operation.isWorking)

        Button {
          model.exportSelection()
        } label: {
          Label(
            HuriL10n.text("pdf.action.extract"),
            systemImage: "square.and.arrow.up"
          )
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(model.selection.isEmpty || model.operation.isWorking)

        Divider()

        Text(HuriL10n.text("pdf.action.splitDocument"))
          .font(.headline)
        if let source = model.selectedSourceURL {
          Text(source.lastPathComponent)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        Picker(HuriL10n.text("pdf.mode"), selection: $model.splitEveryPage) {
          Text(HuriL10n.text("pdf.mode.everyPage")).tag(true)
          Text(HuriL10n.text("pdf.mode.ranges")).tag(false)
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        if !model.splitEveryPage {
          TextField("1-3, 5, 8-10", text: $model.rangeExpression)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(HuriL10n.text("pdf.range.label"))
          Text(HuriL10n.text("pdf.range.example"))
            .font(.caption2)
            .foregroundStyle(.secondary)
        }

        Button {
          model.splitSelectedDocument()
        } label: {
          Label(HuriL10n.text("pdf.action.split"), systemImage: "scissors")
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
    case .working(let message):
      HStack(spacing: 12) {
        ProgressView()
          .controlSize(.small)
        Text(message)
          .font(.callout.weight(.medium))
        Spacer()
        Button(HuriL10n.text("common.cancel")) {
          model.cancelOperation()
        }
      }
      .huriCard()
    case .success(let message, _):
      HStack(spacing: 12) {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(HuriTheme.successText)
        Text(message)
          .font(.callout.weight(.medium))
        Spacer()
        Button(HuriL10n.text("common.close")) {
          model.dismissOperation()
        }
        Button {
          model.revealOperationResults()
        } label: {
          Label(HuriL10n.text("common.showInFinder"), systemImage: "finder")
        }
        .buttonStyle(.borderedProminent)
        .tint(HuriTheme.indigo)
      }
      .huriCard()
    case .failure(let message):
      HStack(spacing: 12) {
        Image(systemName: "exclamationmark.octagon.fill")
          .foregroundStyle(HuriTheme.warningText)
        Text(message)
          .font(.callout)
          .lineLimit(2)
        Spacer()
        Button(HuriL10n.text("common.close")) {
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
          .lineLimit(1)
          .minimumScaleFactor(0.72)
      }
      .frame(maxWidth: .infinity, minHeight: 40)
    }
    .buttonStyle(.bordered)
    .disabled(model.selection.isEmpty)
  }

  private func openPDFPanel() {
    let panel = NSOpenPanel()
    panel.title = HuriL10n.text("pdf.addHelp")
    panel.prompt = HuriL10n.text("common.add")
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
        Text(
          HuriL10n.format(
            "pdf.page",
            arguments: page.sourcePageIndex + 1
          )
        )
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
      HuriL10n.format(
        "pdf.accessibility.page",
        arguments:
          page.sourcePageIndex + 1,
        page.sourceURL.lastPathComponent,
        page.rotation
      )
    )
  }
}
