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
            bundleId: "com.app.galpi",
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
                            "CFBundleURLName": "com.app.galpi.deeplink",
                            "CFBundleURLSchemes": ["galpi"],
                        ],
                    ],
                    // 미열람 리마인드 재등록을 백그라운드에서 보정한다(best effort).
                    // 식별자는 ReminderScheduler.backgroundRefreshTaskIdentifier 와 같아야 한다.
                    "UIBackgroundModes": ["fetch"],
                    // 시안이 라이트 전용이라 다크 팔레트가 없다. 다크 시안이 나오기 전까지 고정.
                    "UIUserInterfaceStyle": "Light",
                    "BGTaskSchedulerPermittedIdentifiers": [
                        "com.app.galpi.reminder.refresh",
                    ],
                ]
            ),
            // Icon Composer 번들. 내부 파일이 개별 복사되지 않도록 `.icon` 디렉터리를
            // 통째로 한 리소스로 넘긴다 — actool 이 이 번들을 읽어 아이콘을 컴파일한다.
            resources: [
                "Galpi/Resources/Galpi.icon",
                // 스플래시 리본 — 아이콘 포그라운드와 같은 그림. `.icon` 번들은 actool 이
                // 컴파일해 버려 안의 png 를 런타임에 못 읽으므로 따로 한 벌 둔다.
                "Galpi/Resources/SplashRibbon.png",
            ],
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
            ],
            // 앱 타깃에만 건다 — Share Extension 은 자체 앱 아이콘이 없다.
            settings: .settings(
                base: [
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "Galpi",
                    // Tuist 기본값 `AccentColor` 를 비운다. 이 레포엔 에셋 카탈로그가 없고
                    // (아이콘은 Icon Composer 번들, 색은 GalpiTheme 토큰) 전역 틴트는
                    // RootView 의 `.tint(GalpiColor.main)` 이 잡으므로 참조할 컬러셋이 없다.
                    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "",
                ]
            )
        ),
        .target(
            name: "GalpiShare",
            destinations: .iOS,
            product: .appExtension,
            // 앱 번들 ID 접두사를 그대로 따라야 확장으로 인정된다.
            bundleId: "com.app.galpi.share",
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
