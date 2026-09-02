//
//  LibraryUseCases.swift
//  GalpiKit
//
//  Created by euijjang97 on 9/1/26.
//

import Foundation

// MARK: - 폴더 관리

public enum ManageFolderError: LocalizedError {
    /// 환경설정의 기본 저장 폴더는 지울 수 없다 — 지우면 공유 확장·저장 시트가 남은 UUID 로
    /// 존재하지 않는 폴더를 계속 가리킨다.
    case folderIsDefaultDestination(name: String)

    public var errorDescription: String? {
        switch self {
        case .folderIsDefaultDestination(let name):
            "'\(name)' 폴더는 기본 저장 폴더라 삭제할 수 없어요."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .folderIsDefaultDestination:
            "내 정보 → 환경설정 → 기본 저장 폴더에서 다른 폴더로 바꾼 뒤 다시 시도해 주세요."
        }
    }
}

@MainActor
public protocol ManageFolderUseCase {
    func create(name: String, color: FolderPalette, iconName: String) throws -> UUID
    func rename(folderID: UUID, to name: String) throws
    func update(folderID: UUID, color: FolderPalette?, iconName: String?) throws
    /// `orderedIDs` 순서대로 `sortOrder` 를 다시 매긴다.
    func reorder(orderedIDs: [UUID]) throws
    /// 폴더만 지운다. 안에 있던 링크는 삭제되지 않고 미분류로 돌아간다.
    /// 기본 저장 폴더는 `ManageFolderError.folderIsDefaultDestination` 으로 거절한다.
    func delete(folderID: UUID) throws
}

@MainActor
public struct DefaultManageFolderUseCase: ManageFolderUseCase {

    private let repository: any LinkRepository
    private let settings: GalpiSettings

    public init(repository: any LinkRepository, settings: GalpiSettings) {
        self.repository = repository
        self.settings = settings
    }

    public func create(
        name: String,
        color: FolderPalette = .blue,
        iconName: String = "folder"
    ) throws -> UUID {
        let nextOrder = (try repository.folders().map(\.sortOrder).max() ?? -1) + 1
        let folder = Folder(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            color: color,
            iconName: iconName,
            sortOrder: nextOrder
        )
        repository.insert(folder)
        try repository.save()
        return folder.id
    }

    public func rename(folderID: UUID, to name: String) throws {
        guard let folder = try folder(folderID) else { return }
        folder.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try repository.save()
    }

    public func update(folderID: UUID, color: FolderPalette?, iconName: String?) throws {
        guard let folder = try folder(folderID) else { return }
        if let color { folder.color = color }
        if let iconName { folder.iconName = iconName }
        try repository.save()
    }

    public func reorder(orderedIDs: [UUID]) throws {
        let byID = Dictionary(uniqueKeysWithValues: try repository.folders().map { ($0.id, $0) })
        for (index, id) in orderedIDs.enumerated() {
            byID[id]?.sortOrder = index
        }
        try repository.save()
    }

    public func delete(folderID: UUID) throws {
        guard let folder = try folder(folderID) else { return }
        guard settings.defaultFolderID != folderID else {
            throw ManageFolderError.folderIsDefaultDestination(name: folder.name)
        }
        repository.delete(folder)
        try repository.save()
    }

    private func folder(_ id: UUID) throws -> Folder? {
        try repository.folders().first { $0.id == id }
    }
}

// MARK: - 주간 리포트

/// 홈의 "이번 주 소비율" 카드와 내 정보의 "주간 리포트" 차트가 함께 쓰는 값.
public struct WeeklyReport: Equatable, Sendable {

    public let savedCount: Int
    public let readCount: Int
    /// 주 시작일부터 7칸. 그 날 읽은 링크 수.
    public let dailyReadCounts: [Int]
    public let previousWeekReadCount: Int
    /// 링크를 하나라도 읽은 날이 오늘부터 연속 며칠인지.
    public let streakDays: Int

    public init(
        savedCount: Int,
        readCount: Int,
        dailyReadCounts: [Int],
        previousWeekReadCount: Int,
        streakDays: Int
    ) {
        self.savedCount = savedCount
        self.readCount = readCount
        self.dailyReadCounts = dailyReadCounts
        self.previousWeekReadCount = previousWeekReadCount
        self.streakDays = streakDays
    }

    /// 이번 주 저장분 중 읽은 비율. 저장이 0이면 0.
    ///
    /// 지난주에 저장해 이번 주에 읽은 링크가 있으면 읽음이 저장을 넘길 수 있어 1로 자른다.
    public var consumptionRate: Double {
        savedCount == 0 ? 0 : min(Double(readCount) / Double(savedCount), 1)
    }

    public var readCountDelta: Int { readCount - previousWeekReadCount }
}

@MainActor
public protocol WeeklyReportUseCase {
    func execute(now: Date, calendar: Calendar) throws -> WeeklyReport
}

@MainActor
public struct DefaultWeeklyReportUseCase: WeeklyReportUseCase {

    private let repository: any LinkRepository

    public init(repository: any LinkRepository) {
        self.repository = repository
    }

    public func execute(now: Date = .now, calendar: Calendar = .current) throws -> WeeklyReport {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now),
              let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start)
        else {
            return WeeklyReport(
                savedCount: 0, readCount: 0, dailyReadCounts: Array(repeating: 0, count: 7),
                previousWeekReadCount: 0, streakDays: 0
            )
        }

        let thisRange = thisWeek.start..<thisWeek.end
        let saved = try repository.links(in: thisRange, by: .created)
        let read = try repository.links(in: thisRange, by: .viewed)
        let lastWeekRead = try repository.links(in: lastWeekStart..<thisWeek.start, by: .viewed)

        var daily = Array(repeating: 0, count: 7)
        for link in read {
            guard let viewedAt = link.lastViewedAt,
                  let day = calendar.dateComponents([.day], from: thisWeek.start, to: viewedAt).day,
                  daily.indices.contains(day) else { continue }
            daily[day] += 1
        }

        return WeeklyReport(
            savedCount: saved.count,
            readCount: read.count,
            dailyReadCounts: daily,
            previousWeekReadCount: lastWeekRead.count,
            streakDays: try streakDays(endingAt: now, calendar: calendar)
        )
    }

    /// 오늘(아직 안 읽었으면 어제)부터 거꾸로 세면서, 읽은 기록이 없는 날에서 멈춘다.
    private func streakDays(endingAt now: Date, calendar: Calendar) throws -> Int {
        let readDays = Set(
            try repository.links(matching: .all, includeArchived: true, limit: nil)
                .compactMap(\.lastViewedAt)
                .map { calendar.startOfDay(for: $0) }
        )
        guard !readDays.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: now)
        if !readDays.contains(cursor) {
            // 오늘 아직 안 읽었다고 해서 어제까지 쌓은 연속이 끊긴 건 아니다.
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                return 0
            }
            cursor = yesterday
        }

        var count = 0
        while readDays.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}
