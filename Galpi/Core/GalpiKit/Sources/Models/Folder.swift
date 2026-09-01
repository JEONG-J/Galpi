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
        get { FolderPalette(rawValue: colorName) }
        set { colorName = newValue.rawValue }
    }

    public var linkCount: Int { links?.count ?? 0 }
}

/// 폴더 색 선택지 — 디자인 명세 §2 의 시스템 12색과, 사용자가 직접 고른 커스텀 색.
///
/// `rawValue` 가 그대로 `Folder.colorName` 이다. 커스텀 색은 `#RRGGBB` 문자열을 같은 필드에
/// 담으므로 SwiftData 스키마는 손대지 않는다. hex → 실제 색 변환은 DesignSystem 쪽
/// `GalpiPastel` 이 맡는다.
public struct FolderPalette: RawRepresentable, Hashable, CaseIterable, Sendable {

    // MARK: - Property

    public let rawValue: String

    public static let red = FolderPalette(rawValue: "red")
    public static let orange = FolderPalette(rawValue: "orange")
    public static let yellow = FolderPalette(rawValue: "yellow")
    public static let green = FolderPalette(rawValue: "green")
    public static let mint = FolderPalette(rawValue: "mint")
    public static let teal = FolderPalette(rawValue: "teal")
    public static let cyan = FolderPalette(rawValue: "cyan")
    public static let blue = FolderPalette(rawValue: "blue")
    public static let indigo = FolderPalette(rawValue: "indigo")
    public static let purple = FolderPalette(rawValue: "purple")
    public static let pink = FolderPalette(rawValue: "pink")
    public static let brown = FolderPalette(rawValue: "brown")

    /// 색 선택 그리드에 고정으로 깔리는 시스템 12색.
    public static let allCases: [FolderPalette] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .pink, .brown,
    ]

    /// 12색 중 하나가 아니면 사용자가 ColorPicker 로 고른 색이다.
    public var isCustom: Bool { !Self.allCases.contains(self) }

    // MARK: - Function

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
