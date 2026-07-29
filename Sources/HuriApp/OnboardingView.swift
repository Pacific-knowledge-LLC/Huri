import HuriCore
import SwiftUI

enum HuriOnboarding {
  static let currentVersion = 1
  static let completedVersionKey = "huri.onboarding.completedVersion"

  static func shouldPresent(completedVersion: Int) -> Bool {
    completedVersion < currentVersion
  }
}

struct OnboardingView: View {
  let onSkip: () -> Void
  let onFinish: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var pageIndex = 0

  private let pages = OnboardingPage.allCases

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      page
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      Divider()
      footer
    }
    .frame(width: 720, height: 560)
    .background(HuriTheme.canvasGradient)
    .accessibilityElement(children: .contain)
  }

  private var header: some View {
    HStack(spacing: 14) {
      HuriTransformationMark(size: 38)
      VStack(alignment: .leading, spacing: 2) {
        Text(HuriL10n.text("onboarding.title"))
          .font(.headline)
        Text(HuriL10n.text("onboarding.subtitle"))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button(HuriL10n.text("common.skip"), action: onSkip)
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 18)
  }

  private var page: some View {
    let current = pages[pageIndex]
    return VStack(spacing: 24) {
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [
                current.color.opacity(0.18),
                HuriTheme.indigo.opacity(0.05),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 184, height: 184)
        Circle()
          .stroke(current.color.opacity(0.22), lineWidth: 1)
          .frame(width: 150, height: 150)
        Image(systemName: current.symbol)
          .font(.system(size: 66, weight: .medium))
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(current.color)
      }
      .accessibilityHidden(true)

      VStack(spacing: 10) {
        Text(HuriL10n.text(current.titleKey))
          .font(.system(size: 32, weight: .bold, design: .rounded))
          .multilineTextAlignment(.center)
        Text(HuriL10n.text(current.bodyKey))
          .font(.title3)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .lineSpacing(4)
          .frame(maxWidth: 520)
      }

      HStack(spacing: 8) {
        ForEach(pages.indices, id: \.self) { index in
          Capsule()
            .fill(index == pageIndex ? current.color : Color.secondary.opacity(0.18))
            .frame(width: index == pageIndex ? 28 : 8, height: 8)
        }
      }
      .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: pageIndex)
      .accessibilityLabel("\(pageIndex + 1) / \(pages.count)")
    }
    .padding(38)
    .id(pageIndex)
    .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.98)))
  }

  private var footer: some View {
    HStack {
      Button(HuriL10n.text("common.previous")) {
        move(to: pageIndex - 1)
      }
      .disabled(pageIndex == 0)

      Spacer()

      if pageIndex == pages.count - 1 {
        Button(HuriL10n.text("onboarding.finish"), action: onFinish)
          .buttonStyle(HuriPrimaryButtonStyle())
          .keyboardShortcut(.defaultAction)
      } else {
        Button(HuriL10n.text("common.next")) {
          move(to: pageIndex + 1)
        }
        .buttonStyle(HuriPrimaryButtonStyle())
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 18)
  }

  private func move(to index: Int) {
    guard pages.indices.contains(index) else { return }
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
      pageIndex = index
    }
  }
}

private enum OnboardingPage: CaseIterable {
  case conversion
  case pdf
  case privacy

  var titleKey: String {
    switch self {
    case .conversion: "onboarding.page.conversion.title"
    case .pdf: "onboarding.page.pdf.title"
    case .privacy: "onboarding.page.privacy.title"
    }
  }

  var bodyKey: String {
    switch self {
    case .conversion: "onboarding.page.conversion.body"
    case .pdf: "onboarding.page.pdf.body"
    case .privacy: "onboarding.page.privacy.body"
    }
  }

  var symbol: String {
    switch self {
    case .conversion: "arrow.triangle.2.circlepath"
    case .pdf: "doc.on.doc"
    case .privacy: "lock.shield"
    }
  }

  var color: Color {
    switch self {
    case .conversion: HuriTheme.lagoon
    case .pdf: HuriTheme.indigo
    case .privacy: HuriTheme.mint
    }
  }
}
