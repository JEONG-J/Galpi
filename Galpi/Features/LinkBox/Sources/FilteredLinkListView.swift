//
//  FilteredLinkListView.swift
//  LinkBoxPresentation
//
//  Created by euijjang97 on 9/1/26.
//

import GalpiDesignSystem
import GalpiKit
import SwiftUI

/// 스마트 리스트·폴더·태그·'전체 보기'가 모두 도착하는 목록 화면.
///
/// 필터 축만 다를 뿐 화면 구조가 같아서 하나로 둔다.
struct FilteredLinkListView: View {

    // MARK: - Property

    let filter: LinkFilter
    let title: String
    let useCases: GalpiUseCases
    @Binding var path: [LinkRoute]

    @State private var links: [Link] = []

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if links.isEmpty {
                    GalpiEmptyState(
                        symbol: emptyState.symbol,
                        title: emptyState.title,
                        message: emptyState.message
                    )
                } else {
                    LinkListCard(links: links) { path.append(.detail($0.id)) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .background(GalpiColor.background)
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
        .onAppear {
            links = (try? useCases.repository.links(
                matching: filter, includeArchived: false, limit: nil
            )) ?? []
        }
    }

    // MARK: - Function

    /// 같은 화면이라도 도착한 필터에 따라 '왜 비었는지'가 다르다.
    private var emptyState: (symbol: String, title: String, message: String) {
        switch filter {
        case .all:
            ("bookmark", "아직 갈피가 없어요",
             "공유 시트에서 '갈피'를 누르면 첫 링크가 여기에 꽂혀요.")
        case .unread:
            ("checkmark.circle", "다 읽었어요",
             "안 읽은 갈피가 하나도 없어요.")
        case .favorite:
            ("star", "즐겨찾기가 비어 있어요",
             "갈피 상세에서 별을 누르면 여기에 모여요.")
        case .inbox:
            ("tray", "받은함이 비어 있어요",
             "폴더를 고르지 않고 저장한 갈피가 여기로 들어와요.")
        case .folder:
            ("folder", "이 폴더가 비어 있어요",
             "갈피 상세에서 폴더를 '\(title)'(으)로 옮기면 여기에 담겨요.")
        case .tag:
            ("number", "이 태그의 갈피가 없어요",
             "'\(title)' 태그를 붙인 갈피가 아직 없어요.")
        }
    }
}

#if DEBUG
#Preview("빈 목록 · 즐겨찾기") {
    NavigationStack {
        FilteredLinkListView(
            filter: .favorite, title: "즐겨찾기", useCases: .empty(), path: .constant([])
        )
    }
}

#Preview("빈 목록 · 받은함") {
    NavigationStack {
        FilteredLinkListView(
            filter: .inbox, title: "받은함", useCases: .empty(), path: .constant([])
        )
    }
}
#endif
