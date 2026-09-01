//
//  NormalizedURL.swift
//  GalpiKit
//
//  Created by euijjang97 on 9/1/26.
//

import Foundation

/// 중복 판정을 위해 URL 을 한 가지 표기로 맞춘다.
///
/// 같은 글이 인스타·카톡·트위터를 거치며 `utm_source`, `fbclid` 같은 꼬리표를 달고 오기 때문에,
/// 원문 그대로 비교하면 같은 링크가 매번 새 링크로 저장된다. 정규화 후 문자열 완전 일치로 판정한다.
public enum NormalizedURL {

    /// 붙어도 목적지가 달라지지 않는 추적 파라미터.
    private static let trackingPrefixes = ["utm_"]
    private static let trackingKeys: Set<String> = [
        "fbclid", "gclid", "igshid", "ref", "ref_src", "spm", "si",
    ]

    // MARK: - Function

    public static func canonical(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 스킴이 없으면 https 로 가정한다 — 공유 시트가 넘겨주는 문자열이 종종 그렇다.
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var components = URLComponents(string: withScheme),
              let host = components.host?.lowercased(),
              !host.isEmpty else {
            return nil
        }

        components.scheme = components.scheme?.lowercased()
        components.host = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        components.fragment = nil

        let kept = (components.queryItems ?? []).filter { item in
            let key = item.name.lowercased()
            return !trackingKeys.contains(key)
                && !trackingPrefixes.contains { key.hasPrefix($0) }
        }
        components.queryItems = kept.isEmpty ? nil : kept

        if components.path.count > 1, components.path.hasSuffix("/") {
            components.path.removeLast()
        }

        return components.url?.absoluteString
    }
}
