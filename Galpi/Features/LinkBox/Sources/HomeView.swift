//
//  HomeView.swift
//  LinkBoxPresentation
//
//  Created by euijjang97 on 9/1/26.
//

import GalpiDesignSystem
import GalpiKit
import SwiftUI

/// 탭 안에서 이동하는 화면들.
enum LinkRoute: Hashable {
    case detail(UUID)
    case filtered(LinkFilter, title: String)
}

@MainActor
@Observable
final class HomeViewModel {

    // MARK: - Property

    private let useCases: GalpiUseCases

    private(set) var unreadLinks: [Link] = []
    private(set) var recentLinks: [Link] = []
    private(set) var unreadCount = 0
    private(set) var report = WeeklyReport(
        savedCount: 0, readCount: 0, dailyReadCounts: Array(repeating: 0, count: 7),
        previousWeekReadCount: 0, streakDays: 0
    )

    // MARK: - Function

    init(useCases: GalpiUseCases) {
        self.useCases = useCases
    }

    func load() {
        unreadLinks = (try? useCases.fetchUnread.execute(limit: 10)) ?? []
        unreadCount = (try? useCases.fetchUnread.count()) ?? unreadLinks.count
        recentLinks = (try? useCases.repository.links(
            matching: .all, includeArchived: false, limit: 4
        )) ?? []
        report = (try? useCases.weeklyReport.execute(now: .now, calendar: .current)) ?? report
    }

    /// 시안의 '12개 중 8개를 읽었어요 · 지난주보다 2개 더!'
    var weeklyCaption: String {
        // 지난주 저장분을 이번 주에 읽으면 읽음이 저장을 넘어서 '2개 중 3개' 가 된다.
        let base = report.readCount > report.savedCount
            ? "이번 주 \(report.readCount)개를 읽었어요"
            : "\(report.savedCount)개 중 \(report.readCount)개를 읽었어요"
        let delta = report.readCountDelta
        return switch delta {
        case 1...: base + " · 지난주보다 \(delta)개 더!"
        case ..<0: base + " · 지난주보다 \(-delta)개 적어요"
        default: base
        }
    }

    var consumptionPercent: Int { Int((report.consumptionRate * 100).rounded()) }
}

/// 홈 탭 — 시안 ① 프레임.
public struct HomeView: View {

    // MARK: - Property

    @State private var viewModel: HomeViewModel
    @State private var path: [LinkRoute] = []
    @Binding private var deepLink: GalpiDeepLink?

    private let useCases: GalpiUseCases

    // MARK: - Function

    public init(useCases: GalpiUseCases, deepLink: Binding<GalpiDeepLink?> = .constant(nil)) {
        self.useCases = useCases
        _deepLink = deepLink
        _viewModel = State(initialValue: HomeViewModel(useCases: useCases))
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    unreadSection
                    weeklyStatCard
                    recentSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(GalpiColor.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LinkRoute.self) { route in
                LinkRouteView(route: route, useCases: useCases, path: $path)
            }
        }
        .onAppear { viewModel.load() }
        .onChange(of: deepLink) { _, link in
            guard let link else { return }
            deepLink = nil
            switch link {
            case .unread:
                path = [.filtered(.unread, title: "아직 안 읽은 갈피")]
            case .link(let id):
                path = [.detail(id)]
            }
        }
    }

    // MARK: - 아직 안 읽은 갈피

    private var unreadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GalpiSectionHeader("아직 안 읽은 갈피", badgeCount: viewModel.unreadCount)

            if viewModel.unreadLinks.isEmpty {
                LinkBoxEmptyState(
                    symbol: "checkmark.circle",
                    title: "다 읽었어요",
                    message: "안 읽은 갈피가 없습니다."
                )
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.unreadLinks) { link in
                            Button { path.append(.detail(link.id)) } label: {
                                UnreadLinkCard(link: link)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    // 카드 그림자가 잘리지 않도록 스크롤 콘텐츠에 여백을 준다.
                    .padding(.vertical, 6)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
    }

    // MARK: - 이번 주 소비율

    private var weeklyStatCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("이번 주 소비율")
                    .font(GalpiFont.text(13, .semibold))
                    .foregroundStyle(GalpiColor.textSecondary)
                Spacer()
                Text("\(viewModel.consumptionPercent)%")
                    .font(GalpiFont.text(19, .bold))
                    .foregroundStyle(GalpiColor.main)
            }

            GalpiProgressTrack(progress: viewModel.report.consumptionRate)

            Text(viewModel.weeklyCaption)
                .font(GalpiFont.text(11, .medium))
                .foregroundStyle(GalpiColor.textSecondary)
        }
        .padding(16)
        .galpiCard(cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("이번 주 소비율 \(viewModel.consumptionPercent)퍼센트. \(viewModel.weeklyCaption)")
    }

    // MARK: - 최근 저장

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GalpiSectionHeader("최근 저장") {
                GalpiSectionAction("전체 보기") {
                    path.append(.filtered(.all, title: "전체 갈피"))
                }
            }

            if viewModel.recentLinks.isEmpty {
                LinkBoxEmptyState(
                    symbol: "bookmark",
                    title: "아직 꽂아둔 갈피가 없어요",
                    message: "공유 시트에서 갈피를 눌러 첫 링크를 꽂아보세요."
                )
            } else {
                LinkListCard(links: viewModel.recentLinks) { path.append(.detail($0.id)) }
            }
        }
    }
}

/// 탭 내부 라우팅 — 스택에 쌓이는 화면을 한 곳에서 만든다.
struct LinkRouteView: View {

    let route: LinkRoute
    let useCases: GalpiUseCases
    @Binding var path: [LinkRoute]

    var body: some View {
        switch route {
        case .detail(let id):
            LinkDetailView(linkID: id, useCases: useCases)
        case .filtered(let filter, let title):
            FilteredLinkListView(filter: filter, title: title, useCases: useCases, path: $path)
        }
    }
}
