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

/// 4개 탭 루트 — 시안 ①·② 하단 탭 바.
struct RootView: View {

    // MARK: - Property

    let useCases: GalpiUseCases

    @State private var selection = Tab.home.rawValue
    @State private var deepLink: GalpiDeepLink?
    @State private var isTabBarHidden = false
    @Environment(\.scenePhase) private var scenePhase

    private enum Tab: Int, CaseIterable {
        case home, search, library, profile

        var item: GalpiTabItem {
            switch self {
            case .home: GalpiTabItem(id: rawValue, title: "홈", symbol: "house.fill")
            case .search: GalpiTabItem(id: rawValue, title: "검색", symbol: "magnifyingglass")
            case .library: GalpiTabItem(id: rawValue, title: "보관함", symbol: "folder.fill")
            case .profile: GalpiTabItem(id: rawValue, title: "내 정보", symbol: "person.fill")
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            switch Tab(rawValue: selection) ?? .home {
            case .home: HomeView(useCases: useCases, deepLink: $deepLink)
            case .search: SearchView(useCases: useCases)
            case .library: LibraryView(useCases: useCases)
            case .profile: ProfileView(useCases: useCases)
            }

            if !isTabBarHidden {
                GalpiTabBar(items: Tab.allCases.map(\.item), selection: $selection)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onPreferenceChange(GalpiTabBarHiddenKey.self) { isHidden in
            withAnimation(.snappy(duration: 0.2)) { isTabBarHidden = isHidden }
        }
        .background(GalpiColor.background)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onOpenURL { url in
            guard let link = GalpiDeepLink(url: url) else { return }
            selection = Tab.home.rawValue
            deepLink = link
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background else { return }
            Task { await useCases.refreshReminder() }
        }
    }
}
