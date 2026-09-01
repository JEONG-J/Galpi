//
//  LibraryView.swift
//  LinkBoxPresentation
//
//  Created by euijjang97 on 9/1/26.
//

import GalpiDesignSystem
import GalpiKit
import SwiftUI

@MainActor
@Observable
final class LibraryViewModel {

    // MARK: - Property

    let useCases: GalpiUseCases

    private(set) var folders: [Folder] = []
    private(set) var tags: [Tag] = []
    private(set) var unreadCount = 0
    private(set) var favoriteCount = 0
    private(set) var inboxCount = 0

    var isEditingFolders = false
    /// 삭제가 거절된 사유. `nil` 이 아니면 보관함 alert 로 뜬다.
    var folderDeleteFailure: String?

    // MARK: - Function

    init(useCases: GalpiUseCases) {
        self.useCases = useCases
    }

    func load() {
        let repository = useCases.repository
        folders = (try? repository.folders()) ?? []
        // 링크가 하나도 안 붙은 태그는 시안의 태그 클라우드에 나올 자리가 없다.
        tags = ((try? repository.tags()) ?? []).filter { $0.linkCount > 0 }
        unreadCount = (try? repository.count(matching: .unread)) ?? 0
        favoriteCount = (try? repository.count(matching: .favorite)) ?? 0
        inboxCount = (try? repository.count(matching: .inbox)) ?? 0
    }

    func delete(_ folder: Folder) {
        do {
            try useCases.manageFolder.delete(folderID: folder.id)
            load()
        } catch {
            folderDeleteFailure = [
                error.localizedDescription,
                (error as? LocalizedError)?.recoverySuggestion
            ]
            .compactMap { $0 }
            .joined(separator: "\n\n")
        }
    }
}

/// 보관함 탭 — 시안 ② 프레임.
public struct LibraryView: View {

    // MARK: - Property

    @State private var viewModel: LibraryViewModel
    @State private var path: [LinkRoute] = []
    @State private var editingFolder: FolderEditorTarget?

    private let useCases: GalpiUseCases

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    // MARK: - Function

    public init(useCases: GalpiUseCases) {
        self.useCases = useCases
        _viewModel = State(initialValue: LibraryViewModel(useCases: useCases))
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    smartLists
                    folderSection
                    tagSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(GalpiColor.background)
            .navigationTitle("보관함")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingFolder = .create
                    } label: {
                        Label("새 폴더", systemImage: "folder.badge.plus")
                    }
                }
            }
            .navigationDestination(for: LinkRoute.self) { route in
                LinkRouteView(route: route, useCases: useCases, path: $path)
            }
        }
        .onAppear { viewModel.load() }
        .sheet(item: $editingFolder) { target in
            FolderEditorView(target: target, useCases: useCases) { viewModel.load() }
        }
        .alert("폴더를 삭제할 수 없어요", isPresented: folderDeleteFailureBinding) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(viewModel.folderDeleteFailure ?? "")
        }
    }

    // MARK: - 스마트 리스트

    private var smartLists: some View {
        HStack(spacing: 10) {
            smartCard("미열람", count: viewModel.unreadCount, symbol: "circle.circle.fill",
                      pastel: .orange, filter: .unread)
            smartCard("즐겨찾기", count: viewModel.favoriteCount, symbol: "star.fill",
                      pastel: .yellow, filter: .favorite)
            smartCard("받은함", count: viewModel.inboxCount, symbol: "tray.fill",
                      pastel: .gray, filter: .inbox)
        }
    }

    private func smartCard(
        _ name: String,
        count: Int,
        symbol: String,
        pastel: GalpiPastel,
        filter: LinkFilter
    ) -> some View {
        Button {
            path.append(.filtered(filter, title: name))
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                GalpiIconBadge(
                    symbol: symbol, pastel: pastel, size: 32, cornerRadius: 16, iconSize: 15
                )
                Text(name)
                    .font(GalpiFont.text(12, .semibold))
                    .foregroundStyle(GalpiColor.textSecondary)
                Text("\(count)개")
                    .font(GalpiFont.text(16, .bold))
                    .foregroundStyle(GalpiColor.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .galpiCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name) \(count)개")
    }

    // MARK: - 폴더

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GalpiSectionHeader("폴더") {
                if !viewModel.folders.isEmpty {
                    GalpiSectionAction(viewModel.isEditingFolders ? "완료" : "편집") {
                        viewModel.isEditingFolders.toggle()
                    }
                }
            }

            if viewModel.folders.isEmpty {
                GalpiEmptyState(
                    symbol: "folder",
                    title: "아직 폴더가 없어요",
                    message: "폴더를 만들면 갈피를 주제별로 모아둘 수 있어요.",
                    action: .init(title: "새 폴더 만들기") { editingFolder = .create }
                )
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.folders) { folder in
                        folderCell(folder)
                    }
                }
            }
        }
    }

    /// 편집 모드의 `ellipsis` 메뉴와 길게 눌러 여는 컨텍스트 메뉴가 같은 항목을 쓴다.
    @ViewBuilder
    private func folderActions(_ folder: Folder) -> some View {
        Button {
            editingFolder = .edit(folder.id)
        } label: {
            Label("이름·색 바꾸기", systemImage: "pencil")
        }
        Button(role: .destructive) {
            viewModel.delete(folder)
        } label: {
            Label("폴더 삭제", systemImage: "trash")
        }
    }

    private func folderCell(_ folder: Folder) -> some View {
        Button {
            path.append(.filtered(.folder(folder.id), title: folder.name))
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    GalpiIconBadge(
                        symbol: folder.iconName, pastel: folder.pastel,
                        size: 34, cornerRadius: 12, iconSize: 16
                    )
                    Spacer()
                    if viewModel.isEditingFolders {
                        Menu {
                            folderActions(folder)
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(GalpiColor.textTertiary)
                                .frame(width: 24, height: 24)
                        }
                        .accessibilityLabel("\(folder.name) 폴더 더 보기")
                    }
                }
                Text(folder.name)
                    .font(GalpiFont.text(15, .bold))
                    .foregroundStyle(GalpiColor.text)
                    .lineLimit(1)
                Text("\(folder.linkCount)개")
                    .font(GalpiFont.text(11, .medium))
                    .foregroundStyle(GalpiColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .frame(height: 104, alignment: .topLeading)
            .galpiCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
        .contextMenu { folderActions(folder) }
    }

    // MARK: - 태그

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GalpiSectionHeader("태그")

            if viewModel.tags.isEmpty {
                GalpiEmptyState(
                    symbol: "number",
                    title: "아직 태그가 없어요",
                    message: "내 정보에서 'AI 자동 정리'를 켜면 저장할 때 추천 태그가 붙어요."
                )
            } else {
                GalpiFlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(viewModel.tags) { tag in
                        Button {
                            path.append(.filtered(.tag(tag.id), title: "#\(tag.name)"))
                        } label: {
                            GalpiChip("#\(tag.name)", count: tag.linkCount)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var folderDeleteFailureBinding: Binding<Bool> {
        Binding(
            get: { viewModel.folderDeleteFailure != nil },
            set: { if !$0 { viewModel.folderDeleteFailure = nil } }
        )
    }
}

#if DEBUG
#Preview("데이터 0건") {
    LibraryView(useCases: .empty())
}
#endif
