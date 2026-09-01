//
//  GalpiApp.swift
//  Galpi
//
//  Created by euijjang97 on 9/1/26.
//

import GalpiKit
import SwiftData
import SwiftUI

@main
struct GalpiApp: App {

    // MARK: - Property

    private let modelContainer: ModelContainer

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            RootPlaceholderView()
                .modelContainer(modelContainer)
        }
    }

    // MARK: - Function

    init() {
        do {
            modelContainer = try GalpiModelContainer.make()
        } catch {
            // iCloud/App Group 이 안 잡히는 개발 환경에서도 앱은 떠야 한다.
            // 로컬 전용으로 열고, 다음 실행에서 다시 CloudKit 을 시도한다.
            modelContainer = try! GalpiModelContainer.makeInMemory()
        }
    }
}

/// Presentation 레이어(홈·검색·보관함·내 정보)는 후속 이슈에서 붙인다.
private struct RootPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "갈피",
            systemImage: "bookmark",
            description: Text("화면은 다음 이슈에서 붙습니다.")
        )
    }
}
