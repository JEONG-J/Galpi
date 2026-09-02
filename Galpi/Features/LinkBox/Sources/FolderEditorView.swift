//
//  FolderEditorView.swift
//  LinkBoxPresentation
//
//  Created by euijjang97 on 9/1/26.
//

import GalpiDesignSystem
import GalpiKit
import SwiftUI

/// 폴더 편집 시트가 무엇을 하는지 — 새로 만들기인지, 기존 폴더 수정인지.
enum FolderEditorTarget: Identifiable {
    case create
    case edit(UUID)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let id): id.uuidString
        }
    }
}

/// 폴더 만들기·수정 시트. 시안의 '새 폴더' 셀과 '편집' 메뉴가 여기로 온다.
struct FolderEditorView: View {

    // MARK: - Property

    /// 시트 안에서 키보드를 받을 수 있는 자리.
    private enum Field: Hashable {
        case name
        case iconQuery
    }

    let target: FolderEditorTarget
    let useCases: GalpiUseCases
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    /// `ColorPicker` 가 준 색을 hex 로 굳히려면 해석 환경이 필요하다.
    @Environment(\.self) private var environment

    @State private var name = ""
    @State private var palette: FolderPalette = .blue
    @State private var customColor = Color(rgba: 0x2E5AE5FF)
    @State private var iconName = "folder"
    @State private var iconQuery = ""

    @FocusState private var focusedField: Field?

    /// 검색어가 비었을 때 보여줄 추천 아이콘. 시안의 폴더 4종에 쓰인 것부터 앞에 둔다.
    private let iconChoices = [
        "folder", "chevron.left.forwardslash.chevron.right", "paintpalette.fill",
        "fork.knife", "airplane", "book", "cart", "music.note",
        "film", "dumbbell", "briefcase", "heart",
    ]

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        fieldLabel("미리보기")
                        preview
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        fieldLabel("이름")
                        nameField
                    }

                    section("색") {
                        ForEach(FolderPalette.allCases, id: \.self) { candidate in
                            swatch(candidate)
                        }
                        customSwatch
                    }

                    iconSection
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
            .background(GalpiColor.background)
            .navigationTitle(isCreating ? "새 폴더" : "폴더 편집")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                loadExisting()
                // 새 폴더는 이름부터 받는다. 편집은 이름이 이미 차 있어 키보드를 띄우지 않는다.
                if isCreating { focusedField = .name }
            }
        }
    }

    // MARK: - Function

    private var isCreating: Bool {
        if case .create = target { true } else { false }
    }

    private var pastel: GalpiPastel { GalpiPastel(name: palette.rawValue) }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    /// 저장하면 보관함에 이렇게 보인다는 결과 카드 — 탭해도 입력되지 않는다.
    /// 아래 입력란과 헷갈리지 않도록 라벨·빈 값 문구를 서로 다르게 뒀다.
    private var preview: some View {
        let displayName = trimmedName.isEmpty ? "이름 없는 폴더" : trimmedName
        return HStack(spacing: 12) {
            GalpiIconBadge(
                symbol: iconName, pastel: pastel, size: 44, cornerRadius: 14, iconSize: 20
            )
            Text(displayName)
                .font(GalpiFont.text(15, .bold))
                .foregroundStyle(trimmedName.isEmpty ? GalpiColor.textTertiary : GalpiColor.text)
            Spacer()
        }
        .padding(14)
        .galpiCard(cornerRadius: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("미리보기")
        .accessibilityValue(displayName)
    }

    private var nameField: some View {
        TextField("예: 개발 아티클", text: $name)
            .font(GalpiFont.text(15, .semibold))
            .focused($focusedField, equals: .name)
            .submitLabel(.done)
            .modifier(InputFieldStyle(isFocused: focusedField == .name))
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(GalpiFont.text(13, .semibold))
            .foregroundStyle(GalpiColor.textSecondary)
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            fieldLabel(title)
            LazyVGrid(columns: gridColumns, spacing: 10, content: content)
        }
    }

    /// 추천 12종만 두면 그 밖의 아이콘을 쓸 방법이 없어서, 위에 검색창을 두고
    /// 검색어가 있을 때는 SF Symbols 전체에서 찾는다.
    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            fieldLabel("아이콘")

            TextField("아이콘 검색 (한글·영문)", text: $iconQuery)
                .font(GalpiFont.text(15, .medium))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .iconQuery)
                .submitLabel(.search)
                .modifier(InputFieldStyle(isFocused: focusedField == .iconQuery))

            if displayedIcons.isEmpty {
                GalpiEmptyState(
                    symbol: "magnifyingglass",
                    title: "찾는 아이콘이 없어요",
                    message: "한글 낱말이나 영문 이름으로 검색해보세요. 예: 여행, 운동, book"
                )
            } else {
                LazyVGrid(columns: gridColumns, spacing: 10) {
                    ForEach(displayedIcons, id: \.self) { symbol in
                        iconOption(symbol)
                    }
                }
            }
        }
    }

    /// 검색어가 있으면 전체 심볼에서, 없으면 추천 목록에서 고른다. 편집으로 들어온 폴더가
    /// 추천에 없는 아이콘을 쓰고 있으면 맨 앞에 붙여 선택 상태가 보이게 한다.
    private var displayedIcons: [String] {
        let query = iconQuery.trimmingCharacters(in: .whitespaces)
        guard query.isEmpty else {
            return SFSymbolCatalog.search(query, limit: Constants.iconSearchLimit)
        }
        return iconChoices.contains(iconName) ? iconChoices : [iconName] + iconChoices
    }

    private func swatch(_ candidate: FolderPalette) -> some View {
        let candidatePastel = GalpiPastel(name: candidate.rawValue)
        return Button { palette = candidate } label: {
            Circle()
                .fill(candidatePastel.foreground)
                .frame(height: 34)
                .overlay {
                    if candidate == palette {
                        Circle().strokeBorder(GalpiColor.text.opacity(0.35), lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(candidate.rawValue)
    }

    /// 12색 밖의 색을 고르는 자리. 시스템 `ColorPicker` 를 스와치처럼 그대로 쓴다.
    ///
    /// 피커가 값을 쓰는 순간이 곧 "커스텀 색 선택"이라, 바인딩 setter 에서 팔레트까지 옮긴다.
    private var customSwatch: some View {
        let picked = Binding {
            customColor
        } set: { color in
            customColor = color
            palette = FolderPalette(rawValue: color.galpiHex(in: environment))
        }

        return ColorPicker("직접 선택", selection: picked, supportsOpacity: false)
            .labelsHidden()
            .frame(height: 34)
            .overlay {
                if palette.isCustom {
                    Circle()
                        .strokeBorder(GalpiColor.text.opacity(0.35), lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
    }

    private func iconOption(_ symbol: String) -> some View {
        Button { iconName = symbol } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(symbol == iconName ? GalpiColor.main : GalpiColor.textSecondary)
                .frame(height: 34)
                .frame(maxWidth: .infinity)
                .background(
                    symbol == iconName ? GalpiColor.tint : GalpiColor.surface,
                    in: .rect(cornerRadius: 12)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol)
    }

    private func loadExisting() {
        guard case .edit(let id) = target,
              let folder = try? useCases.repository.folders().first(where: { $0.id == id })
        else { return }
        name = folder.name
        palette = folder.color
        if palette.isCustom, let picked = Color(galpiHex: palette.rawValue) {
            customColor = picked
        }
        // 예전 버전이 남긴 이름이 지금 OS 에서 안 그려질 수 있다. 그때는 기본값으로 되돌린다.
        iconName = SFSymbolCatalog.isRenderable(folder.iconName) ? folder.iconName : "folder"
    }

    private func save() {
        switch target {
        case .create:
            _ = try? useCases.manageFolder.create(
                name: name, color: palette, iconName: iconName
            )
        case .edit(let id):
            try? useCases.manageFolder.rename(folderID: id, to: name)
            try? useCases.manageFolder.update(folderID: id, color: palette, iconName: iconName)
        }
        onFinish()
        dismiss()
    }
}

/// 입력란 공통 외형. 테두리로 '눌러서 쓰는 칸'임을 드러내고, 포커스되면 브랜드색으로 강조한다.
/// 같은 시트의 이름·아이콘 검색 입력란이 서로 다르게 보이지 않도록 한 곳에 모아 둔다.
fileprivate struct InputFieldStyle: ViewModifier {

    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(GalpiColor.surface, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isFocused ? GalpiColor.main : GalpiColor.dash,
                        lineWidth: isFocused ? 1.5 : 1
                    )
            }
    }
}

fileprivate enum Constants {

    /// 한 번에 보여줄 검색 결과 수. 그리드 길이와 렌더 확인 비용을 같이 묶는다.
    static let iconSearchLimit = 120
}
