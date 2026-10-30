import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    /// Цвет, который сам переключается между светлой и тёмной темой.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

/// «Основной / фон плашки / текст на плашке».
struct Tone {
    let main: Color
    let container: Color
    let onContainer: Color
}

/// Палитра перенесена из Android-версии (Material 3): те же цвета в светлой и тёмной теме.
enum Palette {
    static let primary = Color(light: 0x0F766E, dark: 0x2DD4BF)
    static let onPrimary = Color(light: 0xFFFFFF, dark: 0x042F2E)
    static let primaryContainer = Color(light: 0xCCFBF1, dark: 0x115E59)
    static let background = Color(light: 0xF8FAFC, dark: 0x0B1220)
    static let surface = Color(light: 0xFFFFFF, dark: 0x111A2B)
    static let surfaceVariant = Color(light: 0xE2E8F0, dark: 0x1E293B)
    static let onSurfaceVariant = Color(light: 0x475569, dark: 0x94A3B8)
    static let outline = Color(light: 0xE2E8F0, dark: 0x263449)
    static let error = Color(light: 0xE11D48, dark: 0xFB7185)
    static let errorContainer = Color(light: 0xFFE4E6, dark: 0x4C0519)

    static let ok = Tone(main: Color(light: 0x059669, dark: 0x34D399),
                         container: Color(light: 0xD1FAE5, dark: 0x064E3B),
                         onContainer: Color(light: 0x065F46, dark: 0xA7F3D0))
    static let warn = Tone(main: Color(light: 0xD97706, dark: 0xFBBF24),
                           container: Color(light: 0xFEF3C7, dark: 0x4A3200),
                           onContainer: Color(light: 0x92400E, dark: 0xFDE68A))
    static let danger = Tone(main: Color(light: 0xE11D48, dark: 0xFB7185),
                             container: Color(light: 0xFFE4E6, dark: 0x4C0519),
                             onContainer: Color(light: 0x9F1239, dark: 0xFECDD3))
    static let info = Tone(main: Color(light: 0x4F46E5, dark: 0x818CF8),
                           container: Color(light: 0xE0E7FF, dark: 0x1E1B4B),
                           onContainer: Color(light: 0x3730A3, dark: 0xC7D2FE))
    static let energy = Tone(main: Color(light: 0xF59E0B, dark: 0xFBBF24),
                             container: Color(light: 0xFEF3C7, dark: 0x4A3200),
                             onContainer: Color(light: 0x92400E, dark: 0xFDE68A))

    static func tone(for status: LimitStatus) -> Tone {
        switch status {
        case .ok: return ok
        case .near: return warn
        case .exceeded: return danger
        }
    }
}

/// Фон экрана; в тёмной теме с включённым AMOLED — чисто чёрный.
struct AppBackground: ViewModifier {
    @EnvironmentObject var store: FkuStore
    @Environment(\.colorScheme) var scheme

    func body(content: Content) -> some View {
        let color: Color = (scheme == .dark && store.theme.amoled) ? Color.black : Palette.background
        return content.background(color.ignoresSafeArea())
    }
}

extension View {
    func appBackground() -> some View { modifier(AppBackground()) }

    /// Кнопка «Готово» над цифровой клавиатурой (у numberPad/decimalPad её нет).
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
}
