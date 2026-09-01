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

    private let useCases: GalpiUseCases

    // MARK: - Function

    public init(useCases: GalpiUseCases) {
        self.useCases = useCases
        _viewModel = State(initialValue: SearchViewModel(useCases: useCases))
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("검색")
                        .font(GalpiFont.largeTitle)
                        .kerning(-0.8)
                        .foregroundStyle(GalpiColor.text)

                    searchField

                    if viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
                        tagSuggestions
                    } else if viewModel.results.isEmpty {
                        LinkBoxEmptyState(
                            symbol: "magnifyingglass",
                            title: "결과가 없어요",
                            message: "제목·메모·태그·주소에서 찾아봤어요."
                        )
                    } else {
                        LinkListCard(links: viewModel.results) { path.append(.detail($0.id)) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24 + GalpiTabBar.contentBottomInset)
            }
            .scrollIndicators(.hidden)
            .background(GalpiColor.background)
            .navigationBarHidden(true)
            .navigationDestination(for: LinkRoute.self) { route in
                LinkRouteView(route: route, useCases: useCases, path: $path)
            }
        }
        .onAppear { viewModel.load() }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(GalpiColor.textTertiary)

            TextField("제목·메모·태그로 찾기", text: $viewModel.query)
                .font(GalpiFont.text(14, .medium))
                .foregroundStyle(GalpiColor.text)
                .submitLabel(.search)

            if !viewModel.query.isEmpty {
                Button { viewModel.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(GalpiColor.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색어 지우기")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .galpiCard(cornerRadius: 16)
    }

    @ViewBuilder
    private var tagSuggestions: some View {
        if !viewModel.suggestedTags.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                GalpiSectionHeader("많이 쓴 태그")
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
    }
}
