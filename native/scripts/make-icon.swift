// Renders the OpenBuds app icon to Support/AppIcon.icns.
//   swift scripts/make-icon.swift   (run from native/, with Xcode selected or DEVELOPER_DIR set)
import AppKit
import SwiftUI

struct Icon: View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 185, style: .continuous)
        .fill(LinearGradient(
          colors: [Color(red: 0.36, green: 0.62, blue: 1.0), Color(red: 0.13, green: 0.24, blue: 0.78)],
          startPoint: .top, endPoint: .bottom))
      RoundedRectangle(cornerRadius: 185, style: .continuous)
        .fill(RadialGradient(colors: [.white.opacity(0.35), .clear], center: .init(x: 0.3, y: 0.15), startRadius: 0, endRadius: 520))
      RoundedRectangle(cornerRadius: 185, style: .continuous)
        .strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 5)
      Image(systemName: "airpods.pro")
        .font(.system(size: 440, weight: .medium))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 18, y: 14)
        .offset(y: 10)
    }
    .frame(width: 824, height: 824)
    .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
    .frame(width: 1024, height: 1024)
  }
}

let iconset = URL(fileURLWithPath: ".build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

MainActor.assumeIsolated {
  for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
      let renderer = ImageRenderer(content: Icon())
      renderer.scale = CGFloat(size * scale) / 1024
      guard let image = renderer.cgImage,
        let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
      else { fatalError("render failed") }
      let name = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
      try! png.write(to: iconset.appendingPathComponent(name))
    }
  }
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", "Support/AppIcon.icns"]
try task.run()
task.waitUntilExit()
print(task.terminationStatus == 0 ? "Wrote Support/AppIcon.icns" : "iconutil failed")
