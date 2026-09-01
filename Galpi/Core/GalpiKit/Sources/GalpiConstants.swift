//
//  GalpiConstants.swift
//  GalpiKit
//
//  Created by euijjang97 on 9/1/26.
//

import Foundation

/// 앱·공유 확장·위젯 세 타겟이 공유하는 식별자 모음.
///
/// 세 타겟은 서로 다른 프로세스에서 같은 SwiftData 스토어를 연다. 아래 값이 하나라도
/// 어긋나면 저장은 성공하는데 다른 타겟에서 안 보이는 형태로 조용히 깨지므로,
/// 문자열을 각 타겟에 복제하지 않고 이곳 한 곳에서만 정의한다.
public enum GalpiConstants {

    // MARK: - Property

    /// App Group 컨테이너 — `Galpi.entitlements` 의 값과 동일해야 한다.
    public static let appGroupIdentifier = "group.com.example.galpi"

    /// CloudKit 컨테이너 — `Galpi.entitlements` 의 값과 동일해야 한다.
    public static let cloudKitContainerIdentifier = "iCloud.com.example.galpi"

    /// App Group 안의 SwiftData 스토어 파일명.
    public static let storeFileName = "Galpi.store"

    /// 딥링크 스킴 — `galpi://unread`, `galpi://link/{id}`
    public static let urlScheme = "galpi"

    /// 미열람 리마인드 재등록용 백그라운드 태스크 — Info.plist 의
    /// `BGTaskSchedulerPermittedIdentifiers` 와 동일해야 한다.
    public static let reminderRefreshTaskIdentifier = "com.example.galpi.reminder.refresh"

    /// 미열람 리마인드 알림 식별자. 항상 한 건만 예약하므로 고정값을 재사용한다.
    public static let reminderNotificationIdentifier = "galpi.reminder.unread"
}

/// 위젯·알림에서 앱으로 들어오는 딥링크.
public enum GalpiDeepLink: Equatable, Sendable {

    /// 미열람 목록으로 이동 (`galpi://unread`)
    case unread

    /// 특정 링크 상세로 이동 (`galpi://link/{id}`)
    case link(UUID)

    // MARK: - Function

    public init?(url: URL) {
        guard url.scheme == GalpiConstants.urlScheme else { return nil }

        switch url.host() {
        case "unread":
            self = .unread
        case "link":
            guard let id = url.pathComponents.last.flatMap(UUID.init(uuidString:)) else {
                return nil
            }
            self = .link(id)
        default:
            return nil
        }
    }

    public var url: URL {
        switch self {
        case .unread:
            URL(string: "\(GalpiConstants.urlScheme)://unread")!
        case .link(let id):
            URL(string: "\(GalpiConstants.urlScheme)://link/\(id.uuidString)")!
        }
    }
}
