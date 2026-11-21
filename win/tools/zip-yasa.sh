#!/usr/bin/env bash
#
# Portativ Windows tarqatmasi (ZIP) — oʻrnatuvchisiz.
#
#   ./win/tools/zip-yasa.sh [x64|arm64]
#
# Natija: `dist/Voxly-<versiya>-win-<arch>-portable.zip`
#
# Nega bu mumkin boʻldi: nutq modeli endi ilova ichida yuklab olinadi
# (`core/model_yuklovchi.cpp`). Ilgari model faqat oʻrnatuvchi bilan
# kelardi va modelsiz nusxa ishlamasdi.
#
# Nega ZIP kerak: Inno Setup oʻrnatuvchisi faqat Windows'da yigʻiladi
# (`iscc.exe`), macOS'da esa Wine talab qiladi. ZIP esa shu yerda yigʻiladi
# va SmartScreen ogohlantirishisiz ishlaydi — oʻrnatuvchi kerak emas,
# papkani ochib `Voxly.exe` ni bosish kifoya.
#
# Cheklov: avtostart va Start menyusidagi yorliq YOʻQ (ularni oʻrnatuvchi
# qiladi). Avtostartni ilovaning oʻzi Sozlamalardan yoqadi.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCH="${1:-x64}"
BUILD="$ROOT/win/build-$ARCH"
DIST="$ROOT/dist"

[ -f "$BUILD/Voxly.exe" ] || {
    echo "Voxly.exe topilmadi: $BUILD" >&2
    echo "Avval: ./win/build-mac.sh $ARCH" >&2
    exit 1
}

# Versiya — `VERSION` faylidan (yagona manba). app.rc ham uni CMake orqali oladi.
# shellcheck source=../../scripts/versiya.sh
source "$ROOT/scripts/versiya.sh"
VERSIYA="$KOTIB_VERSIYA"

NOM="Voxly-$VERSIYA-win-$ARCH-portable"
ISH="${TMPDIR:-/tmp}/$NOM"
rm -rf "$ISH"
mkdir -p "$ISH" "$DIST"

cp "$BUILD/Voxly.exe" "$ISH/"
cp "$BUILD"/*.dll "$ISH/" 2>/dev/null || true
cp "$ROOT/LICENSE" "$ISH/LICENSE.txt"

# Silero VAD — jimlikni tashlaydi va uzun ovozni boʻladi; engine.cpp uni
# exe yonidan qidiradi. Yoʻq boʻlsa ZIP yigʻilmaydi (jimlikda gallyutsinatsiya).
# shellcheck source=../../scripts/bogliqliklar.env
source "$ROOT/scripts/bogliqliklar.env"
VAD="$ROOT/vad/$VAD_NOM"
[ -f "$VAD" ] || { echo "VAD topilmadi: $VAD (./setup.sh yuklaydi)" >&2; exit 1; }
[ "$(shasum -a 256 "$VAD" | cut -d' ' -f1)" = "$VAD_SHA256" ] || { echo "VAD sha256 mos emas: $VAD" >&2; exit 1; }
cp "$VAD" "$ISH/"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$ISH/THIRD_PARTY_NOTICES.txt"

# README — rus/ingliz (Windows Notepad UTF-8 ni oʻzi taniydi, CRLF bilan).
cat > "$ISH/README.txt" <<'TXT'
Voxly — офлайн-диктовка для Windows (портативная версия)
=========================================================

ЗАПУСК
  Дважды нажмите Voxly.exe. Значок Voxly появится в правом нижнем углу
  (рядом с часами; если его не видно — нажмите стрелку ^).
  Если Windows пишет «Windows защитил ваш компьютер»: «Подробнее» →
  «Выполнить в любом случае» (программа пока без цифровой подписи).

ПЕРВЫЙ ШАГ — МОДЕЛЬ
  В Настройках выберите язык речи. Затем в окне Voxly, в разделе
  «Диктовка», на жёлтой полосе нажмите «Скачать».
  Модель скачивается один раз (русский/английский ~550 МБ, узбекский
  ~785 МБ). После этого интернет не нужен.

МИКРОФОН
  В Настройках обязательно выберите свой микрофон. Иногда по умолчанию
  стоит «Stereo Mix» — он записывает звук компьютера, а не ваш голос.

ДИКТОВКА
  Поставьте курсор туда, где нужен текст (Telegram, браузер, Word),
  нажмите Ctrl+Alt+D, говорите, нажмите Ctrl+Alt+D ещё раз.

ТРЕБОВАНИЯ
  Windows 10 (1809+) или 11, 64-bit; 6 ГБ RAM; ~1 ГБ на диске.

-----------------------------------------------------------------

Voxly — offline dictation for Windows (portable)

START
  Double-click Voxly.exe. The Voxly icon appears near the clock
  (click the ^ arrow if hidden). If Windows says "Windows protected
  your PC": "More info" -> "Run anyway" (the app is not signed yet).

FIRST STEP — MODEL
  In Settings choose the speech language, then click Download on the
  yellow bar in the Dictation section of the Voxly window.
  The model downloads once (Russian/English ~550 MB, Uzbek ~785 MB).

MICROPHONE
  Pick your microphone in Settings ("Stereo Mix" records computer sound).

DICTATION
  Put the cursor where the text should go, press Ctrl+Alt+D, speak,
  press Ctrl+Alt+D again.

Author: Farkhod Nomonov — https://farhod-nomonov.netlify.app
Licenses: LICENSE.txt, THIRD_PARTY_NOTICES.txt
TXT
# Notepad uchun CRLF.
perl -pi -e 's/\n/\r\n/' "$ISH/README.txt"

# `ditto` HFS metadata qoʻshmaydi va Windows'da `__MACOSX` chiqmaydi.
rm -f "$DIST/$NOM.zip"
(cd "$(dirname "$ISH")" && ditto -c -k --sequesterRsrc --keepParent "$NOM" "$DIST/$NOM.zip")

echo "Tayyor: dist/$NOM.zip"
unzip -l "$DIST/$NOM.zip" | tail -20
