//
//  ReminderScheduler.swift
//  GalpiKit
//
//  Created by euijjang97 on 9/1/26.
//

import Foundation
import UserNotifications

/// 미열람 리마인드 주기(설계 §7-③).
public enum ReminderCadence: String, CaseIterable, Sendable {
    case daily
    case everyThreeDays
    case weekly
    case off

    public var days: Int? {
        switch self {
        case .daily: 1
        case .everyThreeDays: 3
        case .weekly: 7
        case .off: nil
        }
    }

    public var displayName: String {
        switch self {
        case .daily: "매일"
        case .everyThreeDays: "3일마다"
        case .weekly: "매주"
        case .off: "끄기"
        }
    }
}

/// 미열람 리마인드 알림 예약.
///
/// 예약은 **항상 다음 한 건만** 잡는다. 반복 트리거를 쓰면 미열람이 0이 된 뒤에도 계속 울리기
/// 때문에, 앱이 백그라운드로 갈 때마다 지우고 다시 잡는다.
@MainActor
public final class ReminderScheduler {

    // MARK: - Property

    /// `UNUserNotificationCenter.current()` 는 앱 번들 밖(호스트 앱 없는 유닛 테스트)에서 부르면
    /// 곧바로 assertion 으로 죽는다. 시각 계산만 검증하는 테스트가 알림 센터를 건드리지 않도록
    /// 실제 예약 시점까지 생성을 미룬다.
    private lazy var center: UNUserNotificationCenter = makeCenter()

    private let makeCenter: () -> UNUserNotificationCenter
    private let calendar: Calendar

    /// 알림을 보낼 시각(시). 설계 문서 기본값은 21시.
    public var hour: Int

    // MARK: - Function

    public init(
        center: @escaping @autoclosure () -> UNUserNotificationCenter = .current(),
        calendar: Calendar = .current,
        hour: Int = 21
    ) {
        self.makeCenter = center
        self.calendar = calendar
        self.hour = hour
    }

    /// 다음 알림 시각. 순수 계산이라 테스트로 고정할 수 있다.
    ///
    /// - Parameters:
    ///   - lastNotifiedAt: 마지막으로 알림을 보낸 시각. 한 번도 없으면 `nil`.
    ///   - now: 기준 시각.
    /// - Returns: `cadence` 가 `.off` 이면 `nil`.
    public func nextFireDate(
        cadence: ReminderCadence,
        lastNotifiedAt: Date?,
        now: Date = .now
    ) -> Date? {
        guard let days = cadence.days else { return nil }

        // 마지막 알림(없으면 지금)으로부터 주기만큼 지난 날의 지정 시각.
        let anchor = lastNotifiedAt ?? now
        guard let shifted = calendar.date(byAdding: .day, value: days, to: anchor),
              var candidate = calendar.date(
                  bySettingHour: hour, minute: 0, second: 0, of: shifted
              ) else {
            return nil
        }

        // 주기가 이미 지난 상태로 앱이 오래 잠들어 있었을 수 있다. 미래가 될 때까지 당겨 올린다.
        while candidate <= now {
            guard let next = calendar.date(byAdding: .day, value: days, to: candidate) else {
                return nil
            }
            candidate = next
        }
        return candidate
    }

    /// 예약을 통째로 갈아 끼운다. 미열람이 0이면 아무것도 잡지 않는다.
    @discardableResult
    public func reschedule(
        cadence: ReminderCadence,
        unreadCount: Int,
        lastNotifiedAt: Date?,
        now: Date = .now
    ) async -> Date? {
        center.removePendingNotificationRequests(
            withIdentifiers: [GalpiConstants.reminderNotificationIdentifier]
        )

        guard unreadCount > 0,
              let fireDate = nextFireDate(
                  cadence: cadence, lastNotifiedAt: lastNotifiedAt, now: now
              ) else {
            return nil
        }

        let content = UNMutableNotificationContent()
        content.title = "아직 안 읽은 갈피 \(unreadCount)개"
        content.body = "잊기 전에 하나만 꺼내 볼까요?"
        content.sound = .default
        content.userInfo = ["deepLink": GalpiDeepLink.unread.url.absoluteString]

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireDate
        )
        let request = UNNotificationRequest(
            identifier: GalpiConstants.reminderNotificationIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )

        do {
            try await center.add(request)
            return fireDate
        } catch {
            // 권한이 없거나 예약 한도를 넘긴 경우. 리마인드는 보조 기능이라 실패해도 흐름을 막지 않는다.
            return nil
        }
    }

    public func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
}
