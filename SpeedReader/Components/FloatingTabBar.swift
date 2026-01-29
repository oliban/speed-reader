//
//  FloatingTabBar.swift
//  SpeedReader
//
//  Floating pill-style tab bar for Hyperfocus Noir design
//

import SwiftUI

// MARK: - Tab Item

enum TabItem: CaseIterable {
    case home, library, settings

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .library: return "books.vertical.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var title: String {
        switch self {
        case .home: return "Home"
        case .library: return "Library"
        case .settings: return "Settings"
        }
    }
}

// MARK: - Floating Tab Bar

struct FloatingTabBar: View {
    @Binding var selectedTab: TabItem
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Design Constants

    private enum Layout {
        static let height: CGFloat = 60
        static let horizontalPadding: CGFloat = 40
        static let bottomPadding: CGFloat = 8
        static let iconSize: CGFloat = 24
        static let glowRadius: CGFloat = 8
        static let shadowRadius: CGFloat = 12
        static let shadowOpacity: Double = 0.3
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .frame(height: Layout.height)
        .background(tabBarBackground)
        .clipShape(Capsule())
        .shadow(
            color: Color.black.opacity(Layout.shadowOpacity),
            radius: Layout.shadowRadius,
            x: 0,
            y: 4
        )
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, Layout.bottomPadding)
    }

    // MARK: - Tab Button

    @ViewBuilder
    private func tabButton(for tab: TabItem) -> some View {
        let isSelected = selectedTab == tab

        Button {
            withAnimation(.srQuick) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    // Glow effect for active tab
                    if isSelected {
                        Image(systemName: tab.icon)
                            .font(.system(size: Layout.iconSize, weight: .medium))
                            .foregroundColor(.adaptiveAccent)
                            .blur(radius: Layout.glowRadius)
                            .opacity(0.6)
                    }

                    // Main icon
                    Image(systemName: tab.icon)
                        .font(.system(size: Layout.iconSize, weight: .medium))
                        .foregroundColor(isSelected ? .adaptiveAccent : .ash)
                }

                // Tab title
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .adaptiveAccent : .ash)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(TabButtonStyle())
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Background

    @ViewBuilder
    private var tabBarBackground: some View {
        if colorScheme == .dark {
            Color.inkBlack
                .background(.ultraThinMaterial)
        } else {
            Color.cream
                .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Tab Button Style

private struct TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.srQuick, value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Floating Tab Bar - Dark") {
    ZStack {
        Color.voidBlack
            .ignoresSafeArea()

        VStack {
            Spacer()

            Text("Content Area")
                .foregroundColor(.bone)

            Spacer()

            FloatingTabBar(selectedTab: .constant(.home))
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Floating Tab Bar - Light") {
    ZStack {
        Color.paper
            .ignoresSafeArea()

        VStack {
            Spacer()

            Text("Content Area")
                .foregroundColor(.graphite)

            Spacer()

            FloatingTabBar(selectedTab: .constant(.library))
        }
    }
    .preferredColorScheme(.light)
}

#Preview("Tab Selection Animation") {
    struct PreviewWrapper: View {
        @State private var selectedTab: TabItem = .home

        var body: some View {
            ZStack {
                Color.adaptiveBackground
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    Text("Selected: \(selectedTab.title)")
                        .font(.title2)
                        .foregroundColor(.adaptivePrimaryText)

                    Spacer()

                    FloatingTabBar(selectedTab: $selectedTab)
                }
            }
        }
    }

    return PreviewWrapper()
}
