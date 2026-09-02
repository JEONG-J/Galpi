//
//  SplashView.swift
//  Galpi
//
//  Created by euijjang97 on 9/2/26.
//

import SwiftUI

/// 앱 아이콘(파란 그라디언트 + 흰 리본)이 그대로 살아 움직이는 스플래시.
///
/// 아이콘 배경 그라디언트는 `Galpi.icon/icon.json` 의 값을 그대로 옮겼다 — 홈 화면 아이콘에서
/// 앱으로 넘어올 때 배경이 이어지도록. 리본은 `SplashRibbon.png`(아이콘 포그라운드와 같은 파일).
struct SplashView: View {

    // MARK: - Property

    /// 퇴장 애니메이션까지 끝난 뒤 호출된다.
    let onFinish: () -> Void

    @State private var phase: Phase = .hidden
    @State private var shineOffset: CGFloat = -Constants.shineTravel
    @State private var isLeaving = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 리본이 지나는 단계. 값이 바뀔 때마다 리본·링·반짝이가 한꺼번에 따라온다.
    private enum Phase {
        case hidden, burst, settled
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            background
            glow
            rings
            sparkles
            ribbon
        }
        .ignoresSafeArea()
        .opacity(isLeaving ? 0 : 1)
        .scaleEffect(isLeaving ? Constants.exitScale : 1)
        .task { await play() }
    }

    /// 아이콘과 같은 세로 그라디언트.
    private var background: some View {
        LinearGradient(
            colors: [Constants.gradientTop, Constants.gradientBottom],
            startPoint: .top,
            endPoint: UnitPoint(x: 0.5, y: 0.7)
        )
    }

    /// 리본 뒤에서 번지는 빛. 리본이 튀어나오는 순간 같이 부풀었다가 잦아든다.
    private var glow: some View {
        RadialGradient(
            colors: [.white.opacity(0.45), .clear],
            center: .center,
            startRadius: 0,
            endRadius: Constants.glowRadius
        )
        .scaleEffect(phase == .hidden ? 0.2 : 1)
        .opacity(phase == .burst ? 1 : (phase == .settled ? 0.35 : 0))
        .blendMode(.plusLighter)
    }

    /// 리본이 터져 나온 자리에서 퍼지는 두 겹의 파문.
    private var rings: some View {
        ForEach(0..<2, id: \.self) { index in
            Circle()
                .strokeBorder(.white.opacity(0.5), lineWidth: Constants.ringWidth)
                .frame(width: Constants.ringSize, height: Constants.ringSize)
                .scaleEffect(phase == .hidden ? 0.1 : Constants.ringMaxScale)
                .opacity(phase == .hidden ? 0.9 : 0)
                .animation(
                    .easeOut(duration: Constants.ringDuration)
                        .delay(Constants.ringStagger * Double(index)),
                    value: phase
                )
        }
    }

    /// 리본을 중심으로 흩어지는 반짝이.
    private var sparkles: some View {
        ForEach(0..<Constants.sparkleCount, id: \.self) { index in
            let angle = Angle.degrees(360 / Double(Constants.sparkleCount) * Double(index) - 90)
            let distance = phase == .hidden ? 0 : Constants.sparkleDistance

            Circle()
                .fill(.white)
                .frame(width: Constants.sparkleSize, height: Constants.sparkleSize)
                .offset(
                    x: cos(angle.radians) * distance,
                    y: sin(angle.radians) * distance
                )
                .opacity(phase == .hidden ? 0 : (phase == .burst ? 1 : 0))
                .blendMode(.plusLighter)
                .animation(
                    .easeOut(duration: Constants.sparkleDuration)
                        .delay(Constants.sparkleStagger * Double(index % 4)),
                    value: phase
                )
        }
    }

    /// 흰 리본 — 튀어 오르며 자리를 잡고, 그 위로 사선 광택이 한 번 훑고 지나간다.
    private var ribbon: some View {
        ribbonShape
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, Constants.ribbonShade],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.95), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: Constants.shineWidth)
                .rotationEffect(.degrees(Constants.shineAngle))
                .offset(x: shineOffset)
                .blendMode(.plusLighter)
                .mask(ribbonShape)
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
            .scaleEffect(phase == .hidden ? 0.35 : 1)
            .rotationEffect(.degrees(phase == .hidden ? -14 : 0))
            .offset(y: phase == .hidden ? -Constants.ribbonDrop : 0)
            .opacity(phase == .hidden ? 0 : 1)
    }

    private var ribbonShape: some View {
        Image(uiImage: Constants.ribbonImage)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: Constants.ribbonWidth, height: Constants.ribbonHeight)
    }

    // MARK: - Function

    /// 등장 → 정착 → 퇴장. 모션 최소화를 켠 사용자에게는 페이드만 남긴다.
    private func play() async {
        guard !reduceMotion else {
            withAnimation(.easeIn(duration: 0.2)) { phase = .settled }
            try? await Task.sleep(for: .seconds(0.8))
            withAnimation(.easeOut(duration: 0.3)) { isLeaving = true }
            try? await Task.sleep(for: .seconds(0.3))
            onFinish()
            return
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.5)) { phase = .burst }

        try? await Task.sleep(for: .seconds(Constants.shineDelay))
        withAnimation(.easeInOut(duration: Constants.shineDuration)) {
            shineOffset = Constants.shineTravel
        }

        try? await Task.sleep(for: .seconds(Constants.settleDelay))
        withAnimation(.easeOut(duration: 0.4)) { phase = .settled }

        try? await Task.sleep(for: .seconds(Constants.holdDuration))
        withAnimation(.easeIn(duration: Constants.exitDuration)) { isLeaving = true }

        try? await Task.sleep(for: .seconds(Constants.exitDuration))
        onFinish()
    }
}

// MARK: - Constants

private enum Constants {
    /// `icon.json` 의 linear-gradient 두 정지점.
    static let gradientTop = Color(.sRGB, red: 0.36863, green: 0.52549, blue: 1.0)
    static let gradientBottom = Color(.sRGB, red: 0.12157, green: 0.24706, blue: 0.78824)
    /// 리본 아래쪽에 지는 아주 옅은 그림자 — 순백 단색보다 입체가 산다.
    static let ribbonShade = Color(.sRGB, red: 0.90, green: 0.93, blue: 1.0)

    /// SwiftUI `Image(_:)` 는 에셋 카탈로그만 뒤진다. 이 레포엔 카탈로그가 없어
    /// 느슨한 PNG 는 UIKit 쪽 이름 조회로만 잡힌다.
    static let ribbonImage = UIImage(named: "SplashRibbon") ?? UIImage()

    /// 원본 440×620 비율 그대로.
    static let ribbonWidth: CGFloat = 128
    static let ribbonHeight: CGFloat = 180
    static let ribbonDrop: CGFloat = 160

    static let glowRadius: CGFloat = 320

    static let ringSize: CGFloat = 180
    static let ringWidth: CGFloat = 2
    static let ringMaxScale: CGFloat = 3.2
    static let ringDuration: Double = 1.0
    static let ringStagger: Double = 0.18

    static let sparkleCount = 12
    static let sparkleSize: CGFloat = 6
    static let sparkleDistance: CGFloat = 190
    static let sparkleDuration: Double = 0.9
    static let sparkleStagger: Double = 0.06

    static let shineWidth: CGFloat = 70
    static let shineAngle: Double = 20
    static let shineTravel: CGFloat = 160
    static let shineDelay: Double = 0.35
    static let shineDuration: Double = 0.65

    static let settleDelay: Double = 0.5
    static let holdDuration: Double = 0.45
    static let exitDuration: Double = 0.45
    static let exitScale: CGFloat = 1.35
}

#Preview {
    SplashView(onFinish: {})
}
