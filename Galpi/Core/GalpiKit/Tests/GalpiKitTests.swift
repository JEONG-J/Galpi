//
//  GalpiKitTests.swift
//  GalpiKitTests
//
//  Created by euijjang97 on 9/1/26.
//

import Foundation
import SwiftData
import Testing

@testable import GalpiKit

@MainActor
private func makeRepository() throws -> SwiftDataLinkRepository {
    SwiftDataLinkRepository(container: try GalpiModelContainer.makeInMemory())
}

/// 테스트마다 빈 suite 를 써서 실제 App Group 설정값을 건드리지 않는다.
@MainActor
private func makeSettings() -> GalpiSettings {
    let suiteName = "galpi.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return GalpiSettings(defaults: defaults)
}

/// 시각 계산 테스트가 실행 지역·서머타임에 흔들리지 않게 UTC 로 고정한다.
private var fixedCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private func date(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.date(from: iso)!
}

// MARK: - 출처 판별

@Suite("SourceApp 호스트 판별")
struct SourceAppTests {

    @Test(
        "호스트에서 출처를 되짚는다",
        arguments: [
            ("https://www.youtube.com/watch?v=abc", SourceApp.youtube),
            ("https://m.youtube.com/watch?v=abc", SourceApp.youtube),
            ("https://youtu.be/abc", SourceApp.youtube),
            ("https://www.instagram.com/p/abc/", SourceApp.instagram),
            ("https://blog.naver.com/someone/123", SourceApp.naver),
            ("https://x.com/user/status/1", SourceApp.x),
            ("https://twitter.com/user/status/1", SourceApp.x),
            ("https://developer.apple.com/documentation", SourceApp.web),
            ("not a url at all", SourceApp.web),
        ]
    )
    func detectsSource(urlString: String, expected: SourceApp) {
        #expect(SourceApp(urlString: urlString) == expected)
    }

    @Test("youtube 를 포함하기만 한 남의 도메인은 매칭하지 않는다")
    func doesNotMatchLookalikeHost() {
        #expect(SourceApp(urlString: "https://notyoutube.com/watch") == .web)
        #expect(SourceApp(urlString: "https://youtube.com.evil.net/watch") == .web)
    }
}

// MARK: - URL 정규화

@Suite("URL 정규화")
struct NormalizedURLTests {

    @Test("추적 파라미터·프래그먼트·www·끝 슬래시를 털어낸다")
    func stripsNoise() {
        let canonical = NormalizedURL.canonical(
            "HTTPS://WWW.Example.com/post/?utm_source=kakao&id=7&fbclid=xyz#section"
        )
        #expect(canonical == "https://example.com/post?id=7")
    }

    @Test("스킴이 없으면 https 로 채운다")
    func addsMissingScheme() {
        #expect(NormalizedURL.canonical("example.com/a") == "https://example.com/a")
    }

    @Test("URL 로 볼 수 없는 문자열은 nil")
    func rejectsGarbage() {
        #expect(NormalizedURL.canonical("   ") == nil)
        #expect(NormalizedURL.canonical("https://") == nil)
    }
}

// MARK: - 저장 · 중복 감지

@MainActor
@Suite("저장 UseCase")
struct SaveLinkUseCaseTests {

    @Test("추적 파라미터만 다른 같은 링크는 중복으로 잡는다")
    func detectsDuplicate() throws {
        let repository = try makeRepository()
        let useCase = DefaultSaveLinkUseCase(repository: repository)

        guard case .saved(let savedID) = try useCase.execute(
            urlString: "https://www.example.com/post/"
        ) else {
            Issue.record("첫 저장은 .saved 여야 한다")
            return
        }

        let again = try useCase.execute(
            urlString: "https://example.com/post?utm_source=kakao#top"
        )
        #expect(again == .duplicate(id: savedID))
        #expect(try repository.count(matching: .all) == 1)
    }

    @Test("스킴이 다르면 다른 링크로 본다")
    func httpAndHttpsAreDistinct() throws {
        let useCase = DefaultSaveLinkUseCase(repository: try makeRepository())
        let https = try useCase.execute(urlString: "https://example.com/post")
        let http = try useCase.execute(urlString: "http://example.com/post")
        #expect(https != http)
    }

    @Test("저장하면 출처와 태그가 함께 붙는다")
    func savesWithTags() throws {
        let repository = try makeRepository()
        let useCase = DefaultSaveLinkUseCase(repository: repository)

        _ = try useCase.execute(
            urlString: "https://www.youtube.com/watch?v=abc",
            tagNames: ["#스위프트", "스위프트", " 동시성 "]
        )

        let links = try repository.links(matching: .all, includeArchived: false, limit: nil)
        #expect(links.count == 1)
        #expect(links[0].sourceApp == .youtube)
        // "#스위프트" 와 "스위프트" 는 같은 태그다 — 정규화 후 재사용된다.
        #expect(Set(links[0].tags?.map(\.name) ?? []) == ["스위프트", "동시성"])
        #expect(try repository.tags().count == 2)
    }

    @Test("URL 이 아니면 저장하지 않고 던진다")
    func rejectsInvalidURL() throws {
        let useCase = DefaultSaveLinkUseCase(repository: try makeRepository())
        #expect(throws: SaveLinkError.self) {
            try useCase.execute(urlString: "  ")
        }
    }
}

// MARK: - 열람 기록

@MainActor
@Suite("열람 기록")
struct RecordLinkVisitTests {

    @Test("열면 조회수가 오르고 미열람에서 빠진다")
    func recordsVisit() throws {
        let repository = try makeRepository()
        let save = DefaultSaveLinkUseCase(repository: repository)
        let visit = DefaultRecordLinkVisitUseCase(repository: repository)
        let unread = DefaultFetchUnreadLinksUseCase(repository: repository)

        guard case .saved(let id) = try save.execute(urlString: "https://example.com/a") else {
            Issue.record("저장 실패")
            return
        }
        #expect(try unread.count() == 1)

        let openedAt = date("2026-09-01T12:00:00Z")
        try visit.execute(linkID: id, at: openedAt)
        try visit.execute(linkID: id, at: openedAt.addingTimeInterval(60))

        let link = try #require(try repository.link(id: id))
        #expect(link.viewCount == 2)
        #expect(link.lastViewedAt == openedAt.addingTimeInterval(60))
        #expect(link.isUnread == false)
        #expect(try unread.count() == 0)
    }

    @Test("미열람은 오래 묵은 순으로 나온다")
    func ordersUnreadByAge() throws {
        let repository = try makeRepository()
        repository.insert(Link(urlString: "https://a.com", createdAt: date("2026-08-20T00:00:00Z")))
        repository.insert(Link(urlString: "https://b.com", createdAt: date("2026-08-10T00:00:00Z")))
        repository.insert(Link(urlString: "https://c.com", createdAt: date("2026-08-30T00:00:00Z")))
        try repository.save()

        let result = try DefaultFetchUnreadLinksUseCase(repository: repository).execute(limit: 2)
        #expect(result.map(\.urlString) == ["https://b.com", "https://a.com"])
    }
}

// MARK: - 목록 정렬

@MainActor
@Suite("링크 목록 정렬")
struct LinkOrderingTests {

    @Test("고정한 갈피가 더 최신 갈피보다 앞에 오고, 고정끼리는 최신순이다")
    func pinnedLinksComeFirst() throws {
        let repository = try makeRepository()

        func insert(_ host: String, at iso: String, isPinned: Bool = false) {
            repository.insert(
                Link(urlString: "https://\(host).com", createdAt: date(iso), isPinned: isPinned)
            )
        }

        insert("newest", at: "2026-08-30T00:00:00Z")
        insert("pinned-old", at: "2026-08-01T00:00:00Z", isPinned: true)
        insert("middle", at: "2026-08-20T00:00:00Z")
        insert("pinned-new", at: "2026-08-10T00:00:00Z", isPinned: true)
        try repository.save()

        let links = try repository.links(matching: .all, includeArchived: false, limit: nil)
        #expect(
            links.map(\.urlString) == [
                "https://pinned-new.com",
                "https://pinned-old.com",
                "https://newest.com",
                "https://middle.com",
            ]
        )
    }

    @Test("고정을 풀면 다시 최신순 자리로 돌아간다")
    func unpinningRestoresRecencyOrder() throws {
        let repository = try makeRepository()
        let pinned = Link(
            urlString: "https://old.com", createdAt: date("2026-08-01T00:00:00Z"), isPinned: true
        )
        repository.insert(pinned)
        repository.insert(
            Link(urlString: "https://new.com", createdAt: date("2026-08-30T00:00:00Z"))
        )
        try repository.save()

        pinned.isPinned = false
        try repository.save()

        let links = try repository.links(matching: .all, includeArchived: false, limit: nil)
        #expect(links.map(\.urlString) == ["https://new.com", "https://old.com"])
    }
}

// MARK: - 폴더

@MainActor
@Suite("폴더 관리")
struct ManageFolderUseCaseTests {

    @Test("폴더를 지워도 링크는 받은함으로 남는다")
    func deletingFolderKeepsLinks() throws {
        let repository = try makeRepository()
        let folders = DefaultManageFolderUseCase(repository: repository, settings: makeSettings())

        let folderID = try folders.create(name: "개발", color: .purple, iconName: "chevron.left.forwardslash.chevron.right")
        _ = try DefaultSaveLinkUseCase(repository: repository)
            .execute(urlString: "https://example.com/a", folderID: folderID)

        #expect(try repository.count(matching: .folder(folderID)) == 1)
        #expect(try repository.count(matching: .inbox) == 0)

        try folders.delete(folderID: folderID)

        #expect(try repository.folders().isEmpty)
        #expect(try repository.count(matching: .all) == 1)
        #expect(try repository.count(matching: .inbox) == 1)
    }

    @Test("재정렬하면 sortOrder 가 인자 순서대로 다시 매겨진다")
    func reordersFolders() throws {
        let repository = try makeRepository()
        let useCase = DefaultManageFolderUseCase(repository: repository, settings: makeSettings())

        let a = try useCase.create(name: "A", color: .red, iconName: "folder")
        let b = try useCase.create(name: "B", color: .blue, iconName: "folder")
        let c = try useCase.create(name: "C", color: .green, iconName: "folder")

        try useCase.reorder(orderedIDs: [c, a, b])
        #expect(try repository.folders().map(\.name) == ["C", "A", "B"])
    }

    @Test("기본 저장 폴더는 삭제되지 않는다")
    func refusesToDeleteDefaultFolder() throws {
        let repository = try makeRepository()
        let settings = makeSettings()
        let useCase = DefaultManageFolderUseCase(repository: repository, settings: settings)

        let folderID = try useCase.create(name: "읽을거리", color: .blue, iconName: "folder")
        settings.defaultFolderID = folderID

        #expect(throws: ManageFolderError.self) {
            try useCase.delete(folderID: folderID)
        }
        #expect(try repository.folders().map(\.id) == [folderID])
        // 죽은 UUID 가 남지 않도록 설정값도 그대로여야 한다.
        #expect(settings.defaultFolderID == folderID)
    }

    @Test("기본 폴더가 아니면 그대로 삭제된다")
    func deletesNonDefaultFolder() throws {
        let repository = try makeRepository()
        let settings = makeSettings()
        let useCase = DefaultManageFolderUseCase(repository: repository, settings: settings)

        let defaultFolderID = try useCase.create(name: "읽을거리", color: .blue, iconName: "folder")
        let otherID = try useCase.create(name: "레시피", color: .green, iconName: "folder")
        settings.defaultFolderID = defaultFolderID

        try useCase.delete(folderID: otherID)
        #expect(try repository.folders().map(\.id) == [defaultFolderID])
    }
}

// MARK: - 리마인드 시각

@MainActor
@Suite("미열람 리마인드 시각 계산")
struct ReminderSchedulerTests {

    private func scheduler(hour: Int = 21) -> ReminderScheduler {
        ReminderScheduler(calendar: fixedCalendar, hour: hour)
    }

    @Test("첫 알림은 주기만큼 지난 날의 지정 시각이다")
    func firstFireDate() {
        let now = date("2026-09-01T10:00:00Z")
        let next = scheduler().nextFireDate(cadence: .everyThreeDays, lastNotifiedAt: nil, now: now)
        #expect(next == date("2026-09-04T21:00:00Z"))
    }

    @Test("마지막 알림 기준으로 다음 주기를 잡는다")
    func fireDateFromLastNotification() {
        let next = scheduler().nextFireDate(
            cadence: .daily,
            lastNotifiedAt: date("2026-09-01T21:00:00Z"),
            now: date("2026-09-02T08:00:00Z")
        )
        #expect(next == date("2026-09-02T21:00:00Z"))
    }

    @Test("오래 잠들어 있었어도 항상 미래 시각이 나온다")
    func skipsPastOccurrences() throws {
        let now = date("2026-09-20T10:00:00Z")
        let next = try #require(
            scheduler().nextFireDate(
                cadence: .weekly, lastNotifiedAt: date("2026-08-01T21:00:00Z"), now: now
            )
        )
        #expect(next > now)
        #expect(fixedCalendar.component(.hour, from: next) == 21)
    }

    @Test("끄기면 예약하지 않는다")
    func offCadenceHasNoFireDate() {
        #expect(scheduler().nextFireDate(cadence: .off, lastNotifiedAt: nil) == nil)
    }
}

// MARK: - 주간 리포트

@MainActor
@Suite("주간 리포트")
struct WeeklyReportUseCaseTests {

    @Test("이번 주 저장·읽음과 지난주 대비를 센다")
    func countsThisWeek() throws {
        let repository = try makeRepository()
        let calendar = fixedCalendar
        let now = date("2026-09-03T12:00:00Z")   // 목요일
        let weekStart = try #require(calendar.dateInterval(of: .weekOfYear, for: now)?.start)

        func makeLink(_ host: String, createdOffset: Int, viewedOffset: Int?) {
            let created = calendar.date(byAdding: .hour, value: createdOffset, to: weekStart)!
            repository.insert(
                Link(
                    urlString: "https://\(host).com",
                    createdAt: created,
                    lastViewedAt: viewedOffset.map {
                        calendar.date(byAdding: .hour, value: $0, to: weekStart)!
                    }
                )
            )
        }

        makeLink("a", createdOffset: 1, viewedOffset: 2)      // 주 1일차 읽음
        makeLink("b", createdOffset: 26, viewedOffset: 27)    // 주 2일차 읽음
        makeLink("c", createdOffset: 30, viewedOffset: nil)   // 미열람
        // 지난주에 저장하고 지난주에 읽은 링크
        repository.insert(
            Link(
                urlString: "https://old.com",
                createdAt: calendar.date(byAdding: .day, value: -8, to: weekStart)!,
                lastViewedAt: calendar.date(byAdding: .day, value: -6, to: weekStart)!
            )
        )
        try repository.save()

        let report = try DefaultWeeklyReportUseCase(repository: repository)
            .execute(now: now, calendar: calendar)

        #expect(report.savedCount == 3)
        #expect(report.readCount == 2)
        #expect(report.previousWeekReadCount == 1)
        #expect(report.readCountDelta == 1)
        #expect(report.dailyReadCounts.count == 7)
        #expect(report.dailyReadCounts[0] == 1)
        #expect(report.dailyReadCounts[1] == 1)
        #expect(abs(report.consumptionRate - 2.0 / 3.0) < 0.0001)
    }

    @Test("읽은 기록이 없으면 소비율 0, 연속 0")
    func emptyReport() throws {
        let report = try DefaultWeeklyReportUseCase(repository: try makeRepository())
            .execute(now: date("2026-09-03T12:00:00Z"), calendar: fixedCalendar)

        #expect(report.savedCount == 0)
        #expect(report.consumptionRate == 0)
        #expect(report.streakDays == 0)
    }

    @Test("연속 일수는 오늘부터 거꾸로 센다")
    func countsStreak() throws {
        let repository = try makeRepository()
        let calendar = fixedCalendar
        let now = date("2026-09-03T12:00:00Z")

        for dayOffset in [0, -1, -2, -4] {   // -3 이 비어 있으므로 연속은 3일에서 끊긴다
            repository.insert(
                Link(
                    urlString: "https://d\(dayOffset).com",
                    lastViewedAt: calendar.date(byAdding: .day, value: dayOffset, to: now)!
                )
            )
        }
        try repository.save()

        let report = try DefaultWeeklyReportUseCase(repository: repository)
            .execute(now: now, calendar: calendar)
        #expect(report.streakDays == 3)
    }
}

// MARK: - 모든 데이터 삭제

@MainActor
@Suite("모든 데이터 삭제")
struct EraseAllDataTests {

    @Test("갈피·폴더·태그가 함께 사라진다")
    func deletesEveryRecord() throws {
        let repository = try makeRepository()
        repository.insert(Folder(name: "개발"))
        repository.insert(Link(urlString: "https://example.com/a"))
        _ = try repository.tag(named: "swift")
        try repository.save()

        try repository.deleteAll()

        #expect(try repository.count(matching: .all) == 0)
        #expect(try repository.folders().isEmpty)
        #expect(try repository.tags().isEmpty)
    }

    @Test("환경설정이 첫 실행 값으로 돌아간다")
    func resetsSettings() {
        let settings = makeSettings()
        settings.reminderCadence = .off
        settings.reminderHour = 22
        settings.isAIOrganizeEnabled = false
        settings.defaultFolderID = UUID()
        settings.lastSyncedAt = date("2026-09-01T00:00:00Z")
        settings.nickname = "테스터"

        settings.reset(now: date("2026-09-03T12:00:00Z"))

        #expect(settings.reminderCadence == .everyThreeDays)
        #expect(settings.reminderHour == 9)
        #expect(settings.isAIOrganizeEnabled)
        #expect(settings.defaultFolderID == nil)
        #expect(settings.lastSyncedAt == nil)
        #expect(settings.nickname == "부지런한 갈피 수집가")
        #expect(settings.installedAt == date("2026-09-03T12:00:00Z"))
    }

    @Test("초기화한 값은 같은 저장소를 다시 열어도 유지된다")
    func resetSurvivesReload() {
        let suiteName = "galpi.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let settings = GalpiSettings(defaults: defaults)
        settings.nickname = "테스터"
        settings.reminderHour = 22
        settings.reset(now: date("2026-09-03T12:00:00Z"))

        let reloaded = GalpiSettings(defaults: defaults)
        #expect(reloaded.nickname == "부지런한 갈피 수집가")
        #expect(reloaded.reminderHour == 9)
        #expect(reloaded.installedAt == date("2026-09-03T12:00:00Z"))
    }
}
