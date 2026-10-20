import AppKit
import BudsKit
import SwiftUI

// Long-lived objects as globals. (Not @State: SwiftUI's macros need Xcode, and this builds with the
// Command Line Tools; @Observable tracking works through plain references.)
@MainActor let sharedSession = BudsSession()
@MainActor let outputAudio = OutputAudio()
@MainActor let appPrefs = AppPrefs()
@MainActor let companion = Companion(session: sharedSession, prefs: appPrefs)

@main
struct BudsBarApp: App {
  init() {
    DispatchQueue.main.async {
      sharedSession.start()
      outputAudio.start()
      companion.start()
    }
  }

  var body: some Scene {
    MenuBarExtra {
      PanelView(session: sharedSession, model: panelModel, audio: outputAudio, prefs: appPrefs)
    } label: {
      MenuBarLabel(session: sharedSession)
    }
    .menuBarExtraStyle(.window)
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
