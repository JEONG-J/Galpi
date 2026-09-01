//
//  GalpiTheme.swift
//  GalpiDesignSystem
//
//  Created by euijjang97 on 9/1/26.
//

import SwiftUI

/// 시안(`Galpi.pen`)의 디자인 변수를 그대로 옮긴 색 토큰.
///
/// 시안은 라이트 전용이라 다크 팔레트가 없다. 다크 대응은 시안이 나온 뒤에 붙이고,
/// 그때까지 앱은 `UIUserInterfaceStyle: Light` 로 라이트에 고정한다.
public enum GalpiColor {

    // MARK: - Property

    /// `$main` — 브랜드 블루.
    public static let main = Color(rgba: 0x2E5AE5FF)
    /// `$bg` — 화면 배경.
    public static let background = Color(rgba: 0xF2F5FCFF)
    /// `$surface` — 카드 배경.
    public static let surface = Color(rgba: 0xFFFFFFFF)
    /// `$thumb` — 썸네일 플레이스홀더.
    public static let thumbnail = Color(rgba: 0xE8EDF6FF)
    /// `$text` — 본문.
    public static let text = Color(rgba: 0x1C1C1EFF)
    /// `$text2` — 메타.
    public static let textSecondary = Color(rgba: 0x3C3C4399)
    /// `$text3` — 보조·셰브론.
    public static let textTertiary = Color(rgba: 0x3C3C4366)
    /// `$sep` — 구분선.
    public static let separator = Color(rgba: 0x3C3C434A)
    /// `$tint` — 선택된 칩·탭 채움.
    public static let tint = Color(rgba: 0x2E5AE51F)
    /// `$aibox` — AI 요약 박스 배경.
    public static let aiBox = Color(rgba: 0x2E5AE514)
    /// `$dash` — "새 폴더" 점선 테두리·파비콘 자리.
    public static let dash = Color(rgba: 0xB9C6EAFF)

    /// 썸네일 자리에 얹는 글리프 색. 시안에 변수로는 없고 리터럴로 반복된다.
    public static let glyph = Color(rgba: 0x9AA8CCFF)
}

/// 시안의 텍스트 스타일. 크기·굵기·자간이 시안 값 그대로다.
///
/// 시안은 Noto Sans KR 를 쓰지만 폰트 파일이 레포에 없고 iOS 기본 폰트에도 없다.
/// 지금은 시스템 폰트로 그리고, 폰트를 넣게 되면 이 열거형 한 곳만 고치면 된다.
public enum GalpiFont {

    // MARK: - Function

    public static func text(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight)
    }

    /// 화면 상단 라지 타이틀 — 34/700, 자간 -0.8
    public static let largeTitle = text(34, .bold)
    /// 섹션 헤더 — 17/700
    public static let sectionTitle = text(17, .bold)
    /// 섹션 헤더 우측 액션 — 13/600
    public static let sectionAction = text(13, .semibold)
}

/// 시안의 그림자 토큰. `blur` 는 디자인 툴 기준값이라 SwiftUI `radius` 로는 절반을 쓴다.
public struct GalpiShadow: Sendable {

    // MARK: - Property

    public let color: Color
    public let blur: CGFloat
    public let y: CGFloat

    /// 미열람 카드 — blur16 `#2E5AE514` (0,4)
    public static let unreadCard = GalpiShadow(color: Color(rgba: 0x2E5AE514), blur: 16, y: 4)
    /// 주간 통계·설정 카드 — blur10 `#2E5AE50D` (0,2)
    public static let card = GalpiShadow(color: Color(rgba: 0x2E5AE50D), blur: 10, y: 2)
    /// 태그 칩 — blur6 `#2E5AE50D` (0,1)
    public static let chip = GalpiShadow(color: Color(rgba: 0x2E5AE50D), blur: 6, y: 1)
    /// 프로필 카드 — blur14 `#2E5AE514` (0,3)
    public static let profileCard = GalpiShadow(color: Color(rgba: 0x2E5AE514), blur: 14, y: 3)
    /// 마스코트 — blur12 `#2E5AE53D` (0,4)
    public static let mascot = GalpiShadow(color: Color(rgba: 0x2E5AE53D), blur: 12, y: 4)
    /// 토글 손잡이 — blur3 `#00000026` (0,1)
    public static let toggleKnob = GalpiShadow(color: Color(rgba: 0x00000026), blur: 3, y: 1)
    /// 주요 액션 버튼 — blur14 `#2E5AE54D` (0,4)
    public static let primaryButton = GalpiShadow(color: Color(rgba: 0x2E5AE54D), blur: 14, y: 4)
}

public extension View {
    func galpiShadow(_ shadow: GalpiShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.blur / 2, x: 0, y: shadow.y)
    }
}

public extension Color {
    /// `0xRRGGBBAA` 리터럴 — 시안 변수를 눈으로 대조할 수 있게 알파까지 한 값에 담는다.
    init(rgba: UInt32) {
        self.init(
            .sRGB,
            red: Double((rgba >> 24) & 0xFF) / 255,
            green: Double((rgba >> 16) & 0xFF) / 255,
            blue: Double((rgba >> 8) & 0xFF) / 255,
            opacity: Double(rgba & 0xFF) / 255
        )
    }
}

public extension Color {
    /// `#RRGGBB` 문자열로 만든 색. 형식이 어긋나면 nil.
    init?(galpiHex: String) {
        guard let rgb = GalpiPastelDerivation.components(hex: galpiHex) else { return nil }
        self.init(.sRGB, red: rgb[0], green: rgb[1], blue: rgb[2])
    }

    /// ColorPicker 가 준 색을 `#RRGGBB` 로 — `Folder.colorName` 에 그대로 저장한다.
    func galpiHex(in environment: EnvironmentValues) -> String {
        GalpiPastelDerivation.hex(resolve(in: environment))
    }
}

/// 사용자가 고른 `#RRGGBB` 하나에서 배지 전경·배경을 만든다.
///
/// 시안 12색의 배경은 "전경색을 흰색과 12% 로 섞은 것"이다 — `#2E5AE5` → `#E8EDFC`,
/// `#FF3B30` → `#FFE8E6` 가 모두 이 비율로 재현된다. 커스텀 색도 같은 규칙을 쓴다.
/// 다만 노란색처럼 밝은 색을 고르면 아이콘이 배경에 묻히므로, 대비가 3:1(WCAG 큰 텍스트
/// 기준)을 넘을 때까지 전경을 어둡게 죈다. 배경은 고른 색 그대로 두어 색감을 지킨다.
enum GalpiPastelDerivation {

    // MARK: - Property

    /// 배경에 남는 원색 비율 — 시안 12색 표를 역산한 값.
    private static let backgroundTint = 0.12
    /// 배지 아이콘이 배경 위에서 읽히는 최소 대비.
    private static let minimumContrast = 3.0
    /// 대비가 모자랄 때 전경을 한 번에 죄는 비율.
    private static let darkenStep = 0.85

    // MARK: - Function

    /// 하나의 hex 에서 배지 전경·배경을 만든다. 형식이 어긋나면 nil.
    static func derive(hex: String) -> (foreground: Color, background: Color)? {
        guard let base = components(hex: hex) else { return nil }
        let background = backgroundComponents(base)
        return (color(foregroundComponents(base, on: background)), color(background))
    }

    /// `#RRGGBB` / `RRGGBB` → 0~1 sRGB 3성분. 형식이 어긋나면 nil.
    static func components(hex: String) -> [Double]? {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6,
              digits.allSatisfy(\.isHexDigit),
              let value = UInt32(digits, radix: 16)
        else { return nil }
        return [
            Double((value >> 16) & 0xFF) / 255,
            Double((value >> 8) & 0xFF) / 255,
            Double(value & 0xFF) / 255,
        ]
    }

    /// 고른 색을 흰색 쪽으로 밀어 만든 연한 배경.
    static func backgroundComponents(_ base: [Double]) -> [Double] {
        base.map { $0 * backgroundTint + (1 - backgroundTint) }
    }

    /// 배경 위에서 최소 대비를 넘길 때까지 어둡게 죈 전경.
    static func foregroundComponents(_ base: [Double], on background: [Double]) -> [Double] {
        var foreground = base
        while contrast(foreground, background) < minimumContrast,
              foreground.contains(where: { $0 > 0.004 }) {
            foreground = foreground.map { $0 * darkenStep }
        }
        return foreground
    }

    /// WCAG 상대 휘도.
    static func relativeLuminance(_ rgb: [Double]) -> Double {
        let linear = rgb.map { channel in
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }

    /// WCAG 명암비 — 1.0(같은 색) ~ 21.0(흑백).
    static func contrast(_ one: [Double], _ other: [Double]) -> Double {
        let first = relativeLuminance(one)
        let second = relativeLuminance(other)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    /// `Color.Resolved` → `#RRGGBB`. 색 영역 밖 성분은 0~1 로 자른다.
    static func hex(_ resolved: Color.Resolved) -> String {
        [resolved.red, resolved.green, resolved.blue]
            .map { String(format: "%02X", Int((min(max(Double($0), 0), 1) * 255).rounded())) }
            .reduce("#", +)
    }

    private static func color(_ rgb: [Double]) -> Color {
        Color(.sRGB, red: rgb[0], green: rgb[1], blue: rgb[2])
    }
}
