// Nutq modelini ilova ichida yuklab olish.
//
// macOS'dagi `src/model_download.swift` ning ekvivalenti. Ilgari Windows'da
// bu yoʻl umuman yoʻq edi: model faqat oʻrnatuvchi bilan kelardi va u
// yoʻqolsa (oʻchirib yuborilgan, antivirus olib qoʻygan, portable nusxa)
// ilova boshi berk koʻchada qolardi — «Model topilmadi» deb aytardi, lekin
// nima qilishni koʻrsatmasdi.
//
// Oʻrnatuvchi endi model OLIB KELMAYDI (~50 MB): kerakli model birinchi
// ishga tushishda shu yerda, tanlangan nutq tili uchun yuklanadi
// (`model_tanlov.h` — rus/ingliz: Whisper large-v3-turbo, oʻzbek: rubaiSTT).
//
// Model `%LOCALAPPDATA%\Voxly\models\` ga tushadi — `Engine::findModel`
// shu joyga qaraydi.
#pragma once

#include <functional>
#include <memory>
#include <string>

#include "model_tanlov.h"

namespace rubai {

class ModelYuklovchi {
public:
    ModelYuklovchi();
    ~ModelYuklovchi();
    ModelYuklovchi(const ModelYuklovchi&) = delete;
    ModelYuklovchi& operator=(const ModelYuklovchi&) = delete;

    // `til` modelini fon oqimida yuklaydi (hajm va sha256 tekshiruvi bilan).
    // Model boshlanishda tanlanadi — til yuklash oʻrtasida oʻzgarsa ham
    // `.part` va sha256 bitta modelga tegishli qoladi (macOS bilan bir xil).
    // Qayta chaqiruvlar ISHCHI OQIMDAN keladi.
    void boshla(NutqTili til, std::function<void(long long, long long)> jarayon,
                std::function<void(bool, std::wstring)> tugadi);

    // Bekor qilinganda yarim fayl SAQLANIB QOLADI — keyingi urinishda
    // oʻsha joydan davom etadi.
    void bekorQil();
    bool ketyaptimi() const;

private:
    struct Ichki;
    std::shared_ptr<Ichki> ichki_;
};

}  // namespace rubai
