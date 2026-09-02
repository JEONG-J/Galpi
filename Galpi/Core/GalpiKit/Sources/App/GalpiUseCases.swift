//
//  GalpiUseCases.swift
//  GalpiKit
//
//  Created by euijjang97 on 9/1/26.
//

import Foundation
import SwiftData

/// Presentation 이 의존하는 UseCase 묶음. 구현체 조립은 여기 한 곳에서만 한다.
///
/// 컨테이너 프레임워크를 따로 두지 않는 이유는 주입 지점이 앱 루트 하나뿐이기 때문이다.
/// 화면은 이 타입을 이니셜라이저로 받아 ViewModel 에 그대로 넘긴다.
@MainActor
public final class GalpiUseCases {

    // MARK: - Property

    public let repository: any LinkRepository
    public let settings: GalpiSettings

    public let saveLink: any SaveLinkUseCase
    public let recordVisit: any RecordLinkVisitUseCase
    public let fetchUnread: any FetchUnreadLinksUseCase
    public let manageFolder: any ManageFolderUseCase
    public let weeklyReport: any WeeklyReportUseCase
    public let enrichLink: any EnrichLinkUseCase

    public let metadataService: any LinkMetadataService
    public let summaryService: any LinkSummaryService
    public let reminderScheduler: ReminderScheduler

    // MARK: - Function

    public init(
        repository: any LinkRepository,
        settings: GalpiSettings? = nil,
        metadataService: any LinkMetadataService = DefaultLinkMetadataService(),
        summaryService: any LinkSummaryService = DefaultLinkSummaryService()
    ) {
        self.repository = repository
        let settings = settings ?? GalpiSettings()
        self.settings = settings
        self.metadataService = metadataService
        self.summaryService = summaryService

        saveLink = DefaultSaveLinkUseCase(repository: repository)
        recordVisit = DefaultRecordLinkVisitUseCase(repository: repository)
        fetchUnread = DefaultFetchUnreadLinksUseCase(repository: repository)
        manageFolder = DefaultManageFolderUseCase(repository: repository, settings: settings)
        weeklyReport = DefaultWeeklyReportUseCase(repository: repository)
        enrichLink = DefaultEnrichLinkUseCase(
            repository: repository,
            metadataService: metadataService,
            summaryService: summaryService
        )
        reminderScheduler = ReminderScheduler(hour: settings.reminderHour)
    }

    public convenience init(container: ModelContainer) {
        self.init(repository: SwiftDataLinkRepository(container: container))
    }

    /// 내 정보의 '모든 데이터 삭제' — 저장소와 환경설정을 첫 실행 상태로 되돌린다.
    ///
    /// 예약된 리마인드를 따로 취소하지 않는 이유는 `refreshReminder()` 가 미열람 0을 보고
    /// 남은 예약을 걷어낸 뒤 아무것도 다시 잡지 않기 때문이다.
    public func eraseAllData(now: Date = .now) async throws {
        try repository.deleteAll()
        settings.reset(now: now)
        await refreshReminder(now: now)
    }

    /// 앱이 백그라운드로 갈 때 다음 리마인드 한 건을 다시 잡는다.
    public func refreshReminder(now: Date = .now) async {
        reminderScheduler.hour = settings.reminderHour
        let unreadCount = (try? fetchUnread.count()) ?? 0
        _ = await reminderScheduler.reschedule(
            cadence: settings.reminderCadence,
            unreadCount: unreadCount,
            lastNotifiedAt: settings.lastReminderNotifiedAt,
            now: now
        )
    }
}

#if DEBUG
public extension GalpiUseCases {

    /// 프리뷰용 — 디스크에 아무것도 남기지 않는 **빈** 스토어. 빈 상태 화면을 그대로 볼 수 있다.
    static func empty() -> GalpiUseCases {
        GalpiUseCases(container: try! GalpiModelContainer.makeInMemory())
    }
}
#endif
