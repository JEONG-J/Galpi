//
//  SourceApp.swift
//  GalpiKit
//
//  Created by euijjang97 on 9/1/26.
//

import Foundation

/// 링크가 어디서 왔는지 — 셀의 출처 배지에 쓴다.
///
/// 공유 시트는 출처 앱을 알려주지 않는다. 그래서 URL 호스트만 보고 되짚는다.
/// 판별에 실패하면 `.web` 이고, 그것도 정상 상태다(대부분의 링크가 `.web`).
public enum SourceApp: String, CaseIterable, Sendable {
    case youtube
    case instagram
    case kakao
    case naver
    case x
    case web

    // MARK: - Property

    /// 출처 배지용 SF Symbol.
    public var symbolName: String {
        switch self {
        case .youtube: "play.rectangle"
        case .instagram: "camera"
        case .kakao: "message"
        case .naver: "n.square"
        case .x: "at"
        case .web: "globe"
        }
    }

    public var displayName: String {
        switch self {
        case .youtube: "YouTube"
        case .instagram: "Instagram"
        case .kakao: "카카오"
        case .naver: "네이버"
        case .x: "X"
        case .web: "웹"
        }
    }

    /// 호스트 매칭 규칙. 서브도메인까지 포함하려고 접미사로 비교한다
    /// (`m.youtube.com`, `blog.naver.com` 등).
    private static let hostSuffixes: [(suffix: String, source: SourceApp)] = [
        ("youtube.com", .youtube),
        ("youtu.be", .youtube),
        ("instagram.com", .instagram),
        ("kakao.com", .kakao),
        ("kakaocdn.net", .kakao),
        ("naver.com", .naver),
        ("naver.me", .naver),
        ("twitter.com", .x),
        ("x.com", .x),
    ]

    // MARK: - Function

    public init(url: URL) {
        // `www.` 만 떼면 충분하다. 나머지 서브도메인은 접미사 비교가 흡수한다.
        guard var host = url.host()?.lowercased() else {
            self = .web
            return
        }
        if host.hasPrefix("www.") { host.removeFirst(4) }

        let matched = Self.hostSuffixes.first { host == $0.suffix || host.hasSuffix(".\($0.suffix)") }
        self = matched?.source ?? .web
    }

    public init(urlString: String) {
        guard let url = URL(string: urlString) else {
            self = .web
            return
        }
        self.init(url: url)
    }
}
