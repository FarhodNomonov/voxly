# Voxly — Windows

**Status: in progress.** The Windows port is being brought in line with the
macOS app. There is no public download yet.

[Русский ↓](#voxly--windows-по-русски)

Offline dictation for Windows. Press **Ctrl+Alt+D** in any app, speak, press
again, and the text appears where your cursor is. Speech is recognized on your
PC; the only network traffic is the one-time model download and, if you add
one, requests made with your own AI API key. No telemetry, no update pings.

| Tab | What it does |
|---|---|
| **Yozish** (Dictation) | Ctrl+Alt+D dictation, recent dictation history |
| **Fayl** (File) | drop an audio/video file to get a full transcript, optional AI actions |

The interface is still in Uzbek (inherited from Kotib); Russian/English UI and
language selection are planned.

| | |
|---|---|
| OS | Windows 10 1809 (build 17763) or Windows 11, 64-bit (x64 and ARM64) |
| RAM | 4 GB with a GPU, 6 GB CPU-only |
| GPU | optional (Vulkan: NVIDIA, AMD or Intel); CPU works, slower |

## Build from macOS (main path)

Everything is cross-compiled on a Mac with [llvm-mingw](https://github.com/mstorsjo/llvm-mingw);
a Windows machine or VM is only needed to run it.

```bash
./win/build-mac.sh              # x64 with Vulkan (needs glslc, vulkan-headers)
./win/build-mac.sh --cpu        # x64 CPU-only: no Vulkan/glslc/Homebrew needed
./win/build-mac.sh arm64        # ARM64
./win/build-mac.sh hammasi      # both architectures
./win/build-mac.sh --tez        # do not rebuild whisper.cpp
```

The one-time requirements (llvm-mingw, ninja, cmake, and for the Vulkan build
shaderc/glslang/vulkan-headers) are printed by the script. whisper.cpp is
pinned in `scripts/bogliqliklar.env`. Output: `win/build-<arch>/Voxly.exe`
with the whisper.cpp DLLs next to it.

Tests: `./win/tests/mac/hammasi.sh` on macOS (pure-logic subset);
the full suite is `voxly-testlar.exe`, run it on Windows or in a VM.
The installer (Inno Setup, `win/installer/rubai.iss`) is built inside a
Windows VM with `./win/tools/ornatuvchi-yasa.sh`; result:
`dist/Voxly-<version>-win-setup.exe`. A Windows-native MSVC build is
`win\build.ps1`.

## Where data lives

| What | Where |
|---|---|
| Settings, history, documents | `%APPDATA%\Voxly\` |
| Speech model, log, unsaved audio | `%LOCALAPPDATA%\Voxly\` |
| App | `%LOCALAPPDATA%\Programs\Voxly\` |
| AI API key | Windows Credential Manager (`Voxly.llm.<provider>`) |

On first launch Voxly moves an existing `Kotib` (or older `Audio-Matnga`)
data folder to `Voxly` if the `Voxly` folder does not exist yet, so the
downloaded model and settings are reused. Nothing is deleted. An API key
saved by Kotib is copied to Voxly's entry the first time it is needed.

---

## Voxly — Windows (по-русски)

**Статус: в работе.** Порт для Windows доводится до уровня macOS-версии.
Публичной сборки для скачивания пока нет.

Офлайн-диктовка для Windows. Нажмите **Ctrl+Alt+D** в любом приложении,
говорите, нажмите ещё раз — текст появится там, где курсор. Речь распознаётся
на вашем компьютере; в сеть приложение выходит только для разовой загрузки
модели и, если вы добавили ключ, для запросов с вашим собственным AI-ключом.
Без телеметрии и проверки обновлений.

Две вкладки: **Yozish** (диктовка и история) и **Fayl** (расшифровка аудио/видео
файлов, необязательные AI-действия). Интерфейс пока на узбекском (наследство
Kotib); русский/английский интерфейс и выбор языка — следующий этап.

Требования: Windows 10 1809+ или Windows 11, 64-бит (x64 и ARM64); 4 ГБ ОЗУ с
видеокартой, 6 ГБ без неё. Видеокарта необязательна.

### Сборка на macOS

```bash
./win/build-mac.sh --cpu        # x64 без Vulkan — нужны только llvm-mingw, cmake, ninja
./win/build-mac.sh              # x64 с Vulkan (нужны glslc и vulkan-headers)
./win/build-mac.sh hammasi      # x64 + ARM64
```

Результат: `win/build-<arch>/Voxly.exe` и DLL whisper.cpp рядом. Тесты на
macOS — `./win/tests/mac/hammasi.sh`, полный набор — `voxly-testlar.exe` на
Windows. Установщик собирается в Windows-VM: `./win/tools/ornatuvchi-yasa.sh`
→ `dist/Voxly-<версия>-win-setup.exe`.

Данные: настройки и история — `%APPDATA%\Voxly\`, модель и лог —
`%LOCALAPPDATA%\Voxly\`, API-ключ — в Диспетчере учётных данных Windows.
При первом запуске папка `Kotib` переносится в `Voxly` (если `Voxly` ещё нет);
ничего не удаляется.

## License

MIT. Voxly is a fork of [Kotib](https://github.com/MuhammadMirrr/kotib) by
Muhammad Mirqobilov; the original copyright notice is kept in `LICENSE`.
whisper.cpp and the models are under their own licenses — see
`THIRD_PARTY_NOTICES.md`.
