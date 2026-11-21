// Foydalanuvchiga koʻrsatiladigan vaqt yozuvlari.
//
// macOS'dagi `src/vaqt_format.swift` ning ekvivalenti. Matnlar AYNAN bir xil
// boʻlishi shart va interfeys tilida (`ui_tili.h`): «сегодня 16:04» / «today
// 16:04», «22 авг. 18:22» / «22 Aug 18:22», «1 ч 5 мин» / «1 h 5 min».
// Bitta ilovaning ikki tanasi bir xil gapirishi kerak.
//
// Oy qisqartmalari macOS'ning `ru_RU` / `en_US` lokalidagi "d MMM" dan
// olingan — `GetDateFormatEx` Windows versiyasiga qarab boshqacha beradi.
//
// Sof mantiq: fayl UI'dan ham, tarmoqdan ham mustaqil, shuning uchun
// `win/tests/` uni toʻliq qamrab oladi.
#pragma once

#include <string>

namespace rubai {
namespace VaqtFormat {

// Yozib olish taymeri: «0:04», «1:23», «12:05».
// Soniyalar PASTGA yaxlitlanadi — 4.9 soniya hali «0:04».
std::wstring taymer(double soniya);

// Tarix qatoridagi sana: «сегодня 16:04», «вчера 18:22», aks holda «22 авг. 18:22».
// Taqqoslash KALENDAR kuni boʻyicha, «24 soat oldin» boʻyicha emas.
// `hozir` — sinov uchun; 0 berilsa joriy vaqt olinadi.
std::wstring nisbiy(long long unix, long long hozir = 0);

// Fayl uzunligi: «12 мин», «1 ч 5 мин», «меньше минуты» (ingliz: «12 min»…).
std::wstring davomiylik(double soniya);

// Faqat kun: «сегодня», «вчера», aks holda «22 авг.».
std::wstring kun(long long unix, long long hozir = 0);

}  // namespace VaqtFormat
}  // namespace rubai
