//
//  SFSymbolCatalogTests.swift
//  LinkBoxPresentationTests
//
//  Created by euijjang97 on 9/1/26.
//

import Testing

@testable import LinkBoxPresentation

@Suite("SF Symbol 검색")
struct SFSymbolCatalogTests {

    @Test("검색어 토큰을 모두 담은 이름만 나온다")
    func matchesEveryToken() {
        let results = SFSymbolCatalog.search("arrow up", limit: 50)
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.contains("arrow") && $0.contains("up") })
    }

    @Test("검색어로 시작하는 이름이 앞에 온다")
    func prefixMatchesComeFirst() {
        let results = SFSymbolCatalog.search("folder", limit: 20)
        #expect(results.first?.hasPrefix("folder") == true)
    }

    @Test("결과 수는 limit 를 넘지 않는다")
    func respectsLimit() {
        #expect(SFSymbolCatalog.search("circle", limit: 10).count == 10)
    }

    @Test("이 기기에서 그려지는 심볼만 나온다")
    func onlyRenderableSymbols() {
        let results = SFSymbolCatalog.search("book", limit: 30)
        #expect(!results.isEmpty)
        #expect(results.allSatisfy(SFSymbolCatalog.isRenderable))
    }

    @Test("맞는 이름이 없으면 빈 배열")
    func emptyWhenNothingMatches() {
        #expect(SFSymbolCatalog.search("zzqqxx", limit: 20).isEmpty)
        #expect(SFSymbolCatalog.search("   ", limit: 20).isEmpty)
    }

    @Test("한글 낱말은 별칭 표를 거쳐 영문 심볼로 이어진다")
    func koreanQueryMapsToEnglishSymbols() {
        let results = SFSymbolCatalog.search("하트", limit: 30)
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.contains("heart") })
    }

    @Test("낱말을 다 치기 전에도 접두사로 걸린다")
    func koreanPrefixMatchesAlias() {
        let results = SFSymbolCatalog.search("하", limit: 30)
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.contains("heart") })
    }

    @Test("별칭이 여럿이면 결과를 모두 모은다")
    func koreanAliasUnionsEveryCandidate() {
        let results = SFSymbolCatalog.search("커피", limit: 20)
        #expect(results.contains { $0.contains("saucer") })
        #expect(results.contains { $0.contains("mug") })
        #expect(Set(results).count == results.count)
    }

    @Test("별칭 표에 없는 한글은 빈 배열")
    func emptyWhenKoreanIsNotMapped() {
        #expect(SFSymbolCatalog.search("형이상학", limit: 20).isEmpty)
    }
}
