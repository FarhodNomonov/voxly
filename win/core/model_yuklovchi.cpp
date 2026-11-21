// Nutq modelini ilova ichida yuklab olish (hajm va sha256 tekshiruvi bilan).
// Interfeys va izohlar — `model_yuklovchi.h`.

#include "model_yuklovchi.h"

#include "engine.h"
#include "util.h"
#include "yuklovchi.h"

#include <windows.h>

#include <atomic>
#include <mutex>
#include <thread>

namespace rubai {

namespace {

std::wstring modelPapkasi() {
    const std::wstring dir = localAppDataDir();
    if (dir.empty()) return {};
    const std::wstring p = dir + L"\\models";
    ensureDir(p);
    return p;
}

std::wstring modelYoli(const MalumModel& m) {
    const std::wstring p = modelPapkasi();
    return p.empty() ? std::wstring() : p + L"\\" + m.fayl;
}

long long faylHajmi(const std::wstring& yol) {
    WIN32_FILE_ATTRIBUTE_DATA d{};
    if (!GetFileAttributesExW(yol.c_str(), GetFileExInfoStandard, &d)) return -1;
    return (static_cast<long long>(d.nFileSizeHigh) << 32) | d.nFileSizeLow;
}

}  // namespace

struct ModelYuklovchi::Ichki {
    std::atomic<bool> ketyapti{false};
    std::atomic<bool> bekor{false};
    // Joriy yuklash qaysi model uchun — `boshla` qoʻyadi, ish oqimi oʻqiydi.
    const MalumModel* model = &kOzbekModel;

    std::mutex qulf;
    std::function<void(long long, long long)> onJarayon;
    std::function<void(bool, std::wstring)> onTugadi;

    void jarayon(long long a, long long b) {
        std::lock_guard<std::mutex> q(qulf);
        if (onJarayon) onJarayon(a, b);
    }
    void tugadi(bool ok, const std::wstring& xato) {
        ketyapti.store(false);
        std::lock_guard<std::mutex> q(qulf);
        if (onTugadi) onTugadi(ok, xato);
    }
    void uzil() {
        std::lock_guard<std::mutex> q(qulf);
        onJarayon = nullptr;
        onTugadi = nullptr;
    }

    void ishla();
};

void ModelYuklovchi::Ichki::ishla() {
    const MalumModel& m = *model;
    const std::wstring yol = modelYoli(m);
    if (yol.empty()) {
        tugadi(false, L"Maʼlumot papkasi topilmadi.");
        return;
    }

    // Disk joyi: model + yarim yuklangan nusxa oʻrtada ikkalasi ham turadi.
    {
        std::wstring ildiz = yol;
        const size_t ikkiNuqta = ildiz.find(L':');
        if (ikkiNuqta != std::wstring::npos) {
            ildiz = ildiz.substr(0, ikkiNuqta + 2);
            ULARGE_INTEGER bosh{};
            if (GetDiskFreeSpaceExW(ildiz.c_str(), &bosh, nullptr, nullptr) &&
                static_cast<long long>(bosh.QuadPart) < m.hajm + (100LL << 20)) {
                tugadi(false, L"Diskda joy yetarli emas — kamida " +
                                  std::to_wstring(modelHajmiMb(m) + 100) + L" MB kerak.");
                return;
            }
        }
    }

    logWrite(std::wstring(L"nutq modeli: yuklash boshlandi — ") + m.fayl);

    const std::wstring qism = yol + L".part";
    const YuklashNatijasi n = faylYukla(
        m.url, qism, m.hajm,
        [this](long long a, long long b) { jarayon(a, b); }, [this] { return bekor.load(); });

    if (!n.ok) {
        // Yarim fayl ATAYLAB oʻchirilmaydi — keyingi urinishda davom etadi.
        logWrite(L"nutq modeli: yuklanmadi");
        tugadi(false, n.xato);
        return;
    }

    // Hajm mos kelmasa — fayl buzuq yoki server boshqa narsa berdi.
    // Yarim model bilan ishga tushish whisper ichida tushunarsiz xato beradi.
    if (faylHajmi(qism) != m.hajm) {
        DeleteFileW(qism.c_str());
        logWrite(L"nutq modeli: hajm mos kelmadi — fayl oʻchirildi");
        tugadi(false, L"Yuklangan fayl buzuq. Qayta urinib koʻring.");
        return;
    }
    // Hajm toʻgʻri boʻlsa ham ichi buzilgan boʻlishi mumkin (disk, proksi).
    // Buzuq model whisper'da tushunarsiz «yuklanmadi» boʻlib chiqardi (F2).
    if (faylSha256(qism) != m.sha256) {
        DeleteFileW(qism.c_str());
        logWrite(L"nutq modeli: sha256 mos kelmadi — fayl oʻchirildi");
        tugadi(false, L"Yuklangan fayl buzuq. Qayta urinib koʻring (boshidan yuklanadi).");
        return;
    }

    DeleteFileW(yol.c_str());
    if (!MoveFileW(qism.c_str(), yol.c_str())) {
        tugadi(false, L"Faylni joyiga koʻchirib boʻlmadi.");
        return;
    }

    // Yangi model darhol tayyor boʻlsin. Yoʻl majburan berilmaydi
    // (`setModelPath`): dvigatel modelni joriy til boʻyicha oʻzi topadi —
    // ilgari yoʻl qotirib qoʻyilardi va til almashganda model almashmasdi.
    Engine::instance().preload();

    logWrite(L"nutq modeli: tayyor");
    tugadi(true, L"");
}

ModelYuklovchi::ModelYuklovchi() : ichki_(std::make_shared<Ichki>()) {}

ModelYuklovchi::~ModelYuklovchi() {
    bekorQil();
    ichki_->uzil();
}

bool ModelYuklovchi::ketyaptimi() const { return ichki_->ketyapti.load(); }
void ModelYuklovchi::bekorQil() { ichki_->bekor.store(true); }

void ModelYuklovchi::boshla(NutqTili til, std::function<void(long long, long long)> jarayon,
                            std::function<void(bool, std::wstring)> tugadi) {
    if (ichki_->ketyapti.load()) return;
    {
        std::lock_guard<std::mutex> q(ichki_->qulf);
        ichki_->onJarayon = std::move(jarayon);
        ichki_->onTugadi = std::move(tugadi);
    }
    ichki_->model = &modelUchun(til);
    ichki_->bekor.store(false);
    ichki_->ketyapti.store(true);

    auto ichki = ichki_;
    std::thread([ichki] { ichki->ishla(); }).detach();
}

}  // namespace rubai
