# Insula

**[English](#english) · [Русский](#русский)**

Native macOS utility that turns the camera notch into a Dynamic Island-style widget.

Media controls, timers, clipboard history, mic mute, lyrics, calendar/reminders, and more — all in a compact island near the top of the screen.

Works on Macs with a notch and without one (floating pill on non-notch displays).

---

<a id="english"></a>
## English

### Features

- Now Playing + transport controls (Apple Music, Spotify, and other media apps)
- Timers with progress ring
- Clipboard history
- Mic mute toggle
- Synced lyrics (lrclib)
- Playlist panel
- Calendar / Reminders schedule slots
- Audio output switching
- Editable layout (add/remove modules)
- Multi-language interactive guide (RU / EN / ES / ZH / JA / PT)
- Relocatable island (notch / dock / custom position)

### Requirements

- **macOS 14 Sonoma** or later
- **Apple Silicon** (M1 and newer)
- Works with physical notch and on non-notch displays / external monitors

### Installation

#### 1. Download DMG (recommended)

1. Download the latest `Insula.dmg` from the [Releases](../../releases) page  
   or from the project site: `site/downloads/Insula.dmg`
2. Open the DMG and drag **Insula** to the Applications folder
3. First launch: right-click the app → **Open**  
   (double-click is often blocked by Gatekeeper because the app is not notarized yet)

If macOS still complains:

```bash
xattr -cr /Applications/Insula.app
```

#### 2. Homebrew

Not available yet. Planned for a future release.

### Build from Source

1. Install Xcode (15 or later recommended)
2. Clone the repository:

```bash
git clone https://github.com/gk767/insula.git
cd insula
```

3. Open the project:

```bash
open DynamicIslandForMac/DynamicIslandForMac.xcodeproj
```

4. Select the `DynamicIslandForMac` scheme and your Mac as destination
5. Press **⌘R** to build and run

### Permissions

On first launch Insula may request:

| Permission       | Why it needs it                            |
|------------------|--------------------------------------------|
| Accessibility    | Mouse/keyboard interaction with the island |
| Calendar         | Show upcoming events / schedule            |
| Reminders        | Show reminders in the schedule slots       |
| Microphone       | Mic mute status (optional)                 |
| Notifications    | Timer and schedule alerts                  |

You can grant or deny them in **System Settings → Privacy & Security**.

### Roadmap

- [ ] Official notarized builds + proper code signing
- [ ] Homebrew cask
- [ ] Auto-update
- [ ] Windows version (planned)
- [ ] More modules (weather, battery, focus timer, etc.)
- [ ] Custom themes / appearance options
- [ ] Better support for external displays
- [ ] Public Releases page with changelog

### License

No license file is present yet.  
Feel free to open an issue if you need clarification.

### Contributing

Pull requests and issue reports are welcome.  
The project is still early — feedback helps a lot.

---

<a id="русский"></a>
## Русский

### Возможности

- Now Playing + управление воспроизведением (Apple Music, Spotify и другие)
- Таймеры с кольцом прогресса
- История буфера обмена
- Мьют микрофона
- Синхронизированные тексты песен (lrclib)
- Панель плейлиста
- Слоты календаря / напоминаний
- Переключение аудиовыхода
- Редактируемый набор модулей
- Интерактивный гайд на нескольких языках (RU / EN / ES / ZH / JA / PT)
- Перемещаемый остров (notch / dock / произвольная позиция)

### Требования

- **macOS 14 Sonoma** или новее
- **Apple Silicon** (M1 и новее)
- Работает с физической челкой и на экранах без неё / внешних мониторах

### Установка

#### 1. Скачать DMG (рекомендуется)

1. Скачайте последний `Insula.dmg` со страницы [Releases](../../releases)  
   или с сайта проекта: `site/downloads/Insula.dmg`
2. Откройте DMG и перетащите **Insula** в папку «Программы»
3. Первый запуск: правый клик по приложению → **Открыть**  
   (двойной клик macOS часто блокирует, потому что приложение ещё не нотаризовано)

Если macOS всё равно ругается:

```bash
xattr -cr /Applications/Insula.app
```

#### 2. Homebrew

Пока недоступно. Планируется в следующих версиях.

### Сборка из исходников

1. Установите Xcode (рекомендуется 15+)
2. Клонируйте репозиторий:

```bash
git clone https://github.com/gk767/insula.git
cd insula
```

3. Откройте проект:

```bash
open DynamicIslandForMac/DynamicIslandForMac.xcodeproj
```

4. Выберите схему `DynamicIslandForMac` и свой Mac как destination
5. Нажмите **⌘R** для сборки и запуска

### Разрешения

При первом запуске Insula может запросить:

| Разрешение            | Зачем нужно                                  |
|-----------------------|----------------------------------------------|
| Универсальный доступ  | Взаимодействие мышью/клавиатурой с островом  |
| Календарь             | Показ ближайших событий                      |
| Напоминания           | Показ напоминаний в слотах расписания        |
| Микрофон              | Статус мьюта (опционально)                   |
| Уведомления           | Оповещения таймера и расписания              |

Выдать или запретить можно в **Системные настройки → Конфиденциальность и безопасность**.

### Roadmap

- [ ] Официальные нотаризованные сборки + подпись кода
- [ ] Homebrew cask
- [ ] Автообновление
- [ ] Версия для Windows (в планах)
- [ ] Больше модулей (погода, батарея, focus-таймер и т.д.)
- [ ] Темы оформления
- [ ] Лучшая поддержка внешних мониторов
- [ ] Публичные Releases с changelog

### Лицензия

Файл лицензии пока отсутствует.  
Если нужно уточнение — откройте issue.

### Участие

Pull request’ы и сообщения об ошибках приветствуются.  
Проект ещё ранний — обратная связь очень помогает.
```