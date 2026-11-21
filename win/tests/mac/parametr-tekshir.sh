#!/usr/bin/env bash
#
# whisper inference parametrlari ikkala platformada bir xilmi.
#
#   ./win/tests/mac/parametr-tekshir.sh
#
# whisper.cpp ustidagi C shim (`src/whisper_bridge.c`) va ovozni boʻlaklash
# (`src/nutq_bolaklari.{c,h}`) endi YAGONA fayllar: macOS (`src/build.sh`) ham,
# Windows (`win/CMakeLists.txt`) ham shularni kompilyatsiya qiladi. Ilgari
# `win/core/` da nusxa turardi va bu skript ularni solishtirardi. Endi u
# bir xillik BUZILMASLIGINI tekshiradi:
#   • `win/core/` da nusxa qayta paydo boʻlmagan, CMake `src/` dagini oladi;
#   • `#ifdef _WIN32` / `#else` bloklarida whisper (`p.`) yoki VAD (`vp.`)
#     parametri YOʻQ — platformaga xos joylar faqat fayl ochish va backend;
#   • ikkala transkripsiya funksiyasi va VAD parametrlari topiladi va bir-biriga
#     mos (yagona ruxsat etilgan farq — `no_timestamps`);
#   • nutq modellari katalogi (hajm, sha256, manzil) `src/model_tanlov.swift`
#     va `win/core/model_tanlov.h` da bir xil.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ISH="${TMPDIR:-/tmp}/kotib-parametr"
mkdir -p "$ISH"
BRIDGE="$ROOT/src/whisper_bridge.c"

xato=0
yaxshi() { echo "✓ $*"; }
yomon() { echo "✗ $*" >&2; xato=1; }

# 1. Nusxa yoʻq, CMake umumiy faylni oladi.
for f in whisper_bridge.c whisper_bridge.h nutq_bolaklari.c nutq_bolaklari.h; do
    if [ -e "$ROOT/win/core/$f" ]; then
        yomon "win/core/$f qayta paydo boʻldi — umumiy fayl src/$f (nusxa ogʻib ketadi)"
    fi
done
if grep -q 'UMUMIY_SRC}/whisper_bridge.c' "$ROOT/win/CMakeLists.txt" \
    && grep -q 'UMUMIY_SRC}/nutq_bolaklari.c' "$ROOT/win/CMakeLists.txt"; then
    yaxshi "Windows build'i umumiy src/whisper_bridge.c va src/nutq_bolaklari.c ni kompilyatsiya qiladi"
else
    yomon "win/CMakeLists.txt umumiy src/ fayllarini kompilyatsiya qilmayapti"
fi

# 2. Platformaga xos bloklarda parametr yoʻq.
#    `#if…` dan mos `#endif` gacha (ichma-ich bloklarni hisobga olib) chiqaradi.
platforma_bloklari() {
    awk '
        /^[[:space:]]*#[[:space:]]*if/ {
            chuqur++
            if ($0 ~ /_WIN32/ && !ichida) { ichida = 1; boshi = chuqur }
        }
        ichida { print }
        /^[[:space:]]*#[[:space:]]*endif/ {
            if (ichida && chuqur == boshi) ichida = 0
            chuqur--
        }
    ' "$1"
}
platforma_bloklari "$BRIDGE" > "$ISH/platforma.txt"
if grep -nE '^[[:space:]]+v?p\.[a-z_.]+[[:space:]]*=' "$ISH/platforma.txt"; then
    yomon "#ifdef _WIN32 bloklarida inferens/VAD parametri bor — platformalar boshqa matn beradi"
else
    yaxshi "platformaga xos bloklarda inferens/VAD parametri yoʻq ($(wc -l < "$ISH/platforma.txt" | tr -d ' ') qator tekshirildi)"
fi

# 3. Parametrlar topiladi; ikkala transkripsiya funksiyasi mos.
ajrat() {
    local fayl="$1" funksiya="$2"
    # `grep` hech narsa topmasa 1 qaytaradi va `pipefail` butun skriptni
    # toʻxtatardi — shuning uchun `|| true`.
    # BSD sed (macOS) BRE'da `\|` alternatsiyasini tushunmaydi — `-E` kerak.
    sed -nE "/^[^ ].*[ *]${funksiya}\\(/,/^\\}/p" "$fayl" \
        | { grep -E '^[[:space:]]+v?p\.' || true; } \
        | sed -E 's|//.*$||' \
        | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}
for f in rubai_transcribe rubai_transcribe_segments vad_parametrlari; do
    ajrat "$BRIDGE" "$f" > "$ISH/$f.txt"
    if [ -s "$ISH/$f.txt" ]; then
        yaxshi "$f: $(wc -l < "$ISH/$f.txt" | tr -d ' ') ta parametr"
    else
        yomon "$f: parametrlar topilmadi (funksiya nomi oʻzgardimi?)"
    fi
done
# Diktovka va Studiya bir xil model chaqiruvi — farq faqat `no_timestamps`
# (segment chegaralari) va Studiyaning progress/abort callback'larida.
filtr() { grep -vE '^p\.(no_timestamps|progress_callback|abort_callback|audio_ctx)' "$1" || true; }
if diff -u <(filtr "$ISH/rubai_transcribe.txt") <(filtr "$ISH/rubai_transcribe_segments.txt"); then
    yaxshi "diktovka va Studiya parametrlari bir xil (no_timestamps va callback'lardan tashqari)"
else
    yomon "rubai_transcribe va rubai_transcribe_segments parametrlari farq qiladi"
fi

# 4. Nutq modellari katalogi ikki platformada bir xil.
SWIFT="$ROOT/src/model_tanlov.swift"
WINH="$ROOT/win/core/model_tanlov.h"
if [ -f "$WINH" ]; then
    # Swift: hajm `823_369_796`, sha256 64 hex, manzil "https://…".
    while read -r hajm; do
        if grep -q "${hajm//_/}LL" "$WINH"; then
            yaxshi "model hajmi ${hajm//_/} — ikkala katalogda"
        else
            yomon "model hajmi ${hajm//_/} win/core/model_tanlov.h da yoʻq"
        fi
    done < <(grep -oE 'hajm: [0-9_]+' "$SWIFT" | sed 's/hajm: //')
    while read -r sha; do
        grep -q "$sha" "$WINH" || yomon "sha256 $sha win/core/model_tanlov.h da yoʻq"
    done < <(grep -oE '"[0-9a-f]{64}"' "$SWIFT" | tr -d '"')
    while read -r url; do
        grep -qF "$url" "$WINH" || yomon "manzil $url win/core/model_tanlov.h da yoʻq"
    done < <(grep -oE 'url: "https://[^"]+"' "$SWIFT" | sed -E 's/url: "(.*)"/\1/')
    [ "$xato" = 0 ] && yaxshi "model sha256 va manzillari bir xil"
fi

exit "$xato"
