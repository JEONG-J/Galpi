import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "Galpi",
    settings: recommendedProjectSettings,
    targets: [
        .target(
            name: "Galpi",
            destinations: .iOS,
            product: .app,
            // App Store 앱 레코드와 동일해야 한다. 이 값이 바뀌면 별개 앱이 되어
            // App Group·iCloud 컨테이너 식별자까지 전부 무효화된다.
            bundleId: "com.example.galpi",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleDisplayName": "갈피",
                    "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                    "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                    // 위젯·알림 딥링크 (`galpi://unread`, `galpi://link/{id}`) — 설계 문서 §7-③·④
                    "CFBundleURLTypes": [
                        [
                            "CFBundleURLName": "com.example.galpi.deeplink",
                            "CFBundleURLSchemes": ["galpi"],
                        ],
                    ],
                    // 미열람 리마인드 재등록을 백그라운드에서 보정한다(best effort).
                    // 식별자는 ReminderScheduler.backgroundRefreshTaskIdentifier 와 같아야 한다.
                    "UIBackgroundModes": ["fetch"],
                    // 시안이 라이트 전용이라 다크 팔레트가 없다. 다크 시안이 나오기 전까지 고정.
                    "UIUserInterfaceStyle": "Light",
                    "BGTaskSchedulerPermittedIdentifiers": [
                        "com.example.galpi.reminder.refresh",
                    ],
                ]
            ),
            buildableFolders: [
                "Galpi/Sources",
            ],
            entitlements: .file(path: "Galpi.entitlements"),
            dependencies: [
                .target(name: "GalpiShare"),
                .project(target: "GalpiKit", path: .relativeToRoot("Core/GalpiKit")),
                .project(
                    target: "GalpiDesignSystem",
                    path: .relativeToRoot("Core/DesignSystem")
                ),
                .project(
                    target: "LinkBoxPresentation",
                    path: .relativeToRoot("Features/LinkBox")
                ),
                .project(
                    target: "SettingsPresentation",
                    path: .relativeToRoot("Features/Settings")
                ),
            ]
        ),
        .target(
            name: "GalpiShare",
            destinations: .iOS,
            product: .appExtension,
            // 앱 번들 ID 접두사를 그대로 따라야 확장으로 인정된다.
            bundleId: "com.example.galpi.share",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleDisplayName": "갈피에 저장",
                    "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                    "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                    "UIUserInterfaceStyle": "Light",
                    "NSExtension": [
                        "NSExtensionPointIdentifier": "com.apple.share-services",
                        "NSExtensionPrincipalClass":
                            "$(PRODUCT_MODULE_NAME).ShareViewController",
                        "NSExtensionAttributes": [
                            // 링크 하나만 받는다. 여러 개 저장은 설계 범위 밖.
                            "NSExtensionActivationRule": [
                                "NSExtensionActivationSupportsWebURLWithMaxCount": 1,
                                "NSExtensionActivationSupportsWebPageWithMaxCount": 1,
                                "NSExtensionActivationSupportsText": true,
                            ],
                        ],
                    ],
                ]
            ),
            buildableFolders: [
                "Galpi/ShareExtension/Sources",
            ],
            entitlements: .file(path: "GalpiShare.entitlements"),
            dependencies: [
                .project(target: "GalpiKit", path: .relativeToRoot("Core/GalpiKit")),
                .project(
                    target: "GalpiDesignSystem",
                    path: .relativeToRoot("Core/DesignSystem")
                ),
                .project(
                    target: "LinkBoxPresentation",
                    path: .relativeToRoot("Features/LinkBox")
                ),
            ]
        ),
    ]
)
