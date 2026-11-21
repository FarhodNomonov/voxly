// `vaqt_format.cpp` testlari.
//
// Bu matnlar foydalanuvchi koʻradigan yozuvlar va ular macOS bilan AYNAN
// bir xil boʻlishi shart (`tests/test_vaqt_format.swift` dagi bilan bir
// xil holatlar tekshiriladi) — rus va ingliz interfeysida. Shu sabab test bor.
#include "../core/ui_tili.h"
#include "../core/vaqt_format.h"

#include <ctime>
#include <string>

namespace kotib_test {
void tekshir(const std::wstring& nom, bool shart);
void tengmi(const std::wstring& nom, const std::wstring& olingan, const std::wstring& kutilgan);
}  // namespace kotib_test

using kotib_test::tekshir;
using kotib_test::tengmi;
using namespace rubai;

namespace {

// Mahalliy vaqt boʻyicha berilgan kun va soatning Unix vaqtini qaytaradi.
// Test soat mintaqasidan mustaqil boʻlishi uchun `mktime` ishlatiladi.
long long vaqt(int yil, int oy, int kun, int soat, int daqiqa) {
    std::tm t{};
    t.tm_year = yil - 1900;
    t.tm_mon = oy - 1;
    t.tm_mday = kun;
    t.tm_hour = soat;
    t.tm_min = daqiqa;
    t.tm_isdst = -1;
    return static_cast<long long>(std::mktime(&t));
}

}  // namespace

void vaqtFormatTestlari() {
    // Matnlar interfeys tilida (`ui_tili.h`) — avval rus, oxirida ingliz.
    joriyUITiliniQoy(UITili::Rus);

    // ---- taymer ----
    tengmi(L"taymer nol", VaqtFormat::taymer(0), L"0:00");
    tengmi(L"taymer soniyalar", VaqtFormat::taymer(4), L"0:04");
    // 4.9 soniya hali «0:04» — sekund sanogʻi oldinga yugurmasin.
    tengmi(L"taymer pastga yaxlitlanadi", VaqtFormat::taymer(4.9), L"0:04");
    tengmi(L"taymer daqiqa", VaqtFormat::taymer(83), L"1:23");
    tengmi(L"taymer uzun", VaqtFormat::taymer(725), L"12:05");
    tengmi(L"taymer manfiy", VaqtFormat::taymer(-5), L"0:00");

    // ---- davomiylik ----
    tengmi(L"davomiylik juda qisqa", VaqtFormat::davomiylik(30), L"меньше минуты");
    tengmi(L"davomiylik daqiqa", VaqtFormat::davomiylik(12 * 60), L"12 мин");
    tengmi(L"davomiylik roppa-rosa soat", VaqtFormat::davomiylik(3600), L"1 ч");
    tengmi(L"davomiylik soat va daqiqa", VaqtFormat::davomiylik(65 * 60), L"1 ч 5 мин");
    tengmi(L"davomiylik manfiy", VaqtFormat::davomiylik(-10), L"меньше минуты");

    // ---- nisbiy va kun ----
    const long long hozir = vaqt(2026, 9, 10, 12, 0);

    tengmi(L"nisbiy bugun", VaqtFormat::nisbiy(vaqt(2026, 9, 10, 16, 4), hozir), L"сегодня 16:04");
    tengmi(L"nisbiy kecha", VaqtFormat::nisbiy(vaqt(2026, 9, 9, 18, 22), hozir), L"вчера 18:22");
    tengmi(L"nisbiy eski sana", VaqtFormat::nisbiy(vaqt(2026, 8, 22, 18, 22), hozir),
           L"22 авг. 18:22");

    tengmi(L"kun bugun", VaqtFormat::kun(vaqt(2026, 9, 10, 1, 5), hozir), L"сегодня");
    tengmi(L"kun kecha", VaqtFormat::kun(vaqt(2026, 9, 9, 23, 59), hozir), L"вчера");
    tengmi(L"kun eski", VaqtFormat::kun(vaqt(2026, 8, 22, 9, 0), hozir), L"22 авг.");

    // Kecha yarim tundan keyin: taqqoslash KALENDAR kuni boʻyicha ketadi,
    // «24 soat oldin» boʻyicha emas.
    const long long yarimTun = vaqt(2026, 9, 10, 0, 30);
    tengmi(L"yarim tundan keyin kechagi kech", VaqtFormat::kun(vaqt(2026, 9, 9, 22, 0), yarimTun),
           L"вчера");
    tengmi(L"yarim tundan keyin bugun", VaqtFormat::kun(vaqt(2026, 9, 10, 0, 1), yarimTun),
           L"сегодня");

    // Oy chegarasi — «kecha» hisobi oy oʻzgarganda ham toʻgʻri boʻlsin.
    const long long oyBoshi = vaqt(2026, 3, 1, 10, 0);
    tengmi(L"oy chegarasida kecha", VaqtFormat::kun(vaqt(2026, 2, 28, 20, 0), oyBoshi), L"вчера");

    // Yil chegarasi.
    const long long yilBoshi = vaqt(2026, 1, 1, 9, 0);
    tengmi(L"yil chegarasida kecha", VaqtFormat::kun(vaqt(2025, 12, 31, 23, 0), yilBoshi),
           L"вчера");

    // Barcha oy qisqartmalari — macOS'dagi `DateFormatter` ("d MMM") bilan
    // bir xil (`ru_RU` va `en_US`).
    const wchar_t* oylarRu[12] = {L"янв.", L"февр.", L"марта", L"апр.", L"мая",   L"июня",
                                  L"июля", L"авг.",  L"сент.", L"окт.", L"нояб.", L"дек."};
    const wchar_t* oylarEn[12] = {L"Jan", L"Feb", L"Mar", L"Apr", L"May", L"Jun",
                                  L"Jul", L"Aug", L"Sep", L"Oct", L"Nov", L"Dec"};
    for (int oy = 1; oy <= 12; ++oy) {
        tengmi(L"oy qisqartmasi (ru) " + std::to_wstring(oy),
               VaqtFormat::kun(vaqt(2025, oy, 15, 12, 0), hozir),
               L"15 " + std::wstring(oylarRu[oy - 1]));
    }

    // ---- Ingliz interfeysi ----
    joriyUITiliniQoy(UITili::Ingliz);
    for (int oy = 1; oy <= 12; ++oy) {
        tengmi(L"oy qisqartmasi (en) " + std::to_wstring(oy),
               VaqtFormat::kun(vaqt(2025, oy, 15, 12, 0), hozir),
               L"15 " + std::wstring(oylarEn[oy - 1]));
    }
    tengmi(L"en: nisbiy bugun", VaqtFormat::nisbiy(vaqt(2026, 9, 10, 16, 4), hozir),
           L"today 16:04");
    tengmi(L"en: nisbiy kecha", VaqtFormat::nisbiy(vaqt(2026, 9, 9, 18, 22), hozir),
           L"yesterday 18:22");
    tengmi(L"en: nisbiy eski sana", VaqtFormat::nisbiy(vaqt(2026, 8, 22, 18, 22), hozir),
           L"22 Aug 18:22");
    tengmi(L"en: davomiylik juda qisqa", VaqtFormat::davomiylik(30), L"under a minute");
    tengmi(L"en: davomiylik daqiqa", VaqtFormat::davomiylik(12 * 60), L"12 min");
    tengmi(L"en: davomiylik soat", VaqtFormat::davomiylik(3600), L"1 h");
    tengmi(L"en: davomiylik soat va daqiqa", VaqtFormat::davomiylik(65 * 60), L"1 h 5 min");

    joriyUITiliniQoy(UITili::Rus);
}
