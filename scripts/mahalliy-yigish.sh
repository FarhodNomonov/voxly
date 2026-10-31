#!/bin/bash
# Kotib'ni shu Mac uchun yigʻadi va DOIMIY mahalliy imzo bilan imzolaydi.
#
# Nega: Developer ID sertifikati yoʻq boʻlsa build.sh ad-hoc imzoga tushadi va
# macOS (TCC) Accessibility ruxsatini cdhash'ga bogʻlaydi — har yigʻishdan
# keyin ruxsat jimgina tushib qolardi. Oʻz-oʻzidan imzolangan sertifikat bilan
# designated requirement «certificate leaf = H"…"» boʻladi va keyingi
# yigʻishlarda ham oʻzgarmaydi.
#
# Sertifikat alohida keychain'da (kotib-imzo.keychain-db) — login keychain'ga
# tegilmaydi, GUI soʻrovi chiqmaydi. Paroli: ~/.kotib-imzo/parol (faqat egasi
# oʻqiy oladi). Tarqatish uchun YARAMAYDI — faqat shu Mac uchun.
#
#   ./scripts/mahalliy-yigish.sh            # yigʻish → ~/Applications/Kotib.app
#   APP_OUT=/Applications/Kotib.app ./scripts/mahalliy-yigish.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NOM="Kotib Local Signing"
D="$HOME/.kotib-imzo"
KC="$HOME/Library/Keychains/kotib-imzo.keychain-db"

if [ ! -f "$KC" ] || [ ! -f "$D/parol" ]; then
    echo "==> Mahalliy imzo sertifikati yaratilmoqda ($NOM)"
    mkdir -p "$D" && chmod 700 "$D"
    PAROL="$(openssl rand -hex 16)"
    (umask 077 && printf '%s\n' "$PAROL" > "$D/parol")
    VAQT="$(mktemp -d)"
    trap 'rm -rf "$VAQT"' EXIT
    openssl req -x509 -newkey rsa:2048 -keyout "$VAQT/key.pem" -out "$D/cert.pem" \
        -days 3650 -nodes -subj "/CN=$NOM" \
        -addext "extendedKeyUsage=critical,codeSigning" \
        -addext "keyUsage=critical,digitalSignature" \
        -addext "basicConstraints=critical,CA:false" 2>/dev/null
    openssl pkcs12 -export -inkey "$VAQT/key.pem" -in "$D/cert.pem" -out "$VAQT/imzo.p12" \
        -passout pass:"$PAROL" -name "$NOM" 2>/dev/null
    rm -f "$KC"
    security create-keychain -p "$PAROL" "$KC"
    security set-keychain-settings "$KC"
    security unlock-keychain -p "$PAROL" "$KC"
    security import "$VAQT/imzo.p12" -k "$KC" -P "$PAROL" -T /usr/bin/codesign >/dev/null
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PAROL" "$KC" >/dev/null
fi

# Qayta yuklashdan keyin keychain qulflangan boʻladi; qidiruv roʻyxatida ham boʻlsin.
security unlock-keychain -p "$(cat "$D/parol")" "$KC"
if ! security list-keychains -d user | grep -q "kotib-imzo"; then
    # shellcheck disable=SC2046  # roʻyxat ataylab soʻzlarga boʻlinadi
    security list-keychains -d user -s $(security list-keychains -d user | tr -d '"') "$KC"
fi

XESH="$(security find-identity -p codesigning "$KC" | sed -n 's/.*) \([0-9A-F]\{40\}\) ".*/\1/p' | head -1)"
[ -n "$XESH" ] || { echo "Xato: '$NOM' sertifikati topilmadi" >&2; exit 1; }

CODESIGN_IDENTITY="$XESH" exec bash "$ROOT/src/build.sh"
