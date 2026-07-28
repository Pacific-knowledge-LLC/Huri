import HuriCore
import HuriInfrastructure
import SwiftUI

enum HuriDestination: String, Hashable, CaseIterable, Identifiable {
    case convert
    case pdfTools
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .convert: "Convertir"
        case .pdfTools: "Outils PDF"
        case .about: "À propos"
        }
    }

    var symbol: String {
        switch self {
        case .convert: "arrow.triangle.2.circlepath"
        case .pdfTools: "doc.on.doc"
        case .about: "info.circle"
        }
    }
}

struct HuriRootView: View {
    @State private var destination: HuriDestination? = .convert
    @StateObject private var conversionModel: ConversionViewModel
    @StateObject private var pdfModel: PDFToolsViewModel

    init() {
        let services = HuriServices()
        _conversionModel = StateObject(wrappedValue: ConversionViewModel(services: services))
        _pdfModel = StateObject(wrappedValue: PDFToolsViewModel(services: services))
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(
                    min: HuriTheme.sidebarWidth,
                    ideal: HuriTheme.sidebarWidth,
                    max: 260
                )
        } detail: {
            detail
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .tint(HuriTheme.indigo)
    }

    private var sidebar: some View {
        List(selection: $destination) {
            Section {
                ForEach(HuriDestination.allCases) { item in
                    Label(item.title, systemImage: item.symbol)
                        .tag(item)
                        .accessibilityLabel(item.title)
                }
            }

            Section("Sur cet appareil") {
                Label("Traitement local", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Zéro envoi réseau.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .navigationTitle("Huri")
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Circle()
                    .fill(HuriTheme.mint)
                    .frame(width: 7, height: 7)
                Text("Prêt à convertir")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch destination ?? .convert {
        case .convert:
            ConversionWorkspaceView(model: conversionModel)
        case .pdfTools:
            PDFToolsView(model: pdfModel)
        case .about:
            AboutView()
        }
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [HuriTheme.indigo, HuriTheme.coral],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 92, height: 92)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: HuriTheme.indigo.opacity(0.25), radius: 18, y: 8)

            VStack(spacing: 7) {
                Text(HuriCore.applicationName)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(HuriCore.tagline)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                Label("Conversions intelligentes", systemImage: "sparkles")
                Label("Outils PDF précis", systemImage: "doc.on.doc")
                Label("100 % local et privé", systemImage: "lock.shield")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(20)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))

            Text("Version 1.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .navigationTitle("À propos")
    }
}
