//
//  HistoryView.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 9.03.2026.
//

import SwiftUI
import AVKit

/// Displays a list of previously saved sentence translations with timestamps.
struct HistoryView: View {

    @Bindable var viewModel: HistoryViewModel
    @State private var selectedRecord: TranslationRecord?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.savedVideoRecords.isEmpty {
                    emptyStateView
                } else {
                    recordsList
                }
            }
            .navigationTitle("Geçmiş")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 60)
            }
            .toolbar {
                if !viewModel.savedVideoRecords.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Temizle", role: .destructive) {
                            withAnimation {
                                viewModel.clearAll()
                            }
                        }
                        .foregroundStyle(.red.opacity(0.8))
                    }
                }
            }
            .sheet(item: $selectedRecord) { record in
                TranslationVideoDetailView(record: record)
            }
        }
    }

    // MARK: - Records List

    private var recordsList: some View {
        List {
            ForEach(viewModel.savedVideoRecords) { record in
                recordCard(for: record)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedRecord = record
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .onDelete { offsets in
                withAnimation {
                    viewModel.removeRecords(at: offsets)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    private func recordCard(for record: TranslationRecord) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: AppColors.primaryGradient,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(record.sentence)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(record.formattedTimestamp)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: AppColors.primaryGradient,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )

                        Text("Oynat")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.primary)
                    }
                }

                Label("Güven: \(record.confidenceText)", systemImage: "waveform.path.ecg")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(uiColor: .secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)

            Text("Henüz Geçmiş Yok")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Text("Kaydettiğin videolu cümleler burada görünecek.")
                .font(.system(size: 15))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    HistoryView(viewModel: HistoryViewModel())
}

private struct TranslationVideoDetailView: View {
    let record: TranslationRecord
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
            Group {
                if let videoURL = record.localVideoURL {
                    VideoPlayer(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding()
                        .onAppear {
                            let newPlayer = AVPlayer(url: videoURL)
                            player = newPlayer
                            newPlayer.play()
                        }
                        .onDisappear {
                            player?.pause()
                            player = nil
                        }
                } else {
                    ContentUnavailableView(
                        "Video bulunamadı",
                        systemImage: "video.slash",
                        description: Text("Bu kayıt için lokal video dosyası artık erişilebilir değil.")
                    )
                    .padding()
                }
            }
            .navigationTitle("Kayıt Detayı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.sentence)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))

                    Text(record.formattedTimestamp)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("Güven: \(record.confidenceText)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(.ultraThinMaterial)
            }
        }
    }
}
