# ФКУшка — iOS (SwiftUI)

Нативный порт Android-версии: те же экраны, логика, формулы, лимиты ввода и тесты.
Структура повторяет APK-проект:

```
FkuShka/Domain      модели, Limits, Fmt, NutritionCalculator, PatientProfile (нормы, напоминание, дубликаты, отчёт)
FkuShka/Data        AppData (Codable), FkuStore (аналог Repository + ViewModel'ей), хранение — один JSON-файл
FkuShka/UI          Theme (палитра светлая/тёмная/AMOLED), Components, Screens, AppRoot
FkuShka/Resources   Products.json (50 продуктов из Android), иконка, AccentColor
FkuShkaTests        XCTest: те же проверки, что в Android-версии (+ тесты хранилища)
project.yml         описание проекта для XcodeGen (Xcode-проект генерируется, вручную не пишется)
.github/workflows   сборка .ipa в облаке на macOS-раннере GitHub
```

## Как получить .ipa

### Вариант 1 — без Mac (GitHub Actions)
1. Создайте репозиторий на GitHub и загрузите содержимое этой папки (`git push`).
2. Вкладка **Actions → iOS build → Run workflow** (или просто пуш в `main`).
3. После сборки скачайте артефакт **FkuShka-unsigned-ipa** → `FkuShka-unsigned.ipa`.
4. Этот .ipa **не подписан**. Установить его на свой iPhone можно через Sideloadly или AltStore
   (они подпишут вашим бесплатным Apple ID; такое приложение живёт 7 дней и переустанавливается).

### Вариант 2 — Codemagic (тоже без Mac)
1. Репозиторий на GitHub/GitLab/Bitbucket с этим проектом → на codemagic.io войдите через тот же аккаунт.
2. Add application → выберите репозиторий → тип проекта: **Other / codemagic.yaml**.
3. Start new build → workflow `ios-unsigned` → после сборки скачайте `FkuShka-unsigned.ipa` из Artifacts.
Личный аккаунт: 500 бесплатных минут в месяц на Mac M2.

### Вариант 3 — на Mac
```
brew install xcodegen
xcodegen generate
open FkuShka.xcodeproj
```
В Xcode: Signing & Capabilities → выберите свой Team → подключите iPhone → Run.
Для .ipa: Product → Archive → Distribute App.

### Для раздачи другим людям (брату и т. д.)
Нужна подписка Apple Developer Program ($99/год): TestFlight (до 10 000 тестеров) или App Store.
Bundle ID `com.fkushka.app` замените на свой уникальный в `project.yml`
(`PRODUCT_BUNDLE_IDENTIFIER`), версия — `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`.

## Особенности по сравнению с Android
* Минимум iOS 16. Динамических цветов (Material You) на iOS нет; тема: системная / светлая / тёмная + AMOLED.
* Данные хранятся в `Application Support/fku.json` (на устройстве, без облака).
* Для возраста до 18 лет авторасчёт норм отключён — только ввод цифр врача.
* Справочник продуктов ориентировочный; нормы всегда назначает врач.
