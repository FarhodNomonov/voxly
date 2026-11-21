// Studiya amallari (LLM) va ularning prompt'lari.
// Interfeys va izohlar — `amallar.h`.

#include "amallar.h"

#include "llm.h"
#include "ui_tili.h"
#include "util.h"

#include <atomic>
#include <mutex>
#include <thread>

namespace rubai {

namespace {

// Har bir prompt'ga qoʻshiladigan umumiy qoidalar. macOS'dagi `umumiyQoida`
// (`src/amallar.swift`) bilan BELGIMA-BELGI bir xil. Prompt'lar inglizcha —
// modellar ularni eng aniq bajaradi; javob tili esa matnning oʻz tili.
const wchar_t* kUmumiyQoida =
    L"You work on a speech-to-text transcript.\n"
    L"\n"
    L"Strict rules:\n"
    L"- Reply in the SAME language and script as the transcript (Russian stays in\n"
    L"  Cyrillic, Uzbek stays in Latin, English stays English). Do not translate.\n"
    L"- Do NOT change the meaning. Do NOT add facts that are not in the text.\n"
    L"- Return only the result. No preamble like \"Here is the result\" or \"Sure\".";

std::wstring qoida(const std::wstring& vazifa) {
    return std::wstring(kUmumiyQoida) + L"\n\nYour task: " + vazifa;
}

// Bitta boʻlakka beriladigan maksimal soʻz soni — macOS bilan bir xil.
constexpr size_t kBolakSozLimiti = 3000;

}  // namespace

const std::vector<Amal>& amallar() {
    // Nomlar — interfeys tilida (`tr`); til jarayonda oʻzgarmaydi, shuning
    // uchun statik roʻyxat xavfsiz.
    static const std::vector<Amal> royxat = {
        {"tozalash", tr(L"Почистить текст", L"Clean up"), false,
         qoida(L"make the transcript easy to read.\n"
               L"- Fix punctuation.\n"
               L"- Split into meaningful paragraphs.\n"
               L"- Remove filler words, false starts and repeated words.\n"
               L"- Turn half-finished sentences into complete ones.\n"
               L"- Write numbers as digits (\"twenty five\" \u2192 \"25\").")},

        {"xulosa", tr(L"Краткое содержание", L"Summary"), true,
         qoida(L"write a 3\u20135 sentence summary of the text.")},

        {"asosiy_fikrlar", tr(L"Главные мысли", L"Key points"), true,
         qoida(L"list the key points as a bulleted list (each line starts with \"- \").")},

        {"bayonnoma", tr(L"Протокол встречи", L"Meeting minutes"), true,
         qoida(L"write meeting minutes with three sections: what was discussed, decisions,\n"
               L"action items. Use section titles in the transcript's language. Leave a\n"
               L"section empty if the text has nothing for it \u2014 do not invent.")},

        {"maqola", tr(L"Статья", L"Article"), false,
         qoida(L"rewrite the text as an article or blog post with a title, subheadings and "
               L"paragraphs.")},

        {"savol_javob", tr(L"Вопросы и ответы", L"Q&A"), true,
         qoida(L"write a FAQ based on the text. Start each question with \"**Q:** \" and each "
               L"answer with \"**A:** \".")},

        {"qisqartirish", tr(L"Сократить", L"Shorten"), false,
         qoida(L"shorten the text to about half its length, keeping all important information.")},

        {"uzaytirish", tr(L"Расширить", L"Expand"), false,
         qoida(L"write the text out in more detail \u2014 fuller sentences, clearer ideas. Do not "
               L"add new FACTS.")},
    };
    return royxat;
}

const Amal* amalTop(const std::string& id) {
    for (const auto& a : amallar()) {
        if (a.id == id) return &a;
    }
    return nullptr;
}

Amal erkinAmal(const std::wstring& korsatma) {
    return {"erkin", tr(L"Свой запрос", L"Custom request"), false,
            std::wstring(kUmumiyQoida) + L"\n\nUser instruction: " + korsatma};
}

// ---- Ish -------------------------------------------------------------------

struct AmalIshi::Ichki {
    std::atomic<bool> ketyapti{false};
    std::atomic<bool> bekor{false};

    // Qayta chaqiruvlar ishchi oqimdan chaqiriladi, egasi esa UI oqimida
    // yoʻq qilinishi mumkin. Qulf ikkalasini ajratadi: `uzil` dan keyin
    // oqim endi yoʻq obyektga murojaat qilmaydi.
    std::mutex qulf;
    std::function<void(const std::wstring&)> onDelta;
    std::function<void(const std::wstring&)> onTayyor;
    std::function<void(const std::wstring&)> onXato;

    LLMSorov asos;  // provayder, URL, model, kalit — bir marta oʻqiladi

    void delta(const std::wstring& s) {
        std::lock_guard<std::mutex> q(qulf);
        if (onDelta) onDelta(s);
    }
    void tayyor(const std::wstring& s) {
        std::lock_guard<std::mutex> q(qulf);
        if (onTayyor) onTayyor(s);
    }
    void xatoBer(const std::wstring& s) {
        std::lock_guard<std::mutex> q(qulf);
        if (onXato) onXato(s);
    }
    void uzil() {
        std::lock_guard<std::mutex> q(qulf);
        onDelta = nullptr;
        onTayyor = nullptr;
        onXato = nullptr;
    }

    void tugat() { ketyapti.store(false); }

    // Bitta soʻrov. Yigʻilgan matnni qaytaradi; xato boʻlsa `xato` toʻladi.
    std::wstring bitta(const Amal& amal, const std::wstring& matn, bool deltalarniUzat,
                       std::wstring& xato);

    void ishla(Amal amal, std::wstring matn);
};

std::wstring AmalIshi::Ichki::bitta(const Amal& amal, const std::wstring& matn, bool deltalarniUzat,
                                    std::wstring& xato) {
    LLMSorov s = asos;
    s.system = amal.system;
    s.user = matn;

    std::wstring yigilgan;
    xato = llmOqim(
        s,
        [&](const std::wstring& b) {
            yigilgan += b;
            if (deltalarniUzat) delta(b);
        },
        [&] { return bekor.load(); });

    // Bekor qilish tarmoq xatosi emas — foydalanuvchi oʻzi bosgan tugma
    // uchun «Internetga ulanish yoʻq» deb yozish chalgʻitadi.
    if (bekor.load()) xato = tr(L"Отменено.", L"Cancelled.");
    return yigilgan;
}

void AmalIshi::Ichki::ishla(Amal amal, std::wstring matn) {
    const std::vector<std::wstring> bolaklar = paragrafBolaklari(matn, kBolakSozLimiti);

    if (bolaklar.empty()) {
        tugat();
        xatoBer(tr(L"Текст пустой.", L"The text is empty."));
        return;
    }

    std::wstring xato;
    std::wstring natija;

    if (bolaklar.size() == 1) {
        natija = bitta(amal, bolaklar[0], true, xato);
    } else if (amal.yiguvchi) {
        // Yigʻuvchi amallar: har bir boʻlak qisqartiriladi, soʻng yakuniy soʻrov.
        const Amal oraliqAmal{"oraliq", L"", false,
                              qoida(L"briefly write down the main content of this part. "
                                    L"It will be merged with other parts in the next step.")};

        std::wstring oraliq;
        for (const auto& b : bolaklar) {
            const std::wstring q = bitta(oraliqAmal, b, false, xato);
            if (!xato.empty()) break;
            if (!oraliq.empty()) oraliq += L"\n\n";
            oraliq += q;
        }
        if (xato.empty()) natija = bitta(amal, oraliq, true, xato);
    } else {
        // Oʻzgartiruvchi amallar: har bir boʻlak alohida, natijalar ulanadi.
        for (size_t i = 0; i < bolaklar.size(); ++i) {
            if (i > 0) delta(L"\n\n");
            const std::wstring q = bitta(amal, bolaklar[i], true, xato);
            if (!xato.empty()) break;
            if (!natija.empty()) natija += L"\n\n";
            natija += q;
        }
    }

    tugat();
    if (!xato.empty()) {
        xatoBer(xato);
        return;
    }
    tayyor(natija);
}

AmalIshi::AmalIshi() : ichki_(std::make_shared<Ichki>()) {}
AmalIshi::~AmalIshi() {
    // Ketayotgan oqim `shared_ptr` ushlab turadi va biroz vaqt yashaydi.
    // Qayta chaqiruvlarni uzamiz — aks holda u yoʻq qilingan tabga yozardi.
    bekorQil();
    ichki_->uzil();
}

bool AmalIshi::ketyaptimi() const { return ichki_->ketyapti.load(); }

void AmalIshi::bekorQil() { ichki_->bekor.store(true); }

bool AmalIshi::bajar(const Amal& amal, const std::wstring& matn,
                     std::function<void(const std::wstring&)> onDelta,
                     std::function<void(const std::wstring&)> onTayyor,
                     std::function<void(const std::wstring&)> onXato) {
    if (ichki_->ketyapti.load()) {
        if (onXato) onXato(tr(L"Действие уже выполняется.", L"An action is already running."));
        return false;
    }

    const Provayder* p = LLMSozlama::tanlangan();
    if (!p || !LLMSozlama::sozlanganmi()) {
        if (onXato) {
            onXato(tr(L"Ключ API не указан. Откройте Настройки → Дополнительно.",
                      L"No API key. Open Settings → Advanced."));
        }
        return false;
    }

    ichki_->asos = LLMSorov{};
    ichki_->asos.provayder = *p;
    ichki_->asos.baseURL = LLMSozlama::baseURL();
    ichki_->asos.model = LLMSozlama::model();
    ichki_->asos.kalit = LLMSozlama::joriyKalit();

    ichki_->onDelta = std::move(onDelta);
    ichki_->onTayyor = std::move(onTayyor);
    ichki_->onXato = std::move(onXato);
    ichki_->bekor.store(false);
    ichki_->ketyapti.store(true);

    // `shared_ptr` nusxasi oqimga beriladi — ish oʻzini oʻzi tirik saqlaydi
    // (`ish.cpp` dagi bilan bir xil naqsh).
    auto ichki = ichki_;
    std::thread([ichki, amal, matn] { ichki->ishla(amal, matn); }).detach();
    return true;
}

}  // namespace rubai
