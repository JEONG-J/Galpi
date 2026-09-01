//
//  GalpiModelContainer.swift
//  GalpiKit
//
//  Created by euijjang97 on 9/1/26.
//

import Foundation
import SwiftData

/// 앱·공유 확장·위젯이 공유하는 `ModelContainer` 팩토리.
///
/// 세 타겟이 **같은 App Group 파일**을 열어야 공유 시트에서 저장한 링크가 즉시 앱과 위젯에
/// 보인다. 기본 위치(앱 샌드박스)로 열면 각자 다른 DB를 보게 되므로 URL 을 명시한다.
public enum GalpiModelContainer {

    // MARK: - Property

    public static let schema = Schema([Link.self, Folder.self, Tag.self])

    /// App Group 안의 스토어 파일 경로.
    public static var storeURL: URL {
        get throws {
            let group = GalpiConstants.appGroupIdentifier
            guard let container = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: group) else {
                throw GalpiStoreError.appGroupUnavailable(identifier: group)
            }
            return container.appending(path: GalpiConstants.storeFileName)
        }
    }

    // MARK: - Function

    /// 실제 앱에서 쓰는 컨테이너 — App Group 파일 + CloudKit 미러링.
    ///
    /// - Parameter cloudKitEnabled: 시뮬레이터·CI 등 iCloud 계정이 없는 환경에서 끄고 열 수 있다.
    public static func make(cloudKitEnabled: Bool = true) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            url: try storeURL,
            cloudKitDatabase: cloudKitEnabled
                ? .private(GalpiConstants.cloudKitContainerIdentifier)
                : .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// 테스트·프리뷰용 — 디스크에 아무것도 남기지 않는다.
    public static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }
}

public enum GalpiStoreError: LocalizedError {
    case appGroupUnavailable(identifier: String)

    public var errorDescription: String? {
        switch self {
        case .appGroupUnavailable(let identifier):
            "App Group '\(identifier)' 컨테이너를 열 수 없습니다. entitlements 설정을 확인하세요."
        }
    }
}
