//
//  GalpiComponents.swift
//  GalpiDesignSystem
//
//  Created by euijjang97 on 9/1/26.
//

import SwiftUI

// MARK: - 카드

/// 시안의 흰 카드 — `$surface` 채움 + 라운드 + 그림자.
public struct GalpiCardBackground: ViewModifier {

    private let cornerRadius: CGFloat
    private let shadow: GalpiShadow

    public init(cornerRadius: CGFloat, shadow: GalpiShadow) {
        self.cornerRadius = cornerRadius
        self.shadow = shadow
    }

    public func body(content: Content) -> some View {
        content
            .background(GalpiColor.surface, in: .rect(cornerRadius: cornerRadius))
            .galpiShadow(shadow)
    }
}

public extension View {
    func galpiCard(
        cornerRadius: CGFloat,
        shadow: GalpiShadow = .card
    ) -> some View {
        modifier(GalpiCardBackground(cornerRadius: cornerRadius, shadow: shadow))
    }
}

// MARK: - 리스트 행

public extension View {

    /// 카드·헤더처럼 `List` 의 행 배경을 쓰지 않는 행. 배경·기본 여백·구분선을 모두 걷어내
    /// `ScrollView` 안에 있던 모습 그대로 얹는다.
    func plainListRow(insets: EdgeInsets = EdgeInsets()) -> some View {
        listRowBackground(Color.clear)
            .listRowInsets(insets)
            .listRowSeparator(.hidden)
    }
}

// MARK: - 섹션 헤더

/// `제목 [뱃지]  ⟷  액션` — 홈·보관함·내 정보가 공유하는 헤더.
public struct GalpiSectionHeader<Action: View>: View {

    private let title: String
    private let badgeCount: Int?
    private let action: Action

    public init(
        _ title: String,
        badgeCount: Int? = nil,
        @ViewBuilder action: () -> Action = { EmptyView() }
    ) {
        self.title = title
        self.badgeCount = badgeCount
        self.action = action()
    }

    public var body: some View {
        HStack(spacing: 7) {
            Text(title)
                .font(GalpiFont.sectionTitle)
                .foregroundStyle(GalpiColor.text)

            if let badgeCount, badgeCount > 0 {
                Text("\(badgeCount)")
                    .font(GalpiFont.text(11, .bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Color(rgba: 0xFF3B30FF), in: .circle)
                    .accessibilityLabel("\(badgeCount)개")
            }

            Spacer(minLength: 8)
            action
        }
    }
}

/// 섹션 헤더 우측의 텍스트 액션 — '전체 보기' · '편집'
public struct GalpiSectionAction: View {

    private let title: String
    private let handler: () -> Void

    public init(_ title: String, handler: @escaping () -> Void) {
        self.title = title
        self.handler = handler
    }

    public var body: some View {
        Button(title, action: handler)
            .font(GalpiFont.sectionAction)
            .foregroundStyle(GalpiColor.main)
            .buttonStyle(.plain)
    }
}

// MARK: - 아이콘 배지

/// 파스텔 배경 위의 아이콘 — 폴더·설정·스마트 리스트가 전부 이 형태다.
///
/// 모양 규칙: `cornerRadius == size / 2` 인 **원형**은 스마트 리스트처럼 개수를 세는
/// 고정 항목에, `size` 의 1/3 안팎인 **스퀘어클**은 폴더처럼 사용자가 만든 항목에 쓴다.
/// 두 모양이 한 화면에 섞이는 건 의도된 구분이다.
public struct GalpiIconBadge: View {

    private let symbol: String
    private let pastel: GalpiPastel
    private let size: CGFloat
    private let cornerRadius: CGFloat
    private let iconSize: CGFloat

    public init(
        symbol: String,
        pastel: GalpiPastel,
        size: CGFloat,
        cornerRadius: CGFloat,
        iconSize: CGFloat
    ) {
        self.symbol = symbol
        self.pastel = pastel
        self.size = size
        self.cornerRadius = cornerRadius
        self.iconSize = iconSize
    }

    public var body: some View {
        Image(systemName: symbol)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(pastel.foreground)
            .frame(width: size, height: size)
            .background(pastel.background, in: .rect(cornerRadius: cornerRadius))
    }
}

/// 시안의 파스텔 조합(전경 아이콘색 + 연한 배경). 폴더 색 12종에 1:1로 대응한다.
///
/// 12색 이름·`gray` 는 시안 값을 그대로 쓰고, 그 밖의 이름은 사용자가 고른 `#RRGGBB` 로
/// 보고 hex 하나에서 두 색을 파생한다. 이름도 hex 도 아니면 예전처럼 blue 로 떨어진다.
public struct GalpiPastel: Hashable, Sendable {

    // MARK: - Property

    /// 12색 이름·`gray`, 또는 `#RRGGBB` 커스텀 hex.
    public let name: String

    public static let red = GalpiPastel(name: "red")
    public static let orange = GalpiPastel(name: "orange")
    public static let yellow = GalpiPastel(name: "yellow")
    public static let green = GalpiPastel(name: "green")
    public static let mint = GalpiPastel(name: "mint")
    public static let teal = GalpiPastel(name: "teal")
    public static let cyan = GalpiPastel(name: "cyan")
    public static let blue = GalpiPastel(name: "blue")
    public static let indigo = GalpiPastel(name: "indigo")
    public static let purple = GalpiPastel(name: "purple")
    public static let pink = GalpiPastel(name: "pink")
    public static let brown = GalpiPastel(name: "brown")
    /// 시안의 '받은함'·'데이터 내보내기' 같은 무채색 자리.
    public static let gray = GalpiPastel(name: "gray")

    public var foreground: Color {
        switch name {
        case "red": Color(rgba: 0xFF3B30FF)
        case "orange": Color(rgba: 0xFF9500FF)
        case "yellow": Color(rgba: 0xFFC400FF)
        case "green": Color(rgba: 0x34C759FF)
        case "mint": Color(rgba: 0x00C7BEFF)
        case "teal": Color(rgba: 0x30B0C7FF)
        case "cyan": Color(rgba: 0x5AC8FAFF)
        case "blue": Color(rgba: 0x2E5AE5FF)
        case "indigo": Color(rgba: 0x5856D6FF)
        case "purple": Color(rgba: 0xAF52DEFF)
        case "pink": Color(rgba: 0xFF2D55FF)
        case "brown": Color(rgba: 0xA2845EFF)
        case "gray": Color(rgba: 0x8E8E93FF)
        default: GalpiPastelDerivation.derive(hex: name)?.foreground
            ?? Color(rgba: 0x2E5AE5FF)
        }
    }

    public var background: Color {
        switch name {
        case "red": Color(rgba: 0xFFE8E6FF)
        case "orange": Color(rgba: 0xFFF3E0FF)
        case "yellow": Color(rgba: 0xFFF6D9FF)
        case "green": Color(rgba: 0xE5F8EAFF)
        case "mint": Color(rgba: 0xDFF7F5FF)
        case "teal": Color(rgba: 0xE2F3F7FF)
        case "cyan": Color(rgba: 0xE4F5FEFF)
        case "blue": Color(rgba: 0xE8EDFCFF)
        case "indigo": Color(rgba: 0xECECFAFF)
        case "purple": Color(rgba: 0xF3E9FBFF)
        case "pink": Color(rgba: 0xFFE7EEFF)
        case "brown": Color(rgba: 0xF3EEE8FF)
        case "gray": Color(rgba: 0xF0F0F3FF)
        default: GalpiPastelDerivation.derive(hex: name)?.background
            ?? Color(rgba: 0xE8EDFCFF)
        }
    }

    // MARK: - Function

    public init(name: String) {
        self.name = name
    }
}

// MARK: - 칩

/// 태그·추천 태그 칩. 선택 여부로 채움과 글자색이 바뀐다(시안 저장 카드).
public struct GalpiChip: View {

    private let title: String
    private let count: Int?
    private let isSelected: Bool

    public init(_ title: String, count: Int? = nil, isSelected: Bool = false) {
        self.title = title
        self.count = count
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .font(GalpiFont.text(12, .semibold))
                .foregroundStyle(isSelected ? GalpiColor.main : GalpiColor.text)

            if let count {
                Text("\(count)")
                    .font(GalpiFont.text(11, .semibold))
                    .foregroundStyle(GalpiColor.textTertiary)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background(
            isSelected ? GalpiColor.tint : GalpiColor.surface,
            in: .rect(cornerRadius: 15)
        )
        .galpiShadow(.chip)
    }
}

// MARK: - 진행 트랙

/// '이번 주 소비율' 막대. 트랙 8pt, 채움은 `$main`.
public struct GalpiProgressTrack: View {

    private let progress: Double

    public init(progress: Double) {
        self.progress = min(max(progress, 0), 1)
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(GalpiColor.thumbnail)
                Capsule()
                    .fill(GalpiColor.main)
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

// MARK: - 썸네일

/// 링크 썸네일. 이미지가 없으면 `$thumb` 위에 출처 글리프를 얹는다(시안 기본형).
public struct GalpiThumbnail: View {

    private let imageData: Data?
    private let symbol: String
    private let cornerRadius: CGFloat
    private let glyphSize: CGFloat

    public init(
        imageData: Data?,
        symbol: String,
        cornerRadius: CGFloat,
        glyphSize: CGFloat
    ) {
        self.imageData = imageData
        self.symbol = symbol
        self.cornerRadius = cornerRadius
        self.glyphSize = glyphSize
    }

    public var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                GalpiColor.thumbnail.overlay {
                    Image(systemName: symbol)
                        .font(.system(size: glyphSize, weight: .medium))
                        .foregroundStyle(GalpiColor.glyph)
                }
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
    }
}

// MARK: - 주요 버튼

/// '원문 열기' · '저장하기' — 54pt 높이 캡슐, `$main` 채움.
public struct GalpiPrimaryButton: View {

    private let title: String
    private let symbol: String?
    private let handler: () -> Void

    public init(_ title: String, symbol: String? = nil, handler: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.handler = handler
    }

    public var body: some View {
        Button(action: handler) {
            HStack(spacing: 8) {
                Text(title).font(GalpiFont.text(16, .bold))
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(GalpiColor.main, in: .capsule)
            .galpiShadow(.primaryButton)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 리스트 구분선

/// 카드 안쪽 행 사이 1pt 선. 시안은 좌우 여백 없이 카드 폭 전체를 가른다.
public struct GalpiSeparator: View {

    private let leadingInset: CGFloat

    public init(leadingInset: CGFloat = 0) {
        self.leadingInset = leadingInset
    }

    public var body: some View {
        GalpiColor.separator
            .frame(height: 1)
            .padding(.leading, leadingInset)
    }
}
