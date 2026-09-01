import ProjectDescription

let workspace = Workspace(
    name: "Galpi",
    projects: [
        ".",
        "Core/*",
        "Features/*",
        "GalpiWidget",
        "GalpiWatchApp",
    ]
)
