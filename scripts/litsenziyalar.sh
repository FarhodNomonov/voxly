#!/usr/bin/env bash
#
# Ilova bilan tarqatiladigan `Litsenziyalar.txt` ni yasaydi: Voxly litsenziyasi,
# `THIRD_PARTY_NOTICES.md` (jadval) va har bir statik ulangan / birga
# tarqatiladigan komponentning TOʻLIQ litsenziya matni — pinlangan manbalarning
# oʻz LICENSE fayllaridan. Matnlar qoʻlda koʻchirilmaydi: bogʻliqlik yangilansa,
# fayl ham oʻzi yangilanadi.
#
#   ./scripts/litsenziyalar.sh <chiqish-fayli>        # macOS: whisper.cpp + modellar
#   ./scripts/litsenziyalar.sh <chiqish-fayli> win    # Windows: + LLVM/mingw ish vaqti kutubxonalari
#
# `src/build.sh` (→ Contents/Resources) va `win/build-mac.sh` (→ exe yonida)
# chaqiradi. Oflayn tarjimon (CTranslate2, SentencePiece, NLLB) ikkala platformadan olib tashlangan. Manba yetishmasa — xato: litsenziyasiz binar tarqatilmasin.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHIQISH="${1:?Ishlatish: $0 <chiqish-fayli> [win]}"
WIN=0
[ "${2:-}" = "win" ] && WIN=1

# Sarlavha va fayl — tartib bilan. Yoʻl ROOT ga nisbatan.
BOLIMLAR=(
    "Voxly|LICENSE"
    "whisper.cpp / ggml|whisper.cpp/LICENSE"
)

for b in "${BOLIMLAR[@]}"; do
    f="$ROOT/${b#*|}"
    [ -f "$f" ] || { echo "Xato: litsenziya fayli yoʻq: ${b#*|} (avval ./setup.sh)" >&2; exit 1; }
done

{
    echo "VOXLY — LITSENZIYALAR / LICENSES"
    echo "================================"
    echo
    cat "$ROOT/THIRD_PARTY_NOTICES.md"
    for b in "${BOLIMLAR[@]}"; do
        echo
        echo
        echo "────────────────────────────────────────────────────────────────"
        echo "${b%%|*}"
        echo "────────────────────────────────────────────────────────────────"
        echo
        cat "$ROOT/${b#*|}"
    done
    # Litsenziyasi alohida faylda emas, manba sarlavhasida turganlar (faqat Windows).
    if [ "$WIN" = 1 ]; then
        echo
        echo
        echo "────────────────────────────────────────────────────────────────"
        echo "LLVM libc++ / libunwind / OpenMP, mingw-w64 (faqat Windows)"
        echo "────────────────────────────────────────────────────────────────"
        echo
        echo "Apache License v2.0 with LLVM Exceptions — https://llvm.org/LICENSE.txt"
        echo "mingw-w64 runtime — https://sourceforge.net/p/mingw-w64/mingw-w64/ci/master/tree/COPYING"
        echo
    fi
    echo
    echo "────────────────────────────────────────────────────────────────"
    echo "Modellar / Models"
    echo "────────────────────────────────────────────────────────────────"
    echo
    echo "rubaiSTT v2 medium — islomov — Apache License 2.0"
    echo "  https://huggingface.co/islomov/rubaistt_v2_medium"
    echo "  https://www.apache.org/licenses/LICENSE-2.0"
    echo "OpenAI Whisper (large-v3-turbo, medium) — MIT — https://github.com/openai/whisper/blob/main/LICENSE"
    echo "  ggml nusxasi: https://huggingface.co/ggerganov/whisper.cpp"
    echo
    echo "────────────────────────────────────────────────────────────────"
    echo "Silero VAD (ggml-silero-v6.2.0.bin, ilova bilan birga)"
    echo "  https://github.com/snakers4/silero-vad · https://huggingface.co/ggml-org/whisper-vad"
    echo "────────────────────────────────────────────────────────────────"
    echo
    # MIT matni whisper.cpp LICENSE dagi bilan bir xil — faqat mualliflik qatori boshqa.
    sed 's/^Copyright.*/Copyright (c) 2020-present Silero Team/' "$ROOT/whisper.cpp/LICENSE"
} > "$CHIQISH"
