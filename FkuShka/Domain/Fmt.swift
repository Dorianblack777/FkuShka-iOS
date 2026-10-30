import Foundation

/// Форматирование чисел и безопасный разбор ввода.
enum Fmt {
    private static let displayMax = 999_999.0

    private static func display(_ v: Double) -> Double {
        v.isFinite ? min(max(v, -displayMax), displayMax) : 0
    }

    static func int(_ v: Double) -> String { String(Int(display(v).rounded())) }

    static func d1(_ v: Double) -> String {
        String(format: "%.1f", locale: Locale.current, display(v))
    }

    /// Для показа: целые без «.0».
    static func num(_ v: Double) -> String {
        let d = display(v)
        return d.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(d)) : d1(d)
    }

    /// Для текстовых полей: всегда с точкой, без локали.
    static func input(_ v: Double) -> String {
        let d = display(v)
        if d.truncatingRemainder(dividingBy: 1) == 0 { return String(Int(d)) }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), d)
    }

    /// Только цифры и один разделитель (запятая → точка), ≤2 знаков после точки;
    /// число цифр до точки зависит от `max` (для 5000 — 4, для 300 — 3). «,5» → «0.5».
    static func filterDecimalInput(_ raw: String, max: Double = Limits.maxWeightG) -> String {
        let maxIntDigits = Swift.max(1, String(Int(max)).count)
        var out = ""
        var hasDot = false
        var decimals = 0
        for ch in raw {
            if ch >= "0" && ch <= "9" {
                if hasDot {
                    if decimals < 2 { out.append(ch); decimals += 1 }
                } else if out.count < maxIntDigits {
                    out.append(ch)
                }
            } else if (ch == "." || ch == ",") && !hasDot {
                if out.isEmpty { out.append("0") }
                out.append(".")
                hasDot = true
            }
        }
        return out
    }

    static func filterIntInput(_ raw: String, max: Double) -> String {
        let digits = Swift.max(1, String(Int(max)).count)
        return String(raw.filter { $0 >= "0" && $0 <= "9" }.prefix(digits))
    }

    /// Разбор с отсечкой по верхнему пределу; nil — если это не число.
    static func parseClamped(_ text: String, max: Double = Limits.maxWeightG) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let v = Double(t), v.isFinite, v >= 0 else { return nil }
        return min(v, max)
    }
}

extension String {
    /// Принимает и «1,5», и «1.5» (на русской клавиатуре чаще запятая).
    var decimalValue: Double? {
        let t = trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let v = Double(t), v.isFinite, v >= 0 else { return nil }
        return v
    }
}
