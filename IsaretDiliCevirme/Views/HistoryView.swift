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
                TranslationVideoDetailView(record: record) { correctedSentence in
                    viewModel.correctRecord(id: record.id, correctedSentence: correctedSentence)
                    selectedRecord = viewModel.record(id: record.id)
                }
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
                        Text(record.displaySentence)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if record.isCorrected {
                            Label("Düzeltilmiş", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.accentGreen)

                            Text("İlk tahmin: \(record.sentence)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

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
    let onSaveCorrection: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var correctedSentenceText: String
    @State private var correctionDraft: String
    @State private var showsCorrectionEditor = false
    @State private var hasCorrection: Bool

    init(record: TranslationRecord, onSaveCorrection: @escaping (String) -> Void) {
        self.record = record
        self.onSaveCorrection = onSaveCorrection
        _correctedSentenceText = State(initialValue: record.displaySentence)
        _correctionDraft = State(initialValue: record.displaySentence)
        _hasCorrection = State(initialValue: record.isCorrected)
    }

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
                detailFooter
            }
            .sheet(isPresented: $showsCorrectionEditor) {
                CorrectionEditorSheet(
                    originalSentence: record.sentence,
                    draftSentence: $correctionDraft,
                    hasCorrection: hasCorrection
                ) { savedSentence in
                    correctedSentenceText = savedSentence
                    correctionDraft = savedSentence
                    hasCorrection = true
                    showsCorrectionEditor = false
                    onSaveCorrection(savedSentence)
                } onCancel: {
                    correctionDraft = correctedSentenceText
                    showsCorrectionEditor = false
                }
                .presentationDetents([.height(380), .medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var detailFooter: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(correctedSentenceText)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if hasCorrection {
                    Label("Düzeltilmiş tahmin", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                }
            }

            if hasCorrection {
                Text("İlk tahmin: \(record.sentence)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Divider()

            HStack(spacing: 10) {
                Label(record.formattedTimestamp, systemImage: "calendar")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Label("Güven: \(record.confidenceText)", systemImage: "waveform.path.ecg")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

            }

            Button {
                correctionDraft = correctedSentenceText
                showsCorrectionEditor = true
            } label: {
                Label(hasCorrection ? "Düzeltmeyi Güncelle" : "Tahmini Düzelt", systemImage: "pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: AppColors.primaryGradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: AppColors.primary.opacity(0.22), radius: 9, y: 5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial)
    }
}

private struct CorrectionEditorSheet: View {
    let originalSentence: String
    @Binding var draftSentence: String
    let hasCorrection: Bool
    let onSave: (String) -> Void
    let onCancel: () -> Void

    private var trimmedDraft: String {
        draftSentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
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

                    VStack(alignment: .leading, spacing: 3) {
                        Text(hasCorrection ? "Düzeltmeyi Güncelle" : "Tahmini Düzelt")
                            .font(.system(size: 22, weight: .bold, design: .rounded))

                        Text("Doğru çeviriyi yaz ve kaydı güncelle.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("İlk tahmin")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(originalSentence)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Doğru çeviri")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.primary)

                    TextEditor(text: $draftSentence)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 96)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.primary.opacity(0.28), lineWidth: 1)
                        )
                }

                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    Button {
                        onCancel()
                    } label: {
                        Text("Vazgeç")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        guard !trimmedDraft.isEmpty else { return }
                        onSave(trimmedDraft)
                    } label: {
                        Label("Kaydet", systemImage: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        LinearGradient(
                                            colors: trimmedDraft.isEmpty ? [.gray.opacity(0.55), .gray.opacity(0.45)] : AppColors.primaryGradient,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                    .disabled(trimmedDraft.isEmpty)
                }
            }
            .padding(20)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
