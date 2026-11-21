// `config.h` dagi `sozlamaOynasidan` testlari (barqarorlik E1).
#include "../core/config.h"

#include <string>

namespace kotib_test {
void tekshir(const std::wstring& nom, bool shart);
}  // namespace kotib_test

using kotib_test::tekshir;
using namespace rubai;

void sozlamaTestlari() {
    // Oyna ochilganda nusxa olindi, shu orada boshqa modul faylga yozdi,
    // keyin «Saqlash» bosildi.
    Settings oyna;  // ochilgandagi nusxa
    oyna.vkCode = 'K';
    oyna.modifiers = 3;
    oyna.hotkeyLabel = L"K";
    oyna.micDeviceId = L"{mic}";
    oyna.micDeviceName = L"USB mikrofon";
    oyna.insertMode = InsertMode::Type;
    oyna.autoStart = false;
    oyna.useGpu = false;
    oyna.oddiyApostrof = true;
    oyna.llmProvayder = "openai";
    oyna.llmBaseURL = L"https://x";
    oyna.llmModel = L"m";
    oyna.diagnostikaTugash = 1791086400;

    Settings fayl;  // diskdagi, boshqa modullar yozgan
    fayl.didOnboard = true;
    fayl.idleUnloadSeconds = 60;

    const Settings r = sozlamaOynasidan(fayl, oyna);
    tekshir(L"sozlama: onboarding belgisi saqlanadi", r.didOnboard);
    tekshir(L"sozlama: boʻsh turish vaqti saqlanadi", r.idleUnloadSeconds == 60);
    tekshir(L"sozlama: diagnostika oynadan", r.diagnostikaTugash == 1791086400);

    // Diagnostika muddati (macOS'dagi log siyosati testlari bilan bir xil holatlar).
    const long long h = 1791000000;
    tekshir(L"diagnostika: oʻchiq", !diagnostikaFaolmi(0, h));
    tekshir(L"diagnostika: 1 soat qoldi", diagnostikaFaolmi(h + 3600, h));
    tekshir(L"diagnostika: tugagan", !diagnostikaFaolmi(h - 1, h));
    tekshir(L"diagnostika: aniq tugash payti", !diagnostikaFaolmi(h, h));
    tekshir(L"diagnostika: 24 soat qoldi", diagnostikaFaolmi(h + 24 * 3600, h));
    tekshir(L"diagnostika: soat orqaga — 24 soatdan uzaymaydi",
            !diagnostikaFaolmi(h + 24 * 3600 + 1, h));
    tekshir(L"sozlama: oyna maydonlari qoʻllanadi",
            r.vkCode == 'K' && r.modifiers == 3 && r.hotkeyLabel == L"K" &&
                r.micDeviceId == L"{mic}" && r.micDeviceName == L"USB mikrofon" &&
                r.insertMode == InsertMode::Type && !r.autoStart && !r.useGpu && r.oddiyApostrof &&
                r.llmProvayder == "openai" && r.llmBaseURL == L"https://x" && r.llmModel == L"m");
}
