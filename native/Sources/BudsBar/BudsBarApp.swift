import AppKit
import BudsKit
import SwiftUI

// One session for the app's lifetime. (Not @State: SwiftUI's macros need Xcode, and this builds with the
// Command Line Tools; @Observable tracking works through plain references.)
@MainActor let sharedSession = BudsSession()

@main
struct BudsBarApp: App {
  private let session = sharedSession

  init() {
    DispatchQueue.main.async { sharedSession.start() }
  }

  var body: some Scene {
    MenuBarExtra {
      PanelView(session: session)
    } label: {
      MenuBarLabel(session: session)
    }
    .menuBarExtraStyle(.window)

    Window("OnePlus Buds", id: "settings") {
      SettingsView(session: session)
    }
    .windowResizability(.contentMinSize)
  }
}

struct MenuBarLabel: View {
  let session: BudsSession

  var body: some View {
    HStack(spacing: 3) {
      Image(systemName: "earbuds")
        .opacity(session.isConnected ? 1 : 0.5)
      if session.isConnected, let level = session.lowestBud {
        Text("\(level)%").monospacedDigit()
      }
    }
  }
}
