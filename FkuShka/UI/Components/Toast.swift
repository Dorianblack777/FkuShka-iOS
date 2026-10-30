import SwiftUI

/// Всплывающее сообщение (замена Snackbar из Android-версии). Подключается к каждому корневому экрану.
struct ToastOverlay: ViewModifier {
    @EnvironmentObject var store: FkuStore

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message = store.toastMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 90)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.toastMessage)
    }
}

extension View {
    func toastOverlay() -> some View { modifier(ToastOverlay()) }
}
