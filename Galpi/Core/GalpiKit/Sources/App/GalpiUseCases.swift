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
