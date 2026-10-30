import SwiftUI

private let dishHelp = "Когда вы варите суп, печёте хлеб или тушите рагу, вода испаряется (или впитывается), и вес блюда меняется.\n\n1. Добавьте все сырые ингредиенты, которые положили в кастрюлю или на противень.\n2. Взвесьте готовое блюдо целиком (без веса кастрюли) и впишите вес.\n3. Калькулятор сам посчитает ФА и белок в 100 г готового блюда и сохранит его в «Мои блюда»."

private let cookedHelp = "При жарке и запекании влага испаряется — блюдо становится легче («ужарка»), а ФА в 100 г готового блюда становится больше.\n\nПри варке круп и макарон вода впитывается — блюдо тяжелеет («разварка»), и ФА в 100 г становится меньше.\n\nЕсли оставить поле пустым, считаем, что вес готового блюда равен весу сырых продуктов."

/// Конструктор сложного блюда на отдельном экране.
struct DishBuilderView: View {
    @EnvironmentObject var store: FkuStore
    let onClose: () -> Void
    let onSaved: () -> Void
    let onPortionAdded: () -> Void

    @State private var manualMode = false
    @State private var showPicker = false
    @State private var portion = "150"
    @State private var meal: Meal = .lunch
    @StateObject private var manualForm = ProductFormState()
    @State private var manualWeight = ""
    @State private var pendingEdit: Product? = nil
    @FocusState private var nameFocused: Bool

    private var nameBinding: Binding<String> {
        Binding(get: { store.draft.name }, set: { store.setDraftName($0) })
    }
    private var cookedBinding: Binding<String> {
        Binding(get: { store.draft.cooked }, set: { store.setDraftCooked($0) })
    }

    var body: some View {
        let draft = store.draft
        let result = store.draftResult
        let editing = draft.editingDishId != nil
        let excludeKey: String? = draft.editingDishId.map { "c\($0)" }
        let matches = DuplicateFinder.find(draft.name, in: store.allFoods, excludeKey: excludeKey)

        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Название и состав
                    AppCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Название и состав").font(.headline.weight(.bold))
                                Spacer()
                                if !editing { Button("Пример") { store.loadSample() } }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Название блюда").font(.caption).foregroundColor(Palette.onSurfaceVariant)
                                TextField("", text: nameBinding)
                                    .focused($nameFocused)
                                    .padding(10)
                                    .background(Palette.surfaceVariant.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                            }
                            if nameFocused && !matches.isEmpty {
                                DuplicateSuggestions(matches: matches, canEdit: { $0.isDish }, onEdit: { requestEdit($0) })
                            }
                        }
                        .padding(16)
                    }

                    addIngredientCard

                    // Состав
                    AppCard {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("Состав (сырые продукты)").font(.subheadline.weight(.semibold))
                                Spacer()
                                Button("Очистить", role: .destructive) { store.clearDraft() }
                                    .disabled(draft.ingredients.isEmpty && draft.name.isEmpty)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            if draft.ingredients.isEmpty {
                                Text("Добавьте ингредиенты или нажмите «Пример»")
                                    .font(.caption).foregroundColor(Palette.onSurfaceVariant)
                                    .frame(maxWidth: .infinity).padding(20)
                            } else {
                                ForEach(draft.ingredients) { ing in
                                    Divider()
                                    ingredientRow(ing)
                                }
                            }
                        }
                    }

                    // Итог
                    AppCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(text: "Вес готового блюда и расчёт на 100 г",
                                         helpTitle: "Что такое ужарка и разварка?", helpText: cookedHelp)
                            AdaptiveFields {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Сырых продуктов").font(.caption).foregroundColor(Palette.onSurfaceVariant)
                                    Text("\(Fmt.num(result.rawWeight)) г").font(.title3.weight(.bold))
                                }
                                DecimalField(label: "Вес готового, г", text: cookedBinding, max: Limits.maxDishG,
                                             placeholder: result.rawWeight > 0 ? Fmt.num(result.rawWeight) : "")
                            }
                            resultCard(result)
                            Button {
                                if store.saveDish() { onSaved() }
                            } label: {
                                Text(editing ? "Сохранить изменения" : "Сохранить в «Мои блюда»").font(.body.weight(.bold)).frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent).tint(Palette.primary).controlSize(.large)
                            .disabled(result.rawWeight <= 0)
                        }
                        .padding(16)
                    }

                    // Порция сразу в дневник
                    AppCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Или сразу добавить порцию в дневник").font(.subheadline.weight(.semibold))
                            DecimalField(label: "Вес порции", text: $portion, suffix: "г")
                            MealSelector(selected: $meal)
                            let w = portion.decimalValue ?? 0
                            Button {
                                if store.addPortionToDiary(meal: meal, weight: w) { onPortionAdded() }
                            } label: { Text("В рацион").frame(maxWidth: .infinity) }
                                .buttonStyle(.bordered)
                                .disabled(w <= 0 || result.rawWeight <= 0)
                        }
                        .padding(16)
                    }
                }
                .padding(16)
                .frame(maxWidth: 720)
            }
            .frame(maxWidth: .infinity)
            .appBackground()
            .navigationTitle(editing ? "Редактирование блюда" : "Новое сложное блюдо")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { onClose() } label: { Image(systemName: "xmark") }.accessibilityLabel("Закрыть")
                }
                ToolbarItem(placement: .primaryAction) {
                    HelpButton(title: "Как считается сложное блюдо?", text: dishHelp)
                }
            }
            .keyboardDoneButton()
            .sheet(isPresented: $showPicker) { IngredientPickerSheet() }
            .alert("Заменить черновик блюда?", isPresented: Binding(get: { pendingEdit != nil }, set: { if !$0 { pendingEdit = nil } })) {
                Button("Заменить") {
                    if let d = pendingEdit { store.startEditing(d) }
                    pendingEdit = nil
                }
                Button("Отмена", role: .cancel) { pendingEdit = nil }
            } message: {
                Text("Несохранённый черновик будет заменён блюдом «\(pendingEdit?.name ?? "")».")
            }
        }
        .toastOverlay()
    }

    /// Открыть другое блюдо на правку; несохранённый черновик заменяется только после подтверждения.
    private func requestEdit(_ dish: Product) {
        if store.draft.editingDishId == dish.customId { return }
        if store.draft.ingredients.isEmpty { store.startEditing(dish) } else { pendingEdit = dish }
    }

    private func ingredientRow(_ ing: RecipeIngredient) -> some View {
        let n = ing.nutrients
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ing.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text("\(Fmt.int(n.phe)) мг ФА • \(Fmt.d1(n.protein)) г • \(Fmt.int(n.kcal)) ккал")
                    .font(.caption).foregroundColor(Palette.onSurfaceVariant)
            }
            Spacer(minLength: 0)
            Text("\(Fmt.num(ing.weight)) г").font(.subheadline.weight(.bold))
            Button { store.removeIngredient(id: ing.id) } label: {
                Image(systemName: "trash").foregroundColor(Palette.onSurfaceVariant).frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Удалить")
        }
        .padding(.leading, 16).padding(.trailing, 4).padding(.vertical, 6)
    }

    private func resultCard(_ result: RecipeResult) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("100 Г ГОТОВОГО").font(.caption.weight(.medium))
                Spacer()
                Text("Выход: \(String(format: "%.2f", locale: Locale.current, result.yieldRatio))×").font(.caption.weight(.medium))
            }
            HStack {
                resultCell(Fmt.int(result.per100.phe), "ФА, мг")
                resultCell(Fmt.d1(result.per100.protein), "Белок, г")
                resultCell(Fmt.int(result.per100.kcal), "Ккал")
            }
        }
        .padding(16)
        .foregroundColor(.primary)
        .background(Palette.primaryContainer, in: RoundedRectangle(cornerRadius: 16))
    }

    private func resultCell(_ value: String, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text(value).font(.title2.weight(.heavy))
            Text(label).font(.caption2)
        }
        .frame(maxWidth: .infinity)
    }

    private var addIngredientCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Добавить ингредиент").font(.subheadline.weight(.semibold))
                    Spacer()
                    Button(manualMode ? "Выбрать из базы" : "Ввести с упаковки") { manualMode.toggle() }.font(.subheadline)
                }
                if !manualMode {
                    Button { showPicker = true } label: {
                        Label("Выбрать продукт…", systemImage: "magnifyingglass").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    ProductFormFields(form: manualForm, nameLabel: "Название ингредиента")
                    HStack(alignment: .bottom, spacing: 8) {
                        DecimalField(label: "Сырой вес, г", text: $manualWeight)
                        let w = manualWeight.decimalValue ?? 0
                        Button("+ Добавить") {
                            store.addIngredient(name: manualForm.name.trimmingCharacters(in: .whitespaces),
                                                weight: w, per100: manualForm.per100())
                            manualForm.reset()
                            manualWeight = ""
                        }
                        .buttonStyle(.borderedProminent).tint(Palette.primary)
                        .disabled(w <= 0)
                    }
                }
            }
            .padding(16)
        }
    }
}

/// Выбор продукта (или блюда) из всей базы и ввод сырого веса.
struct IngredientPickerSheet: View {
    @EnvironmentObject var store: FkuStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var picked: Product? = nil
    @State private var weightText = ""

    var body: some View {
        NavigationStack {
            Group {
                if let p = picked {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("[\(p.sourceBadge)] \(Fmt.num(p.phe)) мг ФА • \(Fmt.num(p.protein)) г • \(Fmt.num(p.kcal)) ккал на 100 г")
                            .font(.caption).foregroundColor(Palette.onSurfaceVariant)
                        DecimalField(label: "Сырой вес, г", text: $weightText)
                        Button {
                            if let w = weightText.decimalValue, w > 0 {
                                store.addIngredient(name: p.name, weight: w, per100: p.per100)
                                dismiss()
                            }
                        } label: { Text("В блюдо").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent).tint(Palette.primary).controlSize(.large)
                            .disabled((weightText.decimalValue ?? 0) <= 0)
                        Spacer()
                    }
                    .padding(16)
                    .navigationTitle(p.name)
                } else {
                    let q = query.trimmingCharacters(in: .whitespaces).lowercased()
                    let list = store.allFoods.filter { q.isEmpty || $0.name.lowercased().contains(q) }
                    List(list) { p in
                        Button { picked = p } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                                Text("[\(p.sourceBadge)] \(Fmt.num(p.phe)) мг ФА • \(Fmt.num(p.protein)) г • \(Fmt.num(p.kcal)) ккал")
                                    .font(.caption).foregroundColor(Palette.onSurfaceVariant)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $query, prompt: "Поиск…")
                    .navigationTitle("Выбор продукта")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(picked == nil ? "Закрыть" : "Назад") { if picked == nil { dismiss() } else { picked = nil } }
                }
            }
            .keyboardDoneButton()
        }
    }
}
