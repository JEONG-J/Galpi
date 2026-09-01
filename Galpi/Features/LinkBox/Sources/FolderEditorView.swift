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

    /// 색과 짝지어 쓰는 아이콘 후보. 시안의 폴더 4종에 쓰인 것부터 앞에 둔다.
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
                    preview

                    VStack(alignment: .leading, spacing: 10) {
                        Text("이름")
                            .font(GalpiFont.text(13, .semibold))
                            .foregroundStyle(GalpiColor.textSecondary)
                        TextField("폴더 이름", text: $name)
                            .font(GalpiFont.text(15, .semibold))
                            .padding(14)
                            .background(GalpiColor.surface, in: .rect(cornerRadius: 16))
                    }

                    section("색") {
                        ForEach(FolderPalette.allCases, id: \.self) { candidate in
                            swatch(candidate)
                        }
                        customSwatch
                    }

                    section("아이콘") {
                        ForEach(iconChoices, id: \.self) { symbol in
                            iconOption(symbol)
                        }
                    }
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
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    // MARK: - Function

    private var isCreating: Bool {
        if case .create = target { true } else { false }
    }

    private var pastel: GalpiPastel { GalpiPastel(name: palette.rawValue) }

    private var preview: some View {
        HStack(spacing: 12) {
            GalpiIconBadge(
                symbol: iconName, pastel: pastel, size: 44, cornerRadius: 14, iconSize: 20
            )
            Text(name.isEmpty ? "폴더 이름" : name)
                .font(GalpiFont.text(15, .bold))
                .foregroundStyle(name.isEmpty ? GalpiColor.textTertiary : GalpiColor.text)
            Spacer()
        }
        .padding(14)
        .galpiCard(cornerRadius: 20)
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(GalpiFont.text(13, .semibold))
                .foregroundStyle(GalpiColor.textSecondary)
            LazyVGrid(columns: gridColumns, spacing: 10, content: content)
        }
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
    }

    private func loadExisting() {
        guard case .edit(let id) = target,
              let folder = try? useCases.repository.folders().first(where: { $0.id == id })
        else { return }
        name = folder.name
        palette = folder.color
        iconName = folder.iconName
        if palette.isCustom, let picked = Color(galpiHex: palette.rawValue) {
            customColor = picked
        }
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
