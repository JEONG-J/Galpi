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

    var settings: GalpiSettings { useCases.settings }

    var recentSearches: [String] { settings.recentSearches }

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

    /// 검색어를 확정했을 때만 기록에 남긴다 — 타이핑 중간 글자까지 쌓이면 기록이 쓸모없어진다.
    func commitSearch() {
        settings.recordSearch(query)
    }

    func removeRecentSearch(_ keyword: String) {
        settings.removeRecentSearch(keyword)
    }

    func clearRecentSearches() {
        settings.clearRecentSearches()
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

fileprivate enum Constants {

    /// 최근 검색 행의 아이콘 자리 — 구분선 inset 계산에도 쓴다.
    static let rowIconWidth: CGFloat = 22

    /// 아이콘과 검색어 사이 간격.
    static let rowIconSpacing: CGFloat = 12

    /// 최근 검색 행의 좌우·상하 여백 — 링크 행(`LinkListRow`)과 같은 값.
    static let rowHorizontalInset: CGFloat = 14
    static let rowVerticalInset: CGFloat = 11
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
            .navigationTitle("검색")
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
        .onSubmit(of: .search) { viewModel.commitSearch() }
        .onAppear { viewModel.load() }
    }

    // MARK: - Function

    /// 고정 순서는 저장소가 매기므로 토글 뒤 다시 읽는다.
    private func togglePin(_ link: Link) {
        useCases.togglePin(link)
        viewModel.load()
    }

    /// 태그 칩 묶음. 칩이 `#` 로 이미 태그임을 드러내서 섹션 제목을 따로 얹지 않는다.
    @ViewBuilder
    private var tagSuggestions: some View {
        // 태그가 없다고 통째로 지우면 검색창 아래가 텅 빈다.
        if viewModel.suggestedTags.isEmpty {
            emptyTagState
        } else {
            GalpiFlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(viewModel.suggestedTags.prefix(12)) { tag in
                    Button { viewModel.query = tag.name } label: {
                        GalpiChip("#\(tag.name)", count: tag.linkCount)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 최근 검색

    /// 기록이 없으면 섹션 자체를 그리지 않는다 — 빈 '최근 검색' 제목만 남는 게 더 허전하다.
    @ViewBuilder
    private var recentSearchSection: some View {
        if !viewModel.recentSearches.isEmpty {
            Section {
                ForEach(viewModel.recentSearches, id: \.self) { keyword in
                    recentSearchRow(keyword)
                }
            } header: {
                GalpiSectionHeader("최근 검색") {
                    GalpiSectionAction("모두 지우기") { viewModel.clearRecentSearches() }
                }
                .textCase(nil)
                .plainListRow(insets: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }
        }
    }

    /// 탭하면 그 말로 다시 검색하고, 왼쪽으로 밀면 그 한 건만 지운다.
    ///
    /// 스와이프는 VoiceOver 로 닿지 않으므로 같은 동작을 커스텀 액션으로도 연다.
    private func recentSearchRow(_ keyword: String) -> some View {
        Button { viewModel.query = keyword } label: {
            HStack(spacing: Constants.rowIconSpacing) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(GalpiColor.textSecondary)
                    .frame(width: Constants.rowIconWidth)

                Text(keyword)
                    .font(GalpiFont.text(14, .semibold))
                    .foregroundStyle(GalpiColor.text)
                    .lineLimit(1)

                Spacer(minLength: 8)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(GalpiColor.surface)
        .listRowInsets(
            EdgeInsets(
                top: Constants.rowVerticalInset,
                leading: Constants.rowHorizontalInset,
                bottom: Constants.rowVerticalInset,
                trailing: Constants.rowHorizontalInset
            )
        )
        // 링크 행과 같은 규칙 — 구분선이 아이콘 오른쪽에서 시작한다.
        .alignmentGuide(.listRowSeparatorLeading) { _ in
            Constants.rowIconWidth + Constants.rowIconSpacing
        }
        // 루트 `.tint` 가 환경을 타고 내려와 `role: .destructive` 의 빨강을 덮는다.
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { viewModel.removeRecentSearch(keyword) } label: {
                Label("삭제", systemImage: "trash")
            }
            .tint(.red)
        }
        .accessibilityAction(named: "삭제") { viewModel.removeRecentSearch(keyword) }
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
