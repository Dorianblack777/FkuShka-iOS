import Foundation

/// Чистые функции расчётов — без UI-зависимостей, легко тестируются.
enum NutritionCalculator {
    static func total(_ items: [DiaryItem]) -> Nutrients {
        items.reduce(Nutrients.zero) { $0 + $1.nutrients }
    }

    /// Ценность 100 г готового блюда. `cookedOverride` — вес готового блюда; nil/≤0 — равен сырому.
    static func recipe(_ ingredients: [RecipeIngredient], cookedOverride: Double?) -> RecipeResult {
        let raw = ingredients.reduce(0) { $0 + $1.weight }
        if raw <= 0 { return .empty }
        var cooked = raw
        if let c = cookedOverride, c > 0, c.isFinite { cooked = min(c, Limits.maxDishG) }
        let total = ingredients.reduce(Nutrients.zero) { $0 + $1.nutrients }
        let k = 100.0 / cooked
        return RecipeResult(
            rawWeight: raw,
            cookedWeight: cooked,
            per100: Per100(phe: total.phe * k, protein: total.protein * k, kcal: total.kcal * k)
        )
    }

    static func percent(_ value: Double, _ limit: Double) -> Double { limit > 0 ? value / limit * 100.0 : 0 }

    static func status(_ percent: Double) -> LimitStatus {
        if percent > 100 { return .exceeded }
        if percent >= 85 { return .near }
        return .ok
    }

    static func pheFromProtein(_ protein: Double, factor: Double) -> Double { protein * factor }
    static func proteinFromPhe(_ phe: Double, factor: Double) -> Double { factor > 0 ? phe / factor : 0 }
}
