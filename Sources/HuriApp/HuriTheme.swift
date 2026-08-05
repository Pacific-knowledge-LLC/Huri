import AppKit
import SwiftUI

enum HuriTheme {
  static let ocean = Color(red: 0.035, green: 0.078, blue: 0.18)
  static let oceanSoft = Color(red: 0.08, green: 0.16, blue: 0.31)
  static let lagoon = Color(red: 0.00, green: 0.69, blue: 0.76)
  static let indigo = Color(red: 0.24, green: 0.34, blue: 0.96)
  static let indigoDeep = Color(red: 0.14, green: 0.20, blue: 0.64)
  static let coral = Color(red: 0.98, green: 0.36, blue: 0.31)
  static let mint = Color(red: 0.04, green: 0.72, blue: 0.58)
  static let accentText = adaptive(
    light: NSColor(red: 0.00, green: 0.38, blue: 0.44, alpha: 1),
    dark: NSColor(red: 0.28, green: 0.86, blue: 0.90, alpha: 1)
  )
  static let successText = adaptive(
    light: NSColor(red: 0.00, green: 0.40, blue: 0.29, alpha: 1),
    dark: NSColor(red: 0.28, green: 0.90, blue: 0.72, alpha: 1)
  )
  static let warningText = adaptive(
    light: NSColor(red: 0.72, green: 0.14, blue: 0.10, alpha: 1),
    dark: NSColor(red: 1.00, green: 0.51, blue: 0.45, alpha: 1)
  )
  static let sidebarWidth: CGFloat = 226
  static let radius: CGFloat = 18
  static let smallRadius: CGFloat = 11
  static let spacing: CGFloat = 18

  static let brandGradient = LinearGradient(
    colors: [lagoon, indigo, coral],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static let coolGradient = LinearGradient(
    colors: [indigoDeep, indigo],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static let canvasGradient = LinearGradient(
    colors: [lagoon.opacity(0.045), indigo.opacity(0.025), Color.clear],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  private static func adaptive(light: NSColor, dark: NSColor) -> Color {
    Color(
      nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
      }
    )
  }
}

struct HuriCard<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    content
      .padding(HuriTheme.spacing)
      .background(.background.secondary, in: RoundedRectangle(cornerRadius: HuriTheme.radius))
      .overlay {
        RoundedRectangle(cornerRadius: HuriTheme.radius)
          .stroke(
            LinearGradient(
              colors: [
                HuriTheme.lagoon.opacity(0.22),
                Color.secondary.opacity(0.12),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 0.8
          )
      }
      .shadow(color: HuriTheme.ocean.opacity(0.06), radius: 16, y: 8)
  }
}

struct HuriSectionTitle: View {
  let eyebrow: String
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(eyebrow.uppercased())
        .font(.caption.weight(.semibold))
        .tracking(0.8)
        .foregroundStyle(HuriTheme.accentText)
      Text(title)
        .font(.system(size: 28, weight: .bold, design: .rounded))
      Text(subtitle)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
  }
}

struct HuriPrimaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.body.weight(.semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 18)
      .frame(minHeight: 38)
      .background(
        HuriTheme.coolGradient,
        in: RoundedRectangle(cornerRadius: HuriTheme.smallRadius)
      )
      .shadow(
        color: HuriTheme.indigo.opacity(configuration.isPressed ? 0.08 : 0.22),
        radius: configuration.isPressed ? 4 : 10,
        y: configuration.isPressed ? 2 : 5
      )
      .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.42)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
  }
}

struct FormatBadge: View {
  let text: String
  var color = HuriTheme.indigo

  var body: some View {
    Text(text)
      .font(.caption2.weight(.bold))
      .foregroundStyle(color)
      .padding(.horizontal, 7)
      .padding(.vertical, 4)
      .background(color.opacity(0.11), in: Capsule())
  }
}

extension View {
  func huriCard() -> some View {
    padding(HuriTheme.spacing)
      .background(.background.secondary, in: RoundedRectangle(cornerRadius: HuriTheme.radius))
      .overlay {
        RoundedRectangle(cornerRadius: HuriTheme.radius)
          .stroke(
            LinearGradient(
              colors: [
                HuriTheme.lagoon.opacity(0.22),
                Color.secondary.opacity(0.12),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 0.8
          )
      }
      .shadow(color: HuriTheme.ocean.opacity(0.06), radius: 16, y: 8)
  }
}

struct HuriTransformationMark: View {
  var size: CGFloat = 96

  var body: some View {
    ZStack {
      Circle()
        .trim(from: 0.05, to: 0.47)
        .stroke(
          HuriTheme.lagoon,
          style: StrokeStyle(lineWidth: size * 0.18, lineCap: .round)
        )
        .rotationEffect(.degrees(-24))
      Circle()
        .trim(from: 0.05, to: 0.47)
        .stroke(
          HuriTheme.indigo,
          style: StrokeStyle(lineWidth: size * 0.18, lineCap: .round)
        )
        .rotationEffect(.degrees(156))
      Circle()
        .trim(from: 0.005, to: 0.13)
        .stroke(
          HuriTheme.coral,
          style: StrokeStyle(lineWidth: size * 0.10, lineCap: .round)
        )
        .rotationEffect(.degrees(60))
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}
