//
//  HistoryView.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 9.03.2026.
//

import SwiftUI

/// Displays a list of previously detected sign language words with timestamps.
struct HistoryView: View {

    @Bindable var viewModel: HistoryViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.records.isEmpty {
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
                if !viewModel.records.isEmpty {
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
        }
    }

    // MARK: - Records List

    private var recordsList: some View {
        List {
            ForEach(viewModel.records) { record in
                HStack(spacing: 16) {
                    // Word with accent color indicator
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: AppColors.primaryGradient,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 4, height: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.word)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))

                            Text("Güven: \(record.confidenceText)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Timestamp
                    Text(record.formattedTime)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            .onDelete { offsets in
                withAnimation {
                    viewModel.removeRecords(at: offsets)
                }
            }
        }
        .listStyle(.insetGrouped)
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

            Text("Algılanan işaret hareketleri burada görünecek.")
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
