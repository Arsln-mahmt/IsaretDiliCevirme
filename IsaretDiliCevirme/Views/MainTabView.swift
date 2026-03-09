//
//  MainTabView.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 9.03.2026.
//

import SwiftUI

/// Tab identifiers.
enum AppTab: Int, CaseIterable {
    case history   = 0
    case translate = 1
    case settings  = 2

    var title: String {
        switch self {
        case .history:   return "Geçmiş"
        case .translate: return "Çeviri"
        case .settings:  return "Ayarlar"
        }
    }

    var icon: String {
        switch self {
        case .history:   return "clock"
        case .translate: return "hand.wave.fill"
        case .settings:  return "gearshape"
        }
    }
}

/// Main navigation with a custom tab bar.
/// The center Translate tab is visually larger and acts as the primary action.
struct MainTabView: View {

    @State private var selectedTab: AppTab = .translate
    @State private var historyViewModel = HistoryViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: - Native Tab Content
            // Native TabView prevents destroying and recreating views (like the heavy camera) on switch.
            TabView(selection: $selectedTab) {
                HistoryView(viewModel: historyViewModel)
                    .tag(AppTab.history)
                    .toolbar(.hidden, for: .tabBar)

                LiveCameraView()
                    .tag(AppTab.translate)
                    .toolbar(.hidden, for: .tabBar)

                SettingsView()
                    .tag(AppTab.settings)
                    .toolbar(.hidden, for: .tabBar)
            }

            // MARK: - Custom Tab Bar
            Group {
                if selectedTab != .translate {
                    // Show styled tab bar on non-camera tabs
                    customTabBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    // Minimal floating tab bar on camera tab
                    cameraTabBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // Only animate the tab bar changes, not the heavy underlying views
            .animation(.easeInOut(duration: 0.25), value: selectedTab)
        }
    }

    // MARK: - Standard Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            // History tab
            tabButton(for: .history)

            // Center translate button (larger)
            centerButton

            // Settings tab
            tabButton(for: .settings)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10) // Small padding; iOS auto-adds safe area below this
        .background(
            tabBarBackground
        )
    }

    // MARK: - Camera Tab Bar (minimal)

    private var cameraTabBar: some View {
        HStack(spacing: 0) {
            // History tab
            tabButton(for: .history, lightStyle: true)

            Spacer()

            // Center indicator (active)
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 48, height: 48)
                        .shadow(color: AppColors.primary.opacity(0.5), radius: 8, y: 3)

                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(AppColors.cameraOverlayText)
                }

                Text("Çeviri")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.cameraOverlayText)
            }
            .frame(maxWidth: .infinity)
            .offset(y: -6)
            .padding(.bottom, -6)

            Spacer()

            // Settings tab
            tabButton(for: .settings, lightStyle: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [AppColors.cameraBackground.opacity(0.8), AppColors.cameraBackground.opacity(0.6), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Tab Button

    private func tabButton(for tab: AppTab, lightStyle: Bool = false) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(
                        lightStyle
                            ? (selectedTab == tab ? AppColors.tabCameraActive : AppColors.tabCameraInactive)
                            : (selectedTab == tab ? AppColors.tabActive : AppColors.tabInactive)
                    )

                Text(tab.title)
                    .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(
                        lightStyle
                            ? (selectedTab == tab ? AppColors.tabCameraActive : AppColors.tabCameraInactive)
                            : (selectedTab == tab ? AppColors.tabActive : AppColors.tabInactive)
                    )
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Center Button

    private var centerButton: some View {
        Button {
            selectedTab = .translate
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: AppColors.primaryGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: AppColors.primary.opacity(0.4), radius: 8, y: 3)

                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                }

                Text("Çeviri")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
            }
            .frame(maxWidth: .infinity)
            // Slightly float the center button to give it prominence without breaking layout height
            .offset(y: -6)
            .padding(.bottom, -6)
        }
    }

    // MARK: - Tab Bar Background

    private var tabBarBackground: some View {
        UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
            .fill(.ultraThinMaterial)
            .overlay(
                UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
            .ignoresSafeArea()
    }
}

#Preview {
    MainTabView()
}
