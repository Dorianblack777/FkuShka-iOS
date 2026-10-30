import Foundation

struct DayData: Codable, Hashable {
    var items: [DiaryItem] = []
    var aks: Double = 0
}

/// «Мои продукты» и «Мои блюда» (блюдо хранит состав и вес готового для повторного редактирования).
struct CustomProduct: Codable, Identifiable, Hashable {
    var id: Int
    var name: String
    var protein: Double
    var phe: Double
    var kcal: Double
    var pheSource: PheSource
    var isDish: Bool
    var cookedWeight: Double
    var ingredients: [RecipeIngredient]
    var createdAt: TimeInterval
}

/// Всё состояние приложения; хранится одним JSON-файлом (аналог Room + DataStore в Android-версии).
struct AppData: Codable {
    var profile = PatientProfile()
    var nutrition = NutritionSettings()
    var theme = ThemeSettings()
    var days: [String: DayData] = [:]
    var custom: [CustomProduct] = []
    var draft = RecipeDraft()
    var nextId = 1
}

/// Встроенный справочник (значения на 100 г), перенесён из Android-версии без изменений.
/// Значения ориентировочные — сверяйте с упаковкой и рекомендациями врача.
enum BuiltInProducts {
    private struct Record: Decodable {
        let id: String
        let name: String
        let category: String
        let protein: Double
        let phe: Double
        let kcal: Double
    }

    static func load(bundle: Bundle = .main) -> [Product] {
        guard let url = bundle.url(forResource: "Products", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([Record].self, from: data) else { return [] }
        return records.map { r in
            Product(
                key: r.id,
                name: r.name,
                category: ProductCategory(rawValue: r.category) ?? .lowprot,
                protein: r.protein,
                phe: r.phe,
                kcal: r.kcal
            )
        }
    }
}
