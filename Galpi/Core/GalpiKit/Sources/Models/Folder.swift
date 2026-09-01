//
//  Folder.swift
//  GalpiKit
//
//  Created by euijjang97 on 9/1/26.
//

import Foundation
import SwiftData

/// 사용자가 만든 폴더(설계 문서의 "카테고리").
///
/// 폴더 미지정 링크는 화면에서 "받은함"으로 묶이며, 그에 대응하는 레코드는 만들지 않는다.
@Model
public final class Folder {

    // MARK: - Property

    public var id: UUID = UUID()

    public var name: String = ""

    /// `FolderPalette` 의 케이스 rawValue.
    public var colorName: String = FolderPalette.blue.rawValue

    /// SF Symbol 이름.
    public var iconName: String = "folder"

    public var sortOrder: Int = 0

    public var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Link.folder)
    public var links: [Link]?

    // MARK: - Function

    public init(
        id: UUID = UUID(),
        name: String,
        color: FolderPalette = .blue,
        iconName: String = "folder",
        sortOrder: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorName = color.rawValue
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    public var color: FolderPalette {
        get { FolderPalette(rawValue: colorName) ?? .blue }
        set { colorName = newValue.rawValue }
    }

    public var linkCount: Int { links?.count ?? 0 }
}

/// 폴더 색 선택지. 커스텀 색은 두지 않는다(디자인 명세 §2).
public enum FolderPalette: String, CaseIterable, Sendable {
    case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown
}
