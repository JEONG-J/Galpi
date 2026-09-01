//
//  Tag.swift
//  GalpiKit
//
//  Created by euijjang97 on 9/1/26.
//

import Foundation
import SwiftData

/// 링크에 붙이는 태그. 폴더가 "한 곳"이라면 태그는 "여러 축"으로 겹쳐 붙는다.
///
/// 이름 중복은 CloudKit 제약상 `.unique` 로 막을 수 없어
/// `LinkRepository.tag(named:)` 가 조회 후 없을 때만 생성하는 방식으로 처리한다.
@Model
public final class Tag {

    // MARK: - Property

    public var id: UUID = UUID()

    /// `#` 없이 저장한다. 표시할 때만 앞에 붙인다.
    public var name: String = ""

    public var createdAt: Date = Date.now

    public var links: [Link]?

    // MARK: - Function

    public init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = Tag.normalized(name)
        self.createdAt = createdAt
    }

    public var linkCount: Int { links?.count ?? 0 }

    /// 앞의 `#`·공백을 털고 소문자로 맞춘다 — `#Swift` 와 `swift` 를 같은 태그로 본다.
    public static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("#")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
