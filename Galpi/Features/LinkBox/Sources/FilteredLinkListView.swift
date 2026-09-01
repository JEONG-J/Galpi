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
                    LinkBoxEmptyState(
                        symbol: "tray",
                        title: "비어 있어요",
                        message: "여기에 해당하는 갈피가 아직 없습니다."
                    )
                } else {
                    LinkListCard(links: links) { path.append(.detail($0.id)) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .padding(.bottom, GalpiTabBar.contentBottomInset)
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
}
