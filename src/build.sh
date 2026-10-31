#!/bin/bash
# Voxly — native macOS ilovasini yigʻadi → ~/Applications/Voxly.app
#
# whisper.cpp statik kutubxonalari kerak (setup.sh tayyorlaydi):
#   Apple Silicon: whisper.cpp/build-static (Metal) [+ build-x64 — universal]
#   Intel:         whisper.cpp/build-x64 (CPU, AVX2)
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SRC/.." && pwd)"
# Versiya — `VERSION` faylidan (yagona manba), Info.plist ga quyida yoziladi.
# shellcheck source=../scripts/versiya.sh
source "$ROOT/scripts/versiya.sh"
# shellcheck source=../scripts/bogliqliklar.sh
source "$ROOT/scripts/bogliqliklar.sh"

NOM="Voxly"
BUNDLE_ID="app.voxly.mac"
WC="$ROOT/whisper.cpp"
# Silero VAD (S12) — bundle ichida (885 KB). Pinlangan, sha256 bilan.
VAD="$ROOT/vad/$VAD_NOM"
vad_tayyorla "$VAD"
LIB_ARM="$WC/build-static"   # arm64 — Metal GPU
LIB_X64="$WC/build-x64"      # x86_64 — faqat CPU (Intel)
APP="${APP_OUT:-$HOME/Applications/$NOM.app}"

# Qaysi arxitekturalar: Intel mashinada — faqat x86_64 (shu protsessor uchun);
# Apple Silicon'da — arm64, x86_64 kutubxonasi boʻlsa universal.
ARCHS=()
if [ "$(uname -m)" = "x86_64" ]; then
    [ -f "$LIB_X64/src/libwhisper.a" ] || { echo "Xato: $LIB_X64 yoʻq. Avval ./setup.sh" >&2; exit 1; }
    ARCHS=("x86_64")
else
    [ -f "$LIB_ARM/src/libwhisper.a" ] || { echo "Xato: $LIB_ARM yoʻq. Avval ./setup.sh" >&2; exit 1; }
    ARCHS=("arm64")
    if [ -f "$LIB_X64/src/libwhisper.a" ]; then
        ARCHS+=("x86_64")
    else
        echo "⚠ Faqat arm64: whisper.cpp/build-x64 yoʻq — Intel Mac'larda ishga tushmaydi." >&2
    fi
fi

SWIFT_SRCS=("$SRC"/*.swift)

COMMON_FW="-framework Foundation -framework Accelerate -framework AVFoundation \
    -framework AppKit -framework QuartzCore -framework CoreGraphics \
    -framework Carbon -framework ApplicationServices -framework ServiceManagement"

echo "[1/3] Kompilyatsiya + linking (${ARCHS[*]})..."
EXES=()
for ARCH in "${ARCHS[@]}"; do
    if [ "$ARCH" = "arm64" ]; then
        LIB="$LIB_ARM"; TRIPLE="arm64-apple-macos13.0"
        METAL="-Xlinker -force_load -Xlinker $LIB/ggml/src/ggml-metal/libggml-metal.a \
            -framework Metal -framework MetalKit"
    else
        LIB="$LIB_X64"; TRIPLE="x86_64-apple-macos13.0"; METAL=""
    fi
    echo "  -> $ARCH"
    clang -c "$SRC/whisper_bridge.c" -arch "$ARCH" -O2 -mmacosx-version-min=13.0 \
        -I"$WC/include" -I"$WC/ggml/include" -o "$SRC/whisper_bridge.$ARCH.o"
    clang -c "$SRC/nutq_bolaklari.c" -arch "$ARCH" -O2 -mmacosx-version-min=13.0 \
        -o "$SRC/nutq_bolaklari.$ARCH.o"
    # shellcheck disable=SC2086  # $METAL va $COMMON_FW — bayroqlar roʻyxati, ataylab boʻlinadi
    swiftc -O -target "$TRIPLE" "${SWIFT_SRCS[@]}" \
        "$SRC/whisper_bridge.$ARCH.o" "$SRC/nutq_bolaklari.$ARCH.o" \
        -import-objc-header "$SRC/Bridging.h" \
        "$LIB/src/libwhisper.a" \
        "$LIB/ggml/src/libggml.a" \
        "$LIB/ggml/src/libggml-base.a" \
        -Xlinker -force_load -Xlinker "$LIB/ggml/src/libggml-cpu.a" \
        $METAL $COMMON_FW -lc++ \
        -o "$SRC/$NOM.$ARCH"
    EXES+=("$SRC/$NOM.$ARCH")
done

if [ ${#EXES[@]} -gt 1 ]; then
    lipo -create "${EXES[@]}" -output "$SRC/$NOM"
else
    cp "${EXES[0]}" "$SRC/$NOM"
fi
rm -f "$SRC"/whisper_bridge.*.o "$SRC"/nutq_bolaklari.*.o "$SRC/$NOM".arm64 "$SRC/$NOM".x86_64

echo "[2/3] .app bundle..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv "$SRC/$NOM" "$APP/Contents/MacOS/$NOM"
cp "$ROOT/assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$VAD" "$APP/Contents/Resources/$VAD_NOM"
# Oʻchirish skripti ilova ichida keladi — Sozlamalardagi «Удалить…» shu faylni
# koʻrsatadi (u sudo talab qiladi, ilova uni oʻzi bajarmaydi).
cp "$ROOT/scripts/uninstall.sh" "$APP/Contents/Resources/uninstall.sh"
chmod +x "$APP/Contents/Resources/uninstall.sh"
"$ROOT/scripts/litsenziyalar.sh" "$APP/Contents/Resources/Litsenziyalar.txt"
# Info.plist matnlari (mikrofon soʻrovi) — tillar boʻyicha.
for til in en ru; do
    mkdir -p "$APP/Contents/Resources/$til.lproj"
    cp "$SRC/lproj/$til/InfoPlist.strings" "$APP/Contents/Resources/$til.lproj/"
done

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${NOM}</string>
    <key>CFBundleDisplayName</key><string>${NOM}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key><string>${KOTIB_VERSIYA}</string>
    <key>CFBundleShortVersionString</key><string>${KOTIB_VERSIYA}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleExecutable</key><string>${NOM}</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array><string>en</string><string>ru</string></array>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSMicrophoneUsageDescription</key><string>Voxly needs the microphone to turn your speech into text.</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key><string>Audio and video</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.audio</string>
                <string>public.movie</string>
            </array>
            <key>LSHandlerRank</key><string>Alternate</string>
        </dict>
    </array>
</dict>
</plist>
PLIST

# Login'da ishga tushirish uchun LaunchAgent (avtostart.swift). Label fayl nomi
# bilan bir xil boʻlishi SHART — SMAppService.agent(plistName:) shuni qidiradi.
mkdir -p "$APP/Contents/Library/LaunchAgents"
cat > "$APP/Contents/Library/LaunchAgents/${BUNDLE_ID}.autostart.plist" <<AGENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>${BUNDLE_ID}.autostart</string>
  <key>BundleProgram</key><string>Contents/MacOS/${NOM}</string>
  <key>ProgramArguments</key>
  <array>
    <string>Contents/MacOS/${NOM}</string>
    <string>--autostart</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
  <key>ProcessType</key><string>Interactive</string>
  <key>AssociatedBundleIdentifiers</key><array><string>${BUNDLE_ID}</string></array>
</dict></plist>
AGENT

# TCC (Accessibility/Mikrofon) ruxsati imzo KIMLIGIGA bogʻlanadi. Ad-hoc imzoda
# u cdhash'ga bogʻlanadi va har build'dan keyin tushib qoladi — shuning uchun
# Developer ID yoki doimiy mahalliy imzo (scripts/mahalliy-yigish.sh).
IDENT="${CODESIGN_IDENTITY:-}"
if [ -z "$IDENT" ]; then
    IDENT=$(security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1) || true
fi
if [ -n "$IDENT" ]; then
    echo "[3/3] Imzolash: $IDENT"
    SIGN_ARGS=(--force --timestamp=none --sign "$IDENT")
else
    echo "[3/3] Ad-hoc imzolash (sertifikat topilmadi)"
    echo "  DIQQAT: Accessibility ruxsati har build'dan keyin tushadi — scripts/mahalliy-yigish.sh" >&2
    SIGN_ARGS=(--force --sign -)
fi
xattr -cr "$APP" 2>/dev/null || true
codesign "${SIGN_ARGS[@]}" --entitlements "$SRC/entitlements.plist" "$APP" 2>/dev/null \
    || codesign "${SIGN_ARGS[@]}" "$APP"

echo "Tayyor: $APP  (versiya $KOTIB_VERSIYA)"
