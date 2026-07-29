import AppKit
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
    case .convert: HuriL10n.text("nav.convert")
    case .pdfTools: HuriL10n.text("nav.pdfTools")
    case .about: HuriL10n.text("nav.about")
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
  @AppStorage(HuriOnboarding.completedVersionKey)
  private var completedOnboardingVersion = 0

  @State private var destination: HuriDestination? = .convert
  @State private var showsOnboarding = false
  @State private var didEvaluateOnboarding = false
  @State private var showsTour = false
  @State private var tourStep = HuriTourTarget.sidebar
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
          max: 280
        )
    } detail: {
      detail
        .background {
          Color(nsColor: .windowBackgroundColor)
          HuriTheme.canvasGradient
        }
    }
    .tint(HuriTheme.lagoon)
    .onAppear(perform: evaluateOnboarding)
    .sheet(isPresented: $showsOnboarding, onDismiss: onboardingWasDismissed) {
      OnboardingView(
        onSkip: { completeOnboarding(startTour: false) },
        onFinish: { completeOnboarding(startTour: true) }
      )
    }
    .overlayPreferenceValue(HuriTourAnchorKey.self) { anchors in
      if showsTour {
        HuriTourOverlay(
          anchors: anchors,
          step: $tourStep,
          onSkip: finishTour,
          onFinish: finishTour
        )
      }
    }
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

      Section(HuriL10n.text("sidebar.localSection")) {
        Label(
          HuriL10n.text("sidebar.localProcessing"),
          systemImage: "lock.shield"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        Text(HuriL10n.text("sidebar.noNetwork"))
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
    .navigationTitle(HuriCore.applicationName)
    .overlay(alignment: .topLeading) {
      Color.clear
        .frame(width: HuriTheme.sidebarWidth - 28, height: 34)
        .offset(x: 14, y: 40)
        .allowsHitTesting(false)
        .huriTourTarget(.pdfTools)
    }
    .safeAreaInset(edge: .bottom) {
      HStack(spacing: 8) {
        Circle()
          .fill(HuriTheme.mint)
          .frame(width: 7, height: 7)
          .shadow(color: HuriTheme.mint.opacity(0.7), radius: 5)
        Text(HuriL10n.text("sidebar.ready"))
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
      }
      .padding(12)
    }
    .huriTourTarget(.sidebar)
  }

  @ViewBuilder
  private var detail: some View {
    switch destination ?? .convert {
    case .convert:
      ConversionWorkspaceView(model: conversionModel)
    case .pdfTools:
      PDFToolsView(model: pdfModel)
    case .about:
      AboutView(onReplayOnboarding: replayOnboarding)
    }
  }

  private func evaluateOnboarding() {
    guard !didEvaluateOnboarding else { return }
    didEvaluateOnboarding = true
    guard !ProcessInfo.processInfo.arguments.contains("--skip-onboarding") else { return }
    showsOnboarding = HuriOnboarding.shouldPresent(
      completedVersion: completedOnboardingVersion
    )
  }

  private func completeOnboarding(startTour: Bool) {
    completedOnboardingVersion = HuriOnboarding.currentVersion
    showsOnboarding = false
    guard startTour else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
      destination = .convert
      tourStep = .sidebar
      showsTour = true
    }
  }

  private func onboardingWasDismissed() {
    if completedOnboardingVersion < HuriOnboarding.currentVersion {
      completedOnboardingVersion = HuriOnboarding.currentVersion
    }
  }

  private func replayOnboarding() {
    showsTour = false
    showsOnboarding = true
  }

  private func finishTour() {
    showsTour = false
    tourStep = .sidebar
  }
}

struct AboutView: View {
  let onReplayOnboarding: () -> Void

  private var version: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? "—"
  }

  private var build: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
      ?? "—"
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        Image(nsImage: NSApplication.shared.applicationIconImage)
          .resizable()
          .interpolation(.high)
          .frame(width: 124, height: 124)
          .shadow(color: HuriTheme.ocean.opacity(0.28), radius: 24, y: 12)
          .accessibilityHidden(true)

        VStack(spacing: 7) {
          Text(HuriCore.applicationName)
            .font(.system(size: 38, weight: .bold, design: .rounded))
          Text(HuriCore.tagline)
            .font(.title3)
            .foregroundStyle(.secondary)
          Text(HuriL10n.text("about.developedBy"))
            .font(.callout.weight(.medium))
            .foregroundStyle(HuriTheme.lagoon)
        }

        HStack(spacing: 12) {
          feature(
            HuriL10n.text("about.feature.conversion"),
            symbol: "arrow.triangle.2.circlepath",
            color: HuriTheme.lagoon
          )
          feature(
            HuriL10n.text("about.feature.pdf"),
            symbol: "doc.on.doc",
            color: HuriTheme.indigo
          )
          feature(
            HuriL10n.text("about.feature.privacy"),
            symbol: "lock.shield",
            color: HuriTheme.mint
          )
        }

        HStack(spacing: 10) {
          Link(destination: HuriCore.websiteURL) {
            Label(HuriL10n.text("about.website"), systemImage: "globe")
          }
          Link(destination: URL(string: "mailto:\(HuriCore.supportEmail)")!) {
            Label(HuriL10n.text("about.contact"), systemImage: "envelope")
          }
          Link(destination: HuriCore.githubURL) {
            Label(
              HuriL10n.text("about.github"), systemImage: "chevron.left.forwardslash.chevron.right")
          }
        }
        .buttonStyle(.bordered)

        Button(action: onReplayOnboarding) {
          Label(
            HuriL10n.text("about.replayOnboarding"),
            systemImage: "sparkles.rectangle.stack"
          )
        }
        .buttonStyle(HuriPrimaryButtonStyle())

        VStack(spacing: 4) {
          Text(
            HuriL10n.format(
              "about.versionBuild",
              arguments: version,
              build
            )
          )
          Text(HuriL10n.text("about.copyright"))
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
      }
      .padding(40)
      .frame(maxWidth: 860)
      .frame(maxWidth: .infinity)
    }
    .navigationTitle(HuriL10n.text("nav.about"))
  }

  private func feature(_ title: String, symbol: String, color: Color) -> some View {
    VStack(spacing: 10) {
      Image(systemName: symbol)
        .font(.title2)
        .foregroundStyle(color)
      Text(title)
        .font(.callout.weight(.medium))
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, minHeight: 90)
    .huriCard()
  }
}
