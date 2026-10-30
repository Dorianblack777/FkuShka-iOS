import SwiftUI

/// Что открыть в редакторе: новый продукт (с предзаполненным названием) или правка существующего.
struct ProductEditorRequest: Identifiable {
    let id = UUID()
    var editing: Product? = nil
    var prefillName: String = ""
}

struct ProductEditorSheet: View {
    @EnvironmentObject var store: FkuStore
    @Environment(\.dismiss) private var dismiss
    let request: ProductEditorRequest
    let onEditOther: (Product) -> Void
    @StateObject private var form: ProductFormState

    init(request: ProductEditorRequest, onEditOther: @escaping (Product) -> Void) {
        self.request = request
        self.onEditOther = onEditOther
        let e = request.editing
        _form = StateObject(wrappedValue: ProductFormState(
            name: e?.name ?? request.prefillName,
            protein: e.map { Fmt.input($0.protein) } ?? "",
            kcal: e.map { Fmt.input($0.kcal) } ?? "",
            source: e?.pheSource ?? .regular,
            manualPhe: e.map { Fmt.input($0.phe) } ?? ""
        ))
    }

    var body: some View {
        let name = form.name.trimmingCharacters(in: .whitespaces)
        NavigationStack {
            ScrollView {
                ProductFormFields(form: form, nameLabel: "Название продукта",
                                  allFoods: store.allFoods, excludeKey: request.editing?.key,
                                  canEdit: { $0.isCustom }, onEdit: onEditOther)
                    .padding(16)
            }
            .navigationTitle(request.editing != nil ? "Изменить продукт" : "Новый продукт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        store.saveProduct(existingId: request.editing?.customId, name: name,
                                          per100: form.per100(), source: form.pheSource)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .keyboardDoneButton()
        }
    }
}

/// Калькулятор «с упаковки»: считает порцию, добавляет в дневник или сохраняет в «Мои продукты».
struct QuickCalcSheet: View {
    @EnvironmentObject var store: FkuStore
    @Environment(\.dismiss) private var dismiss
    let onEditOther: (Product) -> Void
    @StateObject private var form: ProductFormState
    @State private var weightText = "100"
    @State private var meal: Meal = .lunch

    init(prefillName: String, onEditOther: @escaping (Product) -> Void) {
        self.onEditOther = onEditOther
        _form = StateObject(wrappedValue: ProductFormState(name: prefillName))
    }

    var body: some View {
        let weight = weightText.decimalValue ?? 0
        let per100 = form.per100()
        let portion = per100.forWeight(weight)
        let name = form.name.trimmingCharacters(in: .whitespaces)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ProductFormFields(form: form, nameLabel: "Название (необязательно)",
                                      allFoods: store.allFoods, canEdit: { $0.isCustom }, onEdit: onEditOther)
                    DecimalField(label: "Вес порции, г", text: $weightText)
                    AppCard {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Итого в порции (\(Fmt.num(weight)) г)").font(.caption).foregroundColor(Palette.onSurfaceVariant)
                            Text("\(Fmt.int(portion.phe)) мг ФА").font(.title2.weight(.heavy)).foregroundColor(Palette.primary)
                            Text("Белок \(Fmt.d1(portion.protein)) г • \(Fmt.int(portion.kcal)) ккал").font(.caption)
                        }
                        .padding(12)
                    }
                    MealSelector(selected: $meal)
                    FlowLayout(spacing: 8) {
                        Button {
                            store.saveProduct(existingId: nil, name: name, per100: per100, source: form.pheSource)
                            dismiss()
                        } label: { Text("★ В «Мои продукты»") }
                            .buttonStyle(.bordered).disabled(name.isEmpty)
                        Button {
                            store.addToSelectedDay(meal: meal, name: name.isEmpty ? "Продукт по этикетке" : name,
                                                   weight: weight, per100: per100)
                            dismiss()
                        } label: { Text("В дневник") }
                            .buttonStyle(.borderedProminent).tint(Palette.primary).disabled(weight <= 0)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Быстрый расчёт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
            .keyboardDoneButton()
        }
    }
}
