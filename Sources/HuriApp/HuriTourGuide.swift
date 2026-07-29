import HuriCore
import SwiftUI

enum HuriTourTarget: Int, CaseIterable, Hashable {
  case sidebar
  case importZone
  case settings
  case privacy
  case pdfTools

  var titleKey: String {
    switch self {
    case .sidebar: "tour.sidebar.title"
    case .importZone: "tour.import.title"
    case .settings: "tour.settings.title"
    case .privacy: "tour.privacy.title"
    case .pdfTools: "tour.pdf.title"
    }
  }

  var bodyKey: String {
    switch self {
    case .sidebar: "tour.sidebar.body"
    case .importZone: "tour.import.body"
    case .settings: "tour.settings.body"
    case .privacy: "tour.privacy.body"
    case .pdfTools: "tour.pdf.body"
    }
  }
}

struct HuriTourAnchorKey: PreferenceKey {
  static let defaultValue: [HuriTourTarget: Anchor<CGRect>] = [:]

  static func reduce(
    value: inout [HuriTourTarget: Anchor<CGRect>],
    nextValue: () -> [HuriTourTarget: Anchor<CGRect>]
  ) {
    value.merge(nextValue(), uniquingKeysWith: { _, next in next })
  }
}

extension View {
  func huriTourTarget(_ target: HuriTourTarget) -> some View {
    anchorPreference(key: HuriTourAnchorKey.self, value: .bounds) {
      [target: $0]
    }
  }
}

struct HuriTourOverlay: View {
  let anchors: [HuriTourTarget: Anchor<CGRect>]
  @Binding var step: HuriTourTarget
  let onSkip: () -> Void
  let onFinish: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Color.black.opacity(0.48)
          .ignoresSafeArea()

        if let rect = highlightRect(in: proxy) {
          RoundedRectangle(cornerRadius: 16)
            .stroke(HuriTheme.lagoon, lineWidth: 3)
            .shadow(color: HuriTheme.lagoon.opacity(0.7), radius: 12)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .accessibilityHidden(true)
        }

        VStack {
          Spacer()
          tourCard
            .padding(24)
        }
      }
      .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: step)
    }
    .transition(.opacity)
    .zIndex(50)
  }

  private func highlightRect(in proxy: GeometryProxy) -> CGRect? {
    if step == .pdfTools {
      return CGRect(
        x: 10,
        y: 40,
        width: min(HuriTheme.sidebarWidth - 20, proxy.size.width * 0.25),
        height: 34
      )
    }
    guard let anchor = anchors[step] else { return nil }
    return proxy[anchor].insetBy(dx: -8, dy: -8)
  }

  private var tourCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("\(step.rawValue + 1) / \(HuriTourTarget.allCases.count)")
          .font(.caption.monospacedDigit().weight(.semibold))
          .foregroundStyle(HuriTheme.lagoon)
        Spacer()
        Button(HuriL10n.text("common.skip"), action: onSkip)
          .buttonStyle(.plain)
          .foregroundStyle(.secondary)
      }

      VStack(alignment: .leading, spacing: 6) {
        Text(HuriL10n.text(step.titleKey))
          .font(.title2.bold())
        Text(HuriL10n.text(step.bodyKey))
          .font(.body)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      HStack {
        Button(HuriL10n.text("common.previous"), action: previous)
          .disabled(step == HuriTourTarget.allCases.first!)
        Spacer()
        Button(
          step == HuriTourTarget.allCases.last
            ? HuriL10n.text("tour.finish")
            : HuriL10n.text("common.next"),
          action: next
        )
        .buttonStyle(HuriPrimaryButtonStyle())
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(maxWidth: 520)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    .overlay {
      RoundedRectangle(cornerRadius: 20)
        .stroke(HuriTheme.lagoon.opacity(0.35), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.28), radius: 30, y: 14)
  }

  private func previous() {
    guard let index = HuriTourTarget.allCases.firstIndex(of: step), index > 0 else {
      return
    }
    step = HuriTourTarget.allCases[index - 1]
  }

  private func next() {
    guard let index = HuriTourTarget.allCases.firstIndex(of: step) else { return }
    if index == HuriTourTarget.allCases.count - 1 {
      onFinish()
    } else {
      step = HuriTourTarget.allCases[index + 1]
    }
  }
}
