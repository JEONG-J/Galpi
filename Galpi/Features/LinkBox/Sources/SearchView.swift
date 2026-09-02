//
//  SearchView.swift
//  LinkBoxPresentation
//
//  Created by euijjang97 on 9/1/26.
//

import GalpiDesignSystem
import GalpiKit
import SwiftUI

@MainActor
@Observable
final class SearchViewModel {

    // MARK: - Property

    private let useCases: GalpiUseCases
    private var allLinks: [Link] = []

    private(set) var results: [Link] = []
    private(set) var suggestedTags: [Tag] = []

    /// 태그가 없는 이유가 '저장이 아예 없어서'인지 '태그만 안 붙어서'인지 가른다.
    var hasSavedLinks: Bool { !allLinks.isEmpty }

    /// 저장·중복 제거·상한 규칙은 `GalpiSettings` 가 갖는다. 여기선 그대로 비춘다.
    var recentSearches: [String] { useCases.settings.recentSearches }

    var query = "" {
        didSet { filter() }
    }

    // MARK: - Function

    init(useCases: GalpiUseCases) {
        self.useCases = useCases
    }

    func load() {
        // ponytail: 전체를 한 번 읽고 메모리에서 거른다. 수천 건까지는 이게 제일 싸다.
        //           그 이상 늘면 제목·메모를 술어로 넘기는 FetchDescriptor 로 바꾼다.
        allLinks = (try? useCases.repository.links(
            matching: .all, includeArchived: false, limit: nil
        )) ?? []
        suggestedTags = ((try? useCases.repository.tags()) ?? [])
            .filter { $0.linkCount > 0 }
            .sorted { $0.linkCount > $1.linkCount }
        filter()
    }

    /// 키보드 검색을 눌러 검색어를 확정한 순간에만 기록에 남긴다 — 한 글자씩 칠 때마다 남기면
    /// '최'·'최근'·'최근검색'이 줄줄이 쌓인다.
    func recordSearch() {
        useCases.settings.addRecentSearch(query)
    }

    func search(_ keyword: String) {
        query = keyword
    }

    func removeRecentSearch(_ keyword: String) {
        useCases.settings.removeRecentSearch(keyword)
    }

    func clearRecentSearches() {
        useCases.settings.clearRecentSearches()
    }

    private func filter() {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else {
            results = []
            return
        }

        results = allLinks.filter { link in
            link.title.lowercased().contains(keyword)
                || link.urlString.lowercased().contains(keyword)
                || (link.memo?.lowercased().contains(keyword) ?? false)
                || (link.summary?.lowercased().contains(keyword) ?? false)
                || (link.tags ?? []).contains { $0.name.contains(keyword) }
        }
    }
}

/// 검색 탭.
///
/// 시안에는 탭 바에 '검색'만 있고 화면 프레임이 없다. 나머지 화면과 같은 토큰·컴포넌트로
/// 짜서 이질감이 없게 했고, 시안이 나오면 이 파일만 갈아 끼우면 된다.
public struct SearchView: View {

    // MARK: - Property

    @State private var viewModel: SearchViewModel
    @State private var path: [LinkRoute] = []
    @State private var deletionTarget: Link?

    private let useCases: GalpiUseCases

    // MARK: - Function

    public init(useCases: GalpiUseCases) {
        self.useCases = useCases
        _viewModel = State(initialValue: SearchViewModel(useCases: useCases))
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack(path: $path) {
            List {
                // 좌우 여백은 `.insetGrouped` 섹션 인셋에 맡긴다 — 여기에 여백을 더 얹으면
                // 검색 결과 행보다 안쪽으로 들어가 좌우 라인이 어긋난다.
                if viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
                    recentSearchSection

                    tagSuggestions
                        .plainListRow(
                            insets: EdgeInsets(top: 8, leading: 0, bottom: 24, trailing: 0)
                        )
                } else if viewModel.results.isEmpty {
                    GalpiEmptyState(
                        symbol: "magnifyingglass",
                        title: "결과가 없어요",
                        message: "제목·메모·태그·주소에서 찾아봤어요."
                    )
                    .plainListRow(
                        insets: EdgeInsets(top: 8, leading: 0, bottom: 24, trailing: 0)
                    )
                } else {
                    ForEach(viewModel.results) { link in
                        LinkListRow(link: link, onTogglePin: togglePin) { deletionTarget = $0 }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(GalpiColor.background)
            // 스크롤에 따라 접히는 라지 타이틀은 검색 화면에서 '최근 검색' 헤더와 겹쳐 읽힌다.
            // 상단에 고정되는 inline 로 둔다.
            .navigationTitle("검색")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: LinkRoute.self) { route in
                LinkRouteView(route: route, useCases: useCases)
            }
            .linkDeleteConfirmation(
                target: $deletionTarget,
                useCases: useCases,
                onDeleted: viewModel.load
            )
        }
        .searchable(text: $viewModel.query, prompt: "제목·메모·태그로 찾기")
        .onSubmit(of: .search) { viewModel.recordSearch() }
        .onAppear { viewModel.load() }
    }

    // MARK: - Function

    /// 고정 순서는 저장소가 매기므로 토글 뒤 다시 읽는다.
    private func togglePin(_ link: Link) {
        useCases.togglePin(link)
        viewModel.load()
    }

    /// 기록이 없으면 섹션째로 그리지 않는다 — 빈 '최근 검색' 헤더만 남는 게 더 어색하다.
    @ViewBuilder
    private var recentSearchSection: some View {
        if !viewModel.recentSearches.isEmpty {
            Section {
                ForEach(viewModel.recentSearches, id: \.self, content: recentSearchRow)
            } header: {
                GalpiSectionHeader("최근 검색") {
                    GalpiSectionAction("모두 지우기") { viewModel.clearRecentSearches() }
                }
                .textCase(nil)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
            }
        }
    }

    /// 탭하면 그 말로 다시 검색한다. 스와이프 삭제는 VoiceOver 로 닿지 않으므로
    /// 같은 동작을 커스텀 액션으로도 연다 — `LinkListRow` 와 같은 규칙이다.
    private func recentSearchRow(_ keyword: String) -> some View {
        Button { viewModel.search(keyword) } label: {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GalpiColor.textTertiary)

                Text(keyword)
                    .font(GalpiFont.text(14, .medium))
                    .foregroundStyle(GalpiColor.text)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(GalpiColor.surface)
        .listRowInsets(EdgeInsets(top: 11, leading: 14, bottom: 11, trailing: 14))
        .swipeActions(edge: .trailing) {
            // 루트 `.tint(GalpiColor.main)` 이 `role: .destructive` 의 빨강까지 덮는다.
            Button(role: .destructive) { viewModel.removeRecentSearch(keyword) } label: {
                Label("삭제", systemImage: "trash")
            }
            .tint(.red)
        }
        .accessibilityAction(named: "삭제") { viewModel.removeRecentSearch(keyword) }
    }

    /// 시안의 태그 칩 — 헤더 없이 칩만 놓는다. '#태그'라는 표기로 이미 무엇인지 읽힌다.
    @ViewBuilder
    private var tagSuggestions: some View {
        // 태그가 없다고 섹션을 통째로 지우면 검색창 아래가 텅 빈다.
        if viewModel.suggestedTags.isEmpty {
            emptyTagState
        } else {
            GalpiFlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(viewModel.suggestedTags.prefix(12)) { tag in
                    Button { viewModel.search(tag.name) } label: {
                        GalpiChip("#\(tag.name)", count: tag.linkCount)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyTagState: some View {
        if viewModel.hasSavedLinks {
            GalpiEmptyState(
                symbol: "number",
                title: "아직 붙은 태그가 없어요",
                message: "갈피를 저장할 때 태그를 붙이면 여기서 바로 찾을 수 있어요.",
                action: .init(title: "전체 갈피 보기") {
                    path.append(.filtered(.all, title: "전체 갈피"))
                }
            )
        } else {
            GalpiEmptyState(
                symbol: "magnifyingglass",
                title: "찾을 갈피가 아직 없어요",
                message: "공유 시트에서 '갈피'를 눌러 링크를 꽂으면 제목·메모·태그로 찾을 수 있어요."
            )
        }
    }
}

#if DEBUG
#Preview("데이터 0건") {
    SearchView(useCases: .empty())
}
#endif
