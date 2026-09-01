//
//  LinkSummaryService.swift
//  GalpiKit
//
//  Created by euijjang97 on 9/1/26.
//

import Foundation
import FoundationModels

/// 시안의 "AI 요약"과 "추천 태그".
public struct LinkSummary: Equatable, Sendable {
    public let summary: String
    public let tagNames: [String]

    public init(summary: String, tagNames: [String]) {
        self.summary = summary
        self.tagNames = tagNames
    }
}

public protocol LinkSummaryService: Sendable {
    /// 모델을 못 쓰는 기기·지역이면 `nil`. 요약은 부가 기능이라 실패해도 저장 흐름을 막지 않는다.
    func summarize(url: URL, title: String) async -> LinkSummary?
    var isAvailable: Bool { get }
}

/// 온디바이스 `SystemLanguageModel` 기반 구현.
///
/// 본문 없이 제목만으로는 쓸 만한 요약이 안 나와서, 원문 HTML 을 한 번 받아 본문 텍스트를
/// 거칠게 뽑아 넣는다. 파서를 붙이지 않는 건 요약 입력으로는 태그를 턴 평문이면 충분하기 때문이다.
public struct DefaultLinkSummaryService: LinkSummaryService {

    // MARK: - Property

    /// 모델에 넣을 본문 최대 길이. 길수록 느려지기만 하고 요약 품질은 크게 안 오른다.
    private let maxBodyLength: Int

    private let session: URLSession

    // MARK: - Function

    public init(maxBodyLength: Int = 4_000, session: URLSession = .shared) {
        self.maxBodyLength = maxBodyLength
        self.session = session
    }

    public var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    public func summarize(url: URL, title: String) async -> LinkSummary? {
        guard isAvailable else { return nil }

        let body = await plainText(of: url)
        let prompt = """
        아래 웹 문서를 한국어로 정리해줘.

        제목: \(title.isEmpty ? url.absoluteString : title)
        본문: \(body.isEmpty ? "(본문을 가져오지 못함 — 제목만 보고 판단)" : body)
        """

        do {
            let session = LanguageModelSession(
                instructions: """
                너는 링크 보관함 앱의 요약기다. 문서를 2~3문장 한국어로 요약하고,
                나중에 다시 찾을 때 쓸 검색 키워드를 태그로 3개 뽑는다.
                태그는 '#' 없이 한 단어 또는 짧은 명사구로만 쓴다.
                """
            )
            let response = try await session.respond(
                to: prompt,
                generating: GeneratedLinkSummary.self
            )
            let generated = response.content
            let tags = generated.tags
                .map { Tag.normalized($0) }
                .filter { !$0.isEmpty }

            guard !generated.summary.isEmpty else { return nil }
            return LinkSummary(summary: generated.summary, tagNames: Array(tags.prefix(3)))
        } catch {
            // 모델 거부·컨텍스트 초과 등. 요약 없이 링크는 그대로 남는다.
            return nil
        }
    }

    /// HTML 태그를 털어낸 본문. 실패하면 빈 문자열(요약은 제목만 보고 진행한다).
    private func plainText(of url: URL) async -> String {
        guard let (data, _) = try? await session.data(from: url),
              let html = String(data: data, encoding: .utf8) else { return "" }

        let stripped = html
            .replacingOccurrences(
                of: "<(script|style)[^>]*>[\\s\\S]*?</\\1>",
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&[a-zA-Z#0-9]+;", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return String(stripped.prefix(maxBodyLength))
    }
}

@Generable
private struct GeneratedLinkSummary {

    @Guide(description: "문서 내용을 한국어 2~3문장으로 요약")
    var summary: String

    @Guide(description: "다시 찾을 때 쓸 한국어 키워드 태그 3개. '#' 없이.")
    var tags: [String]
}
