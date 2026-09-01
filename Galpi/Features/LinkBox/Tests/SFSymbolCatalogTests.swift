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
}
