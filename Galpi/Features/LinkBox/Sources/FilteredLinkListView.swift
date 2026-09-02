//
//  FilteredLinkListView.swift
//  LinkBoxPresentation
//
//  Created by euijjang97 on 9/1/26.
//

import GalpiDesignSystem
import GalpiKit
import SwiftUI

/// 일괄 고정 액션의 방향 — 고른 갈피가 전부 고정돼 있을 때만 '해제', 하나라도
/// 안 고정돼 있으면 '고정' 으로 맞춘다. 비어 있으면(액션 비활성) 고정 쪽 라벨을 둔다.
func shouldPinAll(_ links: [Link]) -> Bool {
    links.isEmpty || links.contains { !$0.isPinned }
}

/// 스마트 리스트·폴더·태그·'전체 보기'가 모두 도착하는 목록 화면.
///
/// 필터 축만 다를 뿐 화면 구조가 같아서 하나로 둔다.
/// 선택 모드에서는 여러 갈피를 한 번에 삭제·고정한다 — 홈은 네비게이션 바를 숨겨
/// 툴바 자리가 없으므로 일괄 처리는 이 화면에만 둔다.
struct FilteredLinkListView: View {

    // MARK: - Property

    let filter: LinkFilter
    let title: String
    let useCases: GalpiUseCases

    @State private var links: [Link] = []
    @State private var deletionTarget: Link?
    @State private var editMode: EditMode = .inactive
    @State private var selection: Set<Link.ID> = []
    @State private var isBulkDeleteConfirming = false

    // MARK: - Body

    var body: some View {
        List(selection: $selection) {
            if links.isEmpty {
                GalpiEmptyState(
                    symbol: emptyState.symbol,
                    title: emptyState.title,
                    message: emptyState.message
                )
                .plainListRow(
                    insets: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
                )
            } else {
                ForEach(links) { link in
                    LinkListRow(link: link, onTogglePin: togglePin) { deletionTarget = $0 }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(GalpiColor.background)
        .scrollIndicators(.hidden)
        .linkDeleteConfirmation(target: $deletionTarget, useCases: useCases, onDeleted: load)
        .environment(\.editMode, $editMode)
        .navigationTitle(navigationTitleText)
        .toolbarTitleDisplayMode(.inline)
        // 일괄 액션 바가 탭 바와 겹치지 않게 선택 중에는 탭 바를 접는다.
        .toolbar(isSelecting ? .hidden : .automatic, for: .tabBar)
        .toolbar { selectionToolbar }
        .onAppear(perform: load)
        .confirmationDialog(
            "\(selection.count)개의 갈피를 삭제할까요?",
            isPresented: $isBulkDeleteConfirming,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive, action: deleteSelected)
            Button("취소", role: .cancel) {}
        }
    }

    // MARK: - 툴바

    @ToolbarContentBuilder
    private var selectionToolbar: some ToolbarContent {
        // 목록이 비어 있으면 고를 게 없다.
        if !links.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSelecting ? "완료" : "선택", action: toggleSelectionMode)
                    .accessibilityLabel(isSelecting ? "선택 마치기" : "여러 갈피 선택")
            }
        }

        if isSelecting {
            ToolbarItemGroup(placement: .bottomBar) {
                Button(action: togglePinOnSelection) {
                    Label(bulkPinTitle, systemImage: isPinAction ? "pin.fill" : "pin.slash")
                }
                .disabled(selection.isEmpty)
                .accessibilityLabel("선택한 \(selection.count)개 \(bulkPinTitle)")

                Spacer()

                Button(role: .destructive) { isBulkDeleteConfirming = true } label: {
                    Label("삭제", systemImage: "trash")
                }
                .disabled(selection.isEmpty)
                .accessibilityLabel("선택한 \(selection.count)개 삭제")
            }
        }
    }

    // MARK: - Function

    /// 삭제·고정 뒤에도 다시 읽는다 — 지워진 링크가 배열에 남으면 안 되고,
    /// 고정한 갈피는 저장소 정렬이 맨 위로 올려 준다.
    private func load() {
        links = (try? useCases.repository.links(
            matching: filter, includeArchived: false, limit: nil
        )) ?? []
    }

    private func togglePin(_ link: Link) {
        useCases.togglePin(link)
        load()
    }

    private var isSelecting: Bool { editMode == .active }

    private var selectedLinks: [Link] { links.filter { selection.contains($0.id) } }

    private var isPinAction: Bool { shouldPinAll(selectedLinks) }

    private var bulkPinTitle: String { isPinAction ? "상단 고정" : "고정 해제" }

    /// 선택 중에는 제목 자리가 선택 건수를 알린다 — VoiceOver 도 이 값을 읽는다.
    private var navigationTitleText: String {
        guard isSelecting else { return title }
        return selection.isEmpty ? "갈피 선택" : "\(selection.count)개 선택됨"
    }

    private func toggleSelectionMode() {
        withAnimation { editMode = isSelecting ? .inactive : .active }
        selection.removeAll()
    }

    private func togglePinOnSelection() {
        let shouldPin = isPinAction
        for link in selectedLinks { link.isPinned = shouldPin }
        try? useCases.repository.save()
        endSelection()
    }

    private func deleteSelected() {
        for link in selectedLinks { useCases.repository.delete(link) }
        try? useCases.repository.save()
        endSelection()
    }

    /// 일괄 액션 뒤에는 선택을 비우고 선택 모드를 나간다 — 사라진 id 가 남으면 안 된다.
    private func endSelection() {
        selection.removeAll()
        withAnimation { editMode = .inactive }
        load()
    }

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
        FilteredLinkListView(filter: .favorite, title: "즐겨찾기", useCases: .empty())
    }
}

#Preview("빈 목록 · 받은함") {
    NavigationStack {
        FilteredLinkListView(filter: .inbox, title: "받은함", useCases: .empty())
    }
}
#endif
