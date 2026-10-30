import Foundation

enum Meal: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var title: String {
        switch self {
        case .breakfast: return "Завтрак"
        case .lunch: return "Обед"
        case .dinner: return "Ужин"
        case .snack: return "Перекус"
        }
    }
}

enum ProductCategory: String, Codable, CaseIterable, Identifiable {
    case lowprot, veg, fruit, drinks, oils, custom, dish
    var id: String { rawValue }
    var title: String {
        switch self {
        case .lowprot: return "Низкобелковые"
        case .veg: return "Овощи и зелень"
        case .fruit: return "Фрукты и ягоды"
        case .drinks: return "Напитки и сладости"
        case .oils: return "Масла и прочее"
        case .custom: return "Мои продукты ★"
        case .dish: return "Мои блюда"
        }
    }
}

/// Откуда берётся ФА продукта: коэффициент «мг ФА в 1 г белка» или значение с упаковки.
enum PheSource: String, Codable, CaseIterable, Identifiable {
    case regular, vegetable, fruit, manual
    var id: String { rawValue }
    var factor: Int {
        switch self {
        case .regular: return 50
        case .vegetable: return 40
        case .fruit: return 30
        case .manual: return 0
        }
    }
    var title: String {
        switch self {
        case .regular: return "Обычный продукт"
        case .vegetable: return "Овощи и зелень"
        case .fruit: return "Фрукты и ягоды"
        case .manual: return "ФА указан на упаковке"
        }
    }
    var hint: String {
        switch self {
        case .regular: return "Крупы, макароны, хлеб, выпечка, молочные продукты, сладости"
        case .vegetable: return "Овощи, картофель, зелень"
        case .fruit: return "Свежие и замороженные фрукты, ягоды"
        case .manual: return "Производитель напечатал фенилаланин на 100 г"
        }
    }
}

/// Пищевая ценность на 100 г.
struct Per100: Codable, Hashable {
    var phe: Double
    var protein: Double
    var kcal: Double

    static let zero = Per100(phe: 0, protein: 0, kcal: 0)

    func forWeight(_ grams: Double) -> Nutrients {
        let f = grams / 100.0
        return Nutrients(phe: phe * f, protein: protein * f, kcal: kcal * f)
    }

    /// Предохранитель от абсурдных значений (ввод, сбой, будущий импорт).
    func clamped() -> Per100 {
        Per100(
            phe: Limits.clamp(phe, 0, Limits.maxPhe100g),
            protein: Limits.clamp(protein, 0, Limits.maxProtein100g),
            kcal: Limits.clamp(kcal, 0, Limits.maxKcal100g)
        )
    }
}

/// Абсолютные значения (мг ФА, г белка, ккал).
struct Nutrients: Hashable {
    var phe: Double = 0
    var protein: Double = 0
    var kcal: Double = 0
    static let zero = Nutrients()
    static func + (a: Nutrients, b: Nutrients) -> Nutrients {
        Nutrients(phe: a.phe + b.phe, protein: a.protein + b.protein, kcal: a.kcal + b.kcal)
    }
}

struct RecipeIngredient: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var weight: Double
    var per100: Per100
    var nutrients: Nutrients { per100.forWeight(weight) }
}

struct DiaryItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var meal: Meal
    var name: String
    var weight: Double
    var per100: Per100
    var nutrients: Nutrients { per100.forWeight(weight) }
}

struct Product: Identifiable, Hashable {
    let key: String
    var name: String
    var category: ProductCategory
    var protein: Double
    var phe: Double
    var kcal: Double
    var customId: Int? = nil
    var pheSource: PheSource = .manual
    var ingredients: [RecipeIngredient] = []
    var cookedWeight: Double = 0

    var id: String { key }
    var isDish: Bool { category == .dish }
    var isCustom: Bool { customId != nil }
    var per100: Per100 { Per100(phe: phe, protein: protein, kcal: kcal) }
    var recipeSummary: String { ingredients.map { $0.name }.joined(separator: ", ") }

    /// Пометка источника для списков и подсказок о дубликатах.
    var sourceBadge: String {
        if isDish { return "Мои блюда" }
        if isCustom { return "Мои продукты" }
        return "База продуктов"
    }
}

struct RecipeResult {
    var rawWeight: Double
    var cookedWeight: Double
    var per100: Per100
    /// Выход блюда: готовый вес / сырой вес.
    var yieldRatio: Double { rawWeight > 0 ? cookedWeight / rawWeight : 1 }
    static let empty = RecipeResult(rawWeight: 0, cookedWeight: 0, per100: .zero)
}

enum LimitStatus { case ok, near, exceeded }

struct NutritionSettings: Codable, Hashable {
    var pheLimit: Int = 300
    var protLimit: Double = 6.0
    var coeff: Int = 50
    var autoLink: Bool = true
    var kcalLimit: Int = 1800
    var aksLimit: Int = 45

    /// Приводит нормы к допустимым диапазонам.
    func sanitized() -> NutritionSettings {
        var s = self
        s.pheLimit = min(max(pheLimit, Int(Limits.minPheLimit)), Int(Limits.maxPheLimit))
        s.protLimit = Limits.clamp(protLimit, Limits.minProtLimit, Limits.maxProtLimit)
        s.coeff = min(max(coeff, Int(Limits.minCoeff)), Int(Limits.maxCoeff))
        s.kcalLimit = min(max(kcalLimit, Int(Limits.minKcalLimit)), Int(Limits.maxKcalLimit))
        s.aksLimit = min(max(aksLimit, 0), Int(Limits.maxAks))
        return s
    }
}

enum ThemeMode: String, Codable, CaseIterable {
    case system, light, dark
    var title: String {
        switch self {
        case .system: return "Системная"
        case .light: return "Светлая"
        case .dark: return "Тёмная"
        }
    }
}

struct ThemeSettings: Codable, Hashable {
    var mode: ThemeMode = .system
    var amoled: Bool = false
}

struct RecipeDraft: Codable, Hashable {
    var name: String = ""
    /// Вес готового блюда; пустая строка = «авто» (равен сырому).
    var cooked: String = ""
    var editingDishId: Int? = nil
    var ingredients: [RecipeIngredient] = []
}
