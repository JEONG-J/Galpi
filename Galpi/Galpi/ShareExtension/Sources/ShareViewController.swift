//
//  ShareViewController.swift
//  GalpiShare
//
//  Created by euijjang97 on 9/1/26.
//

import GalpiKit
import LinkBoxPresentation
import SwiftUI
import UniformTypeIdentifiers

/// 공유 시트에서 뜨는 저장 카드 — 시안 ⑤ 프레임.
///
/// 확장은 앱과 같은 App Group 스토어를 열어 곧바로 쓴다(설계 §7-①: 3초·2탭).
final class ShareViewController: UIViewController {

    // MARK: - Function

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        Task {
            guard let urlString = await extractURLString() else {
                complete()
                return
            }
            present(urlString: urlString)
        }
    }

    private func present(urlString: String) {
        let useCases: GalpiUseCases
        do {
            useCases = GalpiUseCases(container: try GalpiModelContainer.make())
        } catch {
            complete()
            return
        }

        let root = SaveLinkSheetHost(urlString: urlString, useCases: useCases) { [weak self] in
            self?.complete()
        }
        let hosting = UIHostingController(rootView: root)
        hosting.view.backgroundColor = .clear
        addChild(hosting)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
    }

    /// 공유 아이템에서 URL 을 뽑는다. URL 첨부가 없으면 텍스트 안의 첫 링크를 쓴다.
    private func extractURLString() async -> String? {
        let attachments = (extensionContext?.inputItems as? [NSExtensionItem])?
            .compactMap(\.attachments)
            .flatMap { $0 } ?? []

        for provider in attachments
        where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = try? await provider.loadItem(
                forTypeIdentifier: UTType.url.identifier
            ) as? URL {
                return url.absoluteString
            }
        }

        for provider in attachments
        where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            guard let text = try? await provider.loadItem(
                forTypeIdentifier: UTType.plainText.identifier
            ) as? String else { continue }
            let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let range = NSRange(text.startIndex..., in: text)
            if let match = detector?.firstMatch(in: text, range: range)?.url {
                return match.absoluteString
            }
        }
        return nil
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: [])
    }
}

/// 저장 카드를 시트로 띄우는 껍데기. 시안의 반투명 배경·라운드 38은 시스템 시트가 그린다.
private struct SaveLinkSheetHost: View {

    let urlString: String
    let useCases: GalpiUseCases
    let onFinish: () -> Void

    @State private var isPresented = true

    var body: some View {
        Color.black.opacity(0.35)
            .ignoresSafeArea()
            .sheet(isPresented: $isPresented, onDismiss: onFinish) {
                SaveLinkSheet(urlString: urlString, useCases: useCases)
                    .interactiveDismissDisabled(false)
            }
    }
}
