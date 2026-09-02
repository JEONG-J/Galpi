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
///
/// 심볼 이름은 전부 영문이라 한글 검색어는 어떤 이름에도 걸리지 않는다. 그래서 한글은
/// `koreanAliases` 로 영문 토큰을 먼저 찾고, 그 토큰으로 같은 검색을 돌린다.
enum SFSymbolCatalog {

    // MARK: - Property

    /// 줄 단위로 쪼갠 전체 이름. 처음 검색할 때 한 번만 만든다.
    private static let names: [String] = sfSymbolNameList
        .split(separator: "\n")
        .map(String.init)

    /// 한글 낱말 → 그 뜻에 맞는 영문 심볼 이름 토큰.
    ///
    /// 심볼 이름을 한글로 찾아주는 API 가 없어 표를 직접 들고 있는 수밖에 없다. 폴더 이름에
    /// 자주 쓰는 말 위주로 추렸고, 여기 없는 낱말은 빈 결과로 떨어진다(입력란이 한글·영문을
    /// 같이 안내한다). 한 낱말에 심볼이 여럿이면 대표적인 것을 앞에 둔다 — 결과 순서가 된다.
    private static let koreanAliases: [String: [String]] = [
        // 파일·글
        "폴더": ["folder"],
        "문서": ["doc"],
        "서류": ["doc"],
        "책": ["book"],
        "독서": ["book"],
        "노트": ["text.document", "square.and.pencil"],
        "메모": ["square.and.pencil", "text.document"],
        "글쓰기": ["square.and.pencil", "pencil"],
        "연필": ["pencil"],
        "북마크": ["bookmark"],
        "태그": ["tag"],
        "링크": ["link"],
        "신문": ["newspaper"],
        "뉴스": ["newspaper"],

        // 표시·상태
        "별": ["star"],
        "즐겨찾기": ["star", "bookmark"],
        "하트": ["heart"],
        "좋아요": ["heart", "hand.thumbsup"],
        "깃발": ["flag"],
        "왕관": ["crown"],
        "체크": ["checkmark"],
        "완료": ["checkmark.circle"],
        "경고": ["exclamationmark.triangle"],
        "정보": ["info.circle"],
        "질문": ["questionmark.circle"],
        "검색": ["magnifyingglass"],
        "설정": ["gearshape", "slider.horizontal.3"],
        "휴지통": ["trash"],
        "공유": ["square.and.arrow.up"],

        // 사람·장소
        "사람": ["person"],
        "프로필": ["person.crop.circle"],
        "계정": ["person.crop.circle"],
        "그룹": ["person.2", "person.3"],
        "팀": ["person.2", "person.3"],
        "집": ["house"],
        "홈": ["house"],
        "건물": ["building", "building.2"],
        "회사": ["building.2", "briefcase"],
        "은행": ["building.columns"],
        "학교": ["graduationcap", "building.columns"],
        "위치": ["location", "mappin"],
        "지도": ["map"],
        "지구": ["globe"],

        // 일상·취미
        "일": ["briefcase"],
        "업무": ["briefcase"],
        "가방": ["bag", "briefcase"],
        "공부": ["graduationcap", "book"],
        "게임": ["gamecontroller"],
        "음악": ["music.note"],
        "노래": ["music.note", "mic"],
        "헤드폰": ["headphones"],
        "영화": ["film"],
        "영상": ["video", "film"],
        "사진": ["photo", "camera"],
        "카메라": ["camera"],
        "그림": ["paintbrush", "paintpalette"],
        "디자인": ["paintpalette", "paintbrush"],
        "운동": ["dumbbell", "figure.run"],
        "건강": ["heart.text", "stethoscope"],
        "병원": ["cross.case", "stethoscope"],
        "잠": ["bed.double", "moon"],
        "선물": ["gift"],
        "생일": ["birthday.cake", "party.popper"],
        "동물": ["pawprint"],
        "식물": ["leaf", "tree"],
        "우산": ["umbrella"],

        // 먹고 사는 것
        "음식": ["fork.knife", "carrot"],
        "맛집": ["fork.knife"],
        "요리": ["fork.knife", "frying.pan"],
        "레시피": ["fork.knife", "frying.pan"],
        "커피": ["cup.and.saucer", "mug"],
        "카페": ["cup.and.saucer"],
        "쇼핑": ["cart", "bag"],
        "장바구니": ["cart"],
        "돈": ["dollarsign", "wonsign"],
        "금융": ["wonsign", "creditcard"],
        "카드": ["creditcard"],
        "지갑": ["wallet.bifold"],

        // 이동
        "여행": ["airplane", "suitcase", "map"],
        "비행기": ["airplane"],
        "자동차": ["car"],
        "자전거": ["bicycle"],
        "기차": ["tram"],

        // 개발·기기
        "개발": ["curlybraces", "chevron.left.forwardslash.chevron.right"],
        "코드": ["chevron.left.forwardslash.chevron.right", "curlybraces"],
        "코딩": ["curlybraces", "terminal"],
        "터미널": ["terminal"],
        "서버": ["server.rack", "externaldrive"],
        "클라우드": ["cloud"],
        "컴퓨터": ["desktopcomputer", "laptopcomputer"],
        "노트북": ["laptopcomputer"],
        "휴대폰": ["smartphone"],
        "키보드": ["keyboard"],
        "프린터": ["printer"],
        "배터리": ["battery.100"],
        "와이파이": ["wifi"],
        "차트": ["chart.bar", "chart.line.uptrend.xyaxis"],
        "통계": ["chart.bar", "chart.pie"],

        // 알림·소통
        "알림": ["bell"],
        "메일": ["envelope"],
        "편지": ["envelope"],
        "메시지": ["bubble"],
        "채팅": ["bubble.left.and.bubble.right", "bubble"],
        "전화": ["phone"],
        "시계": ["clock"],
        "시간": ["clock", "hourglass"],
        "달력": ["calendar"],
        "일정": ["calendar"],

        // 자연·기타
        "잠금": ["lock"],
        "보안": ["lock.shield", "shield"],
        "열쇠": ["key"],
        "불": ["flame"],
        "물": ["drop"],
        "날씨": ["cloud.sun", "sun.max"],
        "해": ["sun.max"],
        "달": ["moon"],
        "눈": ["snowflake", "eye"],
        "번개": ["bolt"],
        "퍼즐": ["puzzlepiece"],
        "가위": ["scissors"]
    ]

    // MARK: - Function

    /// 검색어에 맞는 심볼 이름.
    ///
    /// - Parameters:
    ///   - query: 영문이면 공백·점으로 나눈 토큰이 **모두** 들어있는 이름만 남긴다. (예: `arrow up`)
    ///     한글이면 별칭 표에서 검색어로 시작하는 낱말을 찾아 그 영문 토큰으로 검색한다. (예: `하트`)
    ///   - limit: 그리드에 한 번에 보여줄 최대 개수. 렌더 확인 비용도 이 수에 묶인다.
    static func search(_ query: String, limit: Int) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return [] }

        // 표의 키가 전부 한글이라 영문 검색어는 여기 걸릴 일이 없다. 한글 판별을 따로 안 한다.
        let aliases = englishTokens(forKorean: trimmed)
        guard aliases.isEmpty else { return matches(anyOf: aliases, limit: limit) }

        return matches(trimmed, limit: limit)
    }

    /// 이 기기에서 실제로 그려지는 심볼인지.
    static func isRenderable(_ name: String) -> Bool {
        UIImage(systemName: name) != nil
    }

    /// 별칭 표에서 검색어로 **시작하는** 낱말을 찾아 영문 토큰을 모은다.
    ///
    /// 다 치기 전에도 후보가 나오도록 완전 일치 대신 접두사로 본다(`하` → `하트`).
    /// 짧은 낱말일수록 검색어에 가까우니 그 결과를 앞에 둔다.
    private static func englishTokens(forKorean query: String) -> [String] {
        koreanAliases
            .filter { $0.key.hasPrefix(query) }
            .sorted { ($0.key.count, $0.key) < ($1.key.count, $1.key) }
            .flatMap(\.value)
    }

    /// 여러 검색어의 결과를 순서대로 이어 붙인다. 같은 심볼은 처음 나온 자리에만 둔다.
    private static func matches(anyOf queries: [String], limit: Int) -> [String] {
        var seen: Set<String> = []
        var results: [String] = []

        for query in queries {
            for name in matches(query, limit: limit) where seen.insert(name).inserted {
                results.append(name)
                if results.count == limit { return results }
            }
        }
        return results
    }

    /// 검색어 토큰을 모두 담은 이름. 검색어로 시작하는 이름을 앞에 둔다.
    private static func matches(_ query: String, limit: Int) -> [String] {
        let tokens = query
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
}
