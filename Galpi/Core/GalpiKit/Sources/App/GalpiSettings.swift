//
//  GalpiSettings.swift
//  GalpiKit
//
//  Created by euijjang97 on 9/1/26.
//

import Foundation
import Observation

/// 환경설정 값 저장소.
///
/// 앱·공유 확장·위젯이 같은 값을 읽어야 해서(기본 저장 폴더 등) 표준 `UserDefaults` 가 아니라
/// App Group suite 를 쓴다. suite 를 못 열면(엔타이틀먼트 미설정) 표준 저장소로 떨어진다.
@MainActor
@Observable
public final class GalpiSettings {

    // MARK: - Property

    private let defaults: UserDefaults

    /// 미열람 리마인드 주기(설정 화면 '미열람 리마인더').
    public var reminderCadence: ReminderCadence {
        didSet { defaults.set(reminderCadence.rawValue, forKey: Key.reminderCadence) }
    }

    /// 리마인드 발송 시각(시).
    public var reminderHour: Int {
        didSet { defaults.set(reminderHour, forKey: Key.reminderHour) }
    }

    /// 'AI 자동 정리' — 저장 직후 요약·태그를 자동 생성할지.
    public var isAIOrganizeEnabled: Bool {
        didSet { defaults.set(isAIOrganizeEnabled, forKey: Key.aiOrganize) }
    }

    /// 공유 시트에서 미리 선택되는 폴더. `nil` 이면 받은함.
    public var defaultFolderID: UUID? {
        didSet { defaults.set(defaultFolderID?.uuidString, forKey: Key.defaultFolder) }
    }

    public var lastReminderNotifiedAt: Date? {
        didSet { defaults.set(lastReminderNotifiedAt, forKey: Key.lastReminderNotifiedAt) }
    }

    public var lastSyncedAt: Date? {
        didSet { defaults.set(lastSyncedAt, forKey: Key.lastSyncedAt) }
    }

    public var nickname: String {
        didSet { defaults.set(nickname, forKey: Key.nickname) }
    }

    /// 프로필의 '갈피와 함께한 지 N일째' 기준일. 첫 실행 때 한 번 박힌다.
    public private(set) var installedAt: Date

    /// 검색 화면의 '최근 검색' — 최신순. 쓰기는 아래 세 함수로만 한다(중복·상한 규칙이 붙는다).
    public private(set) var recentSearches: [String] {
        didSet { defaults.set(recentSearches, forKey: Key.recentSearches) }
    }

    /// 기록 상한. 검색 화면 한 화면에 담기는 만큼만 남긴다.
    public static let recentSearchLimit = 10

    // MARK: - Function

    public init(defaults: UserDefaults? = nil) {
        let store = defaults
            ?? UserDefaults(suiteName: GalpiConstants.appGroupIdentifier)
            ?? .standard
        self.defaults = store

        reminderCadence = (store.string(forKey: Key.reminderCadence))
            .flatMap(ReminderCadence.init(rawValue:)) ?? .everyThreeDays
        reminderHour = store.object(forKey: Key.reminderHour) as? Int ?? 9
        isAIOrganizeEnabled = store.object(forKey: Key.aiOrganize) as? Bool ?? true
        defaultFolderID = store.string(forKey: Key.defaultFolder).flatMap(UUID.init(uuidString:))
        lastReminderNotifiedAt = store.object(forKey: Key.lastReminderNotifiedAt) as? Date
        lastSyncedAt = store.object(forKey: Key.lastSyncedAt) as? Date
        nickname = store.string(forKey: Key.nickname) ?? "부지런한 갈피 수집가"

        recentSearches = store.stringArray(forKey: Key.recentSearches) ?? []

        if let stored = store.object(forKey: Key.installedAt) as? Date {
            installedAt = stored
        } else {
            installedAt = .now
            store.set(installedAt, forKey: Key.installedAt)
        }
    }

    /// 프로필의 '함께한 지 N일째'. 설치 당일이 1일째다.
    public func daysSinceInstall(now: Date = .now, calendar: Calendar = .current) -> Int {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: installedAt),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        return max(days, 0) + 1
    }

    /// 검색어 한 건을 기록 맨 위에 올린다.
    ///
    /// 같은 말을 다시 검색하면 아래에 쌓지 않고 맨 위로 끌어올린다 — 대소문자만 다른 것도
    /// 같은 말로 본다. 표기는 마지막에 친 그대로 남긴다.
    public func recordSearch(_ query: String) {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }

        var updated = recentSearches.filter {
            $0.caseInsensitiveCompare(keyword) != .orderedSame
        }
        updated.insert(keyword, at: 0)
        recentSearches = Array(updated.prefix(Self.recentSearchLimit))
    }

    public func removeRecentSearch(_ keyword: String) {
        recentSearches.removeAll { $0 == keyword }
    }

    public func clearRecentSearches() {
        recentSearches = []
    }

    private enum Key {
        static let reminderCadence = "galpi.reminder.cadence"
        static let reminderHour = "galpi.reminder.hour"
        static let aiOrganize = "galpi.ai.organize"
        static let defaultFolder = "galpi.folder.default"
        static let lastReminderNotifiedAt = "galpi.reminder.lastNotifiedAt"
        static let lastSyncedAt = "galpi.sync.lastAt"
        static let nickname = "galpi.profile.nickname"
        static let installedAt = "galpi.profile.installedAt"
        static let recentSearches = "galpi.search.recents"
    }
}
