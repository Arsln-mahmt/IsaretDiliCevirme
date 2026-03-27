//
//  SettingsView.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 9.03.2026.
//

import SwiftUI

/// Settings screen with theme selection and project information.
struct SettingsView: View {
    
    

    @AppStorage("appTheme") private var selectedTheme: String = AppTheme.system.rawValue

    /// The currently selected theme enum value.
    private var currentTheme: AppTheme {
        AppTheme(rawValue: selectedTheme) ?? .system
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Appearance Section
                Section{
                    Picker("Görünüm", selection: $selectedTheme) {
                        ForEach(AppTheme.allCases){
                            theme in
                            Text(theme.rawValue.capitalized)
                                .tag(theme)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.vertical, 8)
                } header: {
                    Label("Görünüm", systemImage: "paintbrush.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                        .textCase(nil)
                }
                
                // MARK: - Architecture Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        pipelineStep(step: "1", text: "Kamera görüntüsü yakalar", icon: "camera.fill")
                        pipelineStep(step: "2", text: "Vision ile el noktaları algılanır", icon: "hand.raised.fill")
                        pipelineStep(step: "3", text: "LSTM modeli hareketi tahmin eder", icon: "brain.fill")
                        pipelineStep(step: "4", text: "Sonuç ekranda gösterilir", icon: "text.bubble.fill")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("Nasıl Çalışır?", systemImage: "questionmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.accentRed)
                        .textCase(nil)
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 60)
            }
        }
    }

    // MARK: - Theme Row

    private func themeRow(_ theme: AppTheme) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTheme = theme.rawValue
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: theme.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(currentTheme == theme ? AppColors.primary : .secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        (currentTheme == theme ? AppColors.primary.opacity(0.15) : Color.secondary.opacity(0.1)),
                        in: RoundedRectangle(cornerRadius: 8)
                    )

                Text(theme.displayName)
                    .font(.system(size: 15, weight: currentTheme == theme ? .semibold : .regular))
                    .foregroundStyle(.primary)

                Spacer()

                if currentTheme == theme {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColors.primary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - About Row

    private func aboutRow(icon: String, title: String, detail: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Pipeline Step

    private func pipelineStep(step: String, text: String, icon: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accentRed.opacity(0.15))
                    .frame(width: 26, height: 26)
                Text(step)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.accentRed)
            }

            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.primary.opacity(0.85))
        }
    }
}

#Preview {
    SettingsView()
}
