import SwiftUI

let normsHelp = "Как врач считает диету и АКС (ориентировочно):\n\n1. Долженствующий вес = рост − 100 (например, при росте 175 см это 75 кг).\n2. Общий белок в сутки = 1 г на каждый кг долженствующего веса.\n3. Допустимый ФА в сутки = долженствующий вес × норма ФА на 1 кг (у взрослых обычно около 10 мг/кг; точное число назначает врач).\n4. Натуральный белок из обычной еды = лимит ФА ÷ 50.\n5. АКС (смесь без фенилаланина) восполняет остальной белок: общий белок − натуральный.\n6. Сухой порошок смеси = белок АКС ÷ (белок в 100 г смеси) × 100; мерные ложки — по весу ложки с банки.\n7. Калории — по формуле Миффлина–Сан Жеора с множителем 1,35.\n\nВсе цифры ориентировочные. Если у вас есть справка с готовыми цифрами — включите ручной ввод и перепишите их."

// MARK: - Вкладка «Профиль и Тема»

struct ProfileView: View {
    @EnvironmentObject var store: FkuStore
    let onEditProfile: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()

    private static func intervalTitle(_ days: Int) -> String {
        switch days {
        case 90: return "3 месяца"
        case 180: return "6 месяцев"
        default: return "\(days) дней"
        }
    }

    var body: some View {
        let p = store.profile
        let n = store.nutrition
        let powder = NormsCalculator.powderGrams(aksProtein: Double(n.aksLimit), mixProteinPer100g: p.mixProteinPer100g)
        let scoops = powder / p.scoopGrams
        let updated = p.lastUpdated > 0 ? Self.dateFormatter.string(from: Date(timeIntervalSince1970: p.lastUpdated)) : "—"

        ScrollView {
            VStack(spacing: 12) {
                // Карта пациента
                AppCard {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionTitle(text: "Карта пациента и суточные нормы", helpTitle: "Индивидуальные нормы",
                                     helpText: "Здесь хранятся параметры пациента (возраст, рост, вес) и суточные лимиты ФА, натурального белка, АКС и калорий.\n\nНормы назначает врач; калькулятор лишь помогает их рассчитать и пересчитать при изменении веса или роста.")
                        Text("Пациент: \(p.fullName.isEmpty ? "не указано" : p.fullName) (\(p.ageYears) лет, рост \(Fmt.num(p.heightCm)) см, вес \(Fmt.num(p.weightKg)) кг)")
                            .font(.subheadline)
                        if p.canAutoCalculate && !p.useManualNorms {
                            Text("Долженствующий вес: \(Int(min(max(p.heightCm - 100, 35), 130).rounded())) кг").font(.subheadline)
                        }
                        Text("Лимит ФА: \(n.pheLimit) мг/сут • Нат. белок: \(Fmt.d1(n.protLimit)) г/сут")
                            .font(.subheadline.weight(.bold)).foregroundColor(Palette.primary)
                        Text("Норма АКС: \(n.aksLimit) г белка (≈ \(Fmt.int(powder)) г порошка, ≈ \(Fmt.int(scoops)) м. л.)").font(.subheadline)
                        Text("Норма калорий: \(n.kcalLimit) ккал/сут").font(.subheadline)
                        Text("Нормы обновлены: \(updated)" + (p.useManualNorms ? " (введены вручную)" : ""))
                            .font(.caption).foregroundColor(Palette.onSurfaceVariant)
                        Button(action: onEditProfile) {
                            Text("Изменить данные и пересчитать нормы").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                    }
                    .padding(16)
                }

                // Напоминание
                AppCard {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(text: "Напоминание об обновлении норм", helpTitle: "Зачем нужны напоминания?",
                                     helpText: "Вес и рост меняются, поэтому нормы нужно пересматривать. Через выбранный срок вверху дневника появится напоминание с предложением обновить данные.\n\nОтключить его можно здесь или прямо в самом напоминании.")
                        Toggle(isOn: Binding(get: { p.reminderEnabled },
                                             set: { store.setReminder(enabled: $0, days: p.reminderIntervalDays) })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Напоминать").font(.body.weight(.semibold))
                                Text("Предложим обновить вес и рост").font(.caption).foregroundColor(Palette.onSurfaceVariant)
                            }
                        }
                        if p.reminderEnabled {
                            FlowLayout(spacing: 8) {
                                ForEach(ReminderLogic.intervalsDays, id: \.self) { days in
                                    Chip(title: Self.intervalTitle(days), selected: p.reminderIntervalDays == days) {
                                        store.setReminder(enabled: true, days: days)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }

                // Внешний вид
                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Внешний вид").font(.headline.weight(.bold))
                        FlowLayout(spacing: 8) {
                            ForEach(ThemeMode.allCases, id: \.self) { mode in
                                Chip(title: mode.title, selected: store.theme.mode == mode) { store.setThemeMode(mode) }
                            }
                        }
                        Toggle(isOn: Binding(get: { store.theme.amoled }, set: { store.setAmoled($0) })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AMOLED-чёрный").font(.body.weight(.semibold))
                                Text("Чисто чёрный фон в тёмной теме").font(.caption).foregroundColor(Palette.onSurfaceVariant)
                            }
                        }
                    }
                    .padding(16)
                }

                Text("Справочник продуктов ориентировочный. Значения ФА, белка и калорий сверяйте с упаковкой, а нормы устанавливайте по рекомендации лечащего врача / диетолога.")
                    .font(.caption).foregroundColor(Palette.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: 720)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Анкета пациента: первый запуск (нельзя закрыть) и «Изменить данные»

struct ProfileFormView: View {
    let first: Bool
    let profile: PatientProfile
    let nutrition: NutritionSettings
    let onSave: (PatientProfile, NutritionSettings) -> Void
    let onClose: (() -> Void)?

    @State private var fullName: String
    @State private var isMale: Bool
    @State private var ageText: String
    @State private var heightText: String
    @State private var weightText: String
    @State private var pheTolText: String
    @State private var mixText: String
    @State private var scoopText: String
    @State private var manual: Bool
    @State private var mPhe: String
    @State private var mNat: String
    @State private var mAks: String
    @State private var mKcal: String

    init(first: Bool, profile: PatientProfile, nutrition: NutritionSettings,
         onSave: @escaping (PatientProfile, NutritionSettings) -> Void, onClose: (() -> Void)?) {
        self.first = first
        self.profile = profile
        self.nutrition = nutrition
        self.onSave = onSave
        self.onClose = onClose
        // При первом запуске поля пустые: нормы нельзя «принять» по умолчанию, их нужно сознательно ввести.
        let fresh = !profile.setupCompleted
        _fullName = State(initialValue: profile.fullName)
        _isMale = State(initialValue: profile.isMale)
        _ageText = State(initialValue: fresh ? "" : String(profile.ageYears))
        _heightText = State(initialValue: fresh ? "" : String(Int(profile.heightCm.rounded())))
        _weightText = State(initialValue: fresh ? "" : Fmt.input(profile.weightKg))
        _pheTolText = State(initialValue: Fmt.input(profile.pheTolPerKg))
        _mixText = State(initialValue: String(profile.mixProteinPer100g))
        _scoopText = State(initialValue: Fmt.input(profile.scoopGrams))
        _manual = State(initialValue: profile.useManualNorms)
        _mPhe = State(initialValue: fresh ? "" : String(nutrition.pheLimit))
        _mNat = State(initialValue: fresh ? "" : Fmt.input(nutrition.protLimit))
        _mAks = State(initialValue: fresh ? "" : String(nutrition.aksLimit))
        _mKcal = State(initialValue: fresh ? "" : String(nutrition.kcalLimit))
    }

    // MARK: вычисления

    private var age: Int? { Int(ageText) }
    private var ageOk: Bool { (age ?? 0) >= 1 && (age ?? 0) <= 120 }
    private var heightOk: Bool { let h = heightText.decimalValue ?? 0; return h >= 45 && h <= 240 }
    private var weightOk: Bool { let w = weightText.decimalValue ?? 0; return w >= 3 && w <= 250 }
    private var bodyOk: Bool { ageOk && heightOk && weightOk }

    private var draft: PatientProfile {
        PatientProfile(
            setupCompleted: true,
            fullName: fullName.trimmingCharacters(in: .whitespaces),
            isMale: isMale,
            ageYears: age ?? 30,
            heightCm: heightText.decimalValue ?? 170,
            weightKg: weightText.decimalValue ?? 70,
            pheTolPerKg: pheTolText.decimalValue ?? 10,
            mixProteinPer100g: Int(mixText) ?? 70,
            scoopGrams: scoopText.decimalValue ?? 5.6,
            useManualNorms: false,
            reminderEnabled: profile.reminderEnabled,
            reminderIntervalDays: profile.reminderIntervalDays,
            lastUpdated: profile.lastUpdated
        ).sanitized()
    }

    /// Для детей и подростков авторасчёт не делаем: нормы назначает врач.
    private var forcedManual: Bool { ageOk && (age ?? 99) < 18 }
    private var manualMode: Bool { forcedManual || manual }
    private var computed: ComputedNorms? { (bodyOk && !manualMode) ? NormsCalculator.calculate(draft) : nil }

    private var manualOk: Bool {
        guard let phe = Int(mPhe), let nat = mNat.decimalValue, Int(mAks) != nil, let kcal = Int(mKcal) else { return false }
        return phe >= 50 && nat >= 1 && kcal >= 300
    }
    private var canSave: Bool { bodyOk && (manualMode ? manualOk : computed != nil) }

    private func setManual(_ on: Bool) {
        let c = computed // считаем до переключения: в ручном режиме расчёт не выполняется
        manual = on
        if on, let c = c {
            mPhe = String(Int(c.maxPheMg.rounded()))
            mNat = Fmt.input((c.naturalProteinG * 10).rounded() / 10)
            mAks = String(Int(c.aksProteinG.rounded()))
            mKcal = String(Int(c.kcal.rounded()))
        }
    }

    private func save() {
        let norms: NutritionSettings?
        if manualMode {
            if let phe = Int(mPhe), let nat = mNat.decimalValue, let aks = Int(mAks), let kcal = Int(mKcal) {
                var s = nutrition
                s.pheLimit = phe; s.protLimit = nat; s.aksLimit = aks; s.kcalLimit = kcal
                norms = s.sanitized()
            } else { norms = nil }
        } else {
            norms = computed?.toSettings(previous: nutrition)
        }
        guard let n = norms else { return }
        var p = draft
        p.useManualNorms = manualMode
        onSave(p, n)
    }

    // MARK: интерфейс

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if first {
                        Text("Укажите возраст, рост и вес — калькулятор рассчитает суточные нормы фенилаланина (ФА), натурального белка, АКС и калорий.")
                            .font(.subheadline)
                    }
                    Text("Расчёт ориентировочный. Нормы ФА и белка назначает лечащий врач — сверьте цифры со справкой и при расхождении введите значения врача вручную.")
                        .font(.caption)
                        .foregroundColor(Palette.warn.onContainer)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.warn.container, in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Имя или ФИО (для отчётов, необязательно)").font(.caption).foregroundColor(Palette.onSurfaceVariant)
                        TextField("", text: Binding(get: { fullName }, set: { fullName = String($0.prefix(60)) }))
                            .padding(10)
                            .background(Palette.surfaceVariant.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                    }
                    Picker("Пол", selection: $isMale) {
                        Text("Мужской пол").tag(true)
                        Text("Женский пол").tag(false)
                    }
                    .pickerStyle(.segmented)

                    AdaptiveFields {
                        DecimalField(label: "Возраст, лет", text: $ageText, max: 120, integerOnly: true)
                        DecimalField(label: "Рост, см", text: $heightText, max: 240, integerOnly: true)
                        DecimalField(label: "Вес, кг", text: $weightText, max: 250)
                    }
                    if !bodyOk {
                        Text("Заполните возраст (1–120), рост (45–240 см) и вес (3–250 кг).")
                            .font(.caption).foregroundColor(Palette.onSurfaceVariant)
                    }

                    if forcedManual {
                        Text("Для детей и подростков (до 18 лет) норму ФА, белка и АКС назначает врач, поэтому калькулятор их не считает. Введите цифры из справки ниже.")
                            .font(.caption)
                            .foregroundColor(Palette.info.onContainer)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.info.container, in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        SectionTitle(text: "Параметры расчёта", helpTitle: "Как врач считает диету и АКС?", helpText: normsHelp)
                        AdaptiveFields {
                            DecimalField(label: "ФА, мг на 1 кг веса", text: $pheTolText, max: 35)
                            DecimalField(label: "Белок в 100 г смеси, г", text: $mixText, max: 100, integerOnly: true)
                            DecimalField(label: "Грамм в мерной ложке", text: $scoopText, max: 30)
                        }
                    }

                    if let c = computed {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Рассчитанные нормы:").font(.subheadline.weight(.bold)).foregroundColor(Palette.primary)
                            Text("• Долженствующий вес: \(Int(c.idealWeightKg.rounded())) кг • общий белок \(Int(c.totalProteinG.rounded())) г/сут").font(.caption)
                            Text("• Лимит ФА: \(Int(c.maxPheMg.rounded())) мг/сут").font(.subheadline.weight(.bold))
                            Text("• Натуральный белок: \(Fmt.d1(c.naturalProteinG)) г/сут").font(.subheadline.weight(.bold))
                            Text("• Норма АКС: \(Int(c.aksProteinG.rounded())) г белка/сут").font(.subheadline.weight(.semibold))
                            Text("   ≈ \(Int(c.dryPowderG.rounded())) г сухого порошка или ≈ \(Int(c.scoops.rounded())) мерных ложек").font(.caption)
                            Text("• Калории: \(Int(c.kcal.rounded())) ккал/сут").font(.subheadline)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.primaryContainer.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                    }

                    Toggle(isOn: Binding(get: { manualMode }, set: { setManual($0) })) {
                        Text("У меня есть готовые цифры от врача (ввести вручную)").font(.subheadline)
                    }
                    .disabled(forcedManual)

                    if manualMode {
                        AdaptiveFields {
                            DecimalField(label: "Лимит ФА, мг", text: Binding(
                                get: { mPhe },
                                set: { v in
                                    mPhe = v
                                    if let phe = Int(v) {
                                        mNat = Fmt.input((Double(phe) / NormsCalculator.phePerGramProtein * 10).rounded() / 10)
                                    }
                                }), max: Limits.maxPheLimit, integerOnly: true)
                            DecimalField(label: "Натур. белок, г", text: $mNat, max: Limits.maxProtLimit)
                            DecimalField(label: "АКС (белок), г", text: $mAks, max: Limits.maxAks, integerOnly: true)
                            DecimalField(label: "Норма ккал", text: $mKcal, max: Limits.maxKcalLimit, integerOnly: true)
                        }
                        if !manualOk {
                            Text("Лимит ФА — от 50 мг, натуральный белок — от 1 г, калории — от 300.")
                                .font(.caption).foregroundColor(Palette.onSurfaceVariant)
                        }
                    }

                    Button(action: save) {
                        Label("Сохранить нормы и перейти к расчётам", systemImage: "checkmark")
                            .font(.body.weight(.bold)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(Palette.primary).controlSize(.large)
                    .disabled(!canSave)
                }
                .padding(16)
                .frame(maxWidth: 720)
            }
            .frame(maxWidth: .infinity)
            .appBackground()
            .navigationTitle(first ? "Добро пожаловать!" : "Карта пациента и нормы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if let close = onClose {
                        Button(action: close) { Image(systemName: "xmark") }.accessibilityLabel("Закрыть")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    HelpButton(title: "Как врач считает диету и АКС?", text: normsHelp)
                }
            }
            .keyboardDoneButton()
        }
        .toastOverlay()
    }
}
