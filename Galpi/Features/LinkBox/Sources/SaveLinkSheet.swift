//
//  SaveLinkSheet.swift
//  LinkBoxPresentation
//
//  Created by euijjang97 on 9/1/26.
//

import GalpiDesignSystem
import GalpiKit
import SwiftUI

@MainActor
@Observable
public final class SaveLinkViewModel {

    // MARK: - Property

    private let useCases: GalpiUseCases

    public let urlString: String

    private(set) var title = ""
    private(set) var thumbnailData: Data?
    private(set) var folders: [Folder] = []
    private(set) var suggestedTags: [String] = []
    private(set) var isSuggestingTags = false
    private(set) var duplicateLinkID: UUID?

    var selectedFolderID: UUID?
    var selectedTags: Set<String> = []

    // MARK: - Function

    public init(urlString: String, useCases: GalpiUseCases) {
        self.urlString = urlString
        self.useCases = useCases
        self.selectedFolderID = useCases.settings.defaultFolderID
    }

    var host: String {
        guard var host = URL(string: urlString)?.host() else { return urlString }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }

    var displayTitle: String { title.isEmpty ? host : title }

    var selectedFolderName: String {
        folders.first { $0.id == selectedFolderID }?.name ?? Folder.unfiledName
    }

    var selectedFolderPastel: GalpiPastel {
        folders.first { $0.id == selectedFolderID }.map(\.pastel) ?? .green
    }

    var selectedFolderIcon: String {
        folders.first { $0.id == selectedFolderID }?.iconName ?? "tray.fill"
    }

    /// 시트를 여는 즉시 부른다. 저장은 이걸 기다리지 않는다.
    func prepare() async {
        folders = (try? useCases.repository.folders()) ?? []
        duplicateLinkID = NormalizedURL.canonical(urlString)
            .flatMap { try? useCases.repository.link(urlString: $0) }?.id

        // 이미 자주 쓰는 태그를 먼저 깔아두고, AI 추천이 오면 앞에 끼워 넣는다.
        suggestedTags = ((try? useCases.repository.tags()) ?? [])
            .sorted { $0.linkCount > $1.linkCount }
            .prefix(4)
            .map(\.name)

        guard let url = URL(string: urlString) else { return }

        if let metadata = try? await useCases.metadataService.fetch(for: url) {
            title = metadata.title ?? ""
            thumbnailData = metadata.thumbnailData
        }

        guard useCases.settings.isAIOrganizeEnabled, useCases.summaryService.isAvailable else {
            return
        }
        isSuggestingTags = true
        let generated = await useCases.summaryService.summarize(url: url, title: title)
        isSuggestingTags = false

        guard let generated else { return }
        let merged = generated.tagNames + suggestedTags.filter { !generated.tagNames.contains($0) }
        suggestedTags = Array(merged.prefix(5))
        selectedTags.formUnion(generated.tagNames)
    }

    /// 저장하고 곧바로 시트를 닫는다. 제목·썸네일·요약 채우기는 뒤에서 마저 돈다.
    @discardableResult
    func save() -> SaveLinkOutcome? {
        let outcome = try? useCases.saveLink.execute(
            urlString: urlString,
            folderID: selectedFolderID,
            tagNames: Array(selectedTags),
            memo: nil
        )

        if case .saved(let id) = outcome {
            let includeSummary = useCases.settings.isAIOrganizeEnabled
            Task { await useCases.enrichLink.execute(linkID: id, includeSummary: includeSummary) }
        }
        return outcome
    }

    func toggle(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
}

/// 저장 카드 · 공유 시트 — 시안 ⑤ 프레임.
///
/// 앱 안(클립보드에서 저장)과 공유 확장이 같은 화면을 쓰도록 `public` 으로 연다.
public struct SaveLinkSheet: View {

    // MARK: - Property

    @State private var viewModel: SaveLinkViewModel
    @Environment(\.dismiss) private var dismiss

    private let onFinish: (SaveLinkOutcome?) -> Void

    // MARK: - Function

    public init(
        urlString: String,
        useCases: GalpiUseCases,
        onFinish: @escaping (SaveLinkOutcome?) -> Void = { _ in }
    ) {
        _viewModel = State(
            initialValue: SaveLinkViewModel(urlString: urlString, useCases: useCases)
        )
        self.onFinish = onFinish
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            linkRow
            folderRow
            tagSection
            Spacer(minLength: 0)
            GalpiPrimaryButton(viewModel.duplicateLinkID == nil ? "저장하기" : "이미 저장된 갈피") {
                let outcome = viewModel.save()
                onFinish(outcome)
                dismiss()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 26)
        .background(GalpiColor.surface)
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(38)
        .task { await viewModel.prepare() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(GalpiColor.main)
            Text("갈피에 저장")
                .font(GalpiFont.text(18, .bold))
                .foregroundStyle(GalpiColor.text)
        }
    }

    private var linkRow: some View {
        HStack(spacing: 12) {
            GalpiThumbnail(
                imageData: viewModel.thumbnailData,
                symbol: "link",
                cornerRadius: 13,
                glyphSize: 20
            )
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.displayTitle)
                    .font(GalpiFont.text(14, .semibold))
                    .foregroundStyle(GalpiColor.text)
                    .lineLimit(2)
                Text(viewModel.host)
                    .font(GalpiFont.text(11, .medium))
                    .foregroundStyle(GalpiColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(GalpiColor.background, in: .rect(cornerRadius: 16))
    }

    private var folderRow: some View {
        Menu {
            Button(Folder.unfiledName) { viewModel.selectedFolderID = nil }
            ForEach(viewModel.folders) { folder in
                Button(folder.name) { viewModel.selectedFolderID = folder.id }
            }
        } label: {
            HStack(spacing: 12) {
                GalpiIconBadge(
                    symbol: viewModel.selectedFolderIcon,
                    pastel: viewModel.selectedFolderPastel,
                    size: 29, cornerRadius: 9, iconSize: 14
                )
                Text("저장 폴더")
                    .font(GalpiFont.text(14, .medium))
                    .foregroundStyle(GalpiColor.text)
                Spacer()
                Text(viewModel.selectedFolderName)
                    .font(GalpiFont.text(14, .semibold))
                    .foregroundStyle(GalpiColor.main)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GalpiColor.textTertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(GalpiColor.background, in: .rect(cornerRadius: 16))
        }
        .accessibilityLabel("저장 폴더 \(viewModel.selectedFolderName)")
    }

    @ViewBuilder
    private var tagSection: some View {
        if !viewModel.suggestedTags.isEmpty || viewModel.isSuggestingTags {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                    Text("추천 태그")
                        .font(GalpiFont.text(12, .bold))
                    if viewModel.isSuggestingTags {
                        ProgressView().controlSize(.mini)
                    }
                }
                .foregroundStyle(GalpiColor.main)

                GalpiFlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(viewModel.suggestedTags, id: \.self) { tag in
                        Button { viewModel.toggle(tag) } label: {
                            SaveLinkTagChip(
                                title: "#\(tag)",
                                isSelected: viewModel.selectedTags.contains(tag)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

/// 저장 카드의 태그 칩 — 비선택 채움이 `$bg` 라 보관함의 태그 칩과 다르다(시안 ⑤).
private struct SaveLinkTagChip: View {

    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(GalpiFont.text(12, .semibold))
            .foregroundStyle(isSelected ? GalpiColor.main : GalpiColor.textSecondary)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                isSelected ? GalpiColor.tint : GalpiColor.background,
                in: .rect(cornerRadius: 15)
            )
    }
}
