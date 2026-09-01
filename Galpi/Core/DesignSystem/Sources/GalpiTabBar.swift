//
//  GalpiTabBar.swift
//  GalpiDesignSystem
//
//  Created by euijjang97 on 9/1/26.
//

import SwiftUI

/// 떠 있는 탭 바 한 칸.
public struct GalpiTabItem: Identifiable, Hashable, Sendable {

    public let id: Int
    public let title: String
    public let symbol: String

    public init(id: Int, title: String, symbol: String) {
        self.id = id
        self.title = title
        self.symbol = symbol
    }
}

/// 시안의 떠 있는 탭 바 — 높이 56, 라운드 28, `#FFFFFFBF` + 배경 블러.
///
/// 시스템 `TabView` 대신 직접 그린다. 시안이 화면 아래에서 살짝 띄운 알약 형태에
/// 선택 칸만 틴트로 채우는 형태라, 시스템 탭 바로는 같은 모양이 나오지 않는다.
public struct GalpiTabBar: View {

    // MARK: - Property

    /// 콘텐츠가 탭 바에 가리지 않도록 스크롤 뷰 하단에 줘야 하는 여백.
    public static let contentBottomInset: CGFloat = 78

    private let items: [GalpiTabItem]
    @Binding private var selection: Int

    // MARK: - Function

    public init(items: [GalpiTabItem], selection: Binding<Int>) {
        self.items = items
        self._selection = selection
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                tab(item)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 56)
        .background(.regularMaterial, in: .rect(cornerRadius: 28))
        .background(GalpiColor.surface.opacity(0.75), in: .rect(cornerRadius: 28))
        .galpiShadow(.tabBar)
        .padding(.horizontal, 16)
    }

    private func tab(_ item: GalpiTabItem) -> some View {
        let isSelected = item.id == selection

        return Button {
            selection = item.id
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.symbol)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                Text(item.title)
                    .font(GalpiFont.text(10, isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? GalpiColor.main : GalpiColor.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                isSelected ? GalpiColor.tint : .clear,
                in: .rect(cornerRadius: 22)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// 탭 바를 숨겨야 하는 화면(시안 ④ 링크 노트처럼 하단 버튼을 쓰는 상세)이 올리는 신호.
public struct GalpiTabBarHiddenKey: PreferenceKey {

    public static let defaultValue = false

    public static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

public extension View {
    func galpiHidesTabBar(_ isHidden: Bool = true) -> some View {
        preference(key: GalpiTabBarHiddenKey.self, value: isHidden)
    }
}
