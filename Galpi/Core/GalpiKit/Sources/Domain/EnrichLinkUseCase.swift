//
//  EnrichLinkUseCase.swift
//  GalpiKit
//
//  Created by euijjang97 on 9/1/26.
//

import Foundation

/// 저장 직후 링크를 채워 넣는다 — 제목·썸네일(항상), AI 요약·태그(설정이 켜져 있을 때).
///
/// 저장 흐름은 이걸 기다리지 않는다(설계 §7-①: 3초·2탭). 저장이 끝난 뒤 백그라운드로 돌리고,
/// 값이 들어오면 화면이 알아서 갱신된다.
@MainActor
public protocol EnrichLinkUseCase {
    func execute(linkID: UUID, includeSummary: Bool) async
}

@MainActor
public struct DefaultEnrichLinkUseCase: EnrichLinkUseCase {

    // MARK: - Property

    private let repository: any LinkRepository
    private let metadataService: any LinkMetadataService
    private let summaryService: any LinkSummaryService

    // MARK: - Function

    public init(
        repository: any LinkRepository,
        metadataService: any LinkMetadataService,
        summaryService: any LinkSummaryService
    ) {
        self.repository = repository
        self.metadataService = metadataService
        self.summaryService = summaryService
    }

    public func execute(linkID: UUID, includeSummary: Bool) async {
        guard let link = try? repository.link(id: linkID), let url = link.url else { return }

        if let metadata = try? await metadataService.fetch(for: url) {
            // 사용자가 그 사이 제목을 고쳤을 수 있으니 비어 있을 때만 채운다.
            if link.title.isEmpty, let title = metadata.title { link.title = title }
            if link.thumbnailData == nil { link.thumbnailData = metadata.thumbnailData }
            try? repository.save()
        }

        guard includeSummary, link.summary == nil else { return }

        guard let generated = await summaryService.summarize(url: url, title: link.title) else {
            return
        }
        link.summary = generated.summary

        let existing = Set((link.tags ?? []).map(\.name))
        let added = generated.tagNames
            .filter { !existing.contains($0) }
            .compactMap { try? repository.tag(named: $0) }
        if !added.isEmpty { link.tags = (link.tags ?? []) + added }

        try? repository.save()
    }
}
