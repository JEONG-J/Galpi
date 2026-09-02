//
//  LinkDetailView.swift
//  LinkBoxPresentation
//
//  Created by euijjang97 on 9/1/26.
//

import GalpiDesignSystem
import GalpiKit
import SwiftUI

@MainActor
@Observable
final class LinkDetailViewModel {

    // MARK: - Property

    private let useCases: GalpiUseCases
    private let linkID: UUID

    private(set) var link: Link?
    private(set) var isSummarizing = false

    var memoDraft = ""
    var isEditingMemo = false

    // MARK: - Function

    init(linkID: UUID, useCases: GalpiUseCases) {
        self.linkID = linkID
        self.useCases = useCases
    }

    func load() {
        link = try? useCases.repository.link(id: linkID)
        memoDraft = link?.memo ?? ""
    }

    var tagNames: [String] { (link?.tags ?? []).map(\.name).sorted() }

    var canSummarize: Bool {
        link?.summary == nil && useCases.summaryService.isAvailable && !isSummarizing
    }

    /// 원문을 여는 순간 열람으로 기록한다 — 미열람 뱃지·소비율이 여기서 움직인다.
    func openOriginal(using openURL: OpenURLAction) {
        guard let url = link?.url else { return }
        try? useCases.recordVisit.execute(linkID: linkID, at: .now)
        openURL(url)
        load()
    }

    func saveMemo() {
        guard let link else { return }
        let trimmed = memoDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        link.memo = trimmed.isEmpty ? nil : trimmed
        try? useCases.repository.save()
        isEditingMemo = false
    }

    func toggleFavorite() {
        guard let link else { return }
        link.isFavorite.toggle()
        try? useCases.repository.save()
    }

    func delete() {
        guard let link else { return }
        useCases.repository.delete(link)
        try? useCases.repository.save()
    }

    func summarize() async {
        guard !isSummarizing else { return }
        isSummarizing = true
        await useCases.enrichLink.execute(linkID: linkID, includeSummary: true)
        isSummarizing = false
        load()
    }
}

/// 링크 노트 · 상세 — 시안 ④ 프레임.
struct LinkDetailView: View {

    // MARK: - Property

    @State private var viewModel: LinkDetailViewModel
    @State private var isDeleteConfirmPresented = false

    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    // MARK: - Function

    init(linkID: UUID, useCases: GalpiUseCases) {
        _viewModel = State(initialValue: LinkDetailViewModel(linkID: linkID, useCases: useCases))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            if let link = viewModel.link {
                VStack(alignment: .leading, spacing: 18) {
                    GalpiThumbnail(
                        imageData: link.thumbnailData,
                        symbol: link.glyphSymbol,
                        cornerRadius: 20,
                        glyphSize: 46
                    )
                    .frame(height: 182)

                    heading(link)
                    summarySection(link)
                    memoSection(link)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
        .background(GalpiColor.background)
        .navigationTitle("링크 노트")
        .toolbarTitleDisplayMode(.inline)
        .toolbar { toolbarActions }
        .safeAreaBar(edge: .bottom) { bottomBar }
        // 시안 ④ 는 하단이 '원문 열기' 버튼이라 탭 바가 없다.
        .toolbar(.hidden, for: .tabBar)
        .onAppear { viewModel.load() }
        .confirmationDialog(
            "이 갈피를 삭제할까요?",
            isPresented: $isDeleteConfirmPresented,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                viewModel.delete()
                dismiss()
            }
            Button("취소", role: .cancel) {}
        }
    }

    // MARK: - 제목·출처

    private func heading(_ link: Link) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(link.displayTitle)
                .font(GalpiFont.text(21, .bold))
                .kerning(-0.4)
                .foregroundStyle(GalpiColor.text)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Circle()
                    .fill(GalpiColor.dash)
                    .frame(width: 14, height: 14)
                Text("\(LinkFormat.host(link)) · \(LinkFormat.relativeDay(link.createdAt)) 저장")
                    .font(GalpiFont.text(12, .medium))
                    .foregroundStyle(GalpiColor.textSecondary)
            }
        }
    }

    // MARK: - AI 요약

    @ViewBuilder
    private func summarySection(_ link: Link) -> some View {
        if let summary = link.summary {
            VStack(alignment: .leading, spacing: 10) {
                summaryHeader

                Text(summary)
                    .font(GalpiFont.text(13, .medium))
                    .lineSpacing(13 * 0.55)
                    .foregroundStyle(GalpiColor.text)
                    .fixedSize(horizontal: false, vertical: true)

                if !viewModel.tagNames.isEmpty {
                    HStack(spacing: 7) {
                        ForEach(viewModel.tagNames, id: \.self) { name in
                            Text("#\(name)")
                                .font(GalpiFont.text(11, .semibold))
                                .foregroundStyle(GalpiColor.main)
                                .padding(.horizontal, 10)
                                .frame(height: 26)
                                .background(
                                    GalpiColor.surface.opacity(0.8),
                                    in: .rect(cornerRadius: 13)
                                )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(GalpiColor.aiBox, in: .rect(cornerRadius: 18))
        } else if viewModel.isSummarizing {
            HStack(spacing: 10) {
                ProgressView()
                Text("요약하는 중…")
                    .font(GalpiFont.text(12, .semibold))
                    .foregroundStyle(GalpiColor.main)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(GalpiColor.aiBox, in: .rect(cornerRadius: 18))
        } else if viewModel.canSummarize {
            Button { Task { await viewModel.summarize() } } label: {
                HStack(spacing: 6) {
                    summaryHeader
                    Spacer()
                    Text("만들기")
                        .font(GalpiFont.text(12, .semibold))
                        .foregroundStyle(GalpiColor.main)
                }
                .padding(14)
                .background(GalpiColor.aiBox, in: .rect(cornerRadius: 18))
            }
            .buttonStyle(.plain)
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 5) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
            Text("AI 요약")
                .font(GalpiFont.text(12, .bold))
        }
        .foregroundStyle(GalpiColor.main)
    }

    // MARK: - 메모

    private func memoSection(_ link: Link) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("메모")
                    .font(GalpiFont.text(15, .bold))
                    .foregroundStyle(GalpiColor.text)
                Spacer()
                Button {
                    if viewModel.isEditingMemo {
                        viewModel.saveMemo()
                    } else {
                        viewModel.isEditingMemo = true
                    }
                } label: {
                    Image(systemName: viewModel.isEditingMemo ? "checkmark" : "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            viewModel.isEditingMemo ? GalpiColor.main : GalpiColor.textTertiary
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.isEditingMemo ? "메모 저장" : "메모 편집")
            }

            Group {
                if viewModel.isEditingMemo {
                    TextEditor(text: $viewModel.memoDraft)
                        .font(GalpiFont.text(13, .medium))
                        .scrollContentBackground(.hidden)
                } else {
                    Text(link.memo ?? "이 갈피에 남길 메모를 적어보세요.")
                        .font(GalpiFont.text(13, .medium))
                        .foregroundStyle(GalpiColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .padding(14)
            .frame(height: 84, alignment: .topLeading)
            .background(GalpiColor.surface, in: .rect(cornerRadius: 16))
        }
    }

    // MARK: - 하단 바

    private var bottomBar: some View {
        GalpiPrimaryButton("원문 열기", symbol: "arrow.up.right") {
            viewModel.openOriginal(using: openURL)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ToolbarContentBuilder
    private var toolbarActions: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            let isFavorite = viewModel.link?.isFavorite == true
            Button {
                viewModel.toggleFavorite()
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
            }
            .tint(isFavorite ? .orange : GalpiColor.text)
            .accessibilityLabel(isFavorite ? "즐겨찾기 해제" : "즐겨찾기")
        }

        ToolbarItem(placement: .topBarTrailing) {
            if let link = viewModel.link, let url = link.url {
                ShareLink(item: url, preview: SharePreview(link.displayTitle)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .tint(GalpiColor.text)
                .accessibilityLabel("이 갈피 공유")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            // 다중 선택 툴바와 같은 이유로 색을 명시한다 — 루트 `.tint(GalpiColor.main)` 이
            // 환경을 타고 내려와 `role: .destructive` 의 빨강까지 덮는다.
            Button(role: .destructive) {
                isDeleteConfirmPresented = true
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)
            .accessibilityLabel("이 갈피 삭제")
        }
    }
}
