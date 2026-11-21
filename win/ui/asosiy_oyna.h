// Voxly — asosiy oyna.
//
// macOS tomonidagi `src/asosiy_oyna.swift` (`AsosiyOyna`) ning ekvivalenti.
// Dizayn bir xil: tepada toolbar — oʻrtada segment boshqaruvi
// (Yozish | Fayl), oʻng chetda ⚙ tugmasi; ostida tanlangan tabning
// koʻrinishi. Yon panel YOʻQ — macOS'da u ataylab olib tashlangan, chunki
// ikki-uch rejim ustiga qoʻyilgan daraxt hech qanday maʼlumot bermasdi.
//
// Sozlamalar tab EMAS: ⚙ alohida modal oyna ochadi (macOS'da sheet).
//
// Tab koʻrinishlari birinchi ochilganda yaratiladi va saqlanadi — ketayotgan
// transkripsiya ishi yoki kiritilgan matn tab almashganda yoʻqolmasligi kerak.
#pragma once

#include <windows.h>

#include <functional>
#include <memory>
#include <string>
#include <vector>

namespace rubai {

class Chizgich;
class Tab;
class YozishTab;
class FaylTab;

class AsosiyOyna {
public:
    AsosiyOyna();
    ~AsosiyOyna();
    AsosiyOyna(const AsosiyOyna&) = delete;
    AsosiyOyna& operator=(const AsosiyOyna&) = delete;

    bool qur(HINSTANCE instance);
    void korsat();
    void yashir();
    bool korinadimi() const;

    HWND deskriptor() const;

    // Diktovka holati oʻzgarganda chaqiriladi (dictate oqimidan).
    //
    // MUHIM: holat oxirgi marta nima berilgani bilan saqlanadi. Foydalanuvchi
    // oynani diktovka OʻRTASIDA ochsa, yangi yaratilgan tab darhol toʻgʻri
    // holatni koʻrsatishi kerak — keyingi oʻzgarishni kutib turmasligi.
    // macOS tomonida ham shu qoida (`AsosiyOyna.diktovkaHolati`).
    // Foydalanuvchi «Bosing va gapiring» kartasini bosdi.
    std::function<void()> onDiktovka;

    void diktovkaHolati(bool yozilyapti);

    // ⚙ tugmasi. Sozlamalar tab EMAS — alohida modal oyna (macOS'da sheet).
    std::function<void()> onSozlamalar;

    YozishTab* yozishTabi();
    FaylTab* faylTabi();

    // Diktovka tugagach tarixga qoʻshish uchun.
    void diktovkaTugadi(const std::wstring& matn);

    // Diktovka tarixini diskdan qayta oʻqib roʻyxatni yangilaydi.
    void tarixniYangila();

    // Yozib olish paytidagi signal darajasi (0…1) — toʻlqin chizigʻi uchun.
    void darajaniQoy(float daraja);

    // Kartadagi «Ctrl · Alt · D» chiplari.
    void hotkeyMatni(const std::wstring& matn);

    // Yozish tabidagi ogohlantirish banneri (mikrofon tanlanmagan va h.k.).
    void banner(const std::wstring& matn, const std::wstring& tugmaNomi = L"",
                std::function<void()> tugmaBosildi = nullptr);

    // Oyna protsedurasi (erkin funksiya) shu tuzilmaga murojaat qiladi,
    // shuning uchun eʼlon ochiq; taʼrifi .cpp faylda. `overlay.h` da ham
    // shunday qilingan.
    struct Ichki;

private:
    std::unique_ptr<Ichki> ichki_;
};

}  // namespace rubai
