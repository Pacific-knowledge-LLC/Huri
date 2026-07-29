import AppKit
import Foundation
import HuriCore
import HuriInfrastructure
import UniformTypeIdentifiers

enum PDFOperationState {
  case idle
  case working(String)
  case success(message: String, urls: [URL])
  case failure(String)

  var isWorking: Bool {
    if case .working = self { true } else { false }
  }
}

@MainActor
final class PDFToolsViewModel: ObservableObject {
  @Published var pages: [PDFPageReference] = []
  @Published var selection: Set<UUID> = []
  @Published private(set) var isImporting = false
  @Published private(set) var operation: PDFOperationState = .idle
  @Published var dropIsTargeted = false
  @Published var splitEveryPage = true
  @Published var rangeExpression = "1-3, 5"

  private let services: HuriServices
  private var operationTask: Task<Void, Never>?

  init(services: HuriServices) {
    self.services = services
  }

  var primarySelection: PDFPageReference? {
    pages.first { selection.contains($0.id) } ?? pages.first
  }

  var selectedPages: [PDFPageReference] {
    let selected = pages.filter { selection.contains($0.id) }
    return selected.isEmpty ? pages : selected
  }

  var selectedSourceURL: URL? {
    primarySelection?.sourceURL
  }

  var uniqueDocumentCount: Int {
    Set(pages.map(\.sourceURL)).count
  }

  func importPDFs(_ urls: [URL]) {
    let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
    guard !pdfs.isEmpty else {
      operation = .failure(HuriL10n.text("pdf.error.selectAtLeastOne"))
      return
    }
    let existingSources = Set(pages.map { $0.sourceURL.standardizedFileURL })
    let candidates = pdfs.filter { !existingSources.contains($0.standardizedFileURL) }
    guard !candidates.isEmpty else { return }

    isImporting = true
    operation = .idle
    let editor = services.pdfEditor
    Task { [weak self] in
      do {
        let imported = try await editor.pages(in: candidates)
        guard let self else { return }
        pages.append(contentsOf: imported)
        if selection.isEmpty, let first = imported.first {
          selection = [first.id]
        }
        isImporting = false
      } catch {
        self?.isImporting = false
        self?.operation = .failure(error.localizedDescription)
      }
    }
  }

  func selectOnly(_ page: PDFPageReference) {
    selection = [page.id]
  }

  func rotateSelection(clockwise: Bool) {
    let delta = clockwise ? 90 : -90
    let affected = selection.isEmpty ? Set(primarySelection.map { [$0.id] } ?? []) : selection
    for index in pages.indices where affected.contains(pages[index].id) {
      pages[index].rotation = normalizedRotation(pages[index].rotation + delta)
    }
    operation = .idle
  }

  func deleteSelection() {
    let ids = selection
    guard !ids.isEmpty else { return }
    let firstDeletedIndex = pages.firstIndex { ids.contains($0.id) } ?? 0
    pages.removeAll { ids.contains($0.id) }
    selection.removeAll()
    if !pages.isEmpty {
      selection = [pages[min(firstDeletedIndex, pages.count - 1)].id]
    }
    operation = .idle
  }

  func removeAll() {
    pages.removeAll()
    selection.removeAll()
    operation = .idle
  }

  func move(from offsets: IndexSet, to destination: Int) {
    pages.move(fromOffsets: offsets, toOffset: destination)
    operation = .idle
  }

  func moveSelection(by offset: Int) {
    guard selection.count == 1,
      let id = selection.first,
      let current = pages.firstIndex(where: { $0.id == id })
    else { return }
    let target = current + offset
    guard pages.indices.contains(target) else { return }
    pages.swapAt(current, target)
    operation = .idle
  }

  func exportMerged() {
    guard !pages.isEmpty,
      let destination = savePDFPanel(
        title: HuriL10n.text("pdf.export.merged.title")
      )
    else {
      return
    }
    export(
      plan: PDFEditorPlan(pages: pages),
      to: destination,
      operationKey: "pdf.operation.merge"
    )
  }

  func exportSelection() {
    let selection = selectedPages
    guard !selection.isEmpty,
      let destination = savePDFPanel(
        title: HuriL10n.text("pdf.export.selection.title")
      )
    else { return }
    export(
      plan: PDFEditorPlan(pages: selection),
      to: destination,
      operationKey: "pdf.operation.extraction"
    )
  }

  func splitSelectedDocument() {
    guard let sourceURL = selectedSourceURL else { return }
    let panel = NSOpenPanel()
    panel.title = HuriL10n.text("pdf.split.folder.title")
    panel.prompt = HuriL10n.text("pdf.split.folder.prompt")
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let destination = panel.url else { return }

    let mode: PDFSplitMode
    if splitEveryPage {
      mode = .everyPage
    } else {
      do {
        mode = .ranges(try parseRanges(rangeExpression))
      } catch {
        operation = .failure(error.localizedDescription)
        return
      }
    }

    operation = .working(
      HuriL10n.format(
        "pdf.split.working",
        arguments: sourceURL.lastPathComponent
      )
    )
    let editor = services.pdfEditor
    operationTask = Task { [weak self] in
      do {
        let urls = try await editor.split(url: sourceURL, mode: mode, to: destination)
        guard !Task.isCancelled else { return }
        self?.operation = .success(
          message: HuriL10n.plural(
            singular: "pdf.split.success.one",
            plural: "pdf.split.success.other",
            count: urls.count
          ),
          urls: urls
        )
      } catch is CancellationError {
        self?.operation = .idle
      } catch {
        self?.operation = .failure(error.localizedDescription)
      }
    }
  }

  func cancelOperation() {
    operationTask?.cancel()
    operationTask = nil
    operation = .idle
  }

  func revealOperationResults() {
    guard case .success(_, let urls) = operation, !urls.isEmpty else { return }
    NSWorkspace.shared.activateFileViewerSelecting(urls)
  }

  func dismissOperation() {
    operation = .idle
  }

  private func export(plan: PDFEditorPlan, to destination: URL, operationKey: String) {
    let operationName = HuriL10n.text(operationKey)
    operation = .working(
      HuriL10n.format("pdf.operation.working", arguments: operationName)
    )
    let editor = services.pdfEditor
    operationTask = Task { [weak self] in
      do {
        try await editor.export(plan: plan, to: destination)
        guard !Task.isCancelled else { return }
        self?.operation = .success(
          message: HuriL10n.format(
            "pdf.operation.completed",
            arguments: operationName
          ),
          urls: [destination]
        )
      } catch is CancellationError {
        self?.operation = .idle
      } catch {
        self?.operation = .failure(error.localizedDescription)
      }
    }
  }

  private func savePDFPanel(title: String) -> URL? {
    let panel = NSSavePanel()
    panel.title = title
    panel.prompt = HuriL10n.text("pdf.export.prompt")
    panel.nameFieldStringValue = "Huri.pdf"
    panel.allowedContentTypes = [.pdf]
    panel.canCreateDirectories = true
    return panel.runModal() == .OK ? panel.url : nil
  }

  private func parseRanges(_ expression: String) throws -> [ClosedRange<Int>] {
    let components = expression.split(separator: ",", omittingEmptySubsequences: true)
    var ranges: [ClosedRange<Int>] = []
    for component in components {
      let value = component.trimmingCharacters(in: .whitespaces)
      let bounds = value.split(separator: "-", omittingEmptySubsequences: true)
      if bounds.count == 1, let page = Int(bounds[0]), page > 0 {
        ranges.append((page - 1)...(page - 1))
      } else if bounds.count == 2,
        let lower = Int(bounds[0]),
        let upper = Int(bounds[1]),
        lower > 0,
        upper >= lower
      {
        ranges.append((lower - 1)...(upper - 1))
      } else {
        throw PDFRangeError.invalidExpression
      }
    }
    guard !ranges.isEmpty else {
      throw PDFRangeError.invalidExpression
    }
    return ranges
  }

  private func normalizedRotation(_ value: Int) -> Int {
    ((value % 360) + 360) % 360
  }
}

private enum PDFRangeError: LocalizedError {
  case invalidExpression

  var errorDescription: String? {
    HuriL10n.text("pdf.error.invalidRanges")
  }
}
