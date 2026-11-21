// Ilova versiyasi va ishga tushish muhiti. Interfeys va izohlar — `versiya.h`.

#include "versiya.h"

#include "kotib_versiya.h"
#include "util.h"

#include <windows.h>

namespace rubai {

namespace {

// Windows versiyasi, masalan "Windows 11 26100".
//
// `GetVersionEx` eskirgan va manifestga bogʻliq yolgʻon qiymat qaytaradi.
// `RtlGetVersion` esa haqiqiy raqamni beradi — u ntdll ichida, shuning uchun
// ish paytida topamiz.
std::wstring osVersiyasi() {
    typedef LONG(WINAPI * RtlGetVersionFn)(PRTL_OSVERSIONINFOW);
    HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    if (!ntdll) return L"Windows";

    auto fn = reinterpret_cast<RtlGetVersionFn>(
        reinterpret_cast<void*>(GetProcAddress(ntdll, "RtlGetVersion")));
    if (!fn) return L"Windows";

    RTL_OSVERSIONINFOW v{};
    v.dwOSVersionInfoSize = sizeof(v);
    if (fn(&v) != 0) return L"Windows";

    // Windows 11 oʻzini 10.0 deb koʻrsatadi; ularni build raqami ajratadi
    // (22000 dan boshlab — Windows 11).
    const wchar_t* nom =
        (v.dwMajorVersion == 10 && v.dwBuildNumber >= 22000) ? L"Windows 11" : L"Windows 10";
    if (v.dwMajorVersion < 10) nom = L"Windows";

    return std::wstring(nom) + L" " + std::to_wstring(v.dwBuildNumber);
}

// Ishlayotgan arxitektura — Windows'da x64 va ARM64 alohida .exe.
const wchar_t* arxitektura() {
#if defined(__aarch64__) || defined(_M_ARM64)
    return L"arm64";
#else
    return L"x64";
#endif
}

}  // namespace

std::wstring joriyVersiya() {
    // `VERSION` → CMake → `kotib_versiya.h`. .exe resursidagi raqamli
    // versiya `-sinov1` qoʻshimchasini yoʻqotardi.
    return toWide(KOTIB_VER_STR);
}

std::wstring ishgaTushishMuhiti() {
    return L"Voxly " + joriyVersiya() + L" " + arxitektura() + L", " + osVersiyasi();
}

}  // namespace rubai
