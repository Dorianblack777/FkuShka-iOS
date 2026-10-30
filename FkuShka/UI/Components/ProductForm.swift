import SwiftUI

/// Состояние формы продукта: ФА считается автоматически из белка либо берётся с упаковки.
final class ProductFormState: ObservableObject {
    @Published var name: String
    @Published var protein: String
    @Published var kcal: String
    @Published var type: PheSource
    @Published var useManualPhe: Bool
    @Published var manualPhe: String

    init(name: String = "", protein: String = "", kcal: String = "",
         source: PheSource = .regular, manualPhe: String = "") {
        self.name = name
        self.protein = protein
        self.kcal = kcal
        self.type = source == .manual ? .regular : source
        self.useManualPhe = source == .manual
        self.manualPhe = manualPhe
    }

    var proteinValue: Double { protein.decimalValue ?? 0 }
    var kcalValue: Double { kcal.decimalValue ?? 0 }
    var pheValue: Double {
        if useManualPhe { return manualPhe.decimalValue ?? 0 }
        return NutritionCalculator.pheFromProtein(proteinValue, factor: Double(type.factor))
    }
    var pheSource: PheSource { useManualPhe ? .manual : type }

    func per100() -> Per100 {
        Per100(phe: pheValue, protein: proteinValue, kcal: kcalValue).clamped()
    }

    func reset() {
        name = ""; protein = ""; kcal = ""; type = .regular; useManualPhe = false; manualPhe = ""
    }
}

/// Список похожих позиций с пометкой источника. Прячется вместе с фокусом поля названия.
struct DuplicateSuggestions: View {
    let matches: [Product]
    let canEdit: (Product) -> Bool
    let onEdit: (Product) -> Void

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Похожее уже есть — возможно, новое создавать не нужно:")
                    .font(.caption).foregroundColor(Palette.onSurfaceVariant)
                ForEach(matches) { p in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                            Text("[\(p.sourceBadge)] • \(Fmt.num(p.phe)) мг ФА на 100 г")
                                .font(.caption).foregroundColor(Palette.onSurfaceVariant)
                        }
                        Spacer(minLength: 0)
                        if canEdit(p) {
                            Button("Изменить этот") { onEdit(p) }.font(.subheadline)
                        }
                    }
                }
            }
            .padding(12)
        }
    }
}

/// Поля продукта: название (с живой проверкой дубликатов), данные с упаковки,
/// тип продукта и необязательный ручной ввод ФА.
struct ProductFormFields: View {
    @ObservedObject var form: ProductFormState
    var nameLabel = "Название продукта"
    var allFoods: [Product] = []
    var excludeKey: String? = nil
    var canEdit: (Product) -> Bool = { _ in false }
    var onEdit: (Product) -> Void = { _ in }
    @FocusState private var nameFocused: Bool

    private var nameBinding: Binding<String> {
        Binding(get: { form.name }, set: { form.name = String($0.prefix(Limits.maxName)) })
    }

    var body: some View {
        let matches = DuplicateFinder.find(form.name, in: allFoods, excludeKey: excludeKey)
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(nameLabel).font(.caption).foregroundColor(Palette.onSurfaceVariant)
                TextField("", text: nameBinding)
                    .focused($nameFocused)
                    .submitLabel(.next)
                    .padding(10)
                    .background(Palette.surfaceVariant.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }
            // Список показывается, пока в поле названия есть фокус, и пропадает, как только фокус уходит.
            if nameFocused && !matches.isEmpty {
                DuplicateSuggestions(matches: matches, canEdit: canEdit, onEdit: onEdit)
            }

            SectionTitle(
                text: "Данные с упаковки (на 100 г)",
                helpTitle: "Откуда брать эти цифры?",
                helpText: "Посмотрите на заднюю сторону магазинной упаковки — раздел «Пищевая ценность на 100 г».\n\nПерепишите оттуда только «Белки» и «Калории (ккал)». Фенилаланин (ФА) калькулятор вычислит сам."
            )
            AdaptiveFields {
                DecimalField(label: "Белки, г", text: $form.protein, max: Limits.maxProtein100g)
                DecimalField(label: "Калории, ккал", text: $form.kcal, max: Limits.maxKcal100g)
            }

            if !form.useManualPhe {
                SectionTitle(
                    text: "Из чего сделан продукт?",
                    helpTitle: "Зачем выбирать тип продукта?",
                    helpText: "На обычных продуктах не пишут количество фенилаланина (ФА), пишут только общий белок.\n\nПо правилам диеты при ФКУ:\n• в 1 г белка обычных продуктов (крупы, хлеб, молоко, сладости) — 50 мг ФА;\n• в 1 г белка овощей и зелени — 40 мг ФА;\n• в 1 г белка фруктов и ягод — 30 мг ФА.\n\nВыберите подходящую карточку — калькулятор сам умножит белок на нужное число."
                )
                Text("Калькулятор сам вычислит ФА из белка").font(.caption).foregroundColor(Palette.onSurfaceVariant)
                PheTypeSelector(selected: $form.type)
            }

            HStack(spacing: 6) {
                Toggle(isOn: $form.useManualPhe) {
                    Text("Указать ФА вручную (только если он напечатан на пачке спецпродукта)").font(.subheadline)
                }
                HelpButton(
                    title: "Когда нужно вводить ФА вручную?",
                    text: "Считать самому ничего не нужно! Включайте этот переключатель только если вы купили специальный диетический продукт (например, низкобелковые макароны), на упаковке которого производитель уже напечатал строчку «Фенилаланин (Phe): … мг на 100 г»."
                )
            }
            if form.useManualPhe {
                DecimalField(label: "Фенилаланин с упаковки (мг на 100 г)", text: $form.manualPhe, max: Limits.maxPhe100g)
            }

            Text(form.useManualPhe
                 ? "ФА на 100 г: \(Fmt.int(form.pheValue)) мг"
                 : "ФА на 100 г: ≈ \(Fmt.int(form.pheValue)) мг (\(Fmt.num(form.proteinValue)) г белка × \(form.type.factor))")
                .font(.subheadline.weight(.bold))
                .foregroundColor(Palette.primary)
        }
    }
}
