// Voxly — interfeys tili (rus / ingliz).
//
// macOS'dagi `src/ui_tili.swift` ning ekvivalenti. Har bir matn chaqiruv
// joyida ikkala tilda turadi: `tr(L"Настройки", L"Settings")`. Nega resurs
// jadvali emas: kalit va tarjima bir joyda — tarjimasi unutilgan matn
// kompilyatsiya qilinmaydi, kodni oʻqiganda ham nima koʻrinishi darhol aniq.
//
// Til jarayonda BIR MARTA aniqlanadi (birinchi `tr` chaqiruvida yoki
// `wWinMain` boshida): Sozlamalar → «Язык интерфейса» oʻzgarsa ilova qayta
// ishga tushadi — macOS bilan bir xil. Win32 boshqaruvlarini jonli qayta
// nomlash har bir oynani qayta qurishni talab qilardi.
#pragma once

#include <string>
#include <vector>

namespace rubai {

// Sozlamalardagi tanlov. Tartib macOS'dagi `UITili.allCases` bilan bir xil —
// Sozlamalardagi roʻyxat shu tartibda (indeks = enum qiymati).
enum class UITili { Tizim, Rus, Ingliz };

// Sozlamalar faylidagi `ui.tili=` qiymati: "system", "ru", "en".
inline const wchar_t* uiTiliKodi(UITili t) {
    switch (t) {
        case UITili::Tizim: return L"system";
        case UITili::Rus: return L"ru";
        case UITili::Ingliz: return L"en";
    }
    return L"system";
}

// Nomaʼlum yoki boʻsh kod — `Tizim`.
inline UITili uiTiliKoddan(const std::wstring& kod) {
    if (kod == L"ru") return UITili::Rus;
    if (kod == L"en") return UITili::Ingliz;
    return UITili::Tizim;
}

// Tizim tillari roʻyxatidan (afzallik tartibida, masalan "ru-RU", "en-US"):
// rus tilini tushunadigan mintaqalar (MDH) — rus, qolganlar — ingliz.
// Roʻyxatdagi BIRINCHI tanish til hal qiladi. macOS'dagi `UITili.tizimdan`
// bilan belgima-belgi bir xil qoida; natija faqat `Rus` yoki `Ingliz`.
UITili uiTiliTizimdan(const std::vector<std::wstring>& tillar);

// Ishlayotgan jarayondagi til (`Rus` yoki `Ingliz`). Birinchi chaqiruvda
// sozlamalar va tizim tilidan aniqlanadi va keyin oʻzgarmaydi.
UITili joriyUITili();

// Jarayon tilini qatʼiy qoʻyadi — testlar uchun. `Tizim` berilsa keyingi
// `joriyUITili()` qaytadan aniqlaydi.
void joriyUITiliniQoy(UITili t);

inline bool uiInglizmi() { return joriyUITili() == UITili::Ingliz; }

// Interfeys matni: rus va ingliz varianti.
inline const wchar_t* tr(const wchar_t* ru, const wchar_t* en) { return uiInglizmi() ? en : ru; }
inline std::wstring tr(const std::wstring& ru, const std::wstring& en) {
    return uiInglizmi() ? en : ru;
}

}  // namespace rubai
