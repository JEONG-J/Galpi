//
//  LinkBoxShared.swift
//  LinkBoxPresentation
//
//  Created by euijjang97 on 9/1/26.
//

import GalpiDesignSystem
import GalpiKit
import SwiftUI

/// `SwiftUI.Link` 와 이름이 겹쳐 매번 모듈 한정이 필요하다. 현재 모듈 선언이 우선하므로
/// 여기 한 줄로 모듈 전체에서 `Link` 를 도메인 모델로 고정한다.
typealias Link = GalpiKit.Link

// MARK: - 상수

fileprivate enum Constants {

    /// 링크 행 썸네일 한 변 — Dynamic Type 배율이 얹힌다.
    static let thumbnailSize: CGFloat = 44

    /// 썸네일과 제목 사이 간격.
    static let thumbnailSpacing: CGFloat = 12

    /// 링크 행의 좌우 여백 — `List` 의 `listRowInsets` 가 쓴다.
    static let rowHorizontalInset: CGFloat = 14

    /// 링크 행의 상하 여백.
    static let rowVerticalInset: CGFloat = 11
}

// MARK: - 표시 형식

enum LinkFormat {

    /// 시안의 '3일 전' · '1주 전' 표기.
    static func relativeDay(
        _ date: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0

        return switch days {
        case ..<0: "예정"
        case 0: "오늘"
        case 1..<7: "\(days)일 전"
        case 7..<30: "\(days / 7)주 전"
        case 30..<365: "\(days / 30)개월 전"
        default: "\(days / 365)년 전"
        }
    }

    /// 시안의 출처 표기 — `www.` 를 뗀 호스트.
    static func host(_ link: Link) -> String {
        guard var host = link.url?.host() else { return link.urlString }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }

    /// 시안의 폴더 라벨 — 폴더가 없으면 '받은함'.
    static func folderName(_ link: Link) -> String {
        link.folder?.name ?? "받은함"
    }
}

extension Folder {
    var pastel: GalpiPastel { GalpiPastel(name: colorName) }
}

extension Link {
    /// 썸네일 자리에 얹을 글리프. 폴더 아이콘이 있으면 그걸, 없으면 출처 심볼을 쓴다.
    var glyphSymbol: String { folder?.iconName ?? sourceApp.symbolName }

    var pastel: GalpiPastel { folder.map(\.pastel) ?? .gray }
}

// MARK: - 미열람 카드

/// 홈 상단 캐러셀 카드 — 168pt 폭, 썸네일 92pt.
struct UnreadLinkCard: View {

    let link: Link

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GalpiThumbnail(
                imageData: link.thumbnailData,
                symbol: link.glyphSymbol,
                cornerRadius: 0,
                glyphSize: 24
            )
            .frame(height: 92)

            VStack(alignment: .leading, spacing: 7) {
                Text(link.displayTitle)
                    .font(GalpiFont.text(13, .bold))
                    .foregroundStyle(GalpiColor.text)
                    .lineSpacing(13 * 0.35)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(LinkFormat.host(link))
                    .font(GalpiFont.text(11, .medium))
                    .foregroundStyle(GalpiColor.textSecondary)
                    .lineLimit(1)

                Text(LinkFormat.relativeDay(link.createdAt))
                    .font(GalpiFont.text(10, .bold))
                    .foregroundStyle(Color(rgba: 0xFF9500FF))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(rgba: 0xFFF1E0FF), in: .rect(cornerRadius: 8))
            }
            .padding(12)
        }
        .frame(width: 168, alignment: .topLeading)
        .background(GalpiColor.surface, in: .rect(cornerRadius: 18))
        .galpiShadow(.unreadCard)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(link.displayTitle), \(LinkFormat.host(link)), "
                + "\(LinkFormat.relativeDay(link.createdAt)) 저장, 안 읽음"
        )
    }
}

// MARK: - 링크 행

/// '최근 저장' 리스트와 검색 결과가 함께 쓰는 `List` 행 본문.
///
/// 좌우·상하 여백은 행이 직접 갖지 않는다 — `List` 가 `listRowInsets` 로 잡아야
/// 구분선 inset 과 스와이프 영역이 행 크기와 어긋나지 않는다.
struct LinkRow: View {

    // MARK: - Property

    let link: Link

    // 최대 배율에서 제목 두 줄이 썸네일보다 커지면 행이 어긋난다. 썸네일도 같이 키운다.
    @ScaledMetric(relativeTo: .body) private var thumbnailSize = Constants.thumbnailSize

    // MARK: - Body

    var body: some View {
        HStack(spacing: Constants.thumbnailSpacing) {
            GalpiThumbnail(
                imageData: link.thumbnailData,
                symbol: link.glyphSymbol,
                cornerRadius: 13,
                glyphSize: 20
            )
            .frame(width: thumbnailSize, height: thumbnailSize)
            .background(link.pastel.background, in: .rect(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 3) {
                Text(link.displayTitle)
                    .font(GalpiFont.text(14, .semibold))
                    .foregroundStyle(GalpiColor.text)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(LinkFormat.host(link))
                    Circle()
                        .fill(GalpiColor.textTertiary)
                        .frame(width: 3, height: 3)
                    Text(LinkFormat.folderName(link))
                }
                .font(GalpiFont.text(11, .medium))
                .foregroundStyle(GalpiColor.textSecondary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if link.isUnread {
                Circle()
                    .fill(GalpiColor.main)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(link.displayTitle), \(LinkFormat.host(link)), \(LinkFormat.folderName(link))"
                + (link.isUnread ? ", 안 읽음" : "")
        )
    }
}

// MARK: - 링크 리스트 카드

/// 여러 `LinkRow` 를 흰 카드 하나로 묶고 사이에 구분선을 넣는다.
struct LinkListCard: View {

    let links: [Link]
    let onSelect: (Link) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(links.enumerated()), id: \.element.id) { index, link in
                Button { onSelect(link) } label: {
                    LinkRow(link: link)
                        .padding(.horizontal, Constants.rowHorizontalInset)
                        .padding(.vertical, Constants.rowVerticalInset)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)

                if index < links.count - 1 {
                    GalpiSeparator(leadingInset: 70)
                }
            }
        }
        .galpiCard(cornerRadius: 20)
    }
}
