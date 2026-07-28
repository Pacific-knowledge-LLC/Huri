import SwiftUI

enum HuriTheme {
    static let indigo = Color(red: 0.31, green: 0.28, blue: 0.93)
    static let indigoDeep = Color(red: 0.20, green: 0.17, blue: 0.69)
    static let coral = Color(red: 1.00, green: 0.39, blue: 0.35)
    static let mint = Color(red: 0.18, green: 0.72, blue: 0.58)
    static let sidebarWidth: CGFloat = 218
    static let radius: CGFloat = 16
    static let smallRadius: CGFloat = 10
    static let spacing: CGFloat = 16
}

struct HuriCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(HuriTheme.spacing)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: HuriTheme.radius))
            .overlay {
                RoundedRectangle(cornerRadius: HuriTheme.radius)
                    .stroke(.separator.opacity(0.55), lineWidth: 0.7)
            }
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
                .foregroundStyle(HuriTheme.indigo)
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
                LinearGradient(
                    colors: [HuriTheme.indigo, HuriTheme.indigoDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: HuriTheme.smallRadius)
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
                    .stroke(.separator.opacity(0.55), lineWidth: 0.7)
            }
    }
}
