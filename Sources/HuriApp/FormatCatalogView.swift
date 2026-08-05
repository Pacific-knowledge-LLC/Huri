import HuriCore
import SwiftUI

struct FormatCatalogView: View {
  @ObservedObject var model: ConversionViewModel
  let onConvert: () -> Void

  @State private var search = ""
  @State private var selectedFamily = "all"

  private var availableFormats: Set<FileFormat> {
    model.availableFormatSet
  }

  private var visibleDescriptors: [FormatDescriptor] {
    let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
    return FormatCatalog.entries.filter { descriptor in
      let matchesFamily =
        selectedFamily == "all" || descriptor.format.family.rawValue == selectedFamily
      let matchesQuery =
        query.isEmpty
        || descriptor.format.displayName.localizedCaseInsensitiveContains(query)
        || descriptor.format.family.displayName.localizedCaseInsensitiveContains(query)
      return matchesFamily && matchesQuery
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        header
        metrics
        filters
        catalog
      }
      .padding(28)
      .frame(maxWidth: 1180, alignment: .leading)
    }
    .navigationTitle(HuriL10n.text("nav.formats"))
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 20) {
      HuriSectionTitle(
        eyebrow: HuriL10n.text("formats.eyebrow"),
        title: HuriL10n.text("formats.title"),
        subtitle: HuriL10n.text("formats.subtitle")
      )
      Spacer()
      Button(action: onConvert) {
        Label(
          HuriL10n.text("formats.start"),
          systemImage: "arrow.triangle.2.circlepath"
        )
      }
      .buttonStyle(HuriPrimaryButtonStyle())
    }
  }

  private var metrics: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 190), spacing: 12)],
      spacing: 12
    ) {
      metric(
        value: "\(FormatCatalog.entries.count)",
        label: HuriL10n.text("formats.metric.catalog"),
        symbol: "square.grid.3x3"
      )
      metric(
        value: "\(availableFormats.count)",
        label: HuriL10n.text("formats.metric.available"),
        symbol: "checkmark.seal"
      )
      metric(
        value: "\(model.availableBackends.count)",
        label: HuriL10n.text("formats.metric.engines"),
        symbol: "gearshape.2"
      )
      metric(
        value: "0",
        label: HuriL10n.text("formats.metric.uploads"),
        symbol: "icloud.slash"
      )
    }
  }

  private func metric(value: String, label: String, symbol: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: symbol)
        .font(.title3)
        .foregroundStyle(HuriTheme.indigo)
        .frame(width: 34, height: 34)
        .background(HuriTheme.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
      VStack(alignment: .leading, spacing: 2) {
        Text(value)
          .font(.title3.monospacedDigit().weight(.bold))
        Text(label)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .huriCard()
  }

  private var filters: some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField(HuriL10n.text("formats.search"), text: $search)
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel(HuriL10n.text("formats.search"))

      Picker(HuriL10n.text("formats.family"), selection: $selectedFamily) {
        Text(HuriL10n.text("formats.family.all")).tag("all")
        ForEach(
          FileFamily.allCases.filter { ![.unsupported, .pdf, .text].contains($0) },
          id: \.self
        ) { family in
          Text(family.displayName).tag(family.rawValue)
        }
      }
      .pickerStyle(.menu)

      HStack {
        Text(
          HuriL10n.format(
            "formats.results",
            arguments: visibleDescriptors.count
          )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        Spacer()
        Text(model.availableBackends.map(\.displayName).joined(separator: " · "))
          .font(.caption2)
          .foregroundStyle(.tertiary)
          .lineLimit(1)
      }
    }
  }

  private var catalog: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 210), spacing: 12)],
      alignment: .leading,
      spacing: 12
    ) {
      ForEach(visibleDescriptors, id: \.format) { descriptor in
        formatCard(descriptor)
      }
    }
  }

  private func formatCard(_ descriptor: FormatDescriptor) -> some View {
    let available = availableFormats.contains(descriptor.format)
    return VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        Image(systemName: symbol(for: descriptor.format.family))
          .font(.title3)
          .foregroundStyle(available ? HuriTheme.indigo : .secondary)
          .frame(width: 34, height: 34)
          .background(
            (available ? HuriTheme.indigo : Color.secondary).opacity(0.09),
            in: RoundedRectangle(cornerRadius: 9)
          )
        VStack(alignment: .leading, spacing: 2) {
          Text(descriptor.format.displayName)
            .font(.headline.monospaced())
          Text(descriptor.format.family.displayName)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: available ? "checkmark.circle.fill" : "plus.circle.dashed")
          .foregroundStyle(
            available ? HuriTheme.successText : Color.secondary.opacity(0.6)
          )
          .help(
            HuriL10n.text(
              available ? "formats.available" : "formats.engineRequired"
            )
          )
      }

      HStack(spacing: 6) {
        if descriptor.access.canRead {
          FormatBadge(text: HuriL10n.text("formats.input"), color: HuriTheme.indigo)
        }
        if descriptor.access.canWrite {
          FormatBadge(text: HuriL10n.text("formats.output"), color: HuriTheme.accentText)
        }
        Spacer()
      }
    }
    .huriCard()
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(descriptor.format.displayName), \(descriptor.format.family.displayName), "
        + HuriL10n.text(available ? "formats.available" : "formats.engineRequired")
    )
  }

  private func symbol(for family: FileFamily) -> String {
    switch family {
    case .archive: "archivebox"
    case .audio: "waveform"
    case .cad: "ruler"
    case .document, .text: "doc.text"
    case .ebook: "books.vertical"
    case .font: "textformat"
    case .image: "photo"
    case .pdf: "doc.richtext"
    case .presentation: "rectangle.on.rectangle.angled"
    case .vector: "point.3.connected.trianglepath.dotted"
    case .video: "film"
    case .unsupported: "questionmark.square.dashed"
    }
  }
}
