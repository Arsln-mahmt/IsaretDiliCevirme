//
//  IsaretDiliCevirmeApp.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 9.03.2026.
//

import SwiftUI
import FirebaseCore

@main
struct IsaretDiliCevirmeApp: App {

    /// Tracks whether onboarding has been completed.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    /// Current theme selection (stored as raw string).
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue

    /// Resolved theme enum.
    private var currentTheme: AppTheme {
        AppTheme(rawValue: appThemeRaw) ?? .system
    }

    @State private var showSplash = true

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashView(showSplash: $showSplash)
                } else if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            hasCompletedOnboarding = true
                        }
                    }
                }
            }
            .preferredColorScheme(currentTheme.colorScheme)
        }
    }
}
