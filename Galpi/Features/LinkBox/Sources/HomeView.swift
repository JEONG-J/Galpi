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

    /// 저장된 갈피가 하나라도 있는지. '최근 저장'은 최신 4건을 읽으므로 이게 비면 전체가 비어 있다.
    var hasSavedLinks: Bool { !recentLinks.isEmpty }

    /// 이번 주에 저장도 읽음도 없는 상태 — 소비율 0% 를 보여줄 이유가 없다.
    var hasWeeklyActivity: Bool { report.savedCount > 0 || report.readCount > 0 }
}

/// 홈 탭 — 시안 ① 프레임.
public struct HomeView: View {

    // MARK: - Property

    @State private var viewModel: HomeViewModel
    @State private var path: [LinkRoute] = []
    @State private var deletionTarget: Link?
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
            List {
                // 좌우 여백은 `.insetGrouped` 섹션 인셋에 맡긴다 — 여기에 여백을 더 얹으면
                // '최근 저장' 섹션 카드보다 안쪽으로 들어가 카드 좌우 라인이 어긋난다.
                unreadSection
                    .plainListRow(insets: EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))

                weeklyStatCard
                    .plainListRow(insets: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                recentSection
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(18)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(GalpiColor.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LinkRoute.self) { route in
                LinkRouteView(route: route, useCases: useCases)
            }
            .linkDeleteConfirmation(
                target: $deletionTarget,
                useCases: useCases,
                onDeleted: viewModel.load
            )
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
                .padding(.horizontal, 16)

            if viewModel.unreadLinks.isEmpty {
                // 저장이 0건인데 '다 읽었어요'가 뜨면 완료로 오해한다. 두 상태를 갈라 놓는다.
                if viewModel.hasSavedLinks {
                    GalpiEmptyState(
                        symbol: "checkmark.circle",
                        title: "다 읽었어요",
                        message: "안 읽은 갈피가 하나도 없어요.",
                        action: .init(title: "전체 갈피 보기") {
                            path.append(.filtered(.all, title: "전체 갈피"))
                        }
                    )
                } else {
                    GalpiEmptyState(
                        symbol: "bookmark",
                        title: "아직 갈피가 없어요",
                        message: "읽고 싶은 글을 공유 시트에서 갈피로 보내면 여기에 쌓여요."
                    )
                }
            } else {
                ScrollView(.horizontal) {
                    // 큰 Dynamic Type 에서 카드 높이가 벌어져도 상단은 맞춰 둔다.
                    HStack(alignment: .top, spacing: 12) {
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

    @ViewBuilder
    private var weeklyStatCard: some View {
        if viewModel.hasWeeklyActivity {
            weeklyProgressCard
        } else {
            GalpiEmptyState(
                symbol: "chart.bar",
                title: "이번 주 기록이 아직 없어요",
                message: "이번 주에 저장하거나 읽은 갈피가 생기면 소비율이 여기에 나와요."
            )
        }
    }

    private var weeklyProgressCard: some View {
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
        .accessibilityLabel(
            "이번 주 소비율 \(viewModel.consumptionPercent)퍼센트. \(viewModel.weeklyCaption)"
        )
    }

    // MARK: - 최근 저장

    @ViewBuilder
    private var recentSection: some View {
        Section {
            if viewModel.recentLinks.isEmpty {
                GalpiEmptyState(
                    symbol: "tray",
                    title: "아직 꽂아둔 갈피가 없어요",
                    message: "공유 시트에서 '갈피'를 누르면 첫 링크가 여기에 꽂혀요."
                )
                .plainListRow(insets: EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            } else {
                ForEach(viewModel.recentLinks) { link in
                    LinkListRow(link: link, onTogglePin: togglePin) { deletionTarget = $0 }
                }
            }
        } header: {
            // 시안의 섹션 헤더 — 기본 `Section` 헤더(대문자 캡션)로 대체하지 않는다.
            GalpiSectionHeader("최근 저장") {
                GalpiSectionAction("전체 보기") {
                    path.append(.filtered(.all, title: "전체 갈피"))
                }
            }
            .textCase(nil)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
        }
    }

    // MARK: - Function

    /// 고정 순서는 저장소가 매기므로 토글 뒤 다시 읽는다.
    private func togglePin(_ link: Link) {
        useCases.togglePin(link)
        viewModel.load()
    }
}

/// 탭 내부 라우팅 — 스택에 쌓이는 화면을 한 곳에서 만든다.
struct LinkRouteView: View {

    let route: LinkRoute
    let useCases: GalpiUseCases

    var body: some View {
        switch route {
        case .detail(let id):
            LinkDetailView(linkID: id, useCases: useCases)
        case .filtered(let filter, let title):
            FilteredLinkListView(filter: filter, title: title, useCases: useCases)
        }
    }
}

#if DEBUG
#Preview("데이터 0건") {
    HomeView(useCases: .empty())
}
#endif
