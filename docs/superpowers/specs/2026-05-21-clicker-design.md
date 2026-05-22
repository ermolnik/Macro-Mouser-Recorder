# Clicker — Дизайн-документ

**Дата:** 2026-05-21
**Тип:** macOS-приложение для записи и воспроизведения действий мыши и клавиатуры
**Платформа:** macOS 13+ (Ventura и новее), Apple Silicon + Intel
**Язык / стек:** Swift 5.9+, SwiftUI, AppKit, CoreGraphics, Carbon (для глобальных хоткеев)

## 1. Цель

Дать пользователю простой нативный инструмент, чтобы:

1. Записать последовательность действий мыши (движения, клики, скролл) и клавиатуры.
2. Воспроизвести записанную последовательность с настраиваемой скоростью и числом повторов.
3. Сохранить запись в файл и загрузить позже.
4. Экстренно прервать воспроизведение глобальным хоткеем.

Не цели (out of scope): условная логика (if/while), реакция на пиксель/изображение, редактирование записи событий вручную, синхронизация между устройствами.

## 2. Архитектура

Приложение `Clicker.app` — единый процесс, SwiftUI + AppKit. Модули изолированы и общаются через единый `AppState` (ObservableObject).

```
                ┌──────────────────┐
                │   ContentView    │  (SwiftUI)
                └────────┬─────────┘
                         │ binds
                ┌────────▼─────────┐
                │     AppState     │  (ObservableObject)
                └────────┬─────────┘
        ┌────────────────┼────────────────┬─────────────────┐
        │                │                │                 │
┌───────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
│EventRecorder │  │ EventPlayer │  │HotkeyManager│  │ MacroStore  │
└──────────────┘  └─────────────┘  └─────────────┘  └─────────────┘
   CGEventTap       CGEvent.post    Carbon HotKey      JSON FS
   (listen-only)                    + NSEvent
```

### 2.1 Модули

**`EventRecorder`**
- Создаёт `CGEventTap` (listen-only) на маске:
  `mouseMoved | leftMouseDown | leftMouseUp | rightMouseDown | rightMouseUp | otherMouseDown | otherMouseUp | leftMouseDragged | rightMouseDragged | scrollWheel | keyDown | keyUp | flagsChanged`.
- Преобразует `CGEvent` → доменный `RecordedEvent` (см. модель данных).
- Замеряет относительное время с момента старта записи (`CFAbsoluteTimeGetCurrent`).
- Фильтрует собственные синтетические события (по `CGEventField.eventSourceUserData`, см. §6).
- Игнорирует события, пока не запущен `start()`.

**`EventPlayer`**
- Принимает `[RecordedEvent]`, `repeats: PlaybackRepeats` (`.count(Int)` или `.infinite`), `speed: Double` (0.5 / 1.0 / 2.0).
- Воспроизводит на фоновом `DispatchQueue` через `CGEvent.post(tap: .cghidEventTap)`.
- Между событиями ждёт `originalDelta / speed` секунд (через `Task.sleep` или `usleep`).
- Помечает свои события `CGEventSourceUserData = clickerSyntheticMarker` (см. §6).
- Реагирует на флаг `cancelRequested` — выходит из цикла на ближайшей границе события.

**`HotkeyManager`**
- Регистрирует глобальный stop-хоткей **F8** через Carbon `RegisterEventHotKey` (работает даже когда приложение неактивно и во время воспроизведения).
- При нажатии — вызывает `appState.requestStop()`.
- Хоткей фиксированный в v1 (упрощение); настройка — в будущих версиях.

**`MacroStore`**
- Каталог: `~/Library/Application Support/Clicker/macros/`.
- Сохраняет `Macro` (метаданные + события) в JSON через `Codable`.
- Имя файла: `<slug>-<uuid>.json`. Имя пользователю — поле `name` внутри JSON.
- API: `list()`, `load(id:)`, `save(_:)`, `delete(id:)`, `rename(id:to:)`.

**`AppState`**
- Опубликованные поля: `status: AppStatus` (`.idle / .recording / .playing`), `currentEvents: [RecordedEvent]`, `savedMacros: [Macro]`, `selectedMacroID: UUID?`, `playbackSpeed: Double`, `playbackRepeats: PlaybackRepeats`, `playbackProgress: Double` (0…1 для индикатора).
- Методы-фасады: `startRecording()`, `stopRecording()`, `startPlayback()`, `requestStop()`, `saveCurrent(as:)`, `loadMacro(_:)`, `deleteMacro(_:)`.
- Один источник истины: все переходы статуса — только через `AppState`.

**`ContentView` (+ субвью)**
- Верхняя панель: индикатор статуса (точка: серая/красная/зелёная) + текст.
- Кнопки: **Record** (toggle), **Play**, **Stop** (enabled только если `.playing`).
- Настройки воспроизведения: `Picker` для скорости (0.5×/1×/2×), `Stepper` + чекбокс «∞» для повторов.
- Список сохранённых макросов (`List`): имя, число событий, длительность; контекстное меню — Rename / Delete / Duplicate.
- Кнопка **Save current...** (открывает sheet с полем имени).
- Подсказка внизу: «Stop hotkey: F8».

## 3. Модель данных

```swift
enum RecordedEvent: Codable {
    case mouseMove(t: TimeInterval, x: Double, y: Double)
    case mouseDown(t: TimeInterval, button: MouseButton, x: Double, y: Double, clickCount: Int)
    case mouseUp(t: TimeInterval, button: MouseButton, x: Double, y: Double, clickCount: Int)
    case mouseDrag(t: TimeInterval, button: MouseButton, x: Double, y: Double)
    case scroll(t: TimeInterval, dx: Int32, dy: Int32)
    case keyDown(t: TimeInterval, keyCode: UInt16, flags: UInt64)
    case keyUp(t: TimeInterval, keyCode: UInt16, flags: UInt64)
    case flagsChanged(t: TimeInterval, flags: UInt64)
}

enum MouseButton: String, Codable { case left, right, other }

struct Macro: Codable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    let events: [RecordedEvent]
    var durationSeconds: Double { events.last?.t ?? 0 }
    var eventCount: Int { events.count }
}

enum PlaybackRepeats: Equatable {
    case count(Int)   // >= 1
    case infinite
}

enum AppStatus: Equatable {
    case idle
    case recording
    case playing(repeatIndex: Int, totalRepeats: Int?)
}
```

`t` — секунды от старта записи (Double). Координаты — в Quartz-системе (origin top-left, точки, не пиксели). Файл сохраняется в одной системе координат — масштаб экрана при воспроизведении не пересчитываем (v1).

## 4. Поток данных

### Запись
1. Пользователь жмёт **Record** → `AppState.startRecording()`.
2. `AppState` → `EventRecorder.start()`. Recorder создаёт CGEventTap и `CFRunLoopSource`, добавляет в текущий runloop.
3. Каждый callback CGEventTap: преобразование в `RecordedEvent`, добавление в буфер.
4. Пользователь жмёт **Stop Recording** → `EventRecorder.stop()` возвращает `[RecordedEvent]`, AppState сохраняет в `currentEvents`, переключает status → `.idle`.
5. Пользователь жмёт **Save current...** → `MacroStore.save(...)`, макрос появляется в списке.

### Воспроизведение
1. Пользователь выбирает макрос → жмёт **Play**.
2. `AppState.startPlayback()` → копирует events в `EventPlayer`, переводит status → `.playing(repeatIndex: 1, totalRepeats: N)`.
3. Player в фоновом таске: цикл по повторам → цикл по событиям → sleep до `t/speed` → `CGEvent.post`.
4. Обновляет `playbackProgress` через `await MainActor.run`.
5. Завершение: либо все повторы пройдены, либо `cancelRequested == true`, либо нажат F8 (через HotkeyManager → AppState.requestStop → Player.cancel).
6. Status → `.idle`.

## 5. Разрешения и системные требования

- **Accessibility** (`kAXTrustedCheckOptionPrompt`): обязательно. И для записи (CGEventTap прослушивает), и для воспроизведения (CGEvent.post на HID-уровне).
- При первом запуске показать понятный экран-онбординг: «Откройте System Settings → Privacy & Security → Accessibility, добавьте Clicker». Кнопка «Открыть Settings» (`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`).
- Проверяем `AXIsProcessTrustedWithOptions` при старте и блокируем Record/Play, если доступ не выдан.
- **Input Monitoring** для CGEventTap на keyDown/keyUp может потребоваться отдельно — показать ту же подсказку, если tap не создаётся.
- Sandbox **выключен** (нужно для CGEventTap на чужие приложения). Hardened Runtime включён.
- Цель — локальная утилита для себя; в App Store не публикуется.

## 6. Защита от рекурсии (synthetic loop)

Когда плеер постит события, они снова попадают в наш CGEventTap, если он запущен. Без защиты — бесконечная петля.

Решение:
- При создании `CGEventSource(stateID: .privateState)` для воспроизведения, в каждое посылаемое событие записываем поле `CGEventField.eventSourceUserData = 0xC1CKER` (магический marker).
- Recorder читает это поле у входящих событий и игнорирует те, у которых маркер совпадает.
- Дополнительно: во время `.playing` запись физически не идёт (recorder остановлен), но защита остаётся на случай одновременного запуска чужих автоматизаций.

## 7. Обработка ошибок

| Ситуация                                          | Поведение                                                                 |
|---------------------------------------------------|--------------------------------------------------------------------------|
| Нет Accessibility-разрешения                       | Кнопки Record/Play disabled, показан баннер со ссылкой в System Settings |
| `CGEvent.tapCreate` вернул nil                     | Алерт «Не удалось создать event tap. Проверьте разрешения», статус .idle |
| Запись пустая, пользователь жмёт Save              | Кнопка Save disabled пока `currentEvents.isEmpty`                        |
| Запись пустая, пользователь жмёт Play              | Кнопка Play disabled                                                     |
| JSON в `macros/` повреждён                         | Файл логируется в Console, в UI помечается «(corrupt)» и не загружается  |
| Пользователь жмёт F8 во время записи               | Игнорируется (хоткей активен только в `.playing`)                        |
| Quit во время `.playing`                           | `applicationShouldTerminate` → `requestStop`, ждём до 1с, затем выходим  |

Все ошибки логируются через `os.Logger(subsystem: "app.clicker", category: ...)`.

## 8. Тестирование

**Unit-тесты (XCTest):**
- `MacroStore`: round-trip Codable, имена файлов, удаление, повреждённые JSON.
- `EventPlayer` с инжектируемым `EventPoster` протоколом (вместо `CGEvent.post`): проверяем порядок, тайминги (с `Clock` mock), скорость, повторы, отмену.
- `RecordedEvent` ↔ `CGEvent` маппинг: фабрики из фейковых событий.
- `PlaybackRepeats` decoding/encoding.

**Integration (ручные сценарии, чек-лист в README):**
1. Записать 5 кликов в TextEdit → проиграть x1, x2 → совпадает.
2. Запись с движением мыши + кликом drag в Finder.
3. Бесконечный повтор → F8 останавливает в течение ≤ 1 события.
4. Сохранение/загрузка/удаление макроса.
5. Отзыв Accessibility-разрешения на лету → UI блокируется с понятным сообщением.

CI: тесты гоняются `swift test` на macOS-раннере (если будет CI; иначе локально перед коммитом).

## 9. Структура проекта

```
clicker/
├── Clicker.xcodeproj/
├── Clicker/
│   ├── App/
│   │   ├── ClickerApp.swift          // @main, WindowGroup
│   │   └── AppState.swift
│   ├── Recording/
│   │   ├── EventRecorder.swift
│   │   └── CGEventMapping.swift      // CGEvent ↔ RecordedEvent
│   ├── Playback/
│   │   ├── EventPlayer.swift
│   │   └── EventPoster.swift         // protocol + real impl
│   ├── Hotkeys/
│   │   └── HotkeyManager.swift
│   ├── Storage/
│   │   ├── MacroStore.swift
│   │   └── Macro.swift
│   ├── Models/
│   │   ├── RecordedEvent.swift
│   │   └── PlaybackRepeats.swift
│   ├── UI/
│   │   ├── ContentView.swift
│   │   ├── MacroListView.swift
│   │   ├── PlaybackControlsView.swift
│   │   ├── SaveMacroSheet.swift
│   │   └── PermissionsView.swift
│   ├── Permissions/
│   │   └── AccessibilityCheck.swift
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   └── Info.plist
│   └── Clicker.entitlements
├── ClickerTests/
│   ├── MacroStoreTests.swift
│   ├── EventPlayerTests.swift
│   └── CGEventMappingTests.swift
├── docs/superpowers/specs/
│   └── 2026-05-21-clicker-design.md
└── README.md
```

## 10. Этапы реализации (превью для writing-plans)

1. Скелет Xcode-проекта + `AppState` + UI-заглушка.
2. `MacroStore` + модель + unit-тесты.
3. `EventRecorder` (CGEventTap) — запись только кликов сначала, затем расширение.
4. `EventPlayer` с инжектируемым poster + unit-тесты на таймингах.
5. Реальный `CGEventPoster` + защита от рекурсии.
6. `HotkeyManager` (F8 stop).
7. Permissions-онбординг.
8. Полировка UI, ручное QA по чек-листу из §8.

## 11. Открытые вопросы

Закрыты на v1; перечислены для последующих версий:

- Настройка stop-хоткея пользователем.
- Редактор событий (timeline view).
- Условная логика (wait-for-pixel, циклы while).
- Импорт/экспорт макросов между машинами с разными разрешениями экрана (нормализация координат).
- Code signing / notarization для распространения.
