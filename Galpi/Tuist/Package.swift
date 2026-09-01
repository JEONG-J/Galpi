// swift-tools-version: 6.0
import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    let packageSettings = PackageSettings(
        productTypes: [:]
    )
#endif

// 갈피는 서버가 없다 — 원격 호출은 LinkPresentation 하나뿐이고, 저장은 SwiftData + CloudKit이
// 전부다. 외부 패키지 의존성이 하나도 없는 상태를 유지한다.
// (설계 문서 §2·§4 "템플릿 다이어트")
let package = Package(
    name: "Galpi",
    dependencies: []
)
