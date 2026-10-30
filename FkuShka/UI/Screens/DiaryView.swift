import SwiftUI

private enum DiarySheet: Identifiable {
    case weight(DiaryItem)
    case aks
    var id: String {
        switch self {
        case .weight(let item): return "w-\(item.id.uuidString)"
        case .aks: return "aks"
        }
    }
}

struct DiaryView: View {
    @EnvironmentObject var store: FkuStore
    let onAddToMeal: (Meal) -> Void
    let onUpdateProfile: () -> Void

    @State private var sheet: DiarySheet? = nil
    @State private var showClear = false

    var body: some View {
        let date = store.selectedDate
        let items = store.items(on: date)
        let totals = NutritionCalculator.total(items)
        let aks = store.aks(on: date)
        let settings = store.nutrition
        let profile = store.profile
        let due = ReminderLogic.isDue(profile, now: Date().timeIntervalSince1970)
        let report = ReportBuilder.build(date: date, items: items, aksTaken: aks, settings: settings, patientName: profile.fullName)

        ScrollView {
            VStack(spacing: 12) {
                if due {
                    ReminderBanner(profile: profile, onUpdate: onUpdateProfile) { store.disableReminders() }
                }
                DaySelector()
                PheCard(totals: totals, settings: settings)
                MetricsCard(totals: totals, settings: settings, profile: profile, aks: aks,
                            onAdjust: { store.setAks(date: date, value: aks + $0) },
                            onEdit: { sheet = .aks },
                            onClose: { store.setAks(date: date, value: Double(settings.aksLimit)) },
                            onReset: { store.setAks(date: date, value: 0) })
                FlowLayout(spacing: 8) {
                    Button {
                        UIPasteboard.general.string = report
                        store.toast("Отчёт скопирован")
                    } label: { Text("Копировать") }
                        .buttonStyle(.bordered)
                    ShareLink(item: report) { Label("Поделиться", systemImage: "square.and.arrow.up") }
                        .buttonStyle(.bordered)
                    Button(role: .destructive) { showClear = true } label: { Image(systemName: "trash") }
                        .buttonStyle(.bordered)
                        .tint(Palette.error)
                        .accessibilityLabel("Очистить день")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(Meal.allCases) { meal in
                    MealCard(meal: meal, items: items.filter { $0.meal == meal },
                             onAdd: { onAddToMeal(meal) },
                             onEdit: { sheet = .weight($0) },
                             onRemove: { store.removeItem(date: date, id: $0.id) })
                }
            }
            .padding(16)
            .frame(maxWidth: 720)
        }
        .frame(maxWidth: .infinity)
        .sheet(item: $sheet) { s in
            switch s {
            case .weight(let item):
                NumberInputSheet(title: item.name, initial: item.weight, suffix: "г") {
                    store.updateWeight(date: date, id: item.id, weight: $0)
                }
            case .aks:
                NumberInputSheet(title: "АКС за день (г белка-эквивалента)", initial: aks, suffix: "г",
                                 max: Limits.maxAks, allowZero: true) {
                    store.setAks(date: date, value: $0)
                }
            }
        }
        .alert("Очистить дневник за день?", isPresented: $showClear) {
            Button("Да, очистить", role: .destructive) { store.clearDay(date: date) }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Все записи этого дня и счётчик АКС будут обнулены.")
        }
    }
}

private struct DaySelector: View {
    @EnvironmentObject var store: FkuStore

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru")
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    private func shift(_ days: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: days, to: store.selectedDate) {
            store.selectedDate = d
        }
    }

    var body: some View {
        let isToday = Calendar.current.isDateInToday(store.selectedDate)
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .accessibilityLabel("Предыдущий день")
            VStack(spacing: 2) {
                Text(isToday ? "Сегодня" : Self.formatter.string(from: store.selectedDate)).font(.headline)
                if isToday {
                    Text(Self.formatter.string(from: store.selectedDate)).font(.caption).foregroundColor(Palette.onSurfaceVariant)
                } else {
                    Button("Вернуться к сегодня") { store.selectedDate = Date() }.font(.caption)
                }
            }
            .frame(maxWidth: .infinity)
            Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .accessibilityLabel("Следующий день")
        }
    }
}

private struct ReminderBanner: View {
    let profile: PatientProfile
    let onUpdate: () -> Void
    let onDisable: () -> Void

    var body: some View {
        let days = ReminderLogic.daysSince(profile.lastUpdated, now: Date().timeIntervalSince1970)
        VStack(alignment: .leading, spacing: 8) {
            Text("Пора обновить данные пациента").font(.subheadline.weight(.bold))
            Text("Нормы пересчитывались \(days) дн. назад (напоминаем раз в \(profile.reminderIntervalDays) дн.). Если изменились вес или рост — обновите данные, и нормы пересчитаются. Отключить напоминания можно кнопкой ниже или в разделе «Профиль».")
                .font(.caption)
            FlowLayout(spacing: 8) {
                Button("Обновить данные", action: onUpdate).buttonStyle(.borderedProminent).tint(Palette.info.main)
                Button("Выключить напоминания", action: onDisable).buttonStyle(.bordered)
            }
        }
        .foregroundColor(Palette.info.onContainer)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.info.container, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct PheCard: View {
    let totals: Nutrients
    let settings: NutritionSettings

    var body: some View {
        let limit = Double(settings.pheLimit)
        let percent = NutritionCalculator.percent(totals.phe, limit)
        let status = NutritionCalculator.status(percent)
        let tone = Palette.tone(for: status)
        let diff = limit - totals.phe
        let remain: String = {
            if diff < 0 { return "Превышение на \(Fmt.int(abs(diff).rounded(.up))) мг!" }
            if status == .near { return "Осталось всего: \(Fmt.int(diff)) мг" }
            return "Осталось: \(Fmt.int(diff)) мг"
        }()
        AppCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle().fill(tone.main).frame(width: 8, height: 8)
                        Text("ФЕНИЛАЛАНИН (ФА)").font(.caption.weight(.medium)).foregroundColor(Palette.onSurfaceVariant).lineLimit(1)
                    }
                    (Text(Fmt.int(totals.phe)).font(.system(size: 34, weight: .heavy))
                        + Text("  / \(settings.pheLimit) мг").font(.system(size: 14)).foregroundColor(Palette.onSurfaceVariant))
                    Pill(text: remain, tone: tone)
                }
                Spacer(minLength: 8)
                RingProgress(progress: percent / 100.0, color: tone.main, size: 96) {
                    VStack(spacing: 0) {
                        Text("\(Fmt.int(percent))%").font(.headline.weight(.bold))
                        Text("сутки").font(.caption2).foregroundColor(Palette.onSurfaceVariant)
                    }
                }
            }
            .padding(18)
        }
    }
}

private struct MetricsCard: View {
    let totals: Nutrients
    let settings: NutritionSettings
    let profile: PatientProfile
    let aks: Double
    let onAdjust: (Double) -> Void
    let onEdit: () -> Void
    let onClose: () -> Void
    let onReset: () -> Void

    private func metricRow(_ title: String, value: String, limit: String, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            (Text(title).font(.subheadline.weight(.semibold))
                + Text("   ") + Text(value).font(.subheadline.weight(.bold))
                + Text(" \(limit)").font(.subheadline).foregroundColor(Palette.onSurfaceVariant))
            ProgressBar(progress: progress / 100.0, color: color)
        }
    }

    var body: some View {
        let protPct = NutritionCalculator.percent(totals.protein, settings.protLimit)
        let kcalPct = NutritionCalculator.percent(totals.kcal, Double(settings.kcalLimit))
        let protColor: Color = protPct > 100 ? Palette.danger.main : Palette.primary
        let kcalColor: Color = kcalPct > 100 ? Palette.danger.main : Palette.energy.main
        let powder = NormsCalculator.powderGrams(aksProtein: Double(settings.aksLimit), mixProteinPer100g: profile.mixProteinPer100g)
        let scoops = powder / profile.scoopGrams
        let reached = settings.aksLimit > 0 && aks >= Double(settings.aksLimit)
        let aksHelp = "АКС — это лечебная аминокислотная смесь без фенилаланина (например, «Нутриген 70»).\n\nТак как при ФКУ обычную белковую еду сильно ограничивают, организм должен получать безопасный белок из смеси.\n\nВаша суточная норма:\n• в пересчёте на чистый белок: \(settings.aksLimit) г/сут;\n• в сухом порошке (белка в 100 г смеси — \(profile.mixProteinPer100g) г): ≈ \(Fmt.int(powder)) г порошка, то есть ≈ \(Fmt.int(scoops)) мерных ложек в день.\n\nВыпили всю дневную норму — нажмите «Закрыть всю норму». Нажали случайно — «Сбросить»."

        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                metricRow("Натуральный белок", value: Fmt.d1(totals.protein), limit: "/ \(Fmt.d1(settings.protLimit)) г",
                          progress: protPct, color: protColor)
                metricRow("Энергетическая ценность", value: Fmt.int(totals.kcal), limit: "/ \(settings.kcalLimit) ккал",
                          progress: kcalPct, color: kcalColor)
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(text: "Аминокислотная смесь (АКС)", helpTitle: "Что такое АКС и как её пить?", helpText: aksHelp)
                    Text("Норма: \(settings.aksLimit) г белка ≈ \(Fmt.int(powder)) г порошка (≈ \(Fmt.int(scoops)) м. л.)")
                        .font(.caption).foregroundColor(Palette.onSurfaceVariant)
                    HStack {
                        Button("−5") { onAdjust(-5) }.buttonStyle(.bordered)
                        Button(action: onEdit) {
                            Text("\(Fmt.num(aks)) / \(settings.aksLimit) г")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(reached ? Palette.ok.main : Palette.info.main)
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.plain)
                        Button("+5") { onAdjust(5) }.buttonStyle(.bordered)
                    }
                    FlowLayout(spacing: 8) {
                        Button { onClose() } label: { Label("Закрыть всю норму", systemImage: "checkmark") }
                            .buttonStyle(.bordered).disabled(reached)
                        Button("Сбросить") { onReset() }.disabled(aks <= 0)
                    }
                }
            }
            .padding(20)
        }
    }
}

private struct MealCard: View {
    let meal: Meal
    let items: [DiaryItem]
    let onAdd: () -> Void
    let onEdit: (DiaryItem) -> Void
    let onRemove: (DiaryItem) -> Void

    var body: some View {
        let total = NutritionCalculator.total(items)
        AppCard {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(meal.title).font(.headline.weight(.bold))
                        Spacer()
                        Button(action: onAdd) { Label("Добавить", systemImage: "plus") }.buttonStyle(.bordered)
                    }
                    Text("\(Fmt.int(total.phe)) мг ФА • \(Fmt.d1(total.protein)) г белка • \(Fmt.int(total.kcal)) ккал")
                        .font(.caption).foregroundColor(Palette.onSurfaceVariant)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surfaceVariant.opacity(0.45))

                if items.isEmpty {
                    Text("Пока нет добавленных продуктов")
                        .font(.caption).foregroundColor(Palette.onSurfaceVariant)
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                } else {
                    ForEach(items) { item in
                        Divider()
                        DiaryRow(item: item, onEdit: { onEdit(item) }, onRemove: { onRemove(item) })
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct DiaryRow: View {
    let item: DiaryItem
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        let n = item.nutrients
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                FlowLayout(spacing: 8) {
                    Pill(text: "\(Fmt.int(n.phe)) мг ФА", tone: Palette.ok)
                    Text("\(Fmt.d1(n.protein)) г • \(Fmt.int(n.kcal)) ккал").font(.caption).foregroundColor(Palette.onSurfaceVariant)
                }
            }
            Spacer(minLength: 0)
            Button(action: onEdit) {
                Text("\(Fmt.num(item.weight)) г").font(.subheadline.weight(.bold)).foregroundColor(.primary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Palette.surfaceVariant, in: RoundedRectangle(cornerRadius: 8))
            }.buttonStyle(.plain)
            Button(action: onRemove) {
                Image(systemName: "xmark").foregroundColor(Palette.onSurfaceVariant).frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Удалить")
        }
        .padding(.leading, 16).padding(.trailing, 4).padding(.vertical, 8)
    }
}
