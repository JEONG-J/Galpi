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
                .project(target: "GalpiKit", path: .relativeToRoot("Core/GalpiKit")),
            ]
        ),
    ]
)
