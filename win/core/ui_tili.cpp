// Interfeys tili — aniqlash va saqlash. Interfeys va izohlar — `ui_tili.h`.

#include "ui_tili.h"

#include <atomic>
#include <cwctype>

#ifdef _WIN32
#include <windows.h>

#include "config.h"
#endif

namespace rubai {

namespace {

// -1 — hali aniqlanmagan; aks holda `UITili` qiymati (Rus yoki Ingliz).
std::atomic<int> g_joriy{-1};

#ifdef _WIN32
// Windows'ning afzal interfeys tillari, tartib bilan ("ru-RU", "en-US", …).
// macOS'dagi `Locale.preferredLanguages` ning ekvivalenti.
std::vector<std::wstring> tizimTillari() {
    std::vector<std::wstring> r;
    ULONG soni = 0, hajm = 0;
    if (GetUserPreferredUILanguages(MUI_LANGUAGE_NAME, &soni, nullptr, &hajm) && hajm > 0) {
        std::wstring bufer(hajm, L'\0');
        if (GetUserPreferredUILanguages(MUI_LANGUAGE_NAME, &soni, bufer.data(), &hajm)) {
            // Ikki marta nol bilan tugaydigan roʻyxat.
            for (const wchar_t* p = bufer.c_str(); *p; p += wcslen(p) + 1) r.emplace_back(p);
        }
    }
    if (r.empty()) {
        wchar_t nom[LOCALE_NAME_MAX_LENGTH] = {};
        if (LCIDToLocaleName(MAKELCID(GetUserDefaultUILanguage(), SORT_DEFAULT), nom,
                             LOCALE_NAME_MAX_LENGTH, 0) > 0) {
            r.emplace_back(nom);
        }
    }
    return r;
}
#endif

UITili aniqla() {
#ifdef _WIN32
    const UITili tanlangan = loadSettings().uiTili;
    if (tanlangan != UITili::Tizim) return tanlangan;
    return uiTiliTizimdan(tizimTillari());
#else
    // macOS'dagi test quvuri: til testda `joriyUITiliniQoy` bilan beriladi.
    return UITili::Rus;
#endif
}

}  // namespace

UITili uiTiliTizimdan(const std::vector<std::wstring>& tillar) {
    // macOS bilan bir xil roʻyxat: rus tilini tushunadigan mintaqalar.
    static const wchar_t* const kRusTushunadi[] = {L"ru", L"uk", L"be", L"kk", L"uz", L"ky",
                                                   L"tg", L"az", L"hy", L"ka", L"tk"};
    for (const std::wstring& t : tillar) {
        std::wstring kod;
        for (wchar_t c : t) {
            if (c == L'-' || c == L'_') break;
            kod += static_cast<wchar_t>(std::towlower(c));
        }
        if (kod == L"en") return UITili::Ingliz;
        for (const wchar_t* r : kRusTushunadi) {
            if (kod == r) return UITili::Rus;
        }
    }
    return UITili::Ingliz;
}

UITili joriyUITili() {
    int v = g_joriy.load();
    if (v < 0) {
        // Bir vaqtda ikki oqim kirsa ham natija bir xil — birinchisi yozadi.
        int kutilgan = -1;
        g_joriy.compare_exchange_strong(kutilgan, static_cast<int>(aniqla()));
        v = g_joriy.load();
    }
    return static_cast<UITili>(v);
}

void joriyUITiliniQoy(UITili t) { g_joriy.store(t == UITili::Tizim ? -1 : static_cast<int>(t)); }

}  // namespace rubai
