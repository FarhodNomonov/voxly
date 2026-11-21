@echo off
rem Windows tomonining sinov skripti. D: diskidan ishga tushiriladi.
d:
echo === 1. Sof mantiq testlari ===
voxly-testlar.exe
echo.
echo === 2. Yadro: WAV fayldan transkripsiya ===
rubai-cli.exe jfk.wav --model d:\models\ggml-rubaistt.bin
echo.
echo === 3. Media Foundation dekoderi (MP3) ===
rubai-cli.exe jfk.mp3 --model d:\models\ggml-rubaistt.bin
echo.
echo === 4. Studiya yoli: segmentlar + matn formatlash ===
rubai-cli.exe jfk.wav --segmentlar --model d:\models\ggml-rubaistt.bin
echo.
echo === Hammasi tugadi ===
