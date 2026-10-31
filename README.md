# Voxly

**Offline dictation for macOS.** Press a hotkey in any app, speak, and the text
appears where your cursor is: Telegram, a browser, Notes, a code editor. Speech
is recognized on your Mac. No audio leaves the computer and no internet is needed.

[Русский ↓](#voxly--по-русски)

| | |
|---|---|
| Platform | macOS 13 Ventura or newer, Apple Silicon and Intel |
| Languages | Russian (Cyrillic), English, Uzbek |
| Default hotkey | **⌃⌥D**: press to start, press again to stop |
| Interface | Russian / English (Settings → Interface language) |
| Model | Whisper large-v3-turbo (q5_0, ~550 MB, downloaded on first use) |

---

## Features

- **Works everywhere.** A global hotkey types the text into whatever field has
  focus, either by pasting through the clipboard (fast, the clipboard is restored
  afterwards) or by typing it character by character.
- **Fixed output language.** Choose the speech language in Settings. In Russian
  mode speech is written in Cyrillic, even if you slip into English words.
  Brand names such as YouTube or Google Chrome may keep their usual Latin
  spelling.
- **Fully offline.** Recognition runs locally on whisper.cpp. There are no
  accounts, no telemetry and no update pings.
- **Files.** Drop an audio or video file to get a full transcript. Long files
  are split at pauses (Silero VAD) and processed in pieces.
- **Optional AI actions.** With your own API key you can clean up, summarize,
  extract key points, write meeting minutes, shorten or expand a transcript, or
  run a custom request. Without a key the app works fully. No key ships with it.
- **Dictation history.** Recent dictations stay in the main window, one click
  to copy.
- **Light on resources.** It lives in the menu bar, and the model is unloaded
  from RAM after 3 minutes without use.

## Speed

Measured on an Intel i7-9750H (6 cores, 2019 MacBook Pro), CPU only, with the
time counted from the end of speech to the finished text:

| Phrase length | Time to text |
|---|---|
| 1.5 s («Привет, как дела?») | 3.0 s |
| 5 s | 3.3 s |
| 10 s | 3.5 s |
| 20 s | 7.3 s |

For comparison, the original upstream build on the same machine took 84 s for
22 s of speech.

What makes it fast:

- **Model.** Whisper large-v3-turbo (4 decoder layers instead of 32), q5_0.
- **Window size.** The encoder only processes the length of the phrase plus a
  margin, not the whole 30-second window. The size is rounded up to a multiple
  of 256 frames: a non-aligned window left uninitialized cache cells and caused
  looping output.
- **Intel builds.** Native AVX2/FMA plus Apple Accelerate (BLAS), and one thread
  per physical core.
- **Loop guard.** If the decoder starts repeating itself, it is stopped
  immediately and the piece is re-run with a larger window.

Apple Silicon builds use Metal on the GPU and should be faster still. They have
not been measured yet.

To check real-world speed on your Mac, every dictation is logged:

```bash
grep 'stt:' ~/Library/Logs/Voxly.log | tail
# stt: ovoz=4.2s ishlov=3.1s    ← 4.2 s of audio, 3.1 s processing
```

## Installation (from source)

You need the Xcode Command Line Tools (`xcode-select --install`). cmake is
installed automatically through Homebrew or pip.

```bash
git clone https://github.com/FarhodNomonov/voxly.git
cd voxly
./setup.sh                    # whisper.cpp → Russian/English model → app
OZBEK=1 ./setup.sh            # also download the Uzbek model (rubaiSTT, ~820 MB)
```

The first build of whisper.cpp takes a few minutes. The app ends up in
`~/Applications/Voxly.app`; move it to `/Applications` if you like.

### Permissions

On first launch macOS asks for:

1. **Microphone**, to record speech.
2. **Accessibility**, to insert text into other apps:
   System Settings → Privacy & Security → Accessibility → enable Voxly.

macOS ties these permissions to the app's signature. An ad-hoc signed build
loses them after every rebuild, so build with a stable local signature:

```bash
./scripts/mahalliy-yigish.sh  # creates a local "Kotib Local Signing" certificate once
```

That signature only works on your own Mac. Distributing the app needs a
Developer ID certificate and notarization. The packaging script
(`scripts/release.sh` → `make_pkg.sh`) is still the original Kotib one and has
not been adapted to Voxly yet.

### Uninstall

Settings → «Удалить Voxly…» copies the command for you, or run it yourself:

```bash
sudo ./scripts/uninstall.sh               # app, settings, permissions, models
sudo ./scripts/uninstall.sh --keep-model  # keep the downloaded models
```

## Privacy

- Audio is processed in memory on your Mac and is never sent anywhere.
- The only network requests are the model download (from Hugging Face) and,
  if you set one up, the AI provider you chose, with your own key, for the
  actions you run.
- Your data lives in `~/Library/Application Support/Voxly` and the log in
  `~/Library/Logs/Voxly.log`. The log records timings and errors, not
  transcripts.

## Development

```bash
./src/build.sh                     # rebuild the app only → ~/Applications/Voxly.app
./scripts/mahalliy-yigish.sh       # the same, with the stable local signature
./src/test.sh                      # pure-logic Swift tests (seconds) + version check
win/tests/mac/parametr-tekshir.sh  # macOS/Windows bridge parity
```

| Path | What it holds |
|---|---|
| `src/` | The macOS app: Swift/AppKit plus a C bridge to whisper.cpp (`whisper_bridge.c`) |
| `src/ui_tili.swift` | Interface language: every string is `tr("русский", "English")` |
| `src/model_tanlov.swift` | Speech languages and their models |
| `src/yollar.swift` | All user-data paths, plus migration from Kotib |
| `tests/` | Tests, registered in `tests/test_ruyxat.swift` |
| `scripts/` | Build, signing, uninstall and license scripts |
| `scripts/bogliqliklar.env` | Pinned versions of whisper.cpp, the models and VAD |
| `win/` | The original Kotib Windows port (not adapted to Voxly yet) |

Code comments and logs are in Uzbek, inherited from the original project.
`AGENTS.md` has the detailed engineering notes.

## Status and plans

- [x] Russian/English recognition, Cyrillic output in Russian mode
- [x] Russian/English interface
- [x] Speed-up for Intel (BLAS, adaptive window, loop guard)
- [x] Translator, auto-updater, telemetry and donation window removed
- [ ] Developer ID signing and notarization
- [ ] Subscription and licensing
- [ ] Measurements on Apple Silicon
- [ ] Our own host for the Uzbek model (it still downloads from the original author's CDN)
- [ ] Windows version

## License and credits

Voxly is a fork of [Kotib](https://github.com/MuhammadMirrr/kotib) by
Muhammad Mirqobilov (MIT). The MIT license allows commercial use. The original
copyright notice stays in [LICENSE](LICENSE).

- [whisper.cpp](https://github.com/ggml-org/whisper.cpp): MIT
- [OpenAI Whisper](https://github.com/openai/whisper) models: MIT
- [rubaiSTT v2 medium](https://huggingface.co/islomov/rubaistt_v2_medium) by islomov: Apache-2.0
- [Silero VAD](https://github.com/snakers4/silero-vad): MIT

The full list is in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

---

# Voxly — по-русски

**Офлайн-диктовка для macOS.** Нажимаете клавишу в любом приложении, говорите,
и текст появляется там, где стоит курсор. Распознавание идёт на вашем Mac: звук
никуда не отправляется, интернет не нужен.

## Что умеет

- **Работает везде**: Telegram, браузер, Заметки, редактор кода. Клавиша по
  умолчанию **⌃⌥D**: нажали, сказали, нажали ещё раз. Её можно сменить в
  настройках.
- **Язык речи выбирается в настройках**: русский, английский или узбекский.
  В русском режиме речь пишется кириллицей. Названия вроде YouTube или
  Google Chrome могут остаться латиницей.
- **Файлы**: перетащите аудио или видео и получите полную расшифровку.
- **ИИ-действия** (по желанию, со своим API-ключом): почистить текст, сделать
  краткое содержание, ключевые пункты или протокол встречи, сократить или
  расширить текст, свой запрос.
- **Интерфейс** на русском и английском: Настройки → «Язык интерфейса».
- Живёт в строке меню. Через 3 минуты простоя модель выгружается из памяти.

## Скорость

Замеры на Intel i7-9750H (MacBook Pro 2019, только процессор). Время считается
от конца фразы до готового текста:

| Длина фразы | Время |
|---|---|
| 1,5 с | 3,0 с |
| 5 с | 3,3 с |
| 10 с | 3,5 с |
| 20 с | 7,3 с |

Исходная сборка на том же Mac тратила 84 с на 22 с речи. На Apple Silicon (GPU,
Metal) должно быть ещё быстрее, но там замеров пока не было.

Проверить реальную скорость на своём Mac:

```bash
grep 'stt:' ~/Library/Logs/Voxly.log | tail
# stt: ovoz=4.2s ishlov=3.1s   ← 4,2 с звука, 3,1 с обработки
```

## Установка из исходников

```bash
xcode-select --install          # если ещё не стоят инструменты разработчика
git clone https://github.com/FarhodNomonov/voxly.git
cd voxly
./setup.sh                      # whisper.cpp → модель (~550 МБ) → приложение
./scripts/mahalliy-yigish.sh    # пересборка с постоянной локальной подписью
```

После первого запуска разрешите доступ к **микрофону** и к **универсальному
доступу**: Системные настройки → Конфиденциальность и безопасность →
Универсальный доступ → Voxly. Без универсального доступа текст не вставится в
другие приложения.

Пересобирайте через `scripts/mahalliy-yigish.sh`, а не через голый
`src/build.sh`: иначе macOS сбрасывает разрешения после каждой сборки.

Удаление: Настройки → «Удалить Voxly…» или `sudo ./scripts/uninstall.sh`.

## Конфиденциальность

Звук обрабатывается в памяти и никуда не уходит. В сеть приложение ходит только
за моделью (Hugging Face) и, если вы сами подключили ИИ-провайдера, к нему с
вашим ключом. В лог (`~/Library/Logs/Voxly.log`) пишется время обработки и
ошибки, но не тексты.

## Лицензия

Voxly — форк проекта [Kotib](https://github.com/MuhammadMirrr/kotib) (Мухаммад
Миркабилов, лицензия MIT, коммерческое использование разрешено). Строка с
авторскими правами оригинала должна оставаться в [LICENSE](LICENSE). Модели и
библиотеки перечислены в [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
