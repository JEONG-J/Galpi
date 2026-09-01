//
//  GalpiDesignSystemTests.swift
//  GalpiDesignSystemTests
//
//  Created by euijjang97 on 9/1/26.
//

import Testing

@testable import GalpiDesignSystem

/// 0~255 표기를 0~1 성분으로.
private func components(_ red: Double, _ green: Double, _ blue: Double) -> [Double] {
    [red / 255, green / 255, blue / 255]
}

// MARK: - 커스텀 폴더 색 파생

@Suite("커스텀 폴더 색 파생")
struct GalpiPastelDerivationTests {

    @Test(
        "hex 를 0~1 sRGB 성분으로 읽는다",
        arguments: [
            ("#2E5AE5", components(46, 90, 229)),
            ("2e5ae5", components(46, 90, 229)),
            ("#FFFFFF", [1.0, 1.0, 1.0]),
            ("#000000", [0.0, 0.0, 0.0]),
        ]
    )
    func parsesHex(hex: String, expected: [Double]) throws {
        #expect(try #require(GalpiPastelDerivation.components(hex: hex)) == expected)
    }

    @Test(
        "hex 가 아니면 nil — 이 경우 GalpiPastel 은 blue 로 떨어진다",
        arguments: ["blue", "", "#12345", "#1234567", "#GGGGGG", "12 34 56"]
    )
    func rejectsNonHex(name: String) {
        #expect(GalpiPastelDerivation.components(hex: name) == nil)
    }

    /// 커스텀 색 배경이 시안 12색의 전경↔배경 관계를 그대로 재현하는지.
    @Test(
        "파생 배경이 시안 12색 표와 같은 톤이다",
        arguments: [
            (components(46, 90, 229), components(232, 237, 252)),   // blue
            (components(255, 59, 48), components(255, 232, 230)),   // red
            (components(162, 132, 94), components(243, 238, 232)),  // brown
            (components(142, 142, 147), components(240, 240, 243)), // gray
        ]
    )
    func derivesBackgroundLikeDesignTable(base: [Double], expected: [Double]) {
        let derived = GalpiPastelDerivation.backgroundComponents(base)
        for (actual, target) in zip(derived, expected) {
            #expect(abs(actual - target) < 0.03)
        }
    }

    /// 노랑·흰색처럼 밝은 색을 골라도 배지 아이콘이 배경 위에서 읽혀야 한다.
    @Test(
        "어떤 색을 골라도 전경 대비가 3:1 을 넘는다",
        arguments: [
            "#FFFF00", "#FFFFFF", "#FFFDE0", "#000000", "#2E5AE5", "#00C7BE",
        ]
    )
    func keepsForegroundReadable(hex: String) throws {
        let base = try #require(GalpiPastelDerivation.components(hex: hex))
        let background = GalpiPastelDerivation.backgroundComponents(base)
        let foreground = GalpiPastelDerivation.foregroundComponents(base, on: background)
        #expect(GalpiPastelDerivation.contrast(foreground, background) >= 3.0)
    }
}
