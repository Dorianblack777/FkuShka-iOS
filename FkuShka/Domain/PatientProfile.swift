import Foundation

/// Данные пациента и параметры расчёта норм. Сами нормы хранятся в `NutritionSettings`.
struct PatientProfile: Codable, Hashable {
    var setupCompleted = false
    var fullName = ""
    var isMale = true
    var ageYears = 30
    var heightCm = 170.0
    var weightKg = 70.0
    /// мг ФА на 1 кг «долженствующего» веса (индивидуально, назначает врач).
    var pheTolPerKg = 10.0
    /// Грамм белка в 100 г сухой смеси АКС (например, 70 для «Нутриген 70»).
    var mixProteinPer100g = 70
    /// Грамм сухого порошка в одной мерной ложке (см. банку).
    var scoopGrams = 5.6
    var useManualNorms = false
    var reminderEnabled = true
    var reminderIntervalDays = 30
    /// Секунды с 1970; 0 — нормы ещё не сохранялись.
    var lastUpdated: TimeInterval = 0

    /// Авторасчёт — только для взрослых: у детей нормы ФА и белка назначает врач.
    var canAutoCalculate: Bool { ageYears >= 18 }

    func sanitized() -> PatientProfile {
        var p = self
        p.fullName = String(fullName.prefix(60))
        p.ageYears = min(max(ageYears, 1), 120)
        p.heightCm = Limits.clamp(heightCm, 45, 240)
        p.weightKg = Limits.clamp(weightKg, 3, 250)
        p.pheTolPerKg = Limits.clamp(pheTolPerKg, 2, 35)
        p.mixProteinPer100g = min(max(mixProteinPer100g, 10), 100)
        p.scoopGrams = Limits.clamp(scoopGrams, 1, 30)
        p.reminderIntervalDays = min(max(reminderIntervalDays, 7), 365)
        return p
    }
}

struct ComputedNorms {
    var idealWeightKg: Double
    var totalProteinG: Double
    var maxPheMg: Double
    var naturalProteinG: Double
    var aksProteinG: Double
    var dryPowderG: Double
    var scoops: Double
    var kcal: Double

    func toSettings(previous: NutritionSettings) -> NutritionSettings {
        var s = previous
        s.pheLimit = Int(maxPheMg.rounded())
        s.protLimit = (naturalProteinG * 10).rounded() / 10
        s.aksLimit = Int(aksProteinG.rounded())
        s.kcalLimit = Int(kcal.rounded())
        return s.sanitized()
    }
}

/// Ориентировочный расчёт суточных норм для ВЗРОСЛЫХ (те же формулы, что в Android-версии;
/// справку врача проверьте вручную — нормы всегда назначает врач):
///  • долженствующий вес = рост − 100 (35…130 кг);
///  • общий белок = 1 г на кг долженствующего веса;
///  • лимит ФА = долженствующий вес × мг ФА на кг;
///  • натуральный белок = лимит ФА / 50;
///  • АКС (белок) = общий белок − натуральный белок;
///  • сухая смесь = АКС / (белок в 100 г смеси) × 100; мерные ложки = граммы / вес ложки;
///  • калории = обмен по Миффлину–Сан Жеору × 1,35.
enum NormsCalculator {
    static let phePerGramProtein = 50.0
    static let activityFactor = 1.35

    static func calculate(_ profile: PatientProfile) -> ComputedNorms? {
        let p = profile.sanitized()
        guard p.canAutoCalculate else { return nil }
        let ideal = min(max(p.heightCm - 100.0, 35.0), 130.0)
        let totalProtein = ideal
        let maxPhe = Limits.clamp(ideal * p.pheTolPerKg, Limits.minPheLimit, Limits.maxPheLimit)
        let natural = Limits.clamp(maxPhe / phePerGramProtein, Limits.minProtLimit, Limits.maxProtLimit)
        let aks = max(totalProtein - natural, 0)
        let powder = powderGrams(aksProtein: aks, mixProteinPer100g: p.mixProteinPer100g)
        let sexConstant = p.isMale ? 5.0 : -161.0
        let bmr = 10.0 * p.weightKg + 6.25 * p.heightCm - 5.0 * Double(p.ageYears) + sexConstant
        return ComputedNorms(
            idealWeightKg: ideal,
            totalProteinG: totalProtein,
            maxPheMg: maxPhe,
            naturalProteinG: natural,
            aksProteinG: aks,
            dryPowderG: powder,
            scoops: powder / p.scoopGrams,
            kcal: Limits.clamp(bmr * activityFactor, 1000, 4500)
        )
    }

    /// Граммы сухого порошка, содержащие `aksProtein` белка.
    static func powderGrams(aksProtein: Double, mixProteinPer100g: Int) -> Double {
        aksProtein / Double(max(mixProteinPer100g, 10)) * 100.0
    }
}

enum ReminderLogic {
    static let daySeconds: TimeInterval = 86_400
    static let intervalsDays = [14, 30, 90, 180]

    static func daysSince(_ last: TimeInterval, now: TimeInterval) -> Int {
        Int(max(now - last, 0) / daySeconds)
    }

    static func isDue(_ p: PatientProfile, now: TimeInterval) -> Bool {
        p.setupCompleted && p.reminderEnabled && p.lastUpdated > 0
            && daysSince(p.lastUpdated, now: now) >= p.reminderIntervalDays
    }
}

/// Поиск похожих названий, чтобы не плодить дубликаты в базе.
enum DuplicateFinder {
    static let minQuery = 3

    private static func normalize(_ s: String) -> String {
        let lowered = s.lowercased().replacingOccurrences(of: "ё", with: "е")
        return lowered.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func find(_ query: String, in all: [Product], excludeKey: String? = nil, limit: Int = 5) -> [Product] {
        let q = normalize(query)
        guard q.count >= minQuery else { return [] }
        let tokens = q.split(separator: " ").map(String.init)
        var ranked: [(Product, Int)] = []
        for p in all {
            if p.key == excludeKey { continue }
            let n = normalize(p.name)
            var rank: Int? = nil
            if n == q { rank = 0 }
            else if n.hasPrefix(q) { rank = 1 }
            else if n.contains(q) { rank = 2 }
            else if tokens.count > 1 && tokens.allSatisfy({ n.contains($0) }) { rank = 3 }
            else if n.count >= 4 && q.contains(n) { rank = 3 }
            if let r = rank { ranked.append((p, r)) }
        }
        // sorted(by:) в Swift не гарантирует устойчивость — сортируем по (ранг, исходный порядок).
        let indexed = ranked.enumerated().sorted { a, b in
            if a.element.1 != b.element.1 { return a.element.1 < b.element.1 }
            return a.offset < b.offset
        }
        return indexed.prefix(limit).map { $0.element.0 }
    }
}

enum ReportBuilder {
    static func build(date: Date, items: [DiaryItem], aksTaken: Double, settings: NutritionSettings, patientName: String) -> String {
        let totals = NutritionCalculator.total(items)
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        var lines: [String] = []
        lines.append("📊 ОТЧЁТ РАЦИОНА ФКУ (\(f.string(from: date)))")
        lines.append("━━━━━━━━━━━━━━━━━━━━━━━━")
        if !patientName.trimmingCharacters(in: .whitespaces).isEmpty { lines.append("Пациент: \(patientName)") }
        let pct = NutritionCalculator.percent(totals.phe, Double(settings.pheLimit))
        lines.append("• Фенилаланин (ФА): \(Fmt.int(totals.phe)) из \(settings.pheLimit) мг (\(Fmt.int(pct))%)")
        lines.append("• Натуральный белок: \(Fmt.d1(totals.protein)) из \(Fmt.d1(settings.protLimit)) г")
        lines.append("• АКС (эквивалент белка): \(Fmt.num(aksTaken)) из \(settings.aksLimit) г")
        lines.append("• Калории: \(Fmt.int(totals.kcal)) из \(settings.kcalLimit) ккал")
        for meal in Meal.allCases {
            let mealItems = items.filter { $0.meal == meal }
            if mealItems.isEmpty { continue }
            let t = NutritionCalculator.total(mealItems)
            lines.append("")
            lines.append("🍽 \(meal.title.uppercased()) (\(Fmt.int(t.phe)) мг ФА | \(Fmt.d1(t.protein)) г | \(Fmt.int(t.kcal)) ккал):")
            for it in mealItems {
                let n = it.nutrients
                lines.append("  - \(it.name): \(Fmt.num(it.weight)) г (\(Fmt.int(n.phe)) мг ФА, \(Fmt.d1(n.protein)) г белка)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
