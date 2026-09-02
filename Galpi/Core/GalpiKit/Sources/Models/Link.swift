//
//  Link.swift
//  GalpiKit
//
//  Created by euijjang97 on 9/1/26.
//

import Foundation
import SwiftData

/// 사용자가 꽂아둔 링크 한 건.
///
/// CloudKit 미러링 제약 때문에 **모든 저장 프로퍼티는 기본값이 있거나 옵셔널**이어야 하고,
/// `@Attribute(.unique)` 는 쓸 수 없다. 중복 URL 은 저장 시점에
/// `LinkRepository.link(matching:)` 로 직접 막는다.
@Model
public final class Link {

    // MARK: - Property

    public var id: UUID = UUID()

    /// 정규화된 원본 URL 문자열. 중복 판정의 기준값이다.
    public var urlString: String = ""

    /// 메타데이터를 아직 못 받았으면 빈 문자열 — 이때 화면은 호스트명을 대신 보여준다.
    public var title: String = ""

    /// AI 요약(설계 §시안 "AI 요약"). 생성 전에는 nil.
    public var summary: String?

    /// 다운샘플된 썸네일. 원본 이미지는 저장하지 않는다(CloudKit 용량).
    @Attribute(.externalStorage)
    public var thumbnailData: Data?

    /// `SourceApp.rawValue`. SwiftData 는 enum 을 그대로 술어에 못 쓰므로 String 으로 저장한다.
    public var sourceAppRawValue: String = SourceApp.web.rawValue

    public var memo: String?

    public var createdAt: Date = Date.now

    public var viewCount: Int = 0

    /// `nil` 이면 아직 한 번도 열지 않은 링크(= 미열람).
    public var lastViewedAt: Date?

    public var isFavorite: Bool = false

    public var isArchived: Bool = false

    /// 목록 맨 위에 붙잡아 두는 갈피. 즐겨찾기(`isFavorite`)는 보관함 스마트 리스트라
    /// 의미가 달라 플래그를 따로 둔다.
    public var isPinned: Bool = false

    /// `nil` 이면 "미분류"(폴더 미지정) 이다 — 미분류는 별도 레코드가 아니다.
    public var folder: Folder?

    @Relationship(inverse: \Tag.links)
    public var tags: [Tag]?

    // MARK: - Function

    public init(
        id: UUID = UUID(),
        urlString: String,
        title: String = "",
        summary: String? = nil,
        thumbnailData: Data? = nil,
        sourceApp: SourceApp = .web,
        memo: String? = nil,
        createdAt: Date = .now,
        viewCount: Int = 0,
        lastViewedAt: Date? = nil,
        isFavorite: Bool = false,
        isArchived: Bool = false,
        isPinned: Bool = false,
        folder: Folder? = nil,
        tags: [Tag]? = nil
    ) {
        self.id = id
        self.urlString = urlString
        self.title = title
        self.summary = summary
        self.thumbnailData = thumbnailData
        self.sourceAppRawValue = sourceApp.rawValue
        self.memo = memo
        self.createdAt = createdAt
        self.viewCount = viewCount
        self.lastViewedAt = lastViewedAt
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.isPinned = isPinned
        self.folder = folder
        self.tags = tags
    }

    public var sourceApp: SourceApp {
        get { SourceApp(rawValue: sourceAppRawValue) ?? .web }
        set { sourceAppRawValue = newValue.rawValue }
    }

    public var isUnread: Bool { lastViewedAt == nil }

    public var url: URL? { URL(string: urlString) }

    /// 제목이 비어 있을 때 셀에 대신 띄울 표시 문자열.
    public var displayTitle: String {
        title.isEmpty ? (url?.host() ?? urlString) : title
    }
}
