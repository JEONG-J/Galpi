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
    @State private var useCases: GalpiUseCases

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            RootView(useCases: useCases)
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

        let useCases = GalpiUseCases(container: modelContainer)
        #if DEBUG
        try? GalpiSampleData.seedIfEmpty(repository: useCases.repository)
        #endif
        _useCases = State(initialValue: useCases)
    }
}

