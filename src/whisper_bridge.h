// whisper.cpp C shim interfeysi (`whisper_bridge.c`) — macOS va Windows uchun
// YAGONA fayl. Swift unga `Bridging.h` orqali, Windows C++ kodi toʻgʻridan-
// toʻgʻri kiradi (`win/CMakeLists.txt` `src/` ni include yoʻliga qoʻshadi).

#ifndef RUBAI_WHISPER_BRIDGE_H
#define RUBAI_WHISPER_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

// Modelni yuklaydi (bir marta), GPU bilan. 0 = muvaffaqiyat.
int rubai_load(const char *model_path);

// GPU'ni majburan oʻchirish mumkin (Windows'da CPU fallback uchun).
// use_gpu = 0 boʻlsa faqat CPU backend ishlatiladi.
int rubai_load_ex(const char *model_path, int use_gpu);

#ifdef _WIN32
#include <wchar.h>
// Yoʻl UTF-16 da, fayl `_wfopen` bilan ochiladi va whisper.cpp'ga oʻz
// oʻquvchimiz (`whisper_model_loader`) orqali beriladi. Kirillcha foydalanuvchi
// nomi (C:\Users\Аброр\…) va 8.3 qisqa nomlar oʻchirilgan disk uchun:
// llvm-mingw'da whisper.cpp yoʻlni tor `ifstream` bilan (ANSI kod sahifasida)
// ochadi va bunday yoʻl ochilmaydi.
int rubai_load_w(const wchar_t *model_path, int use_gpu);

// Silero VAD modeli yoʻli (S12) — yuklashdan OLDIN, bir marta (UTF-16).
// Har model yuklanishida VAD ham yuklanadi; berilmasa yoki yuklanmasa —
// boʻlaksiz ishlaydi.
void rubai_set_vad_path_w(const wchar_t *path);
#else
// Silero VAD modeli yoʻli (S12) — `rubai_load` dan OLDIN, bir marta. Har
// model yuklanishida VAD ham yuklanadi: nutq yoʻq ovozda whisper chaqirilmaydi,
// uzun ovoz jimliklardan boʻlinadi (`nutq_bolaklari.h`). Yoʻl berilmasa yoki
// VAD yuklanmasa — 1.1 dagi kabi boʻlaksiz ishlaydi.
void rubai_set_vad_path(const char *path);
#endif

// Nutq tili — whisper til kodi ("uz", "ru" …). Keyingi transkripsiyadan
// boshlab amal qiladi. Standart: "uz".
void rubai_set_language(const char *til);

// Modelni (va VAD'ni) RAM'dan boʻshatadi.
void rubai_unload(void);

// 16kHz mono float32 namunalardan matn qaytaradi (til — rubai_set_language).
// Qaytgan satrni rubai_free_str bilan boʻshating. NULL = xato.
char *rubai_transcribe(const float *samples, int n_samples, int n_threads);

void rubai_free_str(char *s);

#include <stdint.h>
#include <stdbool.h>

// Progress: 0..100. UI oqimini bloklamaslik uchun tez qaytsin.
typedef void (*rubai_progress_cb)(int percent, void *ud);
// true qaytarsa transkripsiya toʻxtatiladi.
typedef bool (*rubai_abort_cb)(void *ud);

// whisper_full ni segmentlar bilan ishga tushiradi.
// 0 = muvaffaqiyat, 1 = xato, 2 = bekor qilingan.
int rubai_transcribe_segments(const float *samples, int n_samples, int n_threads,
                              rubai_progress_cb pcb, void *pud, rubai_abort_cb acb, void *aud);

// Yuqoridagi 0 qaytargandan keyin natijani oʻqish uchun.
int rubai_n_segments(void);
// Ichki bufferga koʻrsatkich — chaqiruvchi NUSXALAB olsin, free QILMASIN.
const char *rubai_segment_text(int i);
int64_t rubai_segment_t0(int i);  // 10 ms birliklarda
int64_t rubai_segment_t1(int i);

// Oxirgi xatoning qisqa tavsifi (ingliz tilida, log uchun). Hech qachon NULL emas.
const char *rubai_last_error(void);

// Faol backend nomi: "Metal", "Vulkan", "CUDA", "CPU" yoki "" (yuklanmagan).
const char *rubai_backend_name(void);

// whisper.cpp va ggml oʻz xabarlarini stderr'ga chiqaradi. Grafik ilovada
// stderr yoʻq, shuning uchun ularni oʻz logimizga yoʻnaltiramiz.
// fn = NULL boʻlsa xabarlar butunlay oʻchiriladi.
// rubai_load dan OLDIN chaqirilishi kerak.
typedef void (*rubai_log_fn)(const char *msg);
void rubai_set_log(rubai_log_fn fn);

#ifdef __cplusplus
}
#endif

#endif
