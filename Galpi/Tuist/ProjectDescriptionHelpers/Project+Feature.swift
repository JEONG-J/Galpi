import ProjectDescription

private let bundleIdBase = "com.app.galpi.feature"

/// Feature 모듈용 Project 생성 헬퍼
///
/// 갈피의 Feature는 **Presentation 전용** 단일 staticFramework 타겟이다.
/// Domain(모델·UseCase)과 Data(Repository·SwiftData)는 3개 타겟이 공유하는 `GalpiKit`에
/// 모여 있으므로, Feature마다 Domain/Data 타겟을 따로 두지 않는다. (설계 문서 §6)
///
/// - Parameters:
///   - name: Feature 이름 (예: "LinkBox", "Settings"). 타겟명은 `{name}Presentation`.
///   - extraDependencies: GalpiKit·DesignSystem 외에 추가할 의존성
///   - includesTests: `true`이면 `Tests/**` 소스를 사용하는 unitTests 타겟을 함께 생성
///   - testDependencies: 테스트 타겟에 추가로 주입할 의존성 (메인 타겟은 자동 포함)
public func featureProject(
    name: String,
    extraDependencies: [TargetDependency] = [],
    includesTests: Bool = false,
    testDependencies: [TargetDependency] = []
) -> Project {
    let targetName = "\(name)Presentation"
    let bundleId = "\(bundleIdBase).\(name.lowercased())"

    var targets: [Target] = [
        .target(
            name: targetName,
            destinations: [.iPhone],
            product: .staticFramework,
            bundleId: bundleId,
            deploymentTargets: .iOS("26.0"),
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "GalpiKit", path: .relativeToRoot("Core/GalpiKit")),
                .project(target: "GalpiDesignSystem", path: .relativeToRoot("Core/DesignSystem")),
            ] + extraDependencies
        )
    ]

    if includesTests {
        targets.append(
            .target(
                name: "\(targetName)Tests",
                destinations: [.iPhone],
                product: .unitTests,
                bundleId: "\(bundleId).tests",
                deploymentTargets: .iOS("26.0"),
                sources: ["Tests/**"],
                dependencies: [.target(name: targetName)] + testDependencies
            )
        )
    }

    return Project(
        name: name,
        settings: recommendedProjectSettings,
        targets: targets
    )
}
