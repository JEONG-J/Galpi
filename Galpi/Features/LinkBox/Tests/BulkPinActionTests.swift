//
//  BulkPinActionTests.swift
//  LinkBoxPresentationTests
//
//  Created by euijjang97 on 9/2/26.
//

import GalpiKit
import Testing

@testable import LinkBoxPresentation

@Suite("일괄 고정 방향")
struct BulkPinActionTests {

    private func link(pinned: Bool) -> Link {
        Link(urlString: "https://example.com", isPinned: pinned)
    }

    @Test("하나라도 안 고정돼 있으면 전부 고정")
    func pinsWhenSelectionIsMixed() {
        #expect(shouldPinAll([link(pinned: true), link(pinned: false)]))
    }

    @Test("전부 고정돼 있으면 해제")
    func unpinsWhenEverySelectionIsPinned() {
        #expect(!shouldPinAll([link(pinned: true), link(pinned: true)]))
    }

    @Test("빈 선택은 고정 쪽 라벨로 둔다")
    func emptySelectionKeepsPinLabel() {
        #expect(shouldPinAll([]))
    }
}
