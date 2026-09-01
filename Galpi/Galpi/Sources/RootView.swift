//
//  RootView.swift
//  Galpi
//
//  Created by euijjang97 on 9/1/26.
//

import GalpiDesignSystem
import GalpiKit
import LinkBoxPresentation
import SettingsPresentation
import SwiftUI

/// 4개 탭 루트 — 시스템 탭 바(Liquid Glass)에 화면만 꽂는다.
struct RootView: View {

    // MARK: - Property

    let useCases: GalpiUseCases

    @State private var selection: RootTab = .home
    @State private var deepLink: GalpiDeepLink?
    @Environment(\.scenePhase) private var scenePhase

    private enum RootTab: Hashable {
        case home, library, profile, search
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selection) {
            Tab("홈", systemImage: "house.fill", value: .home) {
                HomeView(useCases: useCases, deepLink: $deepLink)
            }
            Tab("보관함", systemImage: "folder.fill", value: .library) {
                LibraryView(useCases: useCases)
            }
            Tab("내 정보", systemImage: "person.fill", value: .profile) {
                ProfileView(useCases: useCases)
            }
            // search role 탭은 시스템이 탭 바 오른쪽 끝에 따로 떼어 놓고 검색 필드로
            // 모핑시킨다. 그 자리가 고정이라 코드 순서도 맨 뒤에 둔다.
            Tab("검색", systemImage: "magnifyingglass", value: .search, role: .search) {
                SearchView(useCases: useCases)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(GalpiColor.main)
        .onOpenURL { url in
            guard let link = GalpiDeepLink(url: url) else { return }
            selection = .home
            deepLink = link
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background else { return }
            Task { await useCases.refreshReminder() }
        }
    }
}
