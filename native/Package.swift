// swift-tools-version: 6.2
import Foundation
import PackageDescription

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path

let package = Package(
  name: "BudsNative",
  platforms: [.macOS(.v26)],
  products: [
    .executable(name: "OpenBuds", targets: ["OpenBuds"]),
    .executable(name: "budsprobe", targets: ["budsprobe"]),
  ],
  targets: [
    .target(
      name: "BudsKit",
      path: "Sources/BudsKit",
      linkerSettings: [.linkedFramework("IOBluetooth")]
    ),
    .executableTarget(
      name: "OpenBuds",
      dependencies: ["BudsKit"],
      path: "Sources/OpenBuds"
    ),
    .executableTarget(
      name: "budsprobe",
      path: "Sources/budsprobe",
      linkerSettings: [
        .linkedFramework("IOBluetooth"),
        // macOS only grants Bluetooth to command-line tools that carry a usage description.
        .unsafeFlags([
          "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
          "-Xlinker", "\(root)/Support/budsprobe-Info.plist",
        ]),
      ]
    ),
  ]
)
