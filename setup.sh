#!/bin/bash
# Voxly — bir buyruqli o'rnatuvchi (macOS 13+, Apple Silicon va Intel).
#   ./setup.sh                                   # kutubxonalar → rus/ingliz modeli → ilova
#   OZBEK=1 ./setup.sh                           # + oʻzbek modeli (rubaiSTT)
#   FAQAT_KUTUBXONALAR=1 UNIVERSAL=0 ./setup.sh  # CI: faqat kutubxonalar
#
# whisper.cpp aniq commit'ga pinlangan (`scripts/bogliqliklar.env`) — toza
# mashinada ham sinalgan kod yigʻiladi.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/bogliqliklar.sh
source "$ROOT/scripts/bogliqliklar.sh"
WC="$ROOT/whisper.cpp"
# Rus/ingliz modeli — ilova oʻzi yuklaydigan joyga (Yollar.foydalanuvchiModellari).
RU_DIR="$HOME/Library/Application Support/Voxly/models"
RU_MODEL="$RU_DIR/$RU_MODEL_NOM"
# Oʻzbek modeli (ixtiyoriy, OZBEK=1) — eski dasturchi yoʻli, ilova u yerdan ham qidiradi.
MODELDIR="$HOME/rubai-stt/models"
MODEL="$MODELDIR/ggml-rubaistt.bin"       # q8_0 (~820MB)
MODEL_F16="$MODELDIR/ggml-rubaistt-f16.bin"
# Tayyor q8_0 ggml model (CDN). Bo'sh bo'lsa — HF'dan konversiya + quant qilinadi.
MODEL_URL="${MODEL_URL-$MODEL_CDN_URL}"

echo "==> Voxly o'rnatilmoqda"

# 1) Talablar
if ! xcode-select -p >/dev/null 2>&1; then
    echo "Xcode Command Line Tools kerak. O'rnatish: xcode-select --install" >&2; exit 1
fi
# cmake: Homebrew boʻlsa — brew orqali, boʻlmasa pip (admin paroli kerak emas).
PIP_BIN="$(python3 -c 'import site; print(site.USER_BASE)' 2>/dev/null)/bin"
[ -x "$PIP_BIN/cmake" ] && export PATH="$PIP_BIN:$PATH"
if ! command -v cmake >/dev/null 2>&1; then
    echo "==> cmake o'rnatilmoqda"
    if command -v brew >/dev/null 2>&1; then
        brew install cmake
    else
        python3 -m pip install --user --quiet cmake
        export PATH="$PIP_BIN:$PATH"
    fi
fi

# Intel Mac'da: faqat x86_64, shu protsessor uchun (GGML_NATIVE=ON — AVX2/FMA,
# GGML_BLAS — Accelerate: encoder 2 baravar tez, i7-9750H da 7,6 s → 4,0 s;
# rasmiy universal build'dagi x86_64 qismi NATIVE=OFF, ancha sekin). arm64
# kutubxonalari bu mashinada kerak emas.
INTEL_XOST=0
[ "$(uname -m)" = "x86_64" ] && INTEL_XOST=1
# ffmpeg KERAK EMAS: audio/video dekodlash AVFoundation orqali
# (`src/media_decode.swift`). Ilgari bu yerda keraksiz oʻrnatilardi.

# 2) whisper.cpp (Metal, statik)
bogliqlik_tayyorla "$WC" "$WHISPER_URL" "$WHISPER_COMMIT"
if [ "$INTEL_XOST" = 1 ] && [ ! -f "$WC/build-x64/src/libwhisper.a" ]; then
    echo "==> whisper.cpp build (Intel, CPU, AVX2)..."
    cmake -S "$WC" -B "$WC/build-x64" \
        -DCMAKE_OSX_ARCHITECTURES=x86_64 -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 -DCMAKE_BUILD_TYPE=Release \
        -DGGML_NATIVE=ON -DGGML_METAL=OFF -DBUILD_SHARED_LIBS=OFF \
        -DWHISPER_BUILD_EXAMPLES=OFF -DWHISPER_BUILD_TESTS=OFF \
        -DGGML_BLAS=ON -DGGML_BLAS_VENDOR=Apple
    nice -n 10 cmake --build "$WC/build-x64" --config Release -j4 --target whisper
fi
if [ "$INTEL_XOST" = 0 ] && [ ! -f "$WC/build-static/src/libwhisper.a" ]; then
    echo "==> whisper.cpp build (Metal)..."
    cmake -S "$WC" -B "$WC/build-static" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
        -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON -DBUILD_SHARED_LIBS=OFF \
        -DWHISPER_BUILD_EXAMPLES=OFF -DWHISPER_BUILD_TESTS=OFF -DGGML_BLAS=OFF
    nice -n 10 cmake --build "$WC/build-static" --config Release -j4 --target whisper
fi

# 2b) x86_64 (Intel) statik — universal ilova uchun (CPU, Metal'siz). Faqat Apple Silicon'da cross-compile.
if [ "$(uname -m)" = "arm64" ] && [ "${UNIVERSAL:-1}" = "1" ] && [ ! -f "$WC/build-x64/src/libwhisper.a" ]; then
    echo "==> whisper.cpp x86_64 (Intel, CPU) build..."
    cmake -S "$WC" -B "$WC/build-x64" \
        -DCMAKE_OSX_ARCHITECTURES=x86_64 -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
        -DGGML_NATIVE=OFF -DGGML_METAL=OFF -DBUILD_SHARED_LIBS=OFF \
        -DWHISPER_BUILD_EXAMPLES=OFF -DWHISPER_BUILD_TESTS=OFF -DGGML_BLAS=OFF
    nice -n 10 cmake --build "$WC/build-x64" --config Release -j4 --target whisper
fi

# CI va tekshiruv uchun: faqat kutubxonalar — model yuklanmaydi, ilova
# oʻrnatilmaydi. `UNIVERSAL=0` x86_64 nusxasini oʻtkazib yuboradi.
if [ "${FAQAT_KUTUBXONALAR:-0}" = "1" ]; then
    echo "==> Kutubxonalar tayyor (FAQAT_KUTUBXONALAR=1 — model va ilova oʻtkazib yuborildi)"
    exit 0
fi

# 3) Rus/ingliz modeli — Whisper large-v3-turbo q5_0 (HuggingFace, MIT).
# `.part` ga yuklanadi, sha256 mos kelsagina asl nomga koʻchadi.
if [ ! -f "$RU_MODEL" ]; then
    mkdir -p "$RU_DIR"
    echo "==> Model yuklanmoqda: $RU_MODEL_NOM (~550 MB)"
    curl -fL --progress-bar -o "$RU_MODEL.part" "$RU_MODEL_URL"
    hash="$(shasum -a 256 "$RU_MODEL.part" | cut -d' ' -f1)"
    if [ "$hash" != "$RU_MODEL_SHA256" ]; then
        rm -f "$RU_MODEL.part"
        echo "Xato: model sha256 mos emas (kutilgan $RU_MODEL_SHA256, olingan $hash)" >&2
        exit 1
    fi
    mv "$RU_MODEL.part" "$RU_MODEL"
    echo "==> Model yuklandi, sha256 mos ✓"
fi

# 3b) Oʻzbek modeli (OZBEK=1) — avval CDN'dan tayyor q8_0, boʻlmasa HuggingFace'dan + quant.
#
# Yuklash `.part` ga ketadi va sha256 tekshirilgandan keyingina asl nomga
# koʻchadi: ilova modelni shu nom bilan qidiradi, chala yoki buzilgan fayl
# esa «Model yuklanmadi» bilan yiqiladi.
if [ "${OZBEK:-0}" = "1" ] && [ ! -f "$MODEL" ]; then
    mkdir -p "$MODELDIR"
    if [[ "$MODEL_URL" == http* ]] && curl -fL --progress-bar -o "$MODEL.part" "$MODEL_URL"; then
        hash="$(shasum -a 256 "$MODEL.part" | cut -d' ' -f1)"
        if [ "$hash" != "$MODEL_SHA256" ]; then
            rm -f "$MODEL.part"
            echo "Xato: yuklangan model sha256 mos emas — fayl buzilgan yoki boshqa." >&2
            echo "  kutilgan: $MODEL_SHA256" >&2
            echo "  olingan:  $hash" >&2
            exit 1
        fi
        mv "$MODEL.part" "$MODEL"
        echo "==> Model (q8_0, yengil) CDN'dan yuklandi, sha256 mos ✓"
    else
        echo "==> CDN'dan olinmadi — HuggingFace'dan yuklab konversiya qilinmoqda"
        echo "    (ochiq model, token shart emas; biroz vaqt oladi)..."
        rm -f "$MODEL" "$MODEL.part"
        # f16 ga o'giradi -> $MODEL_F16
        bash "$ROOT/scripts/convert_model.sh"
        # quantize vositasini build qilib, f16 -> q8_0 ga siqamiz (kamroq RAM/disk)
        echo "==> Model q8_0 ga quantize qilinmoqda (kamroq RAM)..."
        if [ ! -x "$WC/build-quant/bin/whisper-quantize" ]; then
            cmake -S "$WC" -B "$WC/build-quant" \
                -DWHISPER_BUILD_EXAMPLES=ON -DWHISPER_BUILD_TESTS=OFF \
                -DGGML_METAL=OFF -DGGML_BLAS=OFF >/dev/null
            nice -n 10 cmake --build "$WC/build-quant" --target whisper-quantize -j4
        fi
        "$WC/build-quant/bin/whisper-quantize" "$MODEL_F16" "$MODEL" q8_0
        rm -f "$MODEL_F16"   # f16 zaxira kerak emas — diskni bo'shatamiz
    fi
fi

# 4) Ilovani build qilish
echo "==> Ilova build qilinmoqda..."
bash "$ROOT/src/build.sh"

# 5) Avto-ishga tushish
# setup.sh endi oʻz LaunchAgent'ini OʻRNATMAYDI. Ilova login'da ishga tushishni
# .app ichidagi LaunchAgent orqali (SMAppService) oʻzi boshqaradi — birinchi
# ishga tushishda roʻyxatdan oʻtadi. Ikkita agent qolsa login'da ikki nusxa
# yonardi, shuning uchun eskisi bor boʻlsa olib tashlanadi.
ESKI_PLIST="$HOME/Library/LaunchAgents/com.rubaistt.dictation.plist"
if [ -f "$ESKI_PLIST" ]; then
    launchctl bootout "gui/$(id -u)" "$ESKI_PLIST" 2>/dev/null || true
    rm -f "$ESKI_PLIST"
    echo "==> Eski LaunchAgent olib tashlandi (ilova endi buni oʻzi boshqaradi)"
fi

echo ""
echo "✅ O'rnatildi: ~/Applications/Voxly.app — menyu-barda ikonka paydo boʻladi."
echo ""
echo "Oxirgi qadam — Accessibility ruxsati (matnni kursor turgan joyga qoʻyish uchun):"
echo "  System Settings → Privacy & Security → Accessibility → Voxly ni yoqing"
echo ""
echo "Har yigʻishda ruxsat tushib qolmasligi uchun keyingi build'larni"
echo "  ./scripts/mahalliy-yigish.sh  bilan qiling (doimiy mahalliy imzo)."
