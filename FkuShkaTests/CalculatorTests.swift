import XCTest
@testable import FkuShka

final class CalculatorTests: XCTestCase {

    private func ing(_ name: String, _ w: Double, _ phe: Double, _ prot: Double, _ kcal: Double) -> RecipeIngredient {
        RecipeIngredient(name: name, weight: w, per100: Per100(phe: phe, protein: prot, kcal: kcal))
    }

    private var ratatouille: [RecipeIngredient] {
        [ing("Баклажаны", 250, 43, 1.2, 24), ing("Кабачки", 200, 22, 0.6, 24), ing("Черри", 150, 24, 0.8, 18),
         ing("Перец", 100, 38, 1.3, 27), ing("Масло", 20, 0, 0, 899)]
    }

    func testRecipeUsesCookedWeight() {
        // ФА всего: 107.5 + 44 + 36 + 38 = 225.5 мг; готовый вес 580 г
        let r = NutritionCalculator.recipe(ratatouille, cookedOverride: 580)
        XCTAssertEqual(r.rawWeight, 720, accuracy: 1e-9)
        XCTAssertEqual(r.cookedWeight, 580, accuracy: 1e-9)
        XCTAssertEqual(r.per100.phe, 225.5 / 580.0 * 100.0, accuracy: 1e-9)
        XCTAssertEqual(r.yieldRatio, 580.0 / 720.0, accuracy: 1e-9)
    }

    func testRecipeWithoutCookedWeightFallsBackToRaw() {
        let r = NutritionCalculator.recipe(ratatouille, cookedOverride: nil)
        XCTAssertEqual(r.cookedWeight, 720, accuracy: 1e-9)
        XCTAssertEqual(r.per100.phe, 225.5 / 720.0 * 100.0, accuracy: 1e-9)
        XCTAssertEqual(r.yieldRatio, 1, accuracy: 1e-9)
    }

    func testRecipeCookedWeightIsCapped() {
        XCTAssertEqual(NutritionCalculator.recipe(ratatouille, cookedOverride: 1e9).cookedWeight, Limits.maxDishG)
    }

    func testRecipeEmptyIsZero() {
        XCTAssertEqual(NutritionCalculator.recipe([], cookedOverride: 500).rawWeight, 0)
    }

    func testDayTotals() {
        let items = [
            DiaryItem(meal: .lunch, name: "A", weight: 150, per100: Per100(phe: 40, protein: 1, kcal: 100)),
            DiaryItem(meal: .snack, name: "B", weight: 50, per100: Per100(phe: 20, protein: 0.5, kcal: 300)),
        ]
        let t = NutritionCalculator.total(items)
        XCTAssertEqual(t.phe, 70, accuracy: 1e-9)
        XCTAssertEqual(t.protein, 1.75, accuracy: 1e-9)
        XCTAssertEqual(t.kcal, 300, accuracy: 1e-9)
    }

    func testStatusThresholds() {
        XCTAssertEqual(NutritionCalculator.status(84.9), .ok)
        XCTAssertEqual(NutritionCalculator.status(85), .near)
        XCTAssertEqual(NutritionCalculator.status(100), .near)
        XCTAssertEqual(NutritionCalculator.status(100.1), .exceeded)
        XCTAssertEqual(NutritionCalculator.percent(50, 0), 0)
    }

    // MARK: предохранители

    func testFilterInputLimitsDigitsAndDecimals() {
        XCTAssertEqual(Fmt.filterDecimalInput("123456789", max: Limits.maxWeightG), "1234")
        XCTAssertEqual(Fmt.filterDecimalInput("1,5"), "1.5")
        XCTAssertEqual(Fmt.filterDecimalInput(",5"), "0.5")
        XCTAssertEqual(Fmt.filterDecimalInput("1.2345"), "1.23")
        XCTAssertEqual(Fmt.filterDecimalInput("1a2.5.7"), "12.57")
        XCTAssertEqual(Fmt.filterDecimalInput("abc"), "")
        XCTAssertEqual(Fmt.filterDecimalInput("3000", max: Limits.maxAks), "300")
        XCTAssertEqual(Fmt.filterIntInput("12.5a", max: 120), "125")
    }

    func testParseClamped() {
        XCTAssertEqual(Fmt.parseClamped("999999"), 5000)
        XCTAssertNil(Fmt.parseClamped("abc"))
        XCTAssertEqual(Fmt.parseClamped("12,5") ?? -1, 12.5, accuracy: 1e-9)
        XCTAssertEqual("1,5".decimalValue ?? -1, 1.5, accuracy: 1e-9)
    }

    func testSettingsSanitized() {
        var s = NutritionSettings()
        s.pheLimit = 99_999_999; s.protLimit = 0; s.coeff = 1; s.kcalLimit = 1; s.aksLimit = -5
        let r = s.sanitized()
        XCTAssertEqual(r.pheLimit, 10_000)
        XCTAssertEqual(r.protLimit, 1.0)
        XCTAssertEqual(r.coeff, 20)
        XCTAssertEqual(r.kcalLimit, 300)
        XCTAssertEqual(r.aksLimit, 0)
    }

    func testPer100ClampedHandlesNanAndHuge() {
        let p = Per100(phe: .nan, protein: 1e12, kcal: -5).clamped()
        XCTAssertEqual(p.phe, 0)
        XCTAssertEqual(p.protein, 100)
        XCTAssertEqual(p.kcal, 0)
        XCTAssertEqual(Limits.clampWeight(1e12), 5000)
        XCTAssertEqual(Limits.clampWeight(.nan), 0.1)
    }

    func testDisplayNeverOverflows() {
        XCTAssertEqual(Fmt.int(1e30), "999999")
        XCTAssertEqual(Fmt.int(.nan), "0")
    }
}

final class ProfileAndDuplicatesTests: XCTestCase {

    private var adult: PatientProfile {
        var p = PatientProfile()
        p.setupCompleted = true; p.isMale = true; p.ageYears = 32; p.heightCm = 175; p.weightKg = 80
        return p
    }

    func testNormsAdultFollowDocumentedFormulas() throws {
        let n = try XCTUnwrap(NormsCalculator.calculate(adult))
        XCTAssertEqual(n.idealWeightKg, 75, accuracy: 1e-9)
        XCTAssertEqual(n.totalProteinG, 75, accuracy: 1e-9)
        XCTAssertEqual(n.maxPheMg, 750, accuracy: 1e-9)
        XCTAssertEqual(n.naturalProteinG, 15, accuracy: 1e-9)
        XCTAssertEqual(n.aksProteinG, 60, accuracy: 1e-9)
        XCTAssertEqual(n.dryPowderG, 60.0 / 70.0 * 100.0, accuracy: 1e-9)
        XCTAssertEqual(n.scoops, n.dryPowderG / 5.6, accuracy: 1e-9)
        // BMR = 10·80 + 6.25·175 − 5·32 + 5 = 1738.75; × 1.35
        XCTAssertEqual(n.kcal, 1738.75 * 1.35, accuracy: 1e-6)
    }

    func testNormsFemaleUsesMinusConstant() throws {
        var p = adult; p.isMale = false
        let n = try XCTUnwrap(NormsCalculator.calculate(p))
        XCTAssertEqual(n.kcal, (1738.75 - 166.0) * 1.35, accuracy: 1e-6)
    }

    func testMinorsAreNotAutoCalculated() {
        var p = adult; p.ageYears = 17
        XCTAssertNil(NormsCalculator.calculate(p))
        XCTAssertFalse(p.canAutoCalculate)
        p.ageYears = 18
        XCTAssertNotNil(NormsCalculator.calculate(p))
    }

    func testNormsConvertToSettings() throws {
        let s = try XCTUnwrap(NormsCalculator.calculate(adult)).toSettings(previous: NutritionSettings())
        XCTAssertEqual(s.pheLimit, 750)
        XCTAssertEqual(s.protLimit, 15.0, accuracy: 1e-9)
        XCTAssertEqual(s.aksLimit, 60)
        XCTAssertEqual(s.kcalLimit, 2347)
    }

    func testProfileSanitized() {
        var p = adult
        p.ageYears = 999; p.heightCm = 1e9; p.weightKg = -4; p.pheTolPerKg = 500; p.mixProteinPer100g = 0; p.scoopGrams = 0
        let r = p.sanitized()
        XCTAssertEqual(r.ageYears, 120)
        XCTAssertEqual(r.heightCm, 240)
        XCTAssertEqual(r.weightKg, 3)
        XCTAssertEqual(r.pheTolPerKg, 35)
        XCTAssertEqual(r.mixProteinPer100g, 10)
        XCTAssertEqual(r.scoopGrams, 1)
    }

    func testPowderFromAksProtein() {
        XCTAssertEqual(NormsCalculator.powderGrams(aksProtein: 58.8, mixProteinPer100g: 70), 84.0, accuracy: 1e-9)
    }

    // MARK: напоминание

    func testReminderDueOnlyAfterInterval() {
        let day = ReminderLogic.daySeconds
        var p = adult; p.lastUpdated = 1000 * day; p.reminderEnabled = true; p.reminderIntervalDays = 30
        XCTAssertFalse(ReminderLogic.isDue(p, now: 1029 * day))
        XCTAssertTrue(ReminderLogic.isDue(p, now: 1030 * day))
        XCTAssertEqual(ReminderLogic.daysSince(p.lastUpdated, now: 1031 * day), 31)
    }

    func testReminderRespectsSwitchesAndMissingData() {
        let day = ReminderLogic.daySeconds
        var p = adult; p.lastUpdated = 1000 * day; p.reminderIntervalDays = 14
        var off = p; off.reminderEnabled = false
        var notDone = p; notDone.setupCompleted = false
        var never = p; never.lastUpdated = 0
        XCTAssertFalse(ReminderLogic.isDue(off, now: 5000 * day))
        XCTAssertFalse(ReminderLogic.isDue(notDone, now: 5000 * day))
        XCTAssertFalse(ReminderLogic.isDue(never, now: 5000 * day))
        XCTAssertEqual(ReminderLogic.daysSince(1000 * day, now: 500 * day), 0)
    }

    // MARK: дубликаты

    private func prod(_ key: String, _ name: String, custom: Bool = false, dish: Bool = false) -> Product {
        Product(key: key, name: name, category: dish ? .dish : (custom ? .custom : .veg),
                protein: 1, phe: 50, kcal: 20, customId: (custom || dish) ? 1 : nil)
    }

    private var foods: [Product] {
        [prod("v1", "Картофель отварной"), prod("c1", "Картофельное пюре домашнее", custom: true),
         prod("c2", "Суп картофельный", dish: true), prod("v2", "Морковь"), prod("v3", "Ёжик из риса")]
    }

    func testDuplicatesNeedMinimumThreeChars() {
        XCTAssertTrue(DuplicateFinder.find("ка", in: foods).isEmpty)
        XCTAssertTrue(DuplicateFinder.find("  ", in: foods).isEmpty)
    }

    func testDuplicatesFindByPrefixThenContains_withSourceBadges() {
        let found = DuplicateFinder.find("картоф", in: foods)
        XCTAssertEqual(found.map { $0.key }, ["v1", "c1", "c2"])
        XCTAssertEqual(found.map { $0.sourceBadge }, ["База продуктов", "Мои продукты", "Мои блюда"])
    }

    func testDuplicatesExcludeSelfAndTreatYoAsYe() {
        XCTAssertEqual(DuplicateFinder.find("картоф", in: foods, excludeKey: "v1").map { $0.key }, ["c1", "c2"])
        XCTAssertEqual(DuplicateFinder.find("ежик", in: foods).map { $0.key }, ["v3"])
    }

    func testDuplicatesMultiWordQueryMatchesAnyOrder() {
        XCTAssertEqual(DuplicateFinder.find("картофельный суп", in: foods).map { $0.key }, ["c2"])
    }

    func testPheSourceFactors() {
        XCTAssertEqual(PheSource.regular.factor, 50)
        XCTAssertEqual(PheSource.vegetable.factor, 40)
        XCTAssertEqual(PheSource.fruit.factor, 30)
    }
}

@MainActor
final class StoreTests: XCTestCase {

    private func makeStore() -> FkuStore { FkuStore(fileURL: nil, builtIn: [], useDefaultFile: false) }

    func testDiaryItemIsClampedAndGroupedByDate() {
        let s = makeStore()
        let day = Date()
        s.addDiaryItem(date: day, meal: .lunch, name: "X", weight: 1e9, per100: Per100(phe: .nan, protein: 1e9, kcal: 50))
        let item = s.items(on: day)[0]
        XCTAssertEqual(item.weight, 5000)
        XCTAssertEqual(item.per100.phe, 0)
        XCTAssertEqual(item.per100.protein, 100)
        XCTAssertTrue(s.items(on: Calendar.current.date(byAdding: .day, value: 1, to: day)!).isEmpty)
    }

    func testAksIsClampedAndClearDayRemovesEverything() {
        let s = makeStore()
        let day = Date()
        s.setAks(date: day, value: 9999)
        XCTAssertEqual(s.aks(on: day), 300)
        s.clearDay(date: day)
        XCTAssertEqual(s.aks(on: day), 0)
    }

    func testSaveDishAddsToDishesAndCanBeEdited() {
        let s = makeStore()
        s.loadSample()
        XCTAssertTrue(s.saveDish())
        XCTAssertEqual(s.dishes.count, 1)
        let dish = s.dishes[0]
        XCTAssertEqual(dish.ingredients.count, 5)
        XCTAssertEqual(dish.cookedWeight, 580, accuracy: 1e-9)
        XCTAssertEqual(dish.phe, 225.5 / 580.0 * 100.0, accuracy: 1e-6)
        XCTAssertTrue(s.draft.ingredients.isEmpty) // черновик очищен после сохранения

        s.startEditing(dish)
        XCTAssertEqual(s.draft.editingDishId, dish.customId)
        XCTAssertEqual(s.draft.ingredients.count, 5)
        s.setDraftCooked("")
        XCTAssertTrue(s.saveDish())
        XCTAssertEqual(s.dishes.count, 1) // обновлено, а не продублировано
    }

    func testSaveDishWithoutIngredientsFails() {
        XCTAssertFalse(makeStore().saveDish())
    }

    func testProfileSaveMarksSetupAndSanitizesNorms() {
        let s = makeStore()
        XCTAssertFalse(s.profile.setupCompleted)
        var p = PatientProfile(); p.ageYears = 40
        var n = NutritionSettings(); n.pheLimit = 99_999_999
        s.saveProfile(p, norms: n)
        XCTAssertTrue(s.profile.setupCompleted)
        XCTAssertGreaterThan(s.profile.lastUpdated, 0)
        XCTAssertEqual(s.nutrition.pheLimit, 10_000)
    }

    func testCustomProductCrud() {
        let s = makeStore()
        s.saveProduct(existingId: nil, name: "Хлеб", per100: Per100(phe: 400, protein: 8, kcal: 250), source: .regular)
        XCTAssertEqual(s.foods.count, 1)
        let id = s.foods[0].customId!
        s.saveProduct(existingId: id, name: "Хлеб серый", per100: Per100(phe: 410, protein: 8.2, kcal: 250), source: .regular)
        XCTAssertEqual(s.foods[0].name, "Хлеб серый")
        s.deleteCustom(s.foods[0])
        XCTAssertTrue(s.foods.isEmpty)
    }
}
