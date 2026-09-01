//
//  LinkUseCases.swift
//  GalpiKit
//
//  Created by euijjang97 on 9/1/26.
//

import Foundation

// MARK: - 저장

public enum SaveLinkOutcome: Equatable, Sendable {
    /// 새로 꽂았다.
    case saved(id: UUID)
    /// 이미 있던 링크다 — 저장 카드는 새로 만들지 않고 기존 링크로 안내한다.
    case duplicate(id: UUID)
}

public enum SaveLinkError: LocalizedError {
    case invalidURL(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let raw): "링크를 알아볼 수 없어요: \(raw)"
        }
    }
}

@MainActor
public protocol SaveLinkUseCase {
    /// 공유 시트에서 넘어온 원본 문자열을 정규화해 저장한다.
    /// 메타데이터(제목·썸네일)는 기다리지 않는다 — 저장 후 비동기로 채운다(설계 §7-①).
    func execute(
        urlString: String,
        folderID: UUID?,
        tagNames: [String],
        memo: String?
    ) throws -> SaveLinkOutcome
}

@MainActor
public struct DefaultSaveLinkUseCase: SaveLinkUseCase {

    private let repository: any LinkRepository

    public init(repository: any LinkRepository) {
        self.repository = repository
    }

    public func execute(
        urlString: String,
        folderID: UUID? = nil,
        tagNames: [String] = [],
        memo: String? = nil
    ) throws -> SaveLinkOutcome {
        guard let canonical = NormalizedURL.canonical(urlString) else {
            throw SaveLinkError.invalidURL(urlString)
        }

        if let existing = try repository.link(urlString: canonical) {
            return .duplicate(id: existing.id)
        }

        let folder = try folderID.flatMap { id in try repository.folders().first { $0.id == id } }
        let tags = try tagNames.map { try repository.tag(named: $0) }

        let link = Link(
            urlString: canonical,
            sourceApp: SourceApp(urlString: canonical),
            memo: memo?.isEmpty == true ? nil : memo,
            folder: folder,
            tags: tags.isEmpty ? nil : tags
        )
        repository.insert(link)
        try repository.save()

        return .saved(id: link.id)
    }
}

// MARK: - 열람 기록

@MainActor
public protocol RecordLinkVisitUseCase {
    /// 원문을 연 순간 호출한다. 조회수를 올리고 미열람 상태를 푼다(설계 §7-②).
    func execute(linkID: UUID, at date: Date) throws
}

@MainActor
public struct DefaultRecordLinkVisitUseCase: RecordLinkVisitUseCase {

    private let repository: any LinkRepository

    public init(repository: any LinkRepository) {
        self.repository = repository
    }

    public func execute(linkID: UUID, at date: Date = .now) throws {
        guard let link = try repository.link(id: linkID) else { return }
        link.viewCount += 1
        link.lastViewedAt = date
        try repository.save()
    }
}

// MARK: - 미열람 조회

@MainActor
public protocol FetchUnreadLinksUseCase {
    /// 홈 상단 미열람 캐러셀과 리마인드 알림 본문이 함께 쓴다.
    func execute(limit: Int?) throws -> [Link]
    func count() throws -> Int
}

@MainActor
public struct DefaultFetchUnreadLinksUseCase: FetchUnreadLinksUseCase {

    private let repository: any LinkRepository

    public init(repository: any LinkRepository) {
        self.repository = repository
    }

    public func execute(limit: Int? = nil) throws -> [Link] {
        // 오래 묵은 것부터 보여줘야 "잊기 전에 꺼내 본다"는 목적에 맞는다.
        try repository.links(matching: .unread, includeArchived: false, limit: nil)
            .sorted { $0.createdAt < $1.createdAt }
            .prefixed(limit)
    }

    public func count() throws -> Int {
        try repository.count(matching: .unread)
    }
}

private extension Array {
    func prefixed(_ limit: Int?) -> [Element] {
        guard let limit else { return self }
        return Array(prefix(limit))
    }
}
