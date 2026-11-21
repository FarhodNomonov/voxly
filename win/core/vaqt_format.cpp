// Foydalanuvchiga koʻrsatiladigan vaqt yozuvlari.
// Interfeys va izohlar — `vaqt_format.h`.

#include "vaqt_format.h"

#include "ui_tili.h"

#include <algorithm>
#include <cmath>
#include <ctime>

namespace rubai {
namespace VaqtFormat {

namespace {

// macOS'dagi `DateFormatter` ("d MMM", `ru_RU` / `en_US`) bilan bir xil
// qisqartmalar — rus tilida kelishikdagi shakl («15 марта», «15 мая»).
const wchar_t* kOylarRu[12] = {L"янв.", L"февр.", L"марта", L"апр.", L"мая",   L"июня",
                               L"июля", L"авг.",  L"сент.", L"окт.", L"нояб.", L"дек."};
const wchar_t* kOylarEn[12] = {L"Jan", L"Feb", L"Mar", L"Apr", L"May", L"Jun",
                               L"Jul", L"Aug", L"Sep", L"Oct", L"Nov", L"Dec"};

std::tm mahalliy(long long unix) {
    const std::time_t t = static_cast<std::time_t>(unix);
    std::tm m{};
    localtime_s(&m, &t);
    return m;
}

bool birKunmi(const std::tm& a, const std::tm& b) {
    return a.tm_year == b.tm_year && a.tm_mon == b.tm_mon && a.tm_mday == b.tm_mday;
}

std::wstring soatMatni(const std::tm& m) {
    wchar_t b[8];
    swprintf(b, 8, L"%02d:%02d", m.tm_hour, m.tm_min);
    return b;
}

// `swprintf` ATAYLAB yoʻq: ASCII boʻlmagan matn (kirill) bilan u macOS'dagi
// test quvurida («C» lokal) xato qaytaradi — oddiy ulash ikkala tomonda bir xil.
std::wstring sanaMatni(const std::tm& m) {
    return std::to_wstring(m.tm_mday) + L" " + (uiInglizmi() ? kOylarEn : kOylarRu)[m.tm_mon];
}

// «сегодня» / «вчера» / «22 авг.». Ikkala funksiya ham shundan foydalanadi.
std::wstring kunAsosi(const std::tm& sana, const std::tm& hozir) {
    if (birKunmi(sana, hozir)) return tr(L"сегодня", L"today");

    // Kechagi kunni «hozir minus 24 soat» dan olamiz va localtime bilan
    // qaytadan yoyamiz — oy/yil chegarasi va yozgi vaqt oʻzgarishi
    // qoʻlda hisoblashda xato beradi.
    std::tm h = hozir;
    h.tm_isdst = -1;
    std::time_t t = std::mktime(&h) - 24 * 60 * 60;
    std::tm kechaTm{};
    localtime_s(&kechaTm, &t);
    if (birKunmi(sana, kechaTm)) return tr(L"вчера", L"yesterday");

    return sanaMatni(sana);
}

}  // namespace

std::wstring taymer(double soniya) {
    // Tizim soati sozlanib qolsa hisob manfiy chiqishi mumkin.
    const long long jami = std::max<long long>(0, static_cast<long long>(std::floor(soniya)));
    wchar_t b[24];
    swprintf(b, 24, L"%lld:%02lld", jami / 60, jami % 60);
    return b;
}

std::wstring nisbiy(long long unix, long long hozir) {
    if (hozir == 0) hozir = static_cast<long long>(std::time(nullptr));
    const std::tm s = mahalliy(unix);
    const std::tm h = mahalliy(hozir);
    return kunAsosi(s, h) + L" " + soatMatni(s);
}

std::wstring davomiylik(double soniya) {
    const long long daqiqa = std::max<long long>(0, static_cast<long long>(soniya)) / 60;
    // Nol daqiqa «fayl boʻsh» degan taassurot beradi — buni ochiq aytamiz.
    if (daqiqa == 0) return tr(L"меньше минуты", L"under a minute");

    const std::wstring min = tr(L" мин", L" min");
    if (daqiqa < 60) return std::to_wstring(daqiqa) + min;
    const long long soat = daqiqa / 60;
    const long long qoldiq = daqiqa % 60;
    const std::wstring s = std::to_wstring(soat) + tr(L" ч", L" h");
    return qoldiq == 0 ? s : s + L" " + std::to_wstring(qoldiq) + min;
}

std::wstring kun(long long unix, long long hozir) {
    if (hozir == 0) hozir = static_cast<long long>(std::time(nullptr));
    return kunAsosi(mahalliy(unix), mahalliy(hozir));
}

}  // namespace VaqtFormat
}  // namespace rubai
