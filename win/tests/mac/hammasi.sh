#!/usr/bin/env bash
#
# Windows tomonini macOS'da tekshiradigan HAMMA narsani ishga tushiradi.
#
#   ./win/tests/mac/hammasi.sh
#
# Kundalik ishda shu bitta buyruq yetadi. Windows mashina yoki VM faqat
# UI'ni va Win32 qatlamini sinash uchun kerak boʻladi.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
xato=0

bolim() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

bolim "Versiya (VERSION hamma joyda mosmi)"
"$ROOT/scripts/versiya-tekshir.sh" || xato=1

bolim "Birlik testlari"
"$ROOT/win/tests/mac/sinov.sh" || xato=1

bolim "whisper va VAD parametrlari, ovozni boʻlaklash"
"$ROOT/win/tests/mac/parametr-tekshir.sh" || xato=1

bolim "Matn formatlash — korpus"
"$ROOT/win/tests/mac/taqqoslash/taqqosla.sh" || xato=1

printf '\n'
if [ "$xato" = 0 ]; then
    echo "✓ Hammasi oʻtdi"
else
    echo "✗ Xato bor" >&2
fi
exit "$xato"
