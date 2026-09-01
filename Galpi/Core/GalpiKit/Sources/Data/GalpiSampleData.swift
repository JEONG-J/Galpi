//
//  GalpiSampleData.swift
//  GalpiKit
//
//  Created by euijjang97 on 9/1/26.
//

#if DEBUG
import Foundation

/// 시안(`Galpi.pen`)에 그려진 내용을 그대로 넣어 두는 개발용 시드.
///
/// 릴리스 빌드에는 포함되지 않는다. 실제 첫 실행은 비어 있는 게 맞고, 그 상태의 빈 화면도
/// 화면마다 따로 그려 두었다.
public enum GalpiSampleData {

    // MARK: - Function

    /// 스토어가 비어 있을 때만 채운다. 두 번 실행해도 중복되지 않는다.
    @MainActor
    public static func seedIfEmpty(repository: any LinkRepository, now: Date = .now) throws {
        guard try repository.links(matching: .all, includeArchived: true, limit: 1).isEmpty else {
            return
        }

        let folders = [
            Folder(name: "개발", color: .purple, iconName: "chevron.left.forwardslash.chevron.right", sortOrder: 0),
            Folder(name: "디자인", color: .pink, iconName: "paintpalette.fill", sortOrder: 1),
            Folder(name: "레시피", color: .green, iconName: "fork.knife", sortOrder: 2),
            Folder(name: "여행", color: .orange, iconName: "airplane", sortOrder: 3),
        ]
        folders.forEach(repository.insert)

        func daysAgo(_ days: Int) -> Date { now.addingTimeInterval(-Double(days) * 86_400) }
        func tags(_ names: String...) throws -> [Tag] { try names.map { try repository.tag(named: $0) } }

        // 미열람 캐러셀 — 오래 묵은 순서가 그대로 보인다.
        let unread = [
            Link(
                urlString: "https://developer.apple.com/swift-concurrency",
                title: "Swift Concurrency 완벽 가이드",
                summary: "async/await 와 actor 로 동시성 코드를 안전하게 쓰는 법을 정리한 문서. "
                    + "구조적 동시성과 데이터 경합 방지가 핵심이다.",
                createdAt: daysAgo(3),
                folder: folders[0],
                tags: try tags("스위프트", "동시성", "가이드")
            ),
            Link(
                urlString: "https://brunch.co.kr/ui-trend-2026",
                title: "2026 UI 트렌드 리포트",
                createdAt: daysAgo(5),
                folder: folders[1],
                tags: try tags("디자인영감", "읽을거리")
            ),
            Link(
                urlString: "https://blog.naver.com/kyoto-course",
                title: "교토 3박 4일 코스",
                createdAt: daysAgo(7),
                folder: folders[3],
                tags: try tags("읽을거리")
            ),
        ]

        // 최근 저장 — 이미 읽은 링크들.
        let read = [
            Link(
                urlString: "https://swiftwithmajid.com/animation-recipes",
                title: "SwiftUI 애니메이션 레시피",
                createdAt: daysAgo(1),
                viewCount: 2,
                lastViewedAt: daysAgo(0),
                folder: folders[0],
                tags: try tags("스위프트", "디자인영감")
            ),
            Link(
                urlString: "https://minimalposters.example.com/archive",
                title: "미니멀 포스터 아카이브",
                createdAt: daysAgo(2),
                viewCount: 1,
                lastViewedAt: daysAgo(1),
                isFavorite: true,
                folder: folders[1],
                tags: try tags("디자인영감")
            ),
            Link(
                urlString: "https://www.youtube.com/watch?v=gambas",
                title: "10분 감바스 만들기",
                createdAt: daysAgo(4),
                viewCount: 3,
                lastViewedAt: daysAgo(2),
                isFavorite: true,
                folder: folders[2],
                tags: try tags("맛집", "투두")
            ),
            Link(
                urlString: "https://blog.naver.com/osaka-local-12",
                title: "오사카 로컬 맛집 12선",
                createdAt: daysAgo(6),
                viewCount: 1,
                lastViewedAt: daysAgo(3),
                folder: folders[3],
                tags: try tags("맛집", "읽을거리")
            ),
            // 폴더 미지정 = 받은함.
            Link(
                urlString: "https://news.example.com/weekly-digest",
                title: "이번 주 개발 뉴스 다이제스트",
                createdAt: daysAgo(8),
                viewCount: 1,
                lastViewedAt: daysAgo(4),
                tags: try tags("읽을거리")
            ),
        ]

        (unread + read).forEach(repository.insert)
        try repository.save()
    }
}
#endif
