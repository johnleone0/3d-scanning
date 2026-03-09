// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "ScannerApp",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "ScannerApp",
            targets: ["ScannerApp"],
            bundleIdentifier: "com.scanner3d.app",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .camera),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [.phone, .pad],
            supportedInterfaceOrientations: [.portrait, .landscapeLeft, .landscapeRight],
            capabilities: [
                .camera(purposeString: "Camera access is needed to scan 3D objects using LiDAR.")
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "ScannerApp",
            path: "Sources"
        )
    ]
)
