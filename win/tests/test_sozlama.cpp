// `config.h` dagi `sozlamaOynasidan` (barqarorlik E1), nutq tili va
// `model_tanlov.h` testlari.
#include "../core/config.h"
#include "../core/matn_format.h"
#include "../core/model_tanlov.h"
#include "../core/ui_tili.h"

#include <string>

namespace kotib_test {
void tekshir(const std::wstring& nom, bool shart);
}  // namespace kotib_test

using kotib_test::tekshir;
using namespace rubai;

namespace {

void nutqTiliTestlari() {
    // Kod ↔ til (sozlamalar faylidagi `nutq.tili=`).
    for (NutqTili t : {NutqTili::Rus, NutqTili::Ingliz, NutqTili::Ozbek}) {
        tekshir(std::wstring(L"nutq tili: ") + nutqTiliKodi(t) + L" qaytadi",
                nutqTiliKoddan(nutqTiliKodi(t), NutqTili::Ozbek) == t);
    }
    tekshir(L"nutq tili: nomaʼlum kod — standart",
            nutqTiliKoddan(L"de", NutqTili::Ozbek) == NutqTili::Ozbek &&
                nutqTiliKoddan(L"", NutqTili::Rus) == NutqTili::Rus);

    // Yangi oʻrnatish — rus (macOS'dagi `NutqTili.standart`); kalitsiz eski
    // fayl (Kotib'dan koʻchgan) — oʻzbek, til jimgina almashmasin.
    tekshir(L"nutq tili: yangi oʻrnatish — rus", boshlangichNutqTili(false) == NutqTili::Rus);
    tekshir(L"nutq tili: Kotib sozlamasi — oʻzbek", boshlangichNutqTili(true) == NutqTili::Ozbek);
    tekshir(L"nutq tili: Settings standarti — rus", Settings{}.nutqTili == NutqTili::Rus);

    // Modellar: rus va ingliz — bitta Whisper, oʻzbek — rubaiSTT
    // (macOS'dagi `ModelTanlov.malum(til)`).
    tekshir(L"model: rus va ingliz bitta", birXilModel(NutqTili::Rus, NutqTili::Ingliz));
    tekshir(L"model: oʻzbek alohida", !birXilModel(NutqTili::Ozbek, NutqTili::Rus));
    tekshir(L"model: oʻzbek — rubaiSTT",
            std::wstring(modelUchun(NutqTili::Ozbek).fayl) == L"ggml-rubaistt.bin" &&
                modelUchun(NutqTili::Ozbek).hajm == 823369796LL);
    tekshir(L"model: rus — large-v3-turbo q5_0",
            std::wstring(modelUchun(NutqTili::Rus).fayl) == L"ggml-large-v3-turbo-q5_0.bin" &&
                modelUchun(NutqTili::Rus).hajm == 574041195LL);
    tekshir(L"model: sha256 — 64 belgi",
            std::string(kOzbekModel.sha256).size() == 64 &&
                std::string(kWhisperModel.sha256).size() == 64);
    tekshir(L"model: hajm MB", modelHajmiMb(kWhisperModel) == 547 && modelHajmiMb(kOzbekModel) == 785);

    // Apostrof uslubi tilga bogʻliq (macOS'dagi `Prefs.apostrof`): oʻzbek
    // meʼyori faqat oʻzbek nutqida, rus/ingliz matnida hamma variant ASCII.
    Settings s;
    s.nutqTili = NutqTili::Ozbek;
    s.oddiyApostrof = false;
    tekshir(L"apostrof: oʻzbek — standart", apostrofUslubi(s) == Apostrof::Standart);
    s.oddiyApostrof = true;
    tekshir(L"apostrof: oʻzbek + oddiy", apostrofUslubi(s) == Apostrof::Oddiy);
    s.oddiyApostrof = false;
    s.nutqTili = NutqTili::Ingliz;
    tekshir(L"apostrof: ingliz — doim oddiy", apostrofUslubi(s) == Apostrof::Oddiy);
    tekshir(L"apostrof: ingliz matni buzilmaydi",
            matnniTayyorla(L"I don’t know", apostrofUslubi(s)) == L"I don't know");
    s.nutqTili = NutqTili::Rus;
    tekshir(L"apostrof: rus — doim oddiy", apostrofUslubi(s) == Apostrof::Oddiy);
    s.nutqTili = NutqTili::Ozbek;
    tekshir(L"apostrof: oʻzbek matni meʼyorlanadi",
            matnniTayyorla(L"o'zbek", apostrofUslubi(s)) == L"oʻzbek");
}

// Interfeys tili (`ui_tili.h`) — macOS'dagi `UITili.tizimdan` testlari
// (`tests/test_model_tanlov.swift`) bilan bir xil holatlar va yana Windows
// tilidagi koʻrinishlar.
void uiTiliTestlari() {
    tekshir(L"ui tili: rus", uiTiliTizimdan({L"ru-RU"}) == UITili::Rus);
    tekshir(L"ui tili: oʻzbek → rus", uiTiliTizimdan({L"uz-Latn-UZ", L"en-US"}) == UITili::Rus);
    tekshir(L"ui tili: ingliz", uiTiliTizimdan({L"en-US", L"ru-RU"}) == UITili::Ingliz);
    tekshir(L"ui tili: nemis → ingliz", uiTiliTizimdan({L"de-DE"}) == UITili::Ingliz);
    tekshir(L"ui tili: nemis, keyin rus → rus", uiTiliTizimdan({L"de-DE", L"ru"}) == UITili::Rus);
    tekshir(L"ui tili: boʻsh → ingliz", uiTiliTizimdan({}) == UITili::Ingliz);
    for (const wchar_t* t : {L"uk-UA", L"be-BY", L"kk-KZ", L"ky-KG", L"tg-Cyrl-TJ", L"az-Latn-AZ",
                             L"hy-AM", L"ka-GE", L"tk-TM", L"uz-Cyrl-UZ"}) {
        tekshir(std::wstring(L"ui tili: MDH → rus (") + t + L")",
                uiTiliTizimdan({t}) == UITili::Rus);
    }
    tekshir(L"ui tili: katta harf va _", uiTiliTizimdan({L"RU_ru"}) == UITili::Rus);
    tekshir(L"ui tili: fransuz → ingliz", uiTiliTizimdan({L"fr-FR", L"es-ES"}) == UITili::Ingliz);

    // Sozlamalar faylidagi `ui.tili=` kodi.
    for (UITili t : {UITili::Tizim, UITili::Rus, UITili::Ingliz}) {
        tekshir(std::wstring(L"ui tili kodi: ") + uiTiliKodi(t), uiTiliKoddan(uiTiliKodi(t)) == t);
    }
    tekshir(L"ui tili kodi: nomaʼlum — tizim",
            uiTiliKoddan(L"uz") == UITili::Tizim && uiTiliKoddan(L"") == UITili::Tizim);
    tekshir(L"ui tili: Settings standarti — tizim", Settings{}.uiTili == UITili::Tizim);

    // `tr` — qoʻyilgan tilga qarab.
    joriyUITiliniQoy(UITili::Ingliz);
    tekshir(L"tr: ingliz", std::wstring(tr(L"Настройки", L"Settings")) == L"Settings");
    joriyUITiliniQoy(UITili::Rus);
    tekshir(L"tr: rus", std::wstring(tr(L"Настройки", L"Settings")) == L"Настройки");
}

}  // namespace

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
    oyna.nutqTili = NutqTili::Ingliz;
    oyna.uiTili = UITili::Ingliz;

    Settings fayl;  // diskdagi, boshqa modullar yozgan
    fayl.didOnboard = true;
    fayl.idleUnloadSeconds = 60;

    const Settings r = sozlamaOynasidan(fayl, oyna);
    tekshir(L"sozlama: onboarding belgisi saqlanadi", r.didOnboard);
    tekshir(L"sozlama: boʻsh turish vaqti saqlanadi", r.idleUnloadSeconds == 60);
    tekshir(L"sozlama: diagnostika oynadan", r.diagnostikaTugash == 1791086400);
    tekshir(L"sozlama: nutq tili oynadan", r.nutqTili == NutqTili::Ingliz);
    tekshir(L"sozlama: interfeys tili oynadan", r.uiTili == UITili::Ingliz);

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

    nutqTiliTestlari();
    uiTiliTestlari();
}
