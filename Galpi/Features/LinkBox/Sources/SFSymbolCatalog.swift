//
//  SFSymbolCatalog.swift
//  LinkBoxPresentation
//
//  Created by euijjang97 on 9/1/26.
//

import UIKit

/// 앱에 심어둔 SF Symbol 이름 목록에서 아이콘을 찾아준다.
///
/// 이름 목록은 생성물인 `SFSymbolNames.swift` 에 있고(전체 심볼을 열거하는 공개 API 가 없다),
/// 여기서는 검색과 "이 기기에서 실제로 그려지는가" 확인만 한다. 목록에 있어도 기기 OS 버전에
/// 따라 안 그려질 수 있어서, 내보내기 전에 `UIImage(systemName:)` 으로 한 번 거른다.
enum SFSymbolCatalog {

    // MARK: - Property

    /// 줄 단위로 쪼갠 전체 이름. 처음 검색할 때 한 번만 만든다.
    private static let names: [String] = sfSymbolNameList
        .split(separator: "\n")
        .map(String.init)

    // MARK: - Function

    /// 검색어에 맞는 심볼 이름. 검색어로 시작하는 이름을 앞에 둔다.
    ///
    /// - Parameters:
    ///   - query: 공백·점으로 나눈 토큰이 **모두** 들어있는 이름만 남긴다. (예: `arrow up`)
    ///   - limit: 그리드에 한 번에 보여줄 최대 개수. 렌더 확인 비용도 이 수에 묶인다.
    static func search(_ query: String, limit: Int) -> [String] {
        let tokens = query
            .lowercased()
            .split(whereSeparator: { $0 == " " || $0 == "." })
            .map(String.init)
        guard let head = tokens.first else { return [] }

        var prefixMatches: [String] = []
        var otherMatches: [String] = []

        for name in names {
            guard tokens.allSatisfy({ name.contains($0) }) else { continue }
            if name.hasPrefix(head) {
                prefixMatches.append(name)
            } else {
                otherMatches.append(name)
            }
            // 어느 쪽이든 한 화면 분량이 모이면 멈춘다. 6,000개를 끝까지 훑을 이유가 없다.
            if prefixMatches.count >= limit || otherMatches.count >= limit { break }
        }

        let candidates = prefixMatches + otherMatches
        return Array(candidates.lazy.filter(isRenderable).prefix(limit))
    }

    /// 이 기기에서 실제로 그려지는 심볼인지.
    static func isRenderable(_ name: String) -> Bool {
        UIImage(systemName: name) != nil
    }
}
