cmake_minimum_required(VERSION 3.21)
project(Voxly LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)

# Ikkita build yo'li bor va ikkalasi ham qo'llab-quvvatlanadi:
#   1. Windows'da MSVC bilan     — win/build.ps1
#   2. macOS'da llvm-mingw bilan — win/build-mac.sh (cross-compile)
# Ikkinchisi asosiy yo'l: butun ishlab chiqish MacBook'da ketadi.
if(MSVC)
    # /utf-8 — manba fayllar UTF-8 da (o'zbekcha izohlar va UI matnlari).
    # Busiz MSVC ularni tizim kod sahifasida o'qib buzadi.
    add_compile_options(/utf-8 /W4 /permissive-)
else()
    add_compile_options(-Wall -Wextra -finput-charset=UTF-8 -fexec-charset=UTF-8)
    # -municode: WinMain o'rniga wWinMain (UTF-16 argv) kirish nuqtasi bo'lsin.
    # -static: libc++/libunwind DLL'lari kerak bo'lmasin — bitta mustaqil .exe.
    add_link_options(-municode -static)
endif()
# Eng past qo'llab-quvvatlanadigan tizim — Windows 10 1809 (build 17763), win/README.md
# dagi talab bilan bir xil. mingw sarlavhalari yangi API'larni (masalan
# SetProcessDpiAwarenessContext) aynan shu bayroqlar ostida ochadi; MSVC ularni
# o'zi qo'yadi, shuning uchun u yerda bu faqat aniqlik kiritadi.
add_compile_definitions(UNICODE _UNICODE NOMINMAX WIN32_LEAN_AND_MEAN
                        WINVER=0x0A00 _WIN32_WINNT=0x0A00 NTDDI_VERSION=0x0A000006)

# -------------------------------------------------------------------- versiya
#
# Yagona manba — repo ildizidagi `VERSION` (macOS build.sh va make_pkg.sh ham
# shundan oladi). Undan `kotib_versiya.h` yaratiladi va app.rc uni ishlatadi.
# CMAKE_CONFIGURE_DEPENDS: VERSION oʻzgarsa build oʻzi qayta konfiguratsiya
# qilinadi — eski raqam .exe ichida qolib ketmaydi.
set(KOTIB_VERSION_FILE "${CMAKE_CURRENT_SOURCE_DIR}/../VERSION")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${KOTIB_VERSION_FILE}")
file(STRINGS "${KOTIB_VERSION_FILE}" KOTIB_VERSIYA LIMIT_COUNT 1)
string(STRIP "${KOTIB_VERSIYA}" KOTIB_VERSIYA)
if(NOT KOTIB_VERSIYA MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)(-[0-9A-Za-z.]+)?$")
    message(FATAL_ERROR "VERSION notoʻgʻri: '${KOTIB_VERSIYA}' (kutilgan: 1.2.0 yoki 1.2.0-sinov1)")
endif()
set(KOTIB_VER_KATTA    "${CMAKE_MATCH_1}")
set(KOTIB_VER_KICHIK   "${CMAKE_MATCH_2}")
set(KOTIB_VER_TUZATISH "${CMAKE_MATCH_3}")
# Windows versiya resursida har raqam 16 bitlik.
foreach(_qism KOTIB_VER_KATTA KOTIB_VER_KICHIK KOTIB_VER_TUZATISH)
    if(${_qism} GREATER 65535)
        message(FATAL_ERROR "VERSION: ${${_qism}} > 65535 — Windows versiya resursiga sigʻmaydi")
    endif()
endforeach()
configure_file(res/kotib_versiya.h.in "${CMAKE_CURRENT_BINARY_DIR}/gen/kotib_versiya.h" @ONLY)
message(STATUS "Voxly versiyasi: ${KOTIB_VERSIYA}")
# Bogʻliqlik QOʻLDA koʻrsatiladi: llvm-windres `.rc` uchun depfile yozmaydi
# (CMake uni kutadi, lekin fayl hech qachon paydo boʻlmaydi), shuning uchun
# Ninja app.rc ning `#include` va manifestini bilmaydi. Sinovda tutildi:
# VERSION oʻzgardi, sarlavha yangilandi, .exe esa eski versiya bilan qoldi.
set_source_files_properties(res/app.rc PROPERTIES OBJECT_DEPENDS
    "${CMAKE_CURRENT_BINARY_DIR}/gen/kotib_versiya.h;${CMAKE_CURRENT_SOURCE_DIR}/res/app.manifest")

# ---------------------------------------------------------------- whisper.cpp
#
# Tashqi whisper.cpp build papkasi. setup skripti uni Vulkan + backend DL +
# barcha CPU variantlari bilan yig'adi (eski protsessorlarda ham ishlashi uchun).
set(WHISPER_ROOT "" CACHE PATH "whisper.cpp manba papkasi")
set(WHISPER_BUILD "" CACHE PATH "whisper.cpp build papkasi (Release)")

if(NOT WHISPER_ROOT OR NOT WHISPER_BUILD)
    message(FATAL_ERROR
        "WHISPER_ROOT va WHISPER_BUILD ko'rsatilishi kerak.\n"
        "Masalan: -DWHISPER_ROOT=D:/whisper.cpp -DWHISPER_BUILD=D:/whisper.cpp/build-vulkan")
endif()

find_library(WHISPER_LIB   whisper   PATHS "${WHISPER_BUILD}/src/Release"      "${WHISPER_BUILD}/Release" "${WHISPER_BUILD}/src"      REQUIRED NO_DEFAULT_PATH)
find_library(GGML_LIB      ggml      PATHS "${WHISPER_BUILD}/ggml/src/Release" "${WHISPER_BUILD}/Release" "${WHISPER_BUILD}/ggml/src" REQUIRED NO_DEFAULT_PATH)
find_library(GGML_BASE_LIB ggml-base PATHS "${WHISPER_BUILD}/ggml/src/Release" "${WHISPER_BUILD}/Release" "${WHISPER_BUILD}/ggml/src" REQUIRED NO_DEFAULT_PATH)

# Statik build'da (cross-compile) CPU backend'i alohida kutubxona bo'lib chiqadi va
# uni qo'lda ulash kerak — MSVC'ning DLL yo'lida u ggml ichida keladi.
find_library(GGML_CPU_LIB  ggml-cpu  PATHS "${WHISPER_BUILD}/ggml/src" "${WHISPER_BUILD}/ggml/src/Release" NO_DEFAULT_PATH)
find_library(PARAKEET_LIB  parakeet  PATHS "${WHISPER_BUILD}/src"      "${WHISPER_BUILD}/src/Release"      NO_DEFAULT_PATH)

# Vulkan (GPU) backend'i. Statik build'da uni ALOHIDA ulash kerak — DLL yo'lida
# ggml uni ish paytida o'zi yuklaydi, statik yo'lda esa linker ko'rmasa
# backend ro'yxatga umuman tushmaydi va ilova jimgina protsessorda ishlaydi.
# vulkan-1 — Windows Vulkan yuklovchisining import kutubxonasi; drayver bo'lmasa
# ggml buni ish paytida aniqlaydi va CPU'ga tushadi, ilova ishdan chiqmaydi.
find_library(GGML_VULKAN_LIB ggml-vulkan
             PATHS "${WHISPER_BUILD}/ggml/src/ggml-vulkan"
                   "${WHISPER_BUILD}/ggml/src/ggml-vulkan/Release" NO_DEFAULT_PATH)
if(GGML_VULKAN_LIB AND NOT MSVC)
    if(CMAKE_SYSTEM_PROCESSOR STREQUAL "ARM64")
        set(VULKAN_IMPORT_LIB "${CMAKE_CURRENT_SOURCE_DIR}/cmake/vulkan-lib/libvulkan-1-arm64.a")
    else()
        set(VULKAN_IMPORT_LIB "${CMAKE_CURRENT_SOURCE_DIR}/cmake/vulkan-lib/libvulkan-1-x64.a")
    endif()
endif()

set(GGML_EXTRA_LIBS "")
foreach(_lib "${GGML_CPU_LIB}" "${GGML_VULKAN_LIB}" "${VULKAN_IMPORT_LIB}" "${PARAKEET_LIB}")
    if(_lib)
        list(APPEND GGML_EXTRA_LIBS "${_lib}")
    endif()
endforeach()

# --------------------------------------------------------------------- core

add_library(rubai_core STATIC
    core/whisper_bridge.c
    core/nutq_bolaklari.c
    core/util.cpp
    core/samples.cpp
    core/config.cpp
    core/engine.cpp
    core/wav.cpp
    core/audio_capture.cpp
    core/versiya.cpp
    core/matn_format.cpp
    core/media_decode.cpp
    core/json.cpp
    core/hujjat.cpp
    core/ish.cpp
    core/tarix.cpp
    core/saqlanmagan.cpp
    core/llm.cpp
    core/llm_sof.cpp
    core/amallar.cpp
    core/vaqt_format.cpp
    core/yuklovchi.cpp
    core/model_yuklovchi.cpp
)

target_include_directories(rubai_core PUBLIC
    core
    # kotib_versiya.h — toʻliq versiya satri
    "${CMAKE_CURRENT_BINARY_DIR}/gen"
    "${WHISPER_ROOT}/include"
    "${WHISPER_ROOT}/ggml/include"
)

target_link_libraries(rubai_core PUBLIC
    "${WHISPER_LIB}" "${GGML_LIB}" "${GGML_BASE_LIB}" ${GGML_EXTRA_LIBS}
    shell32     # SHGetKnownFolderPath
    ole32       # COM (WASAPI)
    propsys     # PKEY_* qurilma xossalari
    winhttp     # model yuklash va LLM
    bcrypt      # SHA-256 — model fayli tekshiruvi
    credui      # API kalit — Credential Manager
    advapi32
    mfplat      # Media Foundation — audio/video dekodlash
    mfreadwrite
    mfuuid
    propsys
)

# KSDATAFORMAT_SUBTYPE_IEEE_FLOAT GUID'i. MSVC uni o'zining uuid.lib'idan oladi,
# mingw'da esa u alohida ksuser kutubxonasida yotadi.
if(NOT MSVC)
    target_link_libraries(rubai_core PUBLIC ksuser)
endif()

# ------------------------------------------------------------------- vosita

add_executable(rubai-cli tools/rubai_cli.cpp)
target_link_libraries(rubai-cli PRIVATE rubai_core)

# ------------------------------------------------------------------- testlar
#
# macOS'dagi `src/test.sh` ning ekvivalenti. Sof mantiq (matn formatlash,
# JSON, sozlamalar) ikkala platformada BIR XIL natija berishi shart —
# buni faqat test ushlab turadi.
#
# Windows binarisi, shuning uchun macOS'da ishlamaydi: uni VM'da yoki
# Windows mashinada ishga tushiring.

add_executable(voxly-testlar
    tests/main.cpp
    tests/test_matn_format.cpp
    tests/test_json.cpp
    tests/test_llm.cpp
    tests/test_vaqt_format.cpp
    tests/test_saqlanmagan.cpp
    tests/test_sozlama.cpp
    tests/test_nutq.cpp
)
target_link_libraries(voxly-testlar PRIVATE rubai_core)

# ------------------------------------------------------------------ UI qatlami
#
# Native Direct2D interfeysi. Yadrodan (rubai_core) alohida turadi, chunki
# `rubai-cli` va testlar UI'siz ishlaydi va Direct2D'ni ulash ularga ortiqcha.

add_library(rubai_ui STATIC
    ui/uslub.cpp
    ui/vidjet.cpp
    ui/asosiy_oyna.cpp
    ui/yozish_tab.cpp
    ui/fayl_tab.cpp
    ui/matn_maydon.cpp
    ui/soragich.cpp
)
target_include_directories(rubai_ui PUBLIC ui)
# comctl32 — `SetWindowSubclass` (matn maydoni), comdlg32 — fayl dialoglari.
target_link_libraries(rubai_ui PUBLIC rubai_core d2d1 dwrite comctl32 comdlg32)

# UI'ni yadrosiz sinash uchun kichik dastur (relizga kirmaydi).
add_executable(ui-demo WIN32 tools/ui_demo.cpp res/app.rc)
target_link_libraries(ui-demo PRIVATE rubai_ui)
target_include_directories(ui-demo PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/gen")
if(MSVC)
    set_target_properties(ui-demo PROPERTIES LINK_FLAGS "/MANIFEST:NO")
endif()

# ------------------------------------------------------------------- ilova

add_executable(Voxly WIN32
    ui/app.cpp
    ui/app_diktovka.cpp
    ui/autostart.cpp
    ui/inserter.cpp
    ui/overlay.cpp
    ui/settings_window.cpp
    ui/settings_window_llm.cpp
    res/app.rc
)
target_link_libraries(Voxly PRIVATE rubai_ui comctl32 dwmapi)
# app.rc → kotib_versiya.h (yuqoridagi «versiya» boʻlimi).
target_include_directories(Voxly PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/gen")

# Manifest res/app.rc orqali joylanadi. Linker'ning o'z manifestini
# o'chiramiz, aks holda ikkita RT_MANIFEST resursi to'qnashadi (CVT1100).
# mingw linkeri o'zi manifest qo'shmaydi, unda bu kerak emas.
if(MSVC)
    set_target_properties(Voxly PROPERTIES LINK_FLAGS "/MANIFEST:NO")
endif()

if(EXISTS "${WHISPER_BUILD}/bin/Release")
add_custom_command(TARGET Voxly POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory_if_different
            "${WHISPER_BUILD}/bin/Release" "$<TARGET_FILE_DIR:Voxly>"
    COMMENT "whisper.cpp DLL'lari nusxalanmoqda"
)

# Build'dan keyin whisper.cpp DLL'larini .exe yoniga nusxalaymiz, aks holda
# ilova ishga tushmaydi.
add_custom_command(TARGET rubai-cli POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory_if_different
            "${WHISPER_BUILD}/bin/Release" "$<TARGET_FILE_DIR:rubai-cli>"
    COMMENT "whisper.cpp DLL'lari nusxalanmoqda"
)
endif()
