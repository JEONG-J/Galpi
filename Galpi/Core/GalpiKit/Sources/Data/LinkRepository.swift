//
//  LinkRepository.swift
//  GalpiKit
//
//  Created by euijjang97 on 9/1/26.
//

import Foundation
import SwiftData

/// 보관함 화면의 필터 축.
///
/// `inbox` 는 별도 폴더 레코드가 아니라 "폴더가 지정되지 않은 링크"를 뜻한다.
public enum LinkFilter: Hashable, Sendable {
    case all
    case unread
    case favorite
    case inbox
    case folder(UUID)
    case tag(UUID)
}

/// 주간 리포트가 세는 기준 — 저장한 날인지, 읽은 날인지.
public enum LinkDateField: Sendable {
    case created
    case viewed
}

@MainActor
public protocol LinkRepository: AnyObject {

    // MARK: - Read

    /// 최신순 정렬. `limit` 이 `nil` 이면 전부 가져온다.
    func links(matching filter: LinkFilter, includeArchived: Bool, limit: Int?) throws -> [Link]
    func count(matching filter: LinkFilter) throws -> Int
    func link(id: UUID) throws -> Link?

    /// 중복 저장 감지용 — 정규화된 URL 문자열이 정확히 일치하는 링크.
    func link(urlString: String) throws -> Link?

    /// 주간 리포트용. `range` 안에 저장/열람된 링크.
    func links(in range: Range<Date>, by field: LinkDateField) throws -> [Link]

    func folders() throws -> [Folder]
    func tags() throws -> [Tag]

    // MARK: - Write

    func insert(_ link: Link)
    func insert(_ folder: Folder)

    /// 같은 이름의 태그가 있으면 재사용하고, 없을 때만 만든다.
    /// CloudKit 스키마에서 `.unique` 를 못 쓰기 때문에 중복 방지가 이 메서드의 책임이다.
    func tag(named name: String) throws -> Tag

    func delete(_ link: Link)
    func delete(_ folder: Folder)
    func save() throws
}

// MARK: - SwiftData 구현

@MainActor
public final class SwiftDataLinkRepository: LinkRepository {

    // MARK: - Property

    private let context: ModelContext

    // MARK: - Function

    public init(context: ModelContext) {
        self.context = context
    }

    public convenience init(container: ModelContainer) {
        self.init(context: ModelContext(container))
    }

    public func links(
        matching filter: LinkFilter,
        includeArchived: Bool = false,
        limit: Int? = nil
    ) throws -> [Link] {
        var descriptor = FetchDescriptor<Link>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        // 관계(folder/tag)를 타고 들어가는 술어는 SwiftData 에서 표현이 까다로워
        // 스칼라 조건만 술어로 넘기고 관계 조건은 메모리에서 거른다.
        // ponytail: 링크 수천 건까지는 문제없다. 그 이상 늘면 folderID 를 비정규화해 술어로 옮긴다.
        switch filter {
        case .all, .folder, .tag, .inbox:
            descriptor.predicate = #Predicate { includeArchived || !$0.isArchived }
        case .unread:
            descriptor.predicate = #Predicate {
                $0.lastViewedAt == nil && (includeArchived || !$0.isArchived)
            }
        case .favorite:
            descriptor.predicate = #Predicate {
                $0.isFavorite && (includeArchived || !$0.isArchived)
            }
        }

        var results = try context.fetch(descriptor)

        switch filter {
        case .inbox:
            results = results.filter { $0.folder == nil }
        case .folder(let id):
            results = results.filter { $0.folder?.id == id }
        case .tag(let id):
            results = results.filter { $0.tags?.contains { $0.id == id } ?? false }
        case .all, .unread, .favorite:
            break
        }

        if let limit { results = Array(results.prefix(limit)) }
        return results
    }

    public func count(matching filter: LinkFilter) throws -> Int {
        try links(matching: filter, includeArchived: false, limit: nil).count
    }

    public func link(id: UUID) throws -> Link? {
        var descriptor = FetchDescriptor<Link>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    public func link(urlString: String) throws -> Link? {
        var descriptor = FetchDescriptor<Link>(predicate: #Predicate { $0.urlString == urlString })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    public func links(in range: Range<Date>, by field: LinkDateField) throws -> [Link] {
        let lower = range.lowerBound
        let upper = range.upperBound
        let predicate: Predicate<Link>

        switch field {
        case .created:
            predicate = #Predicate { $0.createdAt >= lower && $0.createdAt < upper }
        case .viewed:
            predicate = #Predicate {
                if let viewedAt = $0.lastViewedAt {
                    viewedAt >= lower && viewedAt < upper
                } else {
                    false
                }
            }
        }

        return try context.fetch(FetchDescriptor<Link>(predicate: predicate))
    }

    public func folders() throws -> [Folder] {
        try context.fetch(
            FetchDescriptor<Folder>(sortBy: [
                SortDescriptor(\.sortOrder),
                SortDescriptor(\.createdAt),
            ])
        )
    }

    public func tags() throws -> [Tag] {
        try context.fetch(FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)]))
    }

    public func insert(_ link: Link) { context.insert(link) }

    public func insert(_ folder: Folder) { context.insert(folder) }

    public func tag(named name: String) throws -> Tag {
        let normalized = Tag.normalized(name)
        var descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.name == normalized })
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first { return existing }

        let tag = Tag(name: normalized)
        context.insert(tag)
        return tag
    }

    public func delete(_ link: Link) { context.delete(link) }

    public func delete(_ folder: Folder) { context.delete(folder) }

    public func save() throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}
