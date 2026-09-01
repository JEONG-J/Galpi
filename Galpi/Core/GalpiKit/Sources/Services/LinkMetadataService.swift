//
//  LinkMetadataService.swift
//  GalpiKit
//
//  Created by euijjang97 on 9/1/26.
//

import Foundation
import ImageIO
import LinkPresentation
import UniformTypeIdentifiers

/// 링크에서 뽑아온 표시용 메타데이터.
public struct LinkMetadata: Equatable, Sendable {
    public let title: String?
    /// 다운샘플·JPEG 재인코딩까지 끝난 썸네일. 원본 바이트는 절대 그대로 담지 않는다.
    public let thumbnailData: Data?

    public init(title: String?, thumbnailData: Data?) {
        self.title = title
        self.thumbnailData = thumbnailData
    }
}

public protocol LinkMetadataService: Sendable {
    func fetch(for url: URL) async throws -> LinkMetadata
}

/// `LPMetadataProvider` 기반 구현.
///
/// 저장 흐름은 이걸 **기다리지 않는다**(설계 §7-①: 3초·2탭). 링크를 먼저 저장하고,
/// 결과가 오면 제목·썸네일만 나중에 채워 넣는다.
public struct DefaultLinkMetadataService: LinkMetadataService {

    // MARK: - Property

    /// 썸네일 최대 변, px. 시안에서 가장 큰 썸네일이 카드 상단(390pt 폭의 절반 남짓)이라
    /// 400px 이면 3x 화면에서도 충분하다. CloudKit 용량을 아끼려 이보다 키우지 않는다.
    private let maxPixelSize: CGFloat

    private let timeout: TimeInterval

    // MARK: - Function

    public init(maxPixelSize: CGFloat = 400, timeout: TimeInterval = 10) {
        self.maxPixelSize = maxPixelSize
        self.timeout = timeout
    }

    public func fetch(for url: URL) async throws -> LinkMetadata {
        let provider = LPMetadataProvider()
        provider.timeout = timeout

        let metadata = try await provider.startFetchingMetadata(for: url)
        let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines)

        return LinkMetadata(
            title: (title?.isEmpty ?? true) ? nil : title,
            thumbnailData: await downsampledImageData(from: metadata.imageProvider)
        )
    }

    private func downsampledImageData(from provider: NSItemProvider?) async -> Data? {
        guard let provider,
              provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
            return nil
        }

        let data: Data? = await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(
                forTypeIdentifier: UTType.image.identifier
            ) { data, _ in
                continuation.resume(returning: data)
            }
        }
        guard let data else { return nil }
        return Self.downsample(data, maxPixelSize: maxPixelSize)
    }

    /// 전체 디코딩 없이 축소본만 만든다 — 공유 확장은 메모리 한도가 빡빡하다.
    static func downsample(_ data: Data, maxPixelSize: CGFloat) -> Data? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions),
              let destinationData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                  destinationData, UTType.jpeg.identifier as CFString, 1, nil
              ) else {
            return nil
        }

        CGImageDestinationAddImage(
            destination, thumbnail, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return destinationData as Data
    }
}
