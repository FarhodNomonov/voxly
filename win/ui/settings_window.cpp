// Sozlamalar oynasi: qurilish, joylashuv va surish, mikrofon roʻyxati,
// saqlash (`sozlamaOynasidan`) va ochiq API. LLM boʻlimi —
// `settings_window_llm.cpp`; ichki eʼlonlar — `settings_window_ichki.h`.

#include "settings_window_ichki.h"

#include "../core/versiya.h"

namespace rubai {

namespace {

// HOTKEY boshqaruvi HOTKEYF_* bayroqlarini beradi, RegisterHotKey esa
// MOD_* kutadi — ular boshqacha qiymatlar.
UINT hotkeyFlagsToMod(BYTE flags) {
    UINT m = 0;
    if (flags & HOTKEYF_CONTROL) m |= MOD_CONTROL;
    if (flags & HOTKEYF_ALT) m |= MOD_ALT;
    if (flags & HOTKEYF_SHIFT) m |= MOD_SHIFT;
    return m;
}

BYTE modToHotkeyFlags(UINT mod) {
    BYTE f = 0;
    if (mod & MOD_CONTROL) f |= HOTKEYF_CONTROL;
    if (mod & MOD_ALT) f |= HOTKEYF_ALT;
    if (mod & MOD_SHIFT) f |= HOTKEYF_SHIFT;
    return f;
}

// Tugma nomini virtual key code'dan olamiz — sozlamalar faylida
// va menyuda koʻrsatish uchun.
std::wstring keyLabel(UINT vk) {
    const UINT scan = MapVirtualKeyW(vk, MAPVK_VK_TO_VSC);
    wchar_t name[64] = {};
    if (scan && GetKeyNameTextW((LONG)(scan << 16), name, 64) > 0) return name;
    if (vk >= 'A' && vk <= 'Z') return std::wstring(1, (wchar_t)vk);
    return L"Key" + std::to_wstring(vk);
}

// Oynani ishonchli tarzda oldinga chiqaradi.
//
// SetForegroundWindow yolgʻiz oʻzi YETARLI EMAS: Windows fonda ishlayotgan
// jarayonga faol oynani almashtirishni taqiqlaydi (foreground lock).
// Amalda tekshirildi — sozlamalar oynasi yaratilar, lekin boshqa ilova
// ostida koʻrinmay qolar edi.
//
// Yechim: faol oynaning kirish oqimiga vaqtincha ulanamiz — shunda tizim
// bizni "foydalanuvchi bilan ishlayotgan" deb hisoblaydi.
void forceForeground(HWND hwnd) {
    const HWND fg = GetForegroundWindow();
    const DWORD fgThread = fg ? GetWindowThreadProcessId(fg, nullptr) : 0;
    const DWORD myThread = GetCurrentThreadId();
    const bool attach = fgThread != 0 && fgThread != myThread;

    if (attach) AttachThreadInput(fgThread, myThread, TRUE);

    ShowWindow(hwnd, SW_SHOW);
    BringWindowToTop(hwnd);
    SetForegroundWindow(hwnd);
    SetActiveWindow(hwnd);

    if (attach) AttachThreadInput(fgThread, myThread, FALSE);

    // Baribir ochilmasa — vazifalar panelida miltillatib eʼtibor tortamiz.
    if (GetForegroundWindow() != hwnd) {
        FLASHWINFO fi{sizeof(fi), hwnd, FLASHW_ALL | FLASHW_TIMERNOFG, 3, 0};
        FlashWindowEx(&fi);
    }
}

SettingsWindow::Impl* implOf(HWND h) {
    return reinterpret_cast<SettingsWindow::Impl*>(GetWindowLongPtrW(h, GWLP_USERDATA));
}

LRESULT CALLBACK settingsProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == WM_NCCREATE) {
        auto* cs = reinterpret_cast<CREATESTRUCTW*>(lp);
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)cs->lpCreateParams);
    }
    auto* d = implOf(hwnd);

    switch (msg) {
        case WM_COMMAND:
            if (!d) break;
            switch (LOWORD(wp)) {
                case kIdSave:
                    d->save();
                    ShowWindow(hwnd, SW_HIDE);
                    return 0;
                case IDCANCEL:  // Esc — `IsDialogMessageW` shuni yuboradi
                case kIdCancel: ShowWindow(hwnd, SW_HIDE); return 0;
                case kIdReset:
                    SendMessageW(d->ctrl(kIdHotkey), HKM_SETHOTKEY,
                                 MAKEWORD('D', HOTKEYF_CONTROL | HOTKEYF_ALT), 0);
                    return 0;
                case kIdMic:
                    if (HIWORD(wp) == CBN_SELCHANGE) d->updateMicWarning();
                    return 0;
                case kIdNutqTili:
                    if (HIWORD(wp) == CBN_SELCHANGE) d->tilIzohiniYangila();
                    return 0;
                case kIdLog:
                    ShellExecuteW(nullptr, L"open", logPath().c_str(), nullptr, nullptr,
                                  SW_SHOWNORMAL);
                    return 0;
                case kIdQoshimcha:
                    d->qoshimchaOchiq = !d->qoshimchaOchiq;
                    d->joylashuvniYangila();
                    return 0;
                case kIdProvayder:
                    if (HIWORD(wp) == CBN_SELCHANGE) d->provayderOzgardi();
                    return 0;
                case kIdModelYangila: d->modellarniOlish(); return 0;
                case kIdTekshir: d->ulanishniTekshir(); return 0;
            }
            break;

        // Fon oqimidan kelgan natijalar.
        case WM_LLM_MODELLAR: {
            std::unique_ptr<std::vector<std::wstring>> r(
                reinterpret_cast<std::vector<std::wstring>*>(lp));
            if (!d) return 0;
            d->llmSoravKetyapti = false;
            if (r->empty()) {
                d->maydonQoy(kIdModelHolati,
                             tr(L"Провайдер не даёт список моделей — введите название",
                                L"This provider doesn't list models — type the name"));
            } else {
                d->modellarniKorsat(*r);
                d->maydonQoy(kIdModelHolati, tr(L"Моделей: " + std::to_wstring(r->size()),
                                                std::to_wstring(r->size()) + L" models"));
            }
            return 0;
        }

        case WM_LLM_HOLAT: {
            std::unique_ptr<std::wstring> m(reinterpret_cast<std::wstring*>(lp));
            if (!d) return 0;
            d->llmSoravKetyapti = false;
            d->maydonQoy(static_cast<int>(wp), *m);
            return 0;
        }

        // «Haqida» qatoridagi havola (SysLink): sichqoncha yoki Enter.
        case WM_NOTIFY: {
            auto* n = reinterpret_cast<NMHDR*>(lp);
            if (!d || n->idFrom != static_cast<UINT_PTR>(kIdHaqida)) break;
            if (n->code == NM_CLICK || n->code == NM_RETURN) {
                ShellExecuteW(nullptr, L"open", kMuallifSayti, nullptr, nullptr, SW_SHOWNORMAL);
                return 0;
            }
            break;
        }

        case WM_VSCROLL: {
            if (!d) break;
            SCROLLINFO si{};
            si.cbSize = sizeof(si);
            si.fMask = SIF_ALL;
            GetScrollInfo(hwnd, SB_VERT, &si);
            int yangi = d->surilish;
            switch (LOWORD(wp)) {
                case SB_LINEUP: yangi -= 24; break;
                case SB_LINEDOWN: yangi += 24; break;
                case SB_PAGEUP: yangi -= (int)si.nPage; break;
                case SB_PAGEDOWN: yangi += (int)si.nPage; break;
                case SB_THUMBTRACK:
                case SB_THUMBPOSITION: yangi = si.nTrackPos; break;
                case SB_TOP: yangi = 0; break;
                case SB_BOTTOM: yangi = si.nMax; break;
                default: return 0;
            }
            d->sur(yangi);
            return 0;
        }

        case WM_MOUSEWHEEL: {
            if (!d) break;
            const int qadam = GET_WHEEL_DELTA_WPARAM(wp) / WHEEL_DELTA;
            d->sur(d->surilish - qadam * 60);
            return 0;
        }

        // `IsDialogMessageW` Enter bosilganda default tugmani shu xabar
        // orqali soʻraydi. Javob bermasak u IDOK (1) yuboradi va biz uni
        // bilmaymiz — Enter hech narsa qilmasdi.
        case DM_GETDEFID: return MAKELONG(kIdSave, DC_HASDEFID);

        case WM_CLOSE: ShowWindow(hwnd, SW_HIDE); return 0;

        case WM_CTLCOLORSTATIC: {
            // Yorliqlar va belgilash katakchalari oyna foni bilan bir xil
            // koʻrinishi kerak — aks holda ular kulrang tasma boʻlib chiqadi.
            auto hdc = (HDC)wp;
            SetBkMode(hdc, TRANSPARENT);
            if (d && (HWND)lp == d->ctrl(kIdMicWarning)) {
                SetTextColor(hdc, RGB(176, 92, 0));  // ogohlantirish — toʻq sariq
            } else if (d && ((HWND)lp == d->ctrl(kIdAsosi) || (HWND)lp == d->ctrl(kIdUITiliIzoh))) {
                SetTextColor(hdc, GetSysColor(COLOR_GRAYTEXT));  // atributsiya — xira
            }
            return (LRESULT)GetSysColorBrush(COLOR_WINDOW);
        }
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

}  // namespace

// -------------------------------------------------------------- qurilish

void SettingsWindow::Impl::build() {
    auto S = [&](int v) { return scale(v); };

    auto add = [&](const wchar_t* cls, const wchar_t* text, DWORD style, int x, int y, int w, int h,
                   int id) {
        HWND c = CreateWindowExW(0, cls, text, WS_CHILD | WS_VISIBLE | style, S(x), S(y), S(w),
                                 S(h), hwnd, (HMENU)(INT_PTR)id, instance, nullptr);
        joylar.push_back({c, x, y, w, h});
        if (c) SendMessageW(c, WM_SETFONT, (WPARAM)font, TRUE);
        return c;
    };

    // Matnlar — macOS'dagi `sozlamalar_view.swift` bilan bir xil soʻzlar.
    // Kengliklar rus va ingliz matnining UZUNROGʻIGA qarab (Segoe UI 13 px:
    // ~7 px/belgi): rus matni koʻpincha oʻzbekchadan uzunroq.

    // --- Diktovka tugmasi
    add(L"STATIC", tr(L"Клавиша диктовки", L"Dictation shortcut"), 0, 24, 20, 300, 18, -1);
    add(HOTKEY_CLASSW, L"", 0, 24, 42, 180, 26, kIdHotkey);
    add(L"BUTTON", tr(L"По умолчанию (Ctrl+Alt+D)", L"Default (Ctrl+Alt+D)"), BS_PUSHBUTTON, 212,
        42, 214, 26, kIdReset);
    add(L"STATIC",
        tr(L"Нужен хотя бы один модификатор: Ctrl, Alt или Shift.",
           L"Use at least one modifier: Ctrl, Alt or Shift."),
        0, 24, 72, 402, 20, -1);

    // --- Mikrofon
    add(L"STATIC", tr(L"Микрофон", L"Microphone"), 0, 24, 106, 300, 18, -1);
    add(L"COMBOBOX", L"", CBS_DROPDOWNLIST | WS_VSCROLL | WS_TABSTOP, 24, 128, 402, 200, kIdMic);
    add(L"STATIC", L"", SS_LEFT, 24, 160, 402, 52, kIdMicWarning);

    // --- Nutq tili (macOS'dagi `qurNutqTili`). Til nomlari — har biri oʻz
    // tilida, interfeys tilidan qatʼi nazar: oʻzbek foydalanuvchi rus yoki
    // ingliz interfeysida ham «Oʻzbekcha» ni darhol topsin.
    // Tartib `NutqTili` bilan bir xil (ruyxat indeksi = enum qiymati).
    add(L"STATIC", tr(L"Язык речи", L"Speech language"), 0, 24, 218, 300, 18, -1);
    HWND til = add(L"COMBOBOX", L"", CBS_DROPDOWNLIST | WS_TABSTOP, 24, 240, 180, 120, kIdNutqTili);
    SendMessageW(til, CB_ADDSTRING, 0, (LPARAM)L"Русский");
    SendMessageW(til, CB_ADDSTRING, 0, (LPARAM)L"English");
    SendMessageW(til, CB_ADDSTRING, 0, (LPARAM)L"Oʻzbekcha");
    add(L"STATIC", L"", SS_LEFT, 212, 244, 214, 18, kIdNutqTiliIzoh);

    // --- Interfeys tili (macOS'dagi `qurUITili`). Tartib `UITili` bilan bir
    // xil. Til ishga tushishda bir marta aniqlanadi — oʻzgarsa saqlashda
    // qayta ishga tushirish taklif qilinadi (`save`).
    add(L"STATIC", tr(L"Язык интерфейса", L"App language"), 0, 24, 274, 300, 18, -1);
    HWND ui = add(L"COMBOBOX", L"", CBS_DROPDOWNLIST | WS_TABSTOP, 24, 296, 180, 120, kIdUITili);
    SendMessageW(ui, CB_ADDSTRING, 0, (LPARAM)tr(L"Как в системе", L"System default"));
    SendMessageW(ui, CB_ADDSTRING, 0, (LPARAM)L"Русский");
    SendMessageW(ui, CB_ADDSTRING, 0, (LPARAM)L"English");
    add(L"STATIC", tr(L"Сменится после перезапуска", L"Applies after a restart"), SS_LEFT, 212, 300,
        214, 18, kIdUITiliIzoh);

    // --- Matn kiritish usuli
    add(L"STATIC", tr(L"Способ ввода текста", L"Text input method"), 0, 24, 330, 300, 18, -1);
    HWND mode =
        add(L"COMBOBOX", L"", CBS_DROPDOWNLIST | WS_TABSTOP, 24, 352, 402, 120, kIdInsertMode);
    SendMessageW(mode, CB_ADDSTRING, 0,
                 (LPARAM)tr(L"Быстро (вставка через буфер обмена) — рекомендуется",
                            L"Fast (paste via clipboard) — recommended"));
    SendMessageW(mode, CB_ADDSTRING, 0,
                 (LPARAM)tr(L"Медленно (ввод по символу) — если вставка не работает",
                            L"Slow (type character by character) — if pasting fails"));

    // --- Bayroqlar
    add(L"BUTTON", tr(L"Запускать при входе в систему", L"Open at login"),
        BS_AUTOCHECKBOX | WS_TABSTOP, 24, 390, 402, 22, kIdAutoStart);
    add(L"BUTTON", tr(L"Использовать видеокарту (быстрее)", L"Use the graphics card (faster)"),
        BS_AUTOCHECKBOX | WS_TABSTOP, 24, 416, 402, 22, kIdUseGpu);

    // --- Haqida: versiya va muallif (havola), ostida asl loyiha atributsiyasi
    // — macOS'dagi `qurMuallif` bilan bir xil matn. Avto-yangilanish qatori
    // turgan joyda. Kotib muallifi MIT litsenziyasi talabi bilan
    // koʻrsatiladi — olib tashlamang.
    const std::wstring haqida = L"Voxly " + joriyVersiya() + L" \x00B7 <a href=\"" + kMuallifSayti +
                                L"\">" + tr(L"Фарход Номонов", L"Farkhod Nomonov") + L"</a>";
    add(WC_LINK, haqida.c_str(), WS_TABSTOP, 24, 446, 402, 18, kIdHaqida);
    if (HWND asosi = add(L"STATIC",
                         tr(L"Основано на Kotib (Muhammad Mirqobilov, MIT)",
                            L"Based on Kotib by Muhammad Mirqobilov (MIT)"),
                         SS_LEFT, 24, 466, 402, 16, kIdAsosi)) {
        SendMessageW(asosi, WM_SETFONT, (WPARAM)kichikFont, TRUE);
    }

    // --- «Qoʻshimcha sozlamalar» ochilishi
    //
    // Ostidagi hamma narsa sukut boʻyicha yashirin: toʻliq roʻyxat 700 DIP
    // boʻlib ketadi va kichik ekranga sigʻmaydi. macOS'da ham shu naqsh.
    // Uchburchak (▾/▴) — macOS'dagi ⌄/⌃ oʻrniga. Segoe UI'da U+2303/2304
    // yoʻq va Windows ularni boshqa shriftdan oladi: natijada ingliz
    // klaviaturasidagi «^» kabi ingichka belgi chiqadi.
    add(L"BUTTON", tr(L"Дополнительно  ▾", L"Advanced  ▾"), BS_PUSHBUTTON | BS_FLAT | WS_TABSTOP,
        24, 490, 200, 26, kIdQoshimcha);

    // Oddiy ASCII apostrof. Sukut boʻyicha oʻchiq — oʻzbek lotin meʼyori
    // ʻ va ʼ ni talab qiladi (macOS'da `Prefs.apostrof`).
    add(L"BUTTON", tr(L"Простой апостроф (') в узбекском", L"Plain apostrophe (') for Uzbek"),
        BS_AUTOCHECKBOX | WS_TABSTOP, 24, 528, 402, 22, kIdApostrof);

    // --- Sunʼiy intellekt (ixtiyoriy)
    //
    // Ilova hech qanday kalit bilan kelmaydi va busiz toʻliq ishlaydi.
    // Kalit foydalanuvchining oʻzi kiritadi va Credential Manager'da
    // saqlanadi (`llm.h`), logga hech qachon tushmaydi.
    add(L"STATIC", tr(L"Искусственный интеллект (по желанию)", L"AI (optional)"), 0, 24, 554, 402,
        18, kIdAiSarlavha);
    add(L"STATIC",
        tr(L"С ключом API появятся чистка текста и краткое изложение.",
           L"Add your API key to get text cleanup and summaries."),
        0, 24, 574, 402, 20, kIdAiIzoh);

    HWND prov = add(L"COMBOBOX", L"", CBS_DROPDOWNLIST | WS_VSCROLL | WS_TABSTOP, 24, 596, 180, 240,
                    kIdProvayder);
    SendMessageW(prov, CB_ADDSTRING, 0, (LPARAM)tr(L"— не выбран —", L"— none —"));
    for (const auto& pv : provayderlar()) {
        SendMessageW(prov, CB_ADDSTRING, 0, (LPARAM)pv.nom.c_str());
    }

    // Kalit — yulduzcha bilan. ES_PASSWORD yelkadan qarab oʻqishga qarshi;
    // kalitning oʻzi baribir Credential Manager'da shifrlanadi.
    // Maydonlarda yorliq yoʻq, shuning uchun ishora matni (cue banner)
    // qoʻyiladi — macOS'da bu `placeholderString`.
    add(L"EDIT", L"", ES_AUTOHSCROLL | ES_PASSWORD | WS_BORDER | WS_TABSTOP, 212, 596, 214, 24,
        kIdKalit);

    // Base URL faqat «Boshqa (custom)» provayderda kerak — qolganlarida
    // manzil presetdan keladi va uni koʻrsatish faqat chalgʻitadi.
    add(L"EDIT", L"", ES_AUTOHSCROLL | WS_BORDER | WS_TABSTOP, 24, 626, 402, 24, kIdBaseURL);

    // Model — tahrirlanadigan roʻyxat (CBS_DROPDOWN), oddiy tanlagich emas:
    //  1. OpenRouter 400 ga yaqin model qaytaradi;
    //  2. provayderda `/models` boʻlmasa nom qoʻlda yoziladi — boshi berk
    //     koʻcha hech qachon boʻlmaydi.
    add(L"STATIC", tr(L"Модель", L"Model"), 0, 24, 662, 60, 18, kIdModelYozuv);
    add(L"COMBOBOX", L"", CBS_DROPDOWN | CBS_AUTOHSCROLL | WS_VSCROLL | WS_TABSTOP, 84, 658, 230,
        260, kIdModel);
    add(L"BUTTON", tr(L"Обновить", L"Refresh"), BS_PUSHBUTTON | WS_TABSTOP, 322, 658, 104, 26,
        kIdModelYangila);
    add(L"STATIC", L"", 0, 24, 690, 402, 18, kIdModelHolati);

    add(L"BUTTON", tr(L"Проверить подключение", L"Test connection"), BS_PUSHBUTTON | WS_TABSTOP, 24,
        712, 180, 26, kIdTekshir);
    add(L"STATIC", L"", 0, 212, 716, 214, 18, kIdTekshirNatija);

    // Diagnostika rejimi (G1): logda matn faqat shu yoqiq boʻlsa, 24 soatgacha.
    add(L"BUTTON",
        tr(L"Режим диагностики (24 ч): текст диктовок в логе",
           L"Diagnostic mode (24 h): dictated text goes to the log"),
        BS_AUTOCHECKBOX | WS_TABSTOP, 24, 746, 402, 22, kIdDiagnostika);
    add(L"BUTTON", tr(L"Открыть лог…", L"Open log file…"), BS_PUSHBUTTON | WS_TABSTOP, 24, 774, 150,
        30, kIdLog);

    // --- Pastki tugmalar — ular oʻrni qoʻshimcha boʻlim ochilganda pastga
    // suriladi (`joylashuvniYangila`).
    add(L"BUTTON", tr(L"Сохранить", L"Save"), BS_DEFPUSHBUTTON | WS_TABSTOP, 226, 0, 98, 30,
        kIdSave);
    add(L"BUTTON", tr(L"Отмена", L"Cancel"), BS_PUSHBUTTON | WS_TABSTOP, 328, 0, 98, 30, kIdCancel);

    // Ishora matnlari (macOS'dagi `placeholderString`).
    SendMessageW(ctrl(kIdKalit), EM_SETCUEBANNER, TRUE, (LPARAM)tr(L"Ключ API", L"API key"));
    SendMessageW(ctrl(kIdBaseURL), EM_SETCUEBANNER, TRUE, (LPARAM)L"Base URL");

    joylashuvniYangila();
}

// Qoʻshimcha boʻlimni koʻrsatadi/yashiradi, pastki tugmalarni joyiga qoʻyadi
// va oyna balandligini moslaydi.
void SettingsWindow::Impl::joylashuvniYangila() {
    for (int id : kQoshimchaIdlar) {
        if (HWND c = ctrl(id)) ShowWindow(c, qoshimchaOchiq ? SW_SHOW : SW_HIDE);
    }
    // «Boshqa (custom)» boʻlmasa Base URL baribir yashirin qoladi.
    xosQatorniYangila();

    SetWindowTextW(ctrl(kIdQoshimcha), qoshimchaOchiq ? tr(L"Дополнительно  ▴", L"Advanced  ▴")
                                                      : tr(L"Дополнительно  ▾", L"Advanced  ▾"));

    // Boʻlim ochilib-yopilganda kontent boshiga qaytamiz: quyidagi
    // joylashuv surilmagan koordinatalarda hisoblanadi.
    sur(0);

    // Mikrofon ogohlantirishi boʻsh boʻlsa — pastdagi hamma narsa
    // koʻtariladi.
    const int siljish = ogohBalandligi - kMicOgohH;

    const int toliqBalandlik = (qoshimchaOchiq ? kWinHToliq : kWinH) + siljish;
    const int pastQator = toliqBalandlik - 42;

    for (const Joy& j : joylar) {
        if (!j.h) continue;
        int y = j.y;
        if (j.h == ctrl(kIdSave) || j.h == ctrl(kIdCancel)) {
            y = pastQator;
        } else if (j.y >= kBolimBoshi) {
            y += siljish;
        }
        SetWindowPos(j.h, nullptr, scale(j.x), scale(y), 0, 0,
                     SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
    }

    kontentBalandligi = scale(toliqBalandlik);

    RECT rc{0, 0, scale(kWinW), kontentBalandligi};
    AdjustWindowRectExForDpi(&rc, WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU, FALSE, 0, dpi);
    const int ramkaBalandligi = (rc.bottom - rc.top) - kontentBalandligi;
    int kenglik = rc.right - rc.left;
    int mijoz = kontentBalandligi;

    // Ekranga sigʻmasa — oynani ish maydoni balandligiga qisqartiramiz va
    // kontentni suramiz. Ilgari oyna shunchaki tepaga surilardi va pastki
    // qismi (Saqlash/Bekor) koʻrinmay qolardi: 800×600 VM'da ham,
    // 1366×768 noutbukda ham.
    UINT bayroqlar = SWP_NOMOVE | SWP_NOZORDER;
    int x = 0, y = 0;
    RECT joriy{};
    GetWindowRect(hwnd, &joriy);
    MONITORINFO mi{};
    mi.cbSize = sizeof(mi);
    if (GetMonitorInfoW(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), &mi)) {
        const int ish = mi.rcWork.bottom - mi.rcWork.top;
        if (mijoz + ramkaBalandligi > ish) {
            mijoz = ish - ramkaBalandligi;
            // Surish paneli mijoz kengligini yeydi — oynani shuncha
            // kengaytiramiz, aks holda oʻng chekka kesiladi.
            kenglik += GetSystemMetricsForDpi(SM_CXVSCROLL, dpi);
        }
        const int balandlik = mijoz + ramkaBalandligi;
        if (joriy.top + balandlik > mi.rcWork.bottom) {
            x = joriy.left;
            y = (balandlik >= ish) ? mi.rcWork.top : mi.rcWork.bottom - balandlik;
            bayroqlar = SWP_NOZORDER;
        }
    }

    SetWindowPos(hwnd, nullptr, x, y, kenglik, mijoz + ramkaBalandligi, bayroqlar);
    surishniSozla(mijoz);
    InvalidateRect(hwnd, nullptr, TRUE);
}

void SettingsWindow::Impl::surishniSozla(int mijozBalandligi) {
    SCROLLINFO si{};
    si.cbSize = sizeof(si);
    si.fMask = SIF_RANGE | SIF_PAGE | SIF_POS;
    si.nMin = 0;
    si.nMax = kontentBalandligi > 0 ? kontentBalandligi - 1 : 0;
    si.nPage = mijozBalandligi > 0 ? static_cast<UINT>(mijozBalandligi) : 1;
    si.nPos = surilish;
    SetScrollInfo(hwnd, SB_VERT, &si, TRUE);
    // Diapazon qisqargan boʻlsa siljishni qaytadan qisamiz.
    sur(surilish);
}

void SettingsWindow::Impl::sur(int yangi) {
    RECT mijoz{};
    GetClientRect(hwnd, &mijoz);
    const int eng = kontentBalandligi - (mijoz.bottom - mijoz.top);
    if (yangi < 0) yangi = 0;
    if (yangi > eng) yangi = eng > 0 ? eng : 0;
    if (yangi == surilish) return;

    const int dy = surilish - yangi;
    surilish = yangi;
    ScrollWindowEx(hwnd, 0, dy, nullptr, nullptr, nullptr, nullptr,
                   SW_SCROLLCHILDREN | SW_INVALIDATE | SW_ERASE);
    SetScrollPos(hwnd, SB_VERT, surilish, TRUE);
    UpdateWindow(hwnd);
}

void SettingsWindow::Impl::fillMics() {
    HWND combo = ctrl(kIdMic);
    SendMessageW(combo, CB_RESETCONTENT, 0, 0);

    mics = listMicrophones();

    SendMessageW(combo, CB_ADDSTRING, 0, (LPARAM)tr(L"(системный)", L"(system default)"));
    int select = 0;

    for (size_t i = 0; i < mics.size(); i++) {
        std::wstring label = mics[i].name;
        switch (mics[i].kind) {
            case MicKind::Loopback:
                label += tr(L"   [не микрофон!]", L"   [not a microphone!]");
                break;
            case MicKind::Bluetooth:
                label += tr(L"   [низкое качество]", L"   [low quality]");
                break;
            case MicKind::Virtual: label += tr(L"   [виртуальный]", L"   [virtual]"); break;
            default: break;
        }
        if (mics[i].isDefault) label += tr(L"   (по умолчанию)", L"   (default)");
        SendMessageW(combo, CB_ADDSTRING, 0, (LPARAM)label.c_str());
        if (!settings.micDeviceId.empty() && mics[i].id == settings.micDeviceId) {
            select = (int)i + 1;
        }
    }

    SendMessageW(combo, CB_SETCURSEL, select, 0);
    updateMicWarning();
}

void SettingsWindow::Impl::updateMicWarning() {
    const int sel = (int)SendMessageW(ctrl(kIdMic), CB_GETCURSEL, 0, 0);
    std::wstring text;

    if (sel > 0 && (size_t)(sel - 1) < mics.size()) {
        text = mics[sel - 1].warning();
    } else if (sel == 0) {
        // Standart qurilma xavfli boʻlishi mumkin — tekshiramiz.
        for (const auto& m : mics) {
            if (m.isDefault && m.kind != MicKind::Normal) {
                text = tr(L"Системный: ", L"System default: ") + m.name + L"\n" + m.warning();
                break;
            }
        }
    }
    SetWindowTextW(ctrl(kIdMicWarning), text.c_str());

    const int yangiBalandlik = text.empty() ? 0 : kMicOgohH;
    if (yangiBalandlik != ogohBalandligi) {
        ogohBalandligi = yangiBalandlik;
        joylashuvniYangila();
    }
}

NutqTili SettingsWindow::Impl::tanlanganTil() const {
    switch (SendMessageW(ctrl(kIdNutqTili), CB_GETCURSEL, 0, 0)) {
        case 0: return NutqTili::Rus;
        case 1: return NutqTili::Ingliz;
        case 2: return NutqTili::Ozbek;
        default: return settings.nutqTili;
    }
}

// Tanlangan til modeli diskdami — macOS'dagi `tilIzohiniYangila`. Model
// yoʻq boʻlsa uning hajmi koʻrsatiladi: saqlangach «Yozish» boʻlimidagi
// banner uni yuklashni taklif qiladi.
void SettingsWindow::Impl::tilIzohiniYangila() {
    const NutqTili til = tanlanganTil();
    const std::wstring mb = std::to_wstring(modelHajmiMb(modelUchun(til)));
    const std::wstring matn = Engine::findModel(til).empty()
                                  ? tr(L"Модель (" + mb + L" МБ) будет скачана",
                                       L"Model (" + mb + L" MB) will be downloaded")
                                  : std::wstring(tr(L"Модель готова", L"Model ready"));
    SetWindowTextW(ctrl(kIdNutqTiliIzoh), matn.c_str());
}

void SettingsWindow::Impl::save() {
    // --- Hotkey
    const WORD hk = (WORD)SendMessageW(ctrl(kIdHotkey), HKM_GETHOTKEY, 0, 0);
    const BYTE vk = LOBYTE(hk);
    const BYTE flags = HIBYTE(hk);
    const UINT mods = hotkeyFlagsToMod(flags);

    if (vk != 0 && mods != 0) {
        settings.vkCode = vk;
        settings.modifiers = mods;
        settings.hotkeyLabel = keyLabel(vk);
    } else {
        MessageBoxW(hwnd,
                    tr(L"Клавиша не сохранена: нужен хотя бы один модификатор\n"
                       L"(Ctrl, Alt или Shift) и одна клавиша.\n\n"
                       L"Прежняя клавиша осталась без изменений.",
                       L"The shortcut wasn't saved: it needs at least one modifier\n"
                       L"(Ctrl, Alt or Shift) and one key.\n\n"
                       L"The previous shortcut still works."),
                    tr(L"Настройки", L"Settings"), MB_OK | MB_ICONWARNING);
    }

    // --- Mikrofon
    const int sel = (int)SendMessageW(ctrl(kIdMic), CB_GETCURSEL, 0, 0);
    if (sel > 0 && (size_t)(sel - 1) < mics.size()) {
        settings.micDeviceId = mics[sel - 1].id;
        settings.micDeviceName = mics[sel - 1].name;
    } else {
        settings.micDeviceId.clear();
        settings.micDeviceName.clear();
    }

    // --- Qolgan sozlamalar
    settings.insertMode = SendMessageW(ctrl(kIdInsertMode), CB_GETCURSEL, 0, 0) == 1
                              ? InsertMode::Type
                              : InsertMode::Paste;

    const bool autoStart = SendMessageW(ctrl(kIdAutoStart), BM_GETCHECK, 0, 0) == BST_CHECKED;
    settings.autoStart = autoStart;
    settings.useGpu = SendMessageW(ctrl(kIdUseGpu), BM_GETCHECK, 0, 0) == BST_CHECKED;
    settings.oddiyApostrof = SendMessageW(ctrl(kIdApostrof), BM_GETCHECK, 0, 0) == BST_CHECKED;
    settings.nutqTili = tanlanganTil();
    const UITili oldingiUITili = settings.uiTili;
    {
        const LRESULT i = SendMessageW(ctrl(kIdUITili), CB_GETCURSEL, 0, 0);
        if (i >= 0 && i <= static_cast<LRESULT>(UITili::Ingliz))
            settings.uiTili = static_cast<UITili>(i);
    }
    // Yoqilgan rejim qayta saqlansa muddat uzaymaydi — faqat yangi yoqilganda 24 soat.
    const long long hozir = static_cast<long long>(std::time(nullptr));
    const bool diagnostika = SendMessageW(ctrl(kIdDiagnostika), BM_GETCHECK, 0, 0) == BST_CHECKED;
    if (!diagnostika) {
        settings.diagnostikaTugash = 0;
    } else if (!diagnostikaFaolmi(settings.diagnostikaTugash, hozir)) {
        settings.diagnostikaTugash = hozir + kDiagnostikaMuddati;
    }

    llmniSaqla();

    setAutoStart(autoStart);

    // Fayl QAYTA oʻqiladi va faqat shu oyna tahrirlaydigan maydonlar ustiga
    // yoziladi (E1): oyna ochiq turganda boshqa modul faylga yozgan boʻlishi
    // mumkin.
    settings = sozlamaOynasidan(loadSettings(), settings);
    if (!saveSettings(settings)) {
        MessageBoxW(hwnd,
                    tr(L"Настройки не сохранены. Есть ли место на диске?",
                       L"Couldn't save the settings. Is there space on the disk?"),
                    tr(L"Настройки", L"Settings"), MB_OK | MB_ICONERROR);
        return;
    }
    logWrite(L"sozlamalar saqlandi: " + settings.hotkeyDisplay() + L", nutq tili " +
             nutqTiliKodi(settings.nutqTili));
    if (onSaved) onSaved(settings);

    // Interfeys tili — macOS'dagi `uiTilOzgardi`: til ishga tushishda bir
    // marta aniqlanadi, shuning uchun qayta ishga tushirishni taklif qilamiz.
    if (settings.uiTili != oldingiUITili &&
        MessageBoxW(
            hwnd,
            tr(L"Язык интерфейса сменится после перезапуска.\n\nПерезапустить Voxly сейчас?",
               L"The new language applies after a restart.\n\nRestart Voxly now?"),
            tr(L"Перезапустить Voxly?", L"Restart Voxly?"), MB_YESNO | MB_ICONQUESTION) == IDYES &&
        onQaytaIshga) {
        onQaytaIshga();
    }
}

// ------------------------------------------------------------------- API

SettingsWindow::SettingsWindow() : d(new Impl) {}

SettingsWindow::~SettingsWindow() {
    if (d->hwnd) DestroyWindow(d->hwnd);
    if (d->font) DeleteObject(d->font);
    if (d->kichikFont) DeleteObject(d->kichikFont);
    delete d;
}

HWND SettingsWindow::oyna() const { return d ? d->hwnd : nullptr; }

void SettingsWindow::setOnSaved(std::function<void(const Settings&)> cb) {
    d->onSaved = std::move(cb);
}

void SettingsWindow::setOnQaytaIshga(std::function<void()> cb) { d->onQaytaIshga = std::move(cb); }

void SettingsWindow::show(HINSTANCE instance, const Settings& current, HWND ega) {
    d->settings = current;

    if (!d->hwnd) {
        d->instance = instance;

        INITCOMMONCONTROLSEX icc{sizeof(icc), ICC_HOTKEY_CLASS | ICC_STANDARD_CLASSES | ICC_LINK_CLASS};
        InitCommonControlsEx(&icc);

        WNDCLASSEXW wc{};
        wc.cbSize = sizeof(wc);
        wc.lpfnWndProc = settingsProc;
        wc.hInstance = instance;
        wc.lpszClassName = kClassName;
        wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
        wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
        wc.hIcon = LoadIconW(instance, MAKEINTRESOURCEW(101));
        if (!wc.hIcon) wc.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
        RegisterClassExW(&wc);

        d->hwnd =
            CreateWindowExW(0, kClassName, tr(L"Voxly — Настройки", L"Voxly — Settings"),
                            WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_VSCROLL, CW_USEDEFAULT,
                            CW_USEDEFAULT, 100, 100, ega, nullptr, instance, d);
        if (!d->hwnd) {
            logWrite(L"XATO: sozlamalar oynasi yaratilmadi");
            return;
        }

        d->dpi = GetDpiForWindow(d->hwnd);
        d->font = CreateFontW(-d->scale(13), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                              DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS,
                              CLEARTYPE_QUALITY, VARIABLE_PITCH, L"Segoe UI");
        d->kichikFont = CreateFontW(-d->scale(11), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                                    DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS,
                                    CLEARTYPE_QUALITY, VARIABLE_PITCH, L"Segoe UI");

        // Mijoz maydoni aynan kerakli oʻlchamda boʻlishi uchun ramka
        // qalinligini hisobga olamiz.
        RECT rc{0, 0, d->scale(kWinW), d->scale(kWinH)};
        AdjustWindowRectExForDpi(&rc, WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU, FALSE, 0, d->dpi);
        SetWindowPos(d->hwnd, nullptr, 0, 0, rc.right - rc.left, rc.bottom - rc.top,
                     SWP_NOMOVE | SWP_NOZORDER);

        d->build();
    }

    // Joriy qiymatlarni qoʻyamiz
    SendMessageW(d->ctrl(kIdHotkey), HKM_SETHOTKEY,
                 MAKEWORD(current.vkCode, modToHotkeyFlags(current.modifiers)), 0);
    SendMessageW(d->ctrl(kIdInsertMode), CB_SETCURSEL,
                 current.insertMode == InsertMode::Type ? 1 : 0, 0);
    SendMessageW(d->ctrl(kIdAutoStart), BM_SETCHECK,
                 autoStartEnabled() ? BST_CHECKED : BST_UNCHECKED, 0);
    SendMessageW(d->ctrl(kIdUseGpu), BM_SETCHECK, current.useGpu ? BST_CHECKED : BST_UNCHECKED, 0);
    SendMessageW(d->ctrl(kIdApostrof), BM_SETCHECK,
                 current.oddiyApostrof ? BST_CHECKED : BST_UNCHECKED, 0);
    SendMessageW(d->ctrl(kIdNutqTili), CB_SETCURSEL, static_cast<WPARAM>(current.nutqTili), 0);
    SendMessageW(d->ctrl(kIdUITili), CB_SETCURSEL, static_cast<WPARAM>(current.uiTili), 0);
    d->tilIzohiniYangila();
    SendMessageW(
        d->ctrl(kIdDiagnostika), BM_SETCHECK,
        diagnostikaFaolmi(current.diagnostikaTugash, static_cast<long long>(std::time(nullptr)))
            ? BST_CHECKED
            : BST_UNCHECKED,
        0);
    d->llmniYukla();

    // Qurilmalar roʻyxatini har safar yangilaymiz — foydalanuvchi oyna
    // ochiq boʻlmagan paytda mikrofon ulagan boʻlishi mumkin.
    d->fillMics();

    // Oynani kursor turgan monitorda markazlashtiramiz
    POINT pt;
    GetCursorPos(&pt);
    HMONITOR mon = MonitorFromPoint(pt, MONITOR_DEFAULTTOPRIMARY);
    MONITORINFO mi{};
    mi.cbSize = sizeof(mi);
    GetMonitorInfoW(mon, &mi);
    RECT wr;
    GetWindowRect(d->hwnd, &wr);
    const int w = wr.right - wr.left, h = wr.bottom - wr.top;
    SetWindowPos(d->hwnd, HWND_TOP, mi.rcWork.left + (mi.rcWork.right - mi.rcWork.left - w) / 2,
                 mi.rcWork.top + (mi.rcWork.bottom - mi.rcWork.top - h) / 2, 0, 0, SWP_NOSIZE);

    forceForeground(d->hwnd);
}

}  // namespace rubai
