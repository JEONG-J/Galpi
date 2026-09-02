//
//  ProfileView.swift
//  SettingsPresentation
//
//  Created by euijjang97 on 9/1/26.
//

import GalpiDesignSystem
import GalpiKit
import SwiftUI

// MARK: - 상수

fileprivate enum Constants {

    /// 설정 행 아이콘 배지 한 변.
    static let badgeSize: CGFloat = 29

    /// 배지와 라벨 사이 간격 — 구분선이 배지 오른쪽에서 시작하도록 inset 계산에도 쓴다.
    static let badgeSpacing: CGFloat = 11

    /// 섹션 헤더 좌우 여백 — 시안의 16pt 를 그대로 쓴다.
    static let headerHorizontalInset: CGFloat = 16
}

@MainActor
@Observable
final class ProfileViewModel {

    // MARK: - Property

    let useCases: GalpiUseCases

    private(set) var savedCount = 0
    private(set) var readCount = 0
    private(set) var report: WeeklyReport?
    private(set) var folders: [Folder] = []
    private(set) var exportText = ""

    /// 삭제가 도는 동안 행을 잠가 확인 다이얼로그가 두 번 열리지 않게 한다.
    private(set) var isErasing = false

    /// 삭제 실패 사유. 성공하면 `nil` 이라 화면은 아무것도 띄우지 않는다.
    var eraseFailureMessage: String?

    var settings: GalpiSettings { useCases.settings }

    // MARK: - Function

    init(useCases: GalpiUseCases) {
        self.useCases = useCases
    }

    func load() {
        let all = (try? useCases.repository.links(
            matching: .all, includeArchived: true, limit: nil
        )) ?? []
        savedCount = all.count
        readCount = all.count { !$0.isUnread }
        report = try? useCases.weeklyReport.execute(now: .now, calendar: .current)
        folders = (try? useCases.repository.folders()) ?? []
        exportText = all
            .map { "\($0.displayTitle)\n\($0.urlString)" }
            .joined(separator: "\n\n")
    }

    var sinceText: String {
        "갈피와 함께한 지 \(settings.daysSinceInstall())일째"
    }

    var streakDays: Int { report?.streakDays ?? 0 }

    var consumptionPercent: Int { Int((report?.consumptionRate ?? 0) * 100) }

    /// 이번 주에 읽은 기록이 하나라도 있는지. 없으면 0 막대만 그리는 대신 빈 상태를 보여준다.
    var hasReadRecord: Bool { (report?.dailyReadCounts ?? []).contains { $0 > 0 } }

    /// 시안 문구의 '상위 N%' 는 비교할 모수가 기기 안에 없어 쓰지 않는다.
    var weeklySummary: String {
        guard let report, report.savedCount > 0 || report.readCount > 0 else {
            return "이번 주엔 아직 저장한 갈피가 없어요"
        }
        let delta = report.readCountDelta
        let tail = delta > 0 ? "지난주보다 \(delta)개 더!"
            : delta < 0 ? "지난주보다 \(-delta)개 적어요" : "지난주와 같아요"
        return "이번 주 \(report.savedCount)개 저장 · \(report.readCount)개 읽음 — \(tail)"
    }

    var defaultFolderName: String {
        folders.first { $0.id == settings.defaultFolderID }?.name ?? Folder.unfiledName
    }

    var syncedText: String {
        guard let lastSyncedAt = settings.lastSyncedAt else { return "대기 중" }
        return lastSyncedAt.formatted(.relative(presentation: .named))
    }

    var reminderValue: String {
        guard settings.reminderCadence != .off else { return "끄기" }
        let hour = settings.reminderHour
        let period = hour < 12 ? "오전" : "오후"
        let display = hour % 12 == 0 ? 12 : hour % 12
        return "\(settings.reminderCadence.displayName) · \(period) \(display)시"
    }

    func updateReminder(cadence: ReminderCadence) {
        settings.reminderCadence = cadence
        Task {
            if cadence != .off { _ = await useCases.reminderScheduler.requestAuthorization() }
            await useCases.refreshReminder()
        }
    }

    func updateReminder(hour: Int) {
        settings.reminderHour = hour
        Task { await useCases.refreshReminder() }
    }

    /// 실패해도 조용히 넘기지 않는다 — 지워진 줄 알고 기기를 넘기는 게 제일 나쁜 결말이라
    /// 사유를 그대로 띄운다.
    func eraseAllData() async {
        isErasing = true
        do {
            try await useCases.eraseAllData()
        } catch {
            eraseFailureMessage = error.localizedDescription
        }
        isErasing = false
        load()
    }
}

/// 내 정보 — 시안 ③ 프레임.
public struct ProfileView: View {

    // MARK: - Property

    @State private var viewModel: ProfileViewModel
    @State private var showsEraseConfirmation = false

    // MARK: - Function

    public init(useCases: GalpiUseCases) {
        _viewModel = State(initialValue: ProfileViewModel(useCases: useCases))
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            List {
                profileCard
                    .plainListRow(insets: cardRowInsets)

                weeklyCard
                    .plainListRow(insets: cardRowInsets)

                settingsSection
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(18)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(GalpiColor.background)
            .confirmationDialog(
                "모든 데이터를 삭제할까요?",
                isPresented: $showsEraseConfirmation,
                titleVisibility: .visible
            ) {
                Button("모두 삭제", role: .destructive) {
                    Task { await viewModel.eraseAllData() }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("갈피·폴더·태그와 환경설정이 이 기기와 iCloud에서 지워져요. 되돌릴 수 없어요.")
            }
            .alert("삭제하지 못했어요", isPresented: eraseFailureBinding) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(viewModel.eraseFailureMessage ?? "")
            }
            .navigationTitle("내 정보")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { viewModel.load() }
    }

    /// 카드는 자기 그림자를 갖고 있어 위아래로 번질 자리를 남긴다.
    /// 좌우 여백은 `.insetGrouped` 섹션 인셋에 맡긴다 — 여기에 여백을 더 얹으면
    /// '환경설정' 섹션 카드보다 안쪽으로 들어가 카드 좌우 라인이 어긋난다.
    private var cardRowInsets: EdgeInsets {
        EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
    }

    // MARK: - Profile

    private var profileCard: some View {
        VStack(spacing: 15) {
            GalpiMascot()

            VStack(spacing: 4) {
                Text(viewModel.settings.nickname)
                    .font(GalpiFont.text(17, .bold))
                    .foregroundStyle(GalpiColor.text)
                Text(viewModel.sinceText)
                    .font(GalpiFont.text(12, .medium))
                    .foregroundStyle(GalpiColor.textSecondary)
            }

            GalpiSeparator()

            HStack {
                statColumn("\(viewModel.savedCount)", "저장")
                statColumn("\(viewModel.readCount)", "읽음")
                statColumn("\(viewModel.streakDays)일", "연속")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .galpiCard(cornerRadius: 22, shadow: .profileCard)
    }

    private func statColumn(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(GalpiFont.text(18, .bold))
                .foregroundStyle(GalpiColor.text)
            Text(label)
                .font(GalpiFont.text(11, .medium))
                .foregroundStyle(GalpiColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Weekly

    @ViewBuilder
    private var weeklyCard: some View {
        if viewModel.hasReadRecord {
            weeklyChartCard
        } else {
            GalpiEmptyState(
                symbol: "chart.bar",
                title: "주간 리포트가 아직 비어 있어요",
                message: "갈피를 하나만 읽어도 요일별 기록이 여기에 쌓여요."
            )
        }
    }

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("주간 리포트")
                    .font(GalpiFont.text(15, .bold))
                    .foregroundStyle(GalpiColor.text)
                Spacer()
                Text("\(viewModel.consumptionPercent)%")
                    .font(GalpiFont.text(16, .bold))
                    .foregroundStyle(GalpiColor.main)
            }

            Text(viewModel.weeklySummary)
                .font(GalpiFont.text(12, .medium))
                .foregroundStyle(GalpiColor.textSecondary)

            WeeklyReadChart(counts: viewModel.report?.dailyReadCounts ?? [])
        }
        .padding(16)
        .galpiCard(cornerRadius: 22, shadow: .card)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        Section {
            Menu {
                Picker("주기", selection: reminderCadenceBinding) {
                    ForEach(ReminderCadence.allCases, id: \.self) { cadence in
                        Text(cadence.displayName).tag(cadence)
                    }
                }
                Menu("발송 시각") {
                    Picker("발송 시각", selection: reminderHourBinding) {
                        ForEach(Array(stride(from: 6, through: 23, by: 1)), id: \.self) { hour in
                            Text("\(hour)시").tag(hour)
                        }
                    }
                }
            } label: {
                SettingsRow(
                    symbol: "bell.fill", pastel: .orange, label: "미열람 리마인더",
                    value: viewModel.reminderValue
                )
            }
            .settingsRow()

            Toggle(isOn: aiOrganizeBinding) {
                SettingsLabel(symbol: "sparkles", pastel: .blue, label: "AI 자동 정리")
            }
            .tint(GalpiColor.main)
            .settingsRow()

            Menu {
                Picker("기본 저장 폴더", selection: defaultFolderBinding) {
                    Text(Folder.unfiledName).tag(UUID?.none)
                    ForEach(viewModel.folders) { folder in
                        Text(folder.name).tag(UUID?.some(folder.id))
                    }
                }
            } label: {
                SettingsRow(
                    symbol: "folder.fill", pastel: .green, label: "기본 저장 폴더",
                    value: viewModel.defaultFolderName
                )
            }
            .settingsRow()

            SettingsRow(
                symbol: "cloud.fill", pastel: .cyan, label: "iCloud 동기화",
                value: viewModel.syncedText, showsChevron: false
            )
            .settingsRow()

            ShareLink(item: viewModel.exportText) {
                SettingsRow(
                    symbol: "square.and.arrow.up", pastel: .gray, label: "데이터 내보내기"
                )
            }
            .settingsRow()

            Button {
                showsEraseConfirmation = true
            } label: {
                SettingsLabel(
                    symbol: "trash.fill", pastel: .red, label: "모든 데이터 삭제",
                    labelColor: GalpiPastel.red.foreground
                )
            }
            .disabled(viewModel.isErasing)
            .settingsRow()
        } header: {
            Text("환경설정")
                .font(GalpiFont.sectionTitle)
                .foregroundStyle(GalpiColor.text)
                .textCase(nil)
                .listRowInsets(
                    EdgeInsets(
                        top: 0, leading: Constants.headerHorizontalInset,
                        bottom: 8, trailing: Constants.headerHorizontalInset
                    )
                )
        } footer: {
            Text("갈피 1.0.0 — 모든 데이터는 내 기기와 iCloud에만 저장돼요")
                .font(GalpiFont.text(11, .medium))
                .foregroundStyle(GalpiColor.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 12)
        }
    }

    private var reminderCadenceBinding: Binding<ReminderCadence> {
        Binding(
            get: { viewModel.settings.reminderCadence },
            set: { viewModel.updateReminder(cadence: $0) }
        )
    }

    private var reminderHourBinding: Binding<Int> {
        Binding(
            get: { viewModel.settings.reminderHour },
            set: { viewModel.updateReminder(hour: $0) }
        )
    }

    private var aiOrganizeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.isAIOrganizeEnabled },
            set: { viewModel.settings.isAIOrganizeEnabled = $0 }
        )
    }

    private var eraseFailureBinding: Binding<Bool> {
        Binding(
            get: { viewModel.eraseFailureMessage != nil },
            set: { if !$0 { viewModel.eraseFailureMessage = nil } }
        )
    }

    private var defaultFolderBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.settings.defaultFolderID },
            set: { viewModel.settings.defaultFolderID = $0 }
        )
    }
}

/// 설정 행 — 아이콘 배지 + 라벨, 오른쪽에 현재 값.
private struct SettingsRow: View {

    // MARK: - Property

    let symbol: String
    let pastel: GalpiPastel
    let label: String
    var value: String?

    /// `Menu`·`ShareLink` 처럼 눌러서 더 들어가는 행만 갈매기를 단다.
    var showsChevron = true

    // MARK: - Body

    var body: some View {
        LabeledContent {
            HStack(spacing: 6) {
                if let value {
                    Text(value)
                        .font(GalpiFont.text(12, .medium))
                        .foregroundStyle(GalpiColor.textTertiary)
                        .lineLimit(1)
                }

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(GalpiColor.textTertiary)
                        .accessibilityHidden(true)
                }
            }
        } label: {
            SettingsLabel(symbol: symbol, pastel: pastel, label: label)
        }
    }
}

/// 설정 행의 왼쪽 — 토글 행도 같은 모양을 써야 배지 위치가 어긋나지 않는다.
private struct SettingsLabel: View {

    let symbol: String
    let pastel: GalpiPastel
    let label: String

    /// 파괴적인 행만 배지 색을 글자에도 그대로 쓴다.
    var labelColor: Color = GalpiColor.text

    var body: some View {
        Label {
            Text(label)
                .font(GalpiFont.text(14, .medium))
                .foregroundStyle(labelColor)
        } icon: {
            GalpiIconBadge(
                symbol: symbol, pastel: pastel,
                size: Constants.badgeSize, cornerRadius: 9, iconSize: 14
            )
        }
    }
}

private extension View {

    /// 설정 섹션의 행 공통 — 카드 배경 토큰과 시안의 구분선 시작점(배지 오른쪽).
    func settingsRow() -> some View {
        listRowBackground(GalpiColor.surface)
            .alignmentGuide(.listRowSeparatorLeading) { _ in
                Constants.badgeSize + Constants.badgeSpacing
            }
    }
}

/// 주간 읽기 막대 — 시안 ③ 92h · 7칸.
private struct WeeklyReadChart: View {

    let counts: [Int]

    private static let dayLabels = ["월", "화", "수", "목", "금", "토", "일"]
    private static let maxBarHeight: CGFloat = 64
    private static let minBarHeight: CGFloat = 6

    private var normalized: [Int] {
        counts.count == 7 ? counts : Array(repeating: 0, count: 7)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(normalized.enumerated()), id: \.offset) { index, count in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(count > 0 ? GalpiColor.main : GalpiColor.thumbnail)
                        .frame(width: 22, height: height(for: count))
                    Text(Self.dayLabels[index])
                        .font(GalpiFont.text(10, .medium))
                        .foregroundStyle(GalpiColor.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(Self.dayLabels[index])요일 \(count)개")
            }
        }
        .frame(height: 92, alignment: .bottom)
    }

    private func height(for count: Int) -> CGFloat {
        let peak = normalized.max() ?? 0
        guard peak > 0, count > 0 else { return Self.minBarHeight }
        let ratio = CGFloat(count) / CGFloat(peak)
        return Self.minBarHeight + (Self.maxBarHeight - Self.minBarHeight) * ratio
    }
}

/// 프로필 마스코트 — 시안 ③ 56×70 책갈피.
private struct GalpiMascot: View {

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 16, bottomLeadingRadius: 8,
            bottomTrailingRadius: 8, topTrailingRadius: 16
        )
        .fill(
            LinearGradient(
                stops: [
                    .init(color: Color(rgba: 0x7DA0F7FF), location: 0),
                    .init(color: Color(rgba: 0x3D63E8FF), location: 0.5),
                    .init(color: Color(rgba: 0x1E3FBEFF), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .frame(width: 56, height: 70)
        .galpiShadow(.mascot)
        .overlay(alignment: .top) {
            VStack(spacing: 5) {
                HStack(spacing: 14) {
                    eye
                    eye
                }
                UnevenRoundedRectangle(bottomLeadingRadius: 3.5, bottomTrailingRadius: 3.5)
                    .fill(GalpiColor.surface)
                    .frame(width: 12, height: 7)
            }
            .padding(.top, 22)
        }
        .overlay(alignment: .top) {
            HStack {
                blush
                Spacer()
                blush
            }
            .padding(.horizontal, 5)
            .padding(.top, 33)
        }
        .overlay(alignment: .topTrailing) {
            // 시안의 반짝임은 마스코트 안쪽에 있다. 밖으로 빼면 흰 카드 위라 보이지 않는다.
            Image(systemName: "sparkle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(rgba: 0xFFFFFFE6))
                .padding(.top, 8)
                .padding(.trailing, 8)
        }
        .accessibilityHidden(true)
    }

    private var eye: some View {
        Circle()
            .fill(GalpiColor.surface)
            .frame(width: 8, height: 8)
    }

    private var blush: some View {
        Ellipse()
            .fill(Color(rgba: 0xFF9FC799))
            .frame(width: 7, height: 5)
    }
}

#if DEBUG
#Preview("데이터 0건") {
    ProfileView(useCases: .empty())
}
#endif
