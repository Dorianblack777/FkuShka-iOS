import SwiftUI

/// Единая вкладка «Меню и База»: подвкладки «Продукты» и «Мои блюда».
struct MenuView: View {
    @EnvironmentObject var store: FkuStore
    @Binding var tab: Int
    let defaultMeal: Meal
    let onNewProduct: (String) -> Void
    let onEditProduct: (Product) -> Void
    let onNewDish: () -> Void
    let onEditDish: (Product) -> Void

    @State private var query = ""
    @State private var dishQuery = ""
    @State private var category: ProductCategory? = nil
    @State private var toAdd: Product? = nil
    @State private var toDelete: Product? = nil

    private func matches(_ p: Product, _ q: String) -> Bool {
        let needle = q.trimmingCharacters(in: .whitespaces).lowercased()
        return needle.isEmpty || p.name.lowercased().contains(needle)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("Продукты").tag(0)
                Text("Мои блюда").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16).padding(.top, 8)

            if tab == 0 { productsTab } else { dishesTab }
        }
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .sheet(item: $toAdd) { product in
            AddToDiarySheet(product: product, defaultMeal: defaultMeal)
        }
        .alert("Удалить?", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } })) {
            Button("Удалить", role: .destructive) {
                if let p = toDelete { store.deleteCustom(p) }
                toDelete = nil
            }
            Button("Отмена", role: .cancel) { toDelete = nil }
        } message: {
            Text("«\(toDelete?.name ?? "")» будет удалён из вашей базы. Записи дневника сохранятся.")
        }
    }

    // MARK: Продукты

    private var productsTab: some View {
        let list = store.foods.filter { p in
            (category == nil || p.category == category) && matches(p, query)
        }
        return VStack(spacing: 0) {
            bigButton("Добавить новый продукт") { onNewProduct("") }
            searchField($query, placeholder: "Найти продукт: картофель, МакМастер, кофе…")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(title: "Все", selected: category == nil) { category = nil }
                    ForEach(ProductCategory.allCases.filter { $0 != .dish }) { cat in
                        Chip(title: cat.title, selected: category == cat) { category = (category == cat) ? nil : cat }
                    }
                }
                .padding(.horizontal, 16)
            }
            if list.isEmpty {
                emptyState(title: "Продукт не найден",
                           hint: "Добавьте его сами по данным с упаковки — это займёт пару секунд.",
                           action: ("+ Создать свой продукт", { onNewProduct(query.trimmingCharacters(in: .whitespaces)) }))
            } else {
                foodList(list, onEdit: onEditProduct)
            }
        }
    }

    // MARK: Мои блюда

    private var dishesTab: some View {
        let list = store.dishes.filter { matches($0, dishQuery) }
        return VStack(spacing: 0) {
            bigButton("Создать сложное блюдо") { onNewDish() }
            searchField($dishQuery, placeholder: "Найти блюдо: суп, пирог, рагу…")
            if list.isEmpty {
                emptyState(title: dishQuery.isEmpty ? "Пока нет сохранённых блюд" : "Блюдо не найдено",
                           hint: "Здесь хранятся ваши супы, выпечка и рагу: соберите блюдо из ингредиентов один раз, а калькулятор посчитает ФА на 100 г готового.",
                           action: nil)
            } else {
                foodList(list, onEdit: onEditDish)
            }
        }
    }

    // MARK: Общие куски

    private func bigButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus").font(.body.weight(.bold)).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Palette.primary)
        .controlSize(.large)
        .padding(.horizontal, 16).padding(.top, 12)
    }

    private func searchField(_ text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(Palette.onSurfaceVariant)
            TextField(placeholder, text: text).submitLabel(.search)
            if !text.wrappedValue.isEmpty {
                Button { text.wrappedValue = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(Palette.onSurfaceVariant) }
                    .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Palette.surfaceVariant.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private func emptyState(title: String, hint: String, action: (String, () -> Void)?) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Text(title).font(.headline)
            Text(hint).font(.caption).foregroundColor(Palette.onSurfaceVariant).multilineTextAlignment(.center)
            if let a = action { Button(a.0, action: a.1).padding(.top, 4) }
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    private func foodList(_ list: [Product], onEdit: @escaping (Product) -> Void) -> some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(list) { product in
                    FoodCard(product: product,
                             onAdd: { toAdd = product },
                             onEdit: { onEdit(product) },
                             onDelete: { toDelete = product })
                }
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 96)
        }
    }
}

/// Карточка продукта или блюда: ФА/белок/ккал на 100 г, пометка источника и действия.
private struct FoodCard: View {
    let product: Product
    let onAdd: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let tone: Tone = product.phe > 100 ? Palette.danger : (product.phe > 45 ? Palette.warn : Palette.ok)
        AppCard {
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(product.category.title.uppercased()).font(.caption2).foregroundColor(Palette.onSurfaceVariant)
                    Text(product.name).font(.subheadline.weight(.bold))
                    FlowLayout(spacing: 8) {
                        Pill(text: "\(Fmt.num(product.phe)) мг ФА", tone: tone)
                        Text("\(Fmt.num(product.protein)) г • \(Fmt.num(product.kcal)) ккал")
                            .font(.caption).foregroundColor(Palette.onSurfaceVariant)
                    }
                    if product.isDish && !product.recipeSummary.isEmpty {
                        Text("Состав: \(product.recipeSummary)").font(.caption).foregroundColor(Palette.onSurfaceVariant).lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                if product.isCustom {
                    iconButton("pencil", label: "Изменить", action: onEdit)
                    iconButton("trash", label: "Удалить", action: onDelete)
                }
                Button(action: onAdd) {
                    Image(systemName: "plus").font(.body.weight(.semibold)).foregroundColor(Palette.primary)
                        .frame(width: 40, height: 40)
                        .background(Palette.primaryContainer, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Добавить в рацион")
            }
            .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 12)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onAdd)
    }

    private func iconButton(_ system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system).foregroundColor(Palette.onSurfaceVariant).frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct AddToDiarySheet: View {
    @EnvironmentObject var store: FkuStore
    @Environment(\.dismiss) private var dismiss
    let product: Product
    @State private var weightText = "100"
    @State private var meal: Meal

    init(product: Product, defaultMeal: Meal) {
        self.product = product
        _meal = State(initialValue: defaultMeal)
    }

    var body: some View {
        let weight = weightText.decimalValue
        let preview = weight.map { product.per100.forWeight($0) }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("На 100 г: \(Fmt.num(product.phe)) мг ФА • \(Fmt.num(product.protein)) г белка • \(Fmt.num(product.kcal)) ккал")
                        .font(.caption).foregroundColor(Palette.onSurfaceVariant)
                    DecimalField(label: "Вес порции", text: $weightText, suffix: "г / мл")
                    FlowLayout(spacing: 4) {
                        ForEach([15, 30, 50, 100, 150, 200], id: \.self) { w in
                            Button("\(w) г") { weightText = String(w) }.buttonStyle(.bordered)
                        }
                    }
                    MealSelector(selected: $meal)
                    AppCard {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("В порции:").font(.caption).foregroundColor(Palette.onSurfaceVariant)
                            Text("\(Fmt.int(preview?.phe ?? 0)) мг ФА").font(.title2.weight(.heavy)).foregroundColor(Palette.primary)
                            Text("\(Fmt.d1(preview?.protein ?? 0)) г белка • \(Fmt.int(preview?.kcal ?? 0)) ккал").font(.caption)
                        }
                        .padding(12)
                    }
                }
                .padding(16)
            }
            .navigationTitle(product.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("В рацион") {
                        if let w = weight { store.addToSelectedDay(meal: meal, name: product.name, weight: w, per100: product.per100) }
                        dismiss()
                    }
                    .disabled(!(weight ?? 0 > 0))
                }
            }
            .keyboardDoneButton()
        }
        .presentationDetents([.large])
    }
}
