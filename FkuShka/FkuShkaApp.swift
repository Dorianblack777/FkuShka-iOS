import SwiftUI

@main
struct FkuShkaApp: App {
    @StateObject private var store = FkuStore()

    var body: some Scene {
        WindowGroup {
            ThemedRoot().environmentObject(store)
        }
    }
}

/// Применяет выбранную тему (системная / светлая / тёмная) ко всему приложению.
private struct ThemedRoot: View {
    @EnvironmentObject var store: FkuStore

    private var scheme: ColorScheme? {
        switch store.theme.mode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        AppRoot().preferredColorScheme(scheme)
    }
}
