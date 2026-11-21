// Foydalanuvchi sozlamalari — %LOCALAPPDATA%\Voxly\settings.ini
//
// macOS versiyasida bu UserDefaults edi. Windows'da oddiy `kalit=qiymat`
// UTF-8 matn fayli ishlatiladi: qoʻlda tahrirlash oson, parser xatolari yoʻq,
// tashqi kutubxona kerak emas.
#pragma once

#include <string>

#include "matn_format.h"  // Apostrof
#include "ui_tili.h"      // UITili

namespace rubai {

// Diktovka va fayl transkripsiyasi tili — macOS'dagi `NutqTili`
// (`src/model_tanlov.swift`). Har til — oʻz modeli bilan: rubaiSTT faqat
// oʻzbekcha (rus nutqini ham lotin harflari bilan yozadi), rus va ingliz
// uchun oddiy koʻp tilli Whisper (`model_tanlov.h`). Tartib macOS'dagi
// `allCases` bilan bir xil — Sozlamalardagi roʻyxat shu tartibda.
enum class NutqTili { Rus, Ingliz, Ozbek };

// whisper til kodi: "ru", "en", "uz".
inline const wchar_t* nutqTiliKodi(NutqTili t) {
    switch (t) {
        case NutqTili::Rus: return L"ru";
        case NutqTili::Ingliz: return L"en";
        case NutqTili::Ozbek: return L"uz";
    }
    return L"uz";
}

// Koddan til; nomaʼlum kod — `standart`.
inline NutqTili nutqTiliKoddan(const std::wstring& kod, NutqTili standart) {
    if (kod == L"ru") return NutqTili::Rus;
    if (kod == L"en") return NutqTili::Ingliz;
    if (kod == L"uz") return NutqTili::Ozbek;
    return standart;
}

// Sozlamalar faylida `nutq.tili` kaliti boʻlmasa qaysi til. Yangi oʻrnatish
// (fayl yoʻq) — rus (macOS'dagi `NutqTili.standart`). Fayl bor-u kalit yoʻq —
// Kotib'dan (yoki tilsiz eski Voxly'dan) koʻchgan foydalanuvchi: u oʻzbek
// modeli bilan ishlab kelgan, til jimgina almashmasin.
inline NutqTili boshlangichNutqTili(bool faylBor) {
    return faylBor ? NutqTili::Ozbek : NutqTili::Rus;
}

// Matnni faol oynaga qanday joylash.
enum class InsertMode {
    Paste,  // clipboard + Ctrl+V — tez, uzun matnlar uchun (standart)
    Type,   // belgima-belgi Unicode kiritish — paste'ni bloklaydigan ilovalar uchun
};

struct Settings {
    // Hotkey. Standart: Ctrl+Alt+D (macOS'dagi ⌃⌥D ning ekvivalenti).
    unsigned vkCode = 'D';   // virtual key code
    unsigned modifiers = 0;  // MOD_CONTROL | MOD_ALT (0 = standartni qoʻllash)
    std::wstring hotkeyLabel = L"D";

    // Mikrofon. Boʻsh = tizim standarti.
    // MUHIM: Windows'da standart qurilma "Stereo Mix" boʻlib qolishi mumkin —
    // u ovoz oʻrniga kompyuter ovozini yozadi. Shuning uchun aniq tanlash bor.
    std::wstring micDeviceId;
    std::wstring micDeviceName;  // faqat koʻrsatish uchun

    InsertMode insertMode = InsertMode::Paste;
    bool autoStart = true;
    bool useGpu = true;           // false = majburan CPU
    int idleUnloadSeconds = 180;  // model RAM'dan boʻshash vaqti
    bool didOnboard = false;      // Welcome oynasi koʻrsatilganmi

    // Oddiy ASCII apostrof (') ishlatilsinmi. Sukut boʻyicha yoʻq — oʻzbek
    // lotin meʼyori ʻ va ʼ ni talab qiladi. macOS'da bu `Prefs.apostrof`.
    bool oddiyApostrof = false;

    // Nutq tili — qaysi model va whisper tili ishlatiladi. Faylda kalit
    // yoʻq boʻlsa qiymat `boshlangichNutqTili` dan (`loadSettings`).
    NutqTili nutqTili = NutqTili::Rus;

    // Interfeys tili (macOS'dagi `UITili.tanlangan`, kalit `ui.tili`).
    // `Tizim` — Windows tilidan (`ui_tili.h`). Ishlab turgan jarayonga
    // taʼsir qilmaydi: til ishga tushishda bir marta aniqlanadi.
    UITili uiTili = UITili::Tizim;

    // «Diagnostika rejimi» tugash vaqti (unix soniya, 0 — oʻchiq). Yoqiq
    // boʻlsa diktovka matni ham logga yoziladi; 24 soatdan keyin oʻzi oʻchadi —
    // unutilib qolsa ham abadiy yozib turmaydi (barqarorlik G1, macOS'dagi
    // `Prefs.diagnostika`). Standart holatda logda matn YOʻQ, faqat uzunligi.
    long long diagnostikaTugash = 0;

    // ---- LLM (Studiya «amallari») ----
    // macOS'da bular UserDefaults'dagi `llm.*` kalitlari (`llm_providers.swift`).
    // API kalitning OʻZI bu yerda EMAS — u Credential Manager'da (`llm.h`).
    std::string llmProvayder;  // boʻsh — sozlanmagan
    std::wstring llmBaseURL;   // boʻsh — provayderning oʻz manzili
    std::wstring llmModel;     // boʻsh — provayderning standart modeli

    // Ekranda koʻrinishi, masalan "Ctrl+Alt+D"
    std::wstring hotkeyDisplay() const;
};

// Sozlamalar oynasi tahrirlaydigan maydonlarni `oyna` dan `fayl` ga koʻchiradi,
// qolganini (didOnboard, idleUnloadSeconds) fayldagidek qoldiradi
// (barqarorlik E1).
//
// Nega kerak: oyna ochilganda sozlamalar NUSXASINI oladi va saqlashda butun
// faylni yozardi. Oraliqda boshqa modul yozgan maydonlar nusxadagi eski
// qiymatga qaytardi.
//
// Yangi maydon qoʻshilsa va uni sozlamalar oynasi tahrirlasa — shu yerga ham.
inline Settings sozlamaOynasidan(Settings fayl, const Settings& oyna) {
    fayl.vkCode = oyna.vkCode;
    fayl.modifiers = oyna.modifiers;
    fayl.hotkeyLabel = oyna.hotkeyLabel;
    fayl.micDeviceId = oyna.micDeviceId;
    fayl.micDeviceName = oyna.micDeviceName;
    fayl.insertMode = oyna.insertMode;
    fayl.autoStart = oyna.autoStart;
    fayl.useGpu = oyna.useGpu;
    fayl.oddiyApostrof = oyna.oddiyApostrof;
    fayl.nutqTili = oyna.nutqTili;
    fayl.uiTili = oyna.uiTili;
    fayl.diagnostikaTugash = oyna.diagnostikaTugash;
    fayl.llmProvayder = oyna.llmProvayder;
    fayl.llmBaseURL = oyna.llmBaseURL;
    fayl.llmModel = oyna.llmModel;
    return fayl;
}

// Chiqadigan matndagi apostrof uslubi — macOS'dagi `Prefs.apostrof`. Oʻzbek
// lotin meʼyori (ʻ/ʼ) FAQAT oʻzbek nutqi uchun: rus/ingliz matnida «don't»
// kabi soʻzlar «donʼt» boʻlib ketmasin — u yerda hamma variant ASCII ' ga.
inline Apostrof apostrofUslubi(const Settings& s) {
    if (s.nutqTili != NutqTili::Ozbek) return Apostrof::Oddiy;
    return s.oddiyApostrof ? Apostrof::Oddiy : Apostrof::Standart;
}

// Diagnostika rejimi hali amaldami. macOS'dagi `LogSiyosati.diagnostikaFaolmi`
// bilan bir xil: soat orqaga surilgan boʻlsa ham muddat 24 soatdan uzaymaydi.
constexpr long long kDiagnostikaMuddati = 24 * 3600;
inline bool diagnostikaFaolmi(long long tugash, long long hozir) {
    return tugash > 0 && hozir < tugash && tugash - hozir <= kDiagnostikaMuddati;
}

// Diskdan oʻqiydi. Fayl yoʻq/buzuq boʻlsa standart qiymatlar qaytadi —
// hech qachon xato bermaydi (obunachi kompyuterida ilova ishga tushmay
// qolmasligi uchun).
Settings loadSettings();

bool saveSettings(const Settings& s);

std::wstring settingsPath();

}  // namespace rubai
