//
//  GalpiEmptyState.swift
//  GalpiDesignSystem
//
//  Created by euijjang97 on 9/1/26.
//

import SwiftUI

/// 데이터가 0건일 때 자리를 채우는 카드 — 심볼 + 제목 + 설명 (+ 선택 액션).
///
/// 시안에는 없지만 실제 첫 실행에서 반드시 지나가는 화면이라 홈·검색·보관함·목록·내 정보가
/// 전부 이 하나를 쓴다. 흰 카드 배경까지 포함하므로 다른 카드 안에 넣지 말고 카드 자리를
/// 통째로 대체한다.
public struct GalpiEmptyState: View {

    /// 빈 상태에서 바로 할 수 있는 다음 행동. 없으면 문구만 보여준다.
    public struct Action {

        // MARK: - Property

        let title: String
        let handler: () -> Void

        // MARK: - Function

        public init(title: String, handler: @escaping () -> Void) {
            self.title = title
            self.handler = handler
        }
    }

    // MARK: - Property

    private let symbol: String
    private let title: String
    private let message: String
    private let action: Action?

    // 토큰 크기(15·12·13)를 기준값으로 두고 Dynamic Type 배율만 얹는다. `GalpiFont` 는 고정
    // 크기라 앱 전체가 배율을 따르지 않지만, 이 카드는 높이가 고정돼 있지 않아 늘어나도 안전하다.
    @ScaledMetric(relativeTo: .headline) private var titleSize: CGFloat = 15
    @ScaledMetric(relativeTo: .footnote) private var messageSize: CGFloat = 12
    @ScaledMetric(relativeTo: .footnote) private var actionSize: CGFloat = 13

    // MARK: - Function

    public init(symbol: String, title: String, message: String, action: Action? = nil) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(GalpiColor.glyph)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(GalpiFont.text(titleSize, .bold))
                    .foregroundStyle(GalpiColor.text)
                Text(message)
                    .font(GalpiFont.text(messageSize, .medium))
                    .foregroundStyle(GalpiColor.textSecondary)
            }
            // 큰 글자 크기에서 문구가 잘리지 않고 줄을 늘려 잡게 한다.
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title). \(message)")

            if let action {
                Button(action: action.handler) {
                    Text(action.title)
                        .font(GalpiFont.text(actionSize, .semibold))
                        .foregroundStyle(GalpiColor.main)
                        .padding(.horizontal, 18)
                        // 문구 길이·글자 크기와 무관하게 최소 터치 영역 44pt 를 지킨다.
                        .frame(minHeight: 44)
                        .background(GalpiColor.tint, in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .galpiCard(cornerRadius: 20)
    }
}

#if DEBUG
#Preview("빈 상태") {
    VStack(spacing: 16) {
        GalpiEmptyState(
            symbol: "bookmark",
            title: "아직 갈피가 없어요",
            message: "공유 시트에서 갈피를 눌러 첫 링크를 꽂아보세요."
        )

        GalpiEmptyState(
            symbol: "checkmark.circle",
            title: "다 읽었어요",
            message: "안 읽은 갈피가 하나도 없어요.",
            action: .init(title: "전체 갈피 보기") {}
        )
    }
    .padding(16)
    .frame(maxHeight: .infinity)
    .background(GalpiColor.background)
}
#endif
