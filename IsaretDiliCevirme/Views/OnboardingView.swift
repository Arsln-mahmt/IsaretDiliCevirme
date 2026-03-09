//
//  OnboardingView.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 9.03.2026.
//

import SwiftUI

/// Onboarding screen shown only on first launch.
/// Uses a paged TabView with 3 informational pages and a "Start" button on the last page.
struct OnboardingView: View {

    /// Callback when onboarding is completed.
    var onComplete: () -> Void

    @State private var currentPage = 0

    // MARK: - Page Data

    private let pages: [(icon: String, title: String, description: String, gradient: [Color])] = [
        (
            icon: "hand.wave.fill",
            title: "İşaretçe'ye Hoş Geldiniz",
            description: "Bu uygulama, kameranızı kullanarak Türk İşaret Dili hareketlerini metne çevirir.",
            gradient: AppColors.onboardingGradient1
        ),
        (
            icon: "hand.raised.fill",
            title: "Elinizi Gösterin",
            description: "Elinizi kameranın önünde tutun ve bir işaret hareketi yapın.",
            gradient: AppColors.onboardingGradient2
        ),
        (
            icon: "bolt.fill",
            title: "Gerçek Zamanlı Çeviri",
            description: "Sistem hareketinizi algılar ve anlamını anında tahmin eder.",
            gradient: AppColors.onboardingGradient3
        )
    ]

    var body: some View {
        ZStack {
            // Dynamic background gradient based on current page
            LinearGradient(
                colors: pages[currentPage].gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        onboardingPage(
                            icon: page.icon,
                            title: page.title,
                            description: page.description
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Custom page indicator + button
                VStack(spacing: 30) {
                    // Page dots
                    HStack(spacing: 10) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? .white : .white.opacity(0.4))
                                .frame(
                                    width: index == currentPage ? 28 : 10,
                                    height: 10
                                )
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }

                    // Action button
                    if currentPage == pages.count - 1 {
                        // Last page: "Start" button
                        Button {
                            onComplete()
                        } label: {
                            HStack(spacing: 8) {
                                Text("Uygulamayı Kullanmaya Başla")
                                    .font(.headline)
                                Image(systemName: "arrow.right")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                .white.opacity(0.25),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.white.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        // Other pages: "Next" button
                        Button {
                            withAnimation {
                                currentPage += 1
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("İleri")
                                    .font(.headline)
                                Image(systemName: "chevron.right")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                .white.opacity(0.2),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                        }
                        .padding(.horizontal, 32)
                    }

                    // Skip button (hidden on last page)
                    if currentPage < pages.count - 1 {
                        Button {
                            onComplete()
                        } label: {
                            Text("Atla")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }

    // MARK: - Page View

    private func onboardingPage(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated icon with glow effect
            ZStack {
                // Glow background
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)

                // Icon circle
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 130, height: 130)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 56, weight: .medium))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            }

            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
