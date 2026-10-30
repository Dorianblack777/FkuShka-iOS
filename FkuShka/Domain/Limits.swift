import Foundation

/// Единое место для всех предельных значений: ввод, сохранение и расчёты используют одни и те же числа.
enum Limits {
    static let minWeightG = 0.1
    static let maxWeightG = 5000.0
    static let maxDishG = 20000.0

    static let maxPhe100g = 5000.0
    static let maxProtein100g = 100.0
    static let maxKcal100g = 1000.0

    static let minPheLimit = 50.0
    static let maxPheLimit = 10000.0
    static let minProtLimit = 1.0
    static let maxProtLimit = 200.0
    static let minCoeff = 20.0
    static let maxCoeff = 100.0
    static let minKcalLimit = 300.0
    static let maxKcalLimit = 10000.0
    static let maxAks = 300.0

    static let maxName = 80

    /// NaN/∞ превращаются в min, остальное зажимается в диапазон.
    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        v.isFinite ? min(max(v, lo), hi) : lo
    }

    static func clampWeight(_ w: Double) -> Double { clamp(w, minWeightG, maxWeightG) }
}
