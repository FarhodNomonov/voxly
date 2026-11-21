// Nutq modellari katalogi — qaysi til qaysi modelni ishlatadi (sof mantiq).
//
// macOS'dagi `src/model_tanlov.swift` (`ModelTanlov`) ning ekvivalenti: fayl
// nomlari, hajm, sha256 va manzillar AYNAN bir xil (`win/tests/mac/
// parametr-tekshir.sh` solishtiradi). Rus va ingliz — bitta model, faqat
// whisper tili almashadi.
#pragma once

#include "config.h"  // NutqTili

namespace rubai {

struct MalumModel {
    const wchar_t* fayl;  // %LOCALAPPDATA%\Voxly\models\ dagi nomi
    long long hajm;       // aniq hajm — yarim/buzuq fayl «model» boʻlib qolmasin
    const char* sha256;   // yuklangandan keyin tekshiriladi
    const wchar_t* url;   // yuklab olish manzili
};

// Oʻzbek tili — rubaiSTT (Whisper fine-tune'i, q8_0).
// TODO(voxly): rehost — model hozircha asl muallif (Kotib) CDN'idan olinadi;
// macOS ham shu manzilni ishlatadi (`src/model_download.swift`). Oʻz
// hostingimizga koʻchirilganda ikkala platformada birga almashtiriladi.
inline constexpr MalumModel kOzbekModel{
    L"ggml-rubaistt.bin", 823369796LL,
    "1b02df434902015e1464611a7748927e42fcb55c49791c85239cf713c8edc1a3",
    L"https://cdn.mirqobilov.com/v1.0/ggml-rubaistt.bin"};

// Rus va ingliz tili — oddiy Whisper large-v3-turbo (q5_0, ggml). Encoder'i
// katta, dekoderi 4 qavatli — beam search arzon. Manba: huggingface.co/ggerganov/whisper.cpp.
inline constexpr MalumModel kWhisperModel{
    L"ggml-large-v3-turbo-q5_0.bin", 574041195LL,
    "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2",
    L"https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin"};

// Shu til uchun yuklanadigan model (macOS'dagi `ModelTanlov.joriy(til)`).
inline const MalumModel& modelUchun(NutqTili til) {
    return til == NutqTili::Ozbek ? kOzbekModel : kWhisperModel;
}

// Ikki til bitta model faylini ishlatadimi — u holda til almashganda modelni
// qayta yuklash shart emas, faqat whisper tili almashadi.
inline bool birXilModel(NutqTili a, NutqTili b) { return &modelUchun(a) == &modelUchun(b); }

// Koʻrsatish uchun hajm, MB (yaxlitlangan).
inline long long modelHajmiMb(const MalumModel& m) { return (m.hajm + (1LL << 19)) >> 20; }

}  // namespace rubai
