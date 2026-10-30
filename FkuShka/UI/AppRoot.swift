import SwiftUI

private enum Overlay: Identifiable {
    case profile, dish
    var id: String { self == .profile ? "profile" : "dish" }
}

private enum RootSheet: Identifiable {
    case quick(String)
    case editor(ProductEditorRequest)
    var id: String {
        switch self {
        case .quick(let name): return "quick-\(name)"
        case .editor(let r): return "editor-\(r.id.uuidString)"
        }
    }
}

/// Корень приложения: анкета первого запуска или три вкладки (Дневник / Меню и База / Профиль и Тема).
struct AppRoot: View {
    @EnvironmentObject var store: FkuStore
    @State private var tab = 0
    @State private var menuTab = 0
    @State private var targetMeal: Meal = .lunch
    @State private var overlay: Overlay? = nil
    @State private var rootSheet: RootSheet? = nil
    @State private var pendingDish: Product? = nil

    var body: some View {
        Group {
            if !store.profile.setupCompleted {
                // Первый запуск: пока анкета не заполнена, считать нельзя, закрыть экран нельзя.
                ProfileFormView(first: true, profile: store.profile, nutrition: store.nutrition,
                                onSave: { p, n in store.saveProfile(p, norms: n) }, onClose: nil)
            } else {
                tabs
            }
        }
        .toastOverlay()
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            NavigationStack {
                DiaryView(
                    onAddToMeal: { meal in
                        targetMeal = meal
                        menuTab = 0
                        tab = 1
                    },
                    onUpdateProfile: { overlay = .profile }
                )
                .overlay(alignment: .bottomTrailing) { fab }
                .appBackground()
                .modifier(AppTitle())
            }
            .tabItem { Label("Дневник", systemImage: "house") }
            .tag(0)

            NavigationStack {
                MenuView(
                    tab: $menuTab,
                    defaultMeal: targetMeal,
                    onNewProduct: { name in rootSheet = .editor(ProductEditorRequest(editing: nil, prefillName: name)) },
                    onEditProduct: { rootSheet = .editor(ProductEditorRequest(editing: $0)) },
                    onNewDish: {
                        store.startNewDish()
                        overlay = .dish
                    },
                    onEditDish: { requestDishEdit($0) }
                )
                .overlay(alignment: .bottomTrailing) { fab }
                .appBackground()
                .modifier(AppTitle())
            }
            .tabItem { Label("Меню и База", systemImage: "magnifyingglass") }
            .tag(1)

            NavigationStack {
                ProfileView(onEditProfile: { overlay = .profile })
                    .appBackground()
                    .modifier(AppTitle())
            }
            .tabItem { Label("Профиль и Тема", systemImage: "person.crop.circle") }
            .tag(2)
        }
        .tint(Palette.primary)
        .sheet(item: $rootSheet) { sheet in
            switch sheet {
            case .quick(let name):
                QuickCalcSheet(prefillName: name, onEditOther: { editExisting($0) })
            case .editor(let request):
                ProductEditorSheet(request: request, onEditOther: { editExisting($0) })
            }
        }
        .fullScreenCover(item: $overlay) { o in
            switch o {
            case .profile:
                ProfileFormView(first: false, profile: store.profile, nutrition: store.nutrition,
                                onSave: { p, n in
                                    store.saveProfile(p, norms: n)
                                    overlay = nil
                                },
                                onClose: { overlay = nil })
            case .dish:
                DishBuilderView(
                    onClose: { overlay = nil },
                    onSaved: {
                        overlay = nil
                        menuTab = 1
                        tab = 1
                    },
                    onPortionAdded: {
                        overlay = nil
                        tab = 0
                    }
                )
            }
        }
        .alert("Заменить черновик блюда?", isPresented: Binding(get: { pendingDish != nil }, set: { if !$0 { pendingDish = nil } })) {
            Button("Заменить") {
                if let d = pendingDish {
                    store.startEditing(d)
                    overlay = .dish
                }
                pendingDish = nil
            }
            Button("Отмена", role: .cancel) { pendingDish = nil }
        } message: {
            Text("В конструкторе есть несохранённый черновик. Он будет заменён блюдом «\(pendingDish?.name ?? "")».")
        }
    }

    private var fab: some View {
        Button { rootSheet = .quick("") } label: {
            Label("Быстрый расчёт", systemImage: "plus")
                .font(.subheadline.weight(.bold))
                .foregroundColor(Palette.onPrimary)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Palette.primary, in: Capsule())
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        }
        .padding(16)
    }

    /// Открыть блюдо на правку; если в конструкторе лежит чужой несохранённый черновик — сначала спросить.
    private func requestDishEdit(_ dish: Product) {
        let d = store.draft
        if d.editingDishId == dish.customId {
            overlay = .dish
        } else if !d.ingredients.isEmpty {
            pendingDish = dish
        } else {
            store.startEditing(dish)
            overlay = .dish
        }
    }

    /// «Изменить этот» из подсказки о дубликатах: закрываем лист и открываем нужный редактор.
    private func editExisting(_ p: Product) {
        rootSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if p.isDish {
                requestDishEdit(p)
            } else {
                rootSheet = .editor(ProductEditorRequest(editing: p))
            }
        }
    }
}

private struct AppTitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("ФКУшка").font(.headline.weight(.bold))
                        Text("Контроль фенилаланина, белка и калорий").font(.caption2).foregroundColor(Palette.onSurfaceVariant)
                    }
                }
            }
    }
}
