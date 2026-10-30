import Foundation
import SwiftUI

/// Единая точка доступа к данным и действиям (аналог FkuRepository + ViewModel'ей из Android-версии).
/// Все значения проходят через предохранители `Limits` перед сохранением.
@MainActor
final class FkuStore: ObservableObject {
    @Published private(set) var data: AppData
    @Published var selectedDate: Date = Date()
    @Published var toastMessage: String? = nil

    let builtIn: [Product]
    private let fileURL: URL?
    private var toastTask: Task<Void, Never>? = nil

    init(fileURL: URL? = nil, builtIn: [Product]? = nil, useDefaultFile: Bool = true) {
        let url: URL? = fileURL ?? (useDefaultFile ? FkuStore.defaultFileURL() : nil)
        self.fileURL = url
        self.builtIn = builtIn ?? BuiltInProducts.load()
        var loaded = AppData()
        if let url = url, let raw = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(AppData.self, from: raw) {
            loaded = decoded
        }
        self.data = loaded
    }

    nonisolated static func defaultFileURL() -> URL? {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        return dir.appendingPathComponent("fku.json")
    }

    private func persist() {
        guard let url = fileURL else { return }
        if let raw = try? JSONEncoder().encode(data) {
            try? raw.write(to: url, options: .atomic)
        }
    }

    private func mutate(_ block: (inout AppData) -> Void) {
        var copy = data
        block(&copy)
        data = copy
        persist()
    }

    func toast(_ text: String) {
        toastMessage = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled { self?.toastMessage = nil }
        }
    }

    // MARK: - Профиль, нормы, тема

    var profile: PatientProfile { data.profile }
    var nutrition: NutritionSettings { data.nutrition }
    var theme: ThemeSettings { data.theme }

    func saveProfile(_ p: PatientProfile, norms: NutritionSettings) {
        var profile = p
        profile.setupCompleted = true
        profile.lastUpdated = Date().timeIntervalSince1970
        mutate {
            $0.profile = profile.sanitized()
            $0.nutrition = norms.sanitized()
        }
        toast("Нормы сохранены")
    }

    func setReminder(enabled: Bool, days: Int) {
        mutate {
            $0.profile.reminderEnabled = enabled
            $0.profile.reminderIntervalDays = min(max(days, 7), 365)
        }
    }

    func disableReminders() {
        setReminder(enabled: false, days: data.profile.reminderIntervalDays)
        toast("Напоминания выключены. Включить можно в «Профиле».")
    }

    func setThemeMode(_ mode: ThemeMode) { mutate { $0.theme.mode = mode } }
    func setAmoled(_ on: Bool) { mutate { $0.theme.amoled = on } }

    // MARK: - Дневник

    static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func items(on date: Date) -> [DiaryItem] { data.days[Self.dayKey(date)]?.items ?? [] }
    func aks(on date: Date) -> Double { data.days[Self.dayKey(date)]?.aks ?? 0 }

    func addDiaryItem(date: Date, meal: Meal, name: String, weight: Double, per100: Per100) {
        let item = DiaryItem(
            meal: meal,
            name: String(name.prefix(Limits.maxName)),
            weight: Limits.clampWeight(weight),
            per100: per100.clamped()
        )
        let key = Self.dayKey(date)
        mutate { d in
            var day = d.days[key] ?? DayData()
            day.items.append(item)
            d.days[key] = day
        }
    }

    func addToSelectedDay(meal: Meal, name: String, weight: Double, per100: Per100) {
        addDiaryItem(date: selectedDate, meal: meal, name: name, weight: weight, per100: per100)
        toast("Добавлено: \(name) (\(Fmt.num(weight)) г)")
    }

    func updateWeight(date: Date, id: UUID, weight: Double) {
        let key = Self.dayKey(date)
        mutate { d in
            guard var day = d.days[key], let i = day.items.firstIndex(where: { $0.id == id }) else { return }
            day.items[i].weight = Limits.clampWeight(weight)
            d.days[key] = day
        }
    }

    func removeItem(date: Date, id: UUID) {
        let key = Self.dayKey(date)
        mutate { d in
            guard var day = d.days[key] else { return }
            day.items.removeAll { $0.id == id }
            d.days[key] = day
        }
        toast("Позиция удалена")
    }

    func setAks(date: Date, value: Double) {
        let key = Self.dayKey(date)
        let v = Limits.clamp(value, 0, Limits.maxAks)
        mutate { d in
            var day = d.days[key] ?? DayData()
            day.aks = v
            d.days[key] = day
        }
    }

    func clearDay(date: Date) {
        let key = Self.dayKey(date)
        mutate { $0.days[key] = nil }
        toast("Дневник за день очищен")
    }

    // MARK: - Продукты и блюда

    static func product(from c: CustomProduct) -> Product {
        Product(
            key: "c\(c.id)",
            name: c.name,
            category: c.isDish ? .dish : .custom,
            protein: c.protein,
            phe: c.phe,
            kcal: c.kcal,
            customId: c.id,
            pheSource: c.pheSource,
            ingredients: c.ingredients,
            cookedWeight: c.cookedWeight
        )
    }

    /// Всё: «Мои продукты» и «Мои блюда» (новые сверху) + встроенная база.
    var allFoods: [Product] { data.custom.map { FkuStore.product(from: $0) } + builtIn }
    var foods: [Product] { allFoods.filter { !$0.isDish } }
    var dishes: [Product] { allFoods.filter { $0.isDish } }

    @discardableResult
    func addCustom(name: String, per100: Per100, source: PheSource, isDish: Bool = false,
                   cookedWeight: Double = 0, ingredients: [RecipeIngredient] = []) -> Int {
        let p = per100.clamped()
        var newId = 0
        mutate { d in
            newId = d.nextId
            d.nextId += 1
            let c = CustomProduct(
                id: newId,
                name: String(name.prefix(Limits.maxName)),
                protein: p.protein, phe: p.phe, kcal: p.kcal,
                pheSource: source, isDish: isDish,
                cookedWeight: Limits.clamp(cookedWeight, 0, Limits.maxDishG),
                ingredients: ingredients,
                createdAt: Date().timeIntervalSince1970
            )
            d.custom.insert(c, at: 0)
        }
        return newId
    }

    func updateCustom(id: Int, name: String, per100: Per100, source: PheSource,
                      cookedWeight: Double = 0, ingredients: [RecipeIngredient] = []) {
        let p = per100.clamped()
        mutate { d in
            guard let i = d.custom.firstIndex(where: { $0.id == id }) else { return }
            d.custom[i].name = String(name.prefix(Limits.maxName))
            d.custom[i].protein = p.protein
            d.custom[i].phe = p.phe
            d.custom[i].kcal = p.kcal
            d.custom[i].pheSource = source
            d.custom[i].cookedWeight = Limits.clamp(cookedWeight, 0, Limits.maxDishG)
            d.custom[i].ingredients = ingredients
        }
    }

    /// Новый продукт (`existingId == nil`) или правка существующего из «Моих продуктов».
    func saveProduct(existingId: Int?, name: String, per100: Per100, source: PheSource) {
        if let id = existingId {
            updateCustom(id: id, name: name, per100: per100, source: source)
            toast("Изменения сохранены: «\(name)»")
        } else {
            addCustom(name: name, per100: per100, source: source)
            toast("«\(name)» сохранён в «Мои продукты»")
        }
    }

    func deleteCustom(_ product: Product) {
        guard let id = product.customId else { return }
        mutate { $0.custom.removeAll { $0.id == id } }
        toast("«\(product.name)» удалён")
    }

    // MARK: - Конструктор сложного блюда

    var draft: RecipeDraft { data.draft }
    var draftResult: RecipeResult {
        NutritionCalculator.recipe(data.draft.ingredients, cookedOverride: data.draft.cooked.decimalValue)
    }

    func setDraftName(_ v: String) { mutate { $0.draft.name = String(v.prefix(Limits.maxName)) } }
    func setDraftCooked(_ v: String) { mutate { $0.draft.cooked = v } }

    func addIngredient(name: String, weight: Double, per100: Per100) {
        let ing = RecipeIngredient(
            name: String((name.isEmpty ? "Ингредиент" : name).prefix(Limits.maxName)),
            weight: Limits.clampWeight(weight),
            per100: per100.clamped()
        )
        mutate { $0.draft.ingredients.append(ing) }
    }

    func removeIngredient(id: UUID) { mutate { $0.draft.ingredients.removeAll { $0.id == id } } }

    func clearDraft() { mutate { $0.draft = RecipeDraft() } }

    /// «+ Создать сложное блюдо»: продолжает несохранённый черновик, но не тянет за собой старое редактирование.
    func startNewDish() {
        if data.draft.editingDishId != nil { clearDraft() }
    }

    /// Загружает сохранённое блюдо в конструктор для правки.
    func startEditing(_ dish: Product) {
        guard let id = dish.customId else { return }
        var draft = RecipeDraft()
        draft.name = dish.name
        draft.cooked = dish.cookedWeight > 0 ? Fmt.input(dish.cookedWeight) : ""
        draft.editingDishId = id
        draft.ingredients = dish.ingredients.map { RecipeIngredient(name: $0.name, weight: $0.weight, per100: $0.per100) }
        mutate { $0.draft = draft }
    }

    func loadSample() {
        var draft = RecipeDraft()
        draft.name = "Овощной рататуй с баклажанами и черри"
        draft.cooked = "580" // после запекания влага испаряется: 720 г → 580 г
        let rows: [(String, Double, Per100)] = [
            ("Баклажаны свежие", 250, Per100(phe: 43, protein: 1.2, kcal: 24)),
            ("Кабачки / Цукини молодые", 200, Per100(phe: 22, protein: 0.6, kcal: 24)),
            ("Томаты Черри", 150, Per100(phe: 24, protein: 0.8, kcal: 18)),
            ("Перец болгарский сладкий", 100, Per100(phe: 38, protein: 1.3, kcal: 27)),
            ("Масло растительное", 20, Per100(phe: 0, protein: 0, kcal: 899)),
        ]
        draft.ingredients = rows.map { RecipeIngredient(name: $0.0, weight: $0.1, per100: $0.2) }
        mutate { $0.draft = draft }
        toast("Загружен пример: Рататуй")
    }

    /// Сохраняет (или обновляет) блюдо в «Мои блюда» и очищает черновик.
    @discardableResult
    func saveDish() -> Bool {
        let result = draftResult
        guard result.rawWeight > 0 else {
            toast("Сначала добавьте ингредиенты в блюдо")
            return false
        }
        let d = data.draft
        let name = d.name.trimmingCharacters(in: .whitespaces).isEmpty ? "Моё блюдо" : d.name.trimmingCharacters(in: .whitespaces)
        let cooked = d.cooked.decimalValue ?? 0
        if let id = d.editingDishId {
            updateCustom(id: id, name: name, per100: result.per100, source: .manual, cookedWeight: cooked, ingredients: d.ingredients)
            toast("Блюдо «\(name)» обновлено")
        } else {
            addCustom(name: name, per100: result.per100, source: .manual, isDish: true, cookedWeight: cooked, ingredients: d.ingredients)
            toast("Блюдо «\(name)» сохранено в «Мои блюда»")
        }
        clearDraft()
        return true
    }

    @discardableResult
    func addPortionToDiary(meal: Meal, weight: Double) -> Bool {
        let result = draftResult
        guard result.rawWeight > 0 else {
            toast("Сначала добавьте ингредиенты в блюдо")
            return false
        }
        let trimmed = data.draft.name.trimmingCharacters(in: .whitespaces)
        let name = trimmed.isEmpty ? "Готовое сложное блюдо" : trimmed
        addDiaryItem(date: selectedDate, meal: meal, name: name, weight: weight, per100: result.per100)
        toast("Порция «\(name)» добавлена в дневник")
        return true
    }
}
