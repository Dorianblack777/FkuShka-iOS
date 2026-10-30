import SwiftUI

struct AppCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.outline, lineWidth: 1))
    }
}

struct Pill: View {
    let text: String
    let tone: Tone
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(tone.onContainer)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tone.container, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ProgressBar: View {
    let progress: Double
    let color: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.surfaceVariant)
                Capsule().fill(color).frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)))
            }
        }
        .frame(height: 10)
        .animation(.easeOut(duration: 0.3), value: progress)
    }
}

struct RingProgress<Content: View>: View {
    let progress: Double
    let color: Color
    var size: CGFloat = 104
    let content: Content
    init(progress: Double, color: Color, size: CGFloat = 104, @ViewBuilder content: () -> Content) {
        self.progress = progress
        self.color = color
        self.size = size
        self.content = content()
    }

    var body: some View {
        ZStack {
            Circle().stroke(Palette.surfaceVariant, lineWidth: 10)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: progress)
            content
        }
        .frame(width: size, height: size)
    }
}

/// Кнопка-подсказка «?»: по нажатию объясняет термин простыми словами.
struct HelpButton: View {
    let title: String
    let text: String
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            Text("?")
                .font(.caption.weight(.bold))
                .foregroundColor(Palette.primary)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(Palette.primary, lineWidth: 1.5))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Подсказка: \(title)")
        .sheet(isPresented: $open) {
            NavigationStack {
                ScrollView {
                    Text(text).font(.body).padding().frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Понятно") { open = false } }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

/// Заголовок блока с необязательной кнопкой «?».
struct SectionTitle: View {
    let text: String
    var helpTitle: String? = nil
    var helpText: String? = nil
    var body: some View {
        HStack(spacing: 0) {
            Text(text).font(.subheadline.weight(.semibold))
            if let t = helpTitle, let h = helpText { HelpButton(title: t, text: h) }
            Spacer(minLength: 0)
        }
    }
}

/// Перенос элементов на следующую строку (аналог FlowRow): на узких экранах ничего не сжимается в колонку.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, width: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > maxW { y += rowH + spacing; x = 0; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + sz.width > bounds.maxX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}

/// Группа полей: колонки не уже 140 pt, при нехватке места переносятся на новую строку.
struct AdaptiveFields<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8, alignment: .top)], spacing: 8) { content }
    }
}

/// Числовое поле: принимает «1,5» и «1.5», отбрасывает всё лишнее и не пускает значения выше `max`.
struct DecimalField: View {
    let label: String
    @Binding var text: String
    var max: Double = Limits.maxWeightG
    var integerOnly = false
    var suffix: String? = nil
    var placeholder: String = ""

    private var filtered: Binding<String> {
        Binding(
            get: { text },
            set: { raw in
                let f = integerOnly ? Fmt.filterIntInput(raw, max: max) : Fmt.filterDecimalInput(raw, max: max)
                if let n = Double(f), n > max { return }
                text = f
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(Palette.onSurfaceVariant).lineLimit(1)
            HStack {
                TextField(placeholder, text: filtered)
                    .keyboardType(integerOnly ? .numberPad : .decimalPad)
                if let s = suffix { Text(s).foregroundColor(Palette.onSurfaceVariant) }
            }
            .padding(10)
            .background(Palette.surfaceVariant.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(selected ? .bold : .regular))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? Palette.primaryContainer : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Palette.primary : Palette.outline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct MealSelector: View {
    @Binding var selected: Meal
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Meal.allCases) { meal in
                    Chip(title: meal.title, selected: meal == selected) { selected = meal }
                }
            }
        }
    }
}

/// Карточки «Из чего сделан продукт?» вместо непонятных ×50 / ×40 / ×30.
struct PheTypeSelector: View {
    @Binding var selected: PheSource
    var body: some View {
        VStack(spacing: 8) {
            ForEach([PheSource.regular, .vegetable, .fruit]) { type in
                let isSelected = type == selected
                Button { selected = type } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(isSelected ? Palette.primary : Palette.onSurfaceVariant)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.title).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                            Text(type.hint).font(.caption).foregroundColor(Palette.onSurfaceVariant)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Palette.primary : Palette.outline, lineWidth: isSelected ? 2 : 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Небольшой лист для ввода одного числа (вес позиции, АКС за день).
struct NumberInputSheet: View {
    let title: String
    let suffix: String
    let max: Double
    let allowZero: Bool
    let onSave: (Double) -> Void
    @State private var text: String
    @Environment(\.dismiss) private var dismiss

    init(title: String, initial: Double, suffix: String, max: Double = Limits.maxWeightG,
         allowZero: Bool = false, onSave: @escaping (Double) -> Void) {
        self.title = title
        self.suffix = suffix
        self.max = max
        self.allowZero = allowZero
        self.onSave = onSave
        _text = State(initialValue: Fmt.input(initial))
    }

    private var value: Double? { text.decimalValue }
    private var valid: Bool {
        guard let v = value else { return false }
        return allowZero || v > 0
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                DecimalField(label: "Значение", text: $text, max: max, suffix: suffix)
                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        if let v = value { onSave(v) }
                        dismiss()
                    }.disabled(!valid)
                }
            }
            .keyboardDoneButton()
        }
        .presentationDetents([.height(230)])
    }
}
