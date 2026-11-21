// Sozlamalar oynasining ichki qismi — `settings_window.cpp` va
// `settings_window_llm.cpp` uchun umumiy: boshqaruv ID'lari, oʻlchamlar,
// yordamchilar va `SettingsWindow::Impl`. Tashqariga ochiq interfeys —
// `settings_window.h`.
#pragma once

#include <windows.h>

#include "settings_window.h"

#include <commctrl.h>

#include <algorithm>
#include <ctime>
#include <memory>
#include <shellapi.h>
#include <string>
#include <thread>
#include <vector>

#include "../core/audio_capture.h"
#include "../core/engine.h"  // findModel — nutq tili izohi
#include "../core/llm.h"
#include "../core/util.h"
#include "autostart.h"

namespace rubai {

namespace {

constexpr wchar_t kClassName[] = L"VoxlySettings";

enum CtrlId : int {
    kIdHotkey = 200,
    kIdMic,
    kIdMicWarning,
    kIdInsertMode,
    kIdAutoStart,
    kIdUseGpu,
    kIdApostrof,
    kIdSave,
    kIdCancel,
    kIdReset,
    kIdLog,
    // Sunʼiy intellekt boʻlimi
    kIdProvayder,
    kIdKalit,
    kIdBaseURL,
    kIdModel,
    kIdModelYangila,
    kIdModelHolati,
    kIdTekshir,
    kIdTekshirNatija,
    // «Qoʻshimcha sozlamalar» ostidagi hamma narsa. Yorliqlarga ham id
    // kerak: ular ham yashiriladi.
    kIdQoshimcha,
    kIdApostrofIzoh,
    kIdAiSarlavha,
    kIdAiIzoh,
    kIdModelYozuv,
    // «Haqida» qatori (doim koʻrinadi): versiya, muallif havolasi va
    // asl loyiha (Kotib) atributsiyasi.
    kIdHaqida,
    kIdAsosi,
    kIdDiagnostika,
    // Nutq tili (doim koʻrinadi) va uning izohi (model holati).
    kIdNutqTili,
    kIdNutqTiliIzoh,
    kIdBirinchiQoshimcha = kIdApostrof,  // roʻyxat chegaralari (pastga qarang)
};

// Fon oqimidan (model roʻyxati, ulanish tekshiruvi) natija qaytadi.
constexpr UINT WM_LLM_MODELLAR = WM_APP + 40;  // lp: new std::vector<std::wstring>*
constexpr UINT WM_LLM_HOLAT = WM_APP + 41;     // wp: maydon id, lp: new std::wstring*

// Oyna oʻlchamlari 96 DPI da; DPI boʻyicha masshtablanadi.
//
// Ikkita balandlik: qoʻshimcha sozlamalar yopiq va ochiq. macOS'da ham
// shunday (`sozlamalar_view.swift` → `qoshimchaniAlmashtir`).
//
// Nega yigʻiladi: toʻliq roʻyxat 700 DIP boʻlib ketadi va 150% masshtabdagi
// 768 piksellik noutbukda oynaning pastki qismi ekrandan chiqib ketardi —
// «Saqlash» tugmasi koʻrinmay qolardi.
constexpr int kWinW = 460;
constexpr int kWinH = 528;       // yopiq
constexpr int kWinHToliq = 814;  // ochiq

// Mikrofon ogohlantirishi uchun ajratilgan joy. Ogohlantirish YOʻQ boʻlsa
// (oddiy mikrofon — eng koʻp uchraydigan holat) pastdagi hamma narsa shu
// balandlikka koʻtariladi, aks holda oynada 52 DIP boʻsh joy qolib ketardi.
// macOS'da bu oʻz-oʻzidan chiqadi: u yerda `NSStackView` yashiringan
// qatorni yigʻib qoʻyadi.
constexpr int kMicOgohH = 52;
constexpr int kBolimBoshi = 218;  // ogohlantirishdan keyingi birinchi qator

// Muallif sayti — «Haqida» qatoridagi havola.
constexpr wchar_t kMuallifSayti[] = L"https://farhod-nomonov.netlify.app";

// Qoʻshimcha boʻlimdagi boshqaruvlar — birga yashiriladi/koʻrsatiladi.
constexpr int kQoshimchaIdlar[] = {
    kIdApostrof,    kIdAiSarlavha,   kIdAiIzoh,      kIdProvayder,
    kIdKalit,       kIdBaseURL,      kIdModelYozuv,  kIdModel,
    kIdModelYangila, kIdModelHolati, kIdTekshir,     kIdTekshirNatija,
    kIdLog,         kIdDiagnostika,
};

}  // namespace

struct SettingsWindow::Impl {
    HWND hwnd = nullptr;
    HINSTANCE instance = nullptr;
    HFONT font = nullptr;
    HFONT kichikFont = nullptr;  // «Haqida» ostidagi atributsiya qatori
    UINT dpi = 96;

    Settings settings;
    std::vector<MicDevice> mics;
    std::function<void(const Settings&)> onSaved;

    int scale(int v) const { return MulDiv(v, (int)dpi, 96); }

    void build();
    void fillMics();
    void updateMicWarning();
    NutqTili tanlanganTil() const;
    void tilIzohiniYangila();
    void save();
    HWND ctrl(int id) const { return GetDlgItem(hwnd, id); }

    // ---- Sunʼiy intellekt boʻlimi ----
    void llmniYukla();
    void llmniSaqla();
    void provayderOzgardi();
    void xosQatorniYangila();
    void modellarniKorsat(const std::vector<std::wstring>& royxat);
    void modellarniOlish();
    void ulanishniTekshir();

    std::wstring maydonMatni(int id) const;
    void maydonQoy(int id, const std::wstring& s);

    // Fon oqimidagi soʻrov hali ketyaptimi — ikki marta bosishdan himoya.
    bool llmSoravKetyapti = false;

    // Qoʻshimcha sozlamalar ochiqmi.
    bool qoshimchaOchiq = false;
    void joylashuvniYangila();

    // Har bir boshqaruvning LOYIHA koordinatalari (DIP). Joylashuv
    // oʻzgarganda (ogohlantirish yigʻilishi, boʻlim ochilishi) hammasi shu
    // roʻyxatdan qayta hisoblanadi — ekrandagi joriy oʻrindan emas.
    struct Joy {
        HWND h;
        int x, y, w, balandlik;
    };
    std::vector<Joy> joylar;
    int ogohBalandligi = kMicOgohH;  // 0 yoki kMicOgohH

    // Vertikal surish. Kontent 716 DIP gacha choʻziladi va 768 piksellik
    // (yoki masshtablangan) ekranga sigʻmaydi — macOS tomonida sozlamalar
    // `NSScrollView` ichida turadi, bu yerda ham shunday boʻlishi kerak,
    // aks holda «Saqlash» tugmasi ekrandan chiqib ketadi.
    int surilish = 0;           // joriy siljish, piksel
    int kontentBalandligi = 0;  // toʻliq kontent balandligi, piksel
    void surishniSozla(int mijozBalandligi);
    void sur(int yangi);
};

}  // namespace rubai
