# Oʻzgarishlar / Changelog

Format — [Keep a Changelog](https://keepachangelog.com/), versiyalar —
[SemVer](https://semver.org/). Versiya bitta joyda: [`VERSION`](VERSION).

## [Keyingi]

### Voxly (форк Kotib)
- Новое имя **Voxly**, bundle id `app.voxly.mac`. Данные переносятся из
  `Application Support/Kotib` автоматически.
- Интерфейс на русском и английском (Настройки → «Язык интерфейса»).
- Языки речи: русский (кириллица), английский, узбекский.
- Убраны офлайн-переводчик (NLLB, лицензия только для некоммерческого
  использования), автообновление, телеметрия и окно пожертвований.
- Скорость на Intel: Accelerate (BLAS), окно кодировщика по длине фразы с
  выравниванием на 256, остановка зацикливания прямо во время декодирования.
  i7-9750H: 1,5 с речи → 3,0 с, 10 с → 3,5 с, 20 с → 7,3 с (было 17–84 с).

### Qoʻshildi
- **Rus tili (kirill).** Sozlamalarda «Nutq tili»: rus yoki oʻzbek. Rus tili
  oddiy Whisper large-v3-turbo (q5_0, 548 MB) bilan ishlaydi — rubaiSTT rus
  nutqini lotin harflarida yozardi («privet, kak dela?»). Model birinchi
  diktovkada yuklab olinadi; til almashtirilsa model oʻzi almashadi.
- `scripts/mahalliy-yigish.sh` — Developer ID'siz yigʻishda doimiy mahalliy
  imzo: Accessibility ruxsati har yigʻishdan keyin tushib qolmaydi.

### Tezlashdi
- Rus tilida encoder oynasi ovoz uzunligiga moslanadi (audio_ctx): 12,6 s
  ovoz — 19,3 s → 9,8 s (i7-9750H). Takror chiqsa boʻlak kattaroq oyna bilan
  avtomatik qayta oʻgiriladi.
- Intel'da oqimlar soni — fizik yadrolar soni (Hyper-Threading sekinlashtirardi).
- Intel Mac'da `setup.sh` / `build.sh` mahalliy x86_64 (AVX2) build qiladi;
  Homebrew shart emas (cmake pip orqali).

### Oʻzgardi
- Mustaqil build'da (`RASMIY_SERVER=1` siz) avto-yangilanish va statistika
  oʻchiq — fork muallif serveridan yangilanib ketmasligi uchun.

### Tuzatildi
- macOS: Sozlamalar ochiq turganda «Hozir tekshirish» orqali yangilansa,
  «Oʻrnatilmoqda…» oynasi qotib qolardi. Endi ochiq oynalar yopiladi va
  yangilanish oʻrnatiladi.

## [1.2.1] — 2026-10-08

### Tuzatildi
- macOS: yozuv paytida model fayli yoʻqolsa, toʻxtatish tugmasi ishlamasdi —
  mikrofon yozishda qolardi va ovoz saqlanmasdi. Endi yozuv toʻxtaydi va ovoz
  saqlanadi (keyin oʻzi matnga oʻgiriladi).
- macOS: «Bosing va gapiring» kartasi va «Qoʻshimcha sozlamalar» VoiceOver'da
  tugma sifatida koʻrinadi va bosiladi.

## [1.2.0] — 2026-10-08

### Qoʻshildi
- **Avtomatik yangilanish.** Yangi versiya fonda yuklanadi, imzosi tekshiriladi
  va boʻsh paytda — yozuv va fayl ishi tugagach — oʻrnatiladi, Kotib oʻzi qayta
  ochiladi. Sozlamalarda «Hozir tekshirish». macOS'da Sparkle, Windows'da oʻz
  yangilovchimiz; ikkalasi bir xil qoidalar bilan.
- **Majburiy yangilanish** (masalan, xavfsizlik tuzatishi uchun): avval
  ogohlantirish va muhlat (odatda 3 kun), muhlat tugagach yangilanmaguncha
  diktovka toʻxtaydi. Internetga hech chiqmagan Kotib hech qachon bloklanmaydi.
- **Ovoz yoʻqolmaydi.** Diktovka matnga oʻgirilmasa (masalan, model
  yuklanmagan boʻlsa), ovoz qurilmada WAV boʻlib saqlanadi: menyuda
  «Saqlangan ovozni matnga oʻgirish», model tayyor boʻlgach bir marta oʻzi
  urinadi. Faqat qurilmada, 7 kungacha va oxirgi 20 tagacha.
- **Diagnostika rejimi** (24 soat): muammoni tekshirish uchun diktovka matnini
  logga yozishni vaqtincha yoqish.
- **Litsenziyalar** — Sozlamalarda (macOS) va tray menyusida (Windows).
- Logda ishga tushish qatori: versiya, platforma, model, GPU.

### Oʻzgardi
- **Clipboard aslidek tiklanadi** — rasm, fayl, boy matn ham (ilgari faqat matn).
  Windows'da transkript clipboard tarixiga (Win+V) va bulutga tushmaydi.
- **Diktovkada ham `oʻ`/`gʻ`/`ʼ`** — ilgari faqat Studiya natijasi
  toʻgʻrilanardi, diktovka ASCII `'` qoʻyardi.
- **Logda diktovka matni yozilmaydi** — faqat uzunligi va vaqti. Log 1 MB dan
  oshsa almashtiriladi.
- macOS: nutq modeli ilova ichida emas — keyingi yangilanishlar kichik boʻladi.
- **Windows: administrator huquqisiz oʻrnatiladi** — faqat joriy foydalanuvchiga
  (`%LOCALAPPDATA%\Programs\Kotib`), shuning uchun yangilanishlar UAC oynasisiz,
  jim oʻtadi. 1.1.0 dan oʻtishda model koʻchiriladi va eski nusxa bir marta
  ruxsat soʻrab olib tashlanadi; «Ilovalar» roʻyxatida bitta Kotib qoladi.
- Windows: Kotibni oʻchirganda til modellarini (~4 GB) saqlab qolish yoki oʻchirish
  soʻraladi; avtostart yozuvi ham oʻchiriladi.
- Windows: birinchi diktovka boʻsh turishdan keyin kechikmaydi (GPU isitish
  faqat ishga tushishda).

### Tuzatildi
- Windows: internet uzilib qolsa, yuklash (yangilanish, nutq va tarjima modeli) keyingi
  safar uzilgan joyidan davom etadi — ilgari chala fayl oʻchirilib, noldan boshlanardi.
- **Jimlik va shovqin endi «musiqa» boʻlib yozilmaydi**, uzun ovozda jumlalar tushib
  qolmaydi: ovoz Silero VAD bilan jimliklardan boʻlinadi (ikkala platforma). Oʻlchovda
  uzun nutq xatosi 30 % dan 8 % ga tushdi, Fayl boʻlimi ikki barobar tezlashdi va bir
  xil fayl har safar bir xil matn beradi. Qisqa diktovka sifati oʻzgarmadi.
- macOS: mikrofon kech ochilsa qayta urinish yangi yozuvni toʻxtatib qoʻyardi;
  yozuv koʻrsatkichi vaqtidan oldin yoʻqolardi; «Sekin» kiritish uzun matnda
  ilovani qotirardi; mikrofon xatosining sababi aytilmasdi.
- macOS: model yuklashini bekor qilgach davom ettirib boʻlmasdi; toʻliq yuklangan
  fayl qayta yuklanardi; tarjima modeli «kod 416» da qotib qolardi.
- macOS: faqat ⇧ bilan tugma tanlansa bosh harflar yozilmay qolardi; band
  tugma va Keychain xatosi haqida xabar berilmasdi.
- Diktovka va fayl ishi bir vaqtda boshlansa, diktovka matni daqiqalar oʻtib
  boshqa oynaga tushishi mumkin edi (ikkala platforma).
- Windows: sozlamalar saqlanganda oʻrnatma raqami yoʻqolardi; rus/oʻzbek
  lokalida statistika buzilardi; bekor qilingan oʻchirishda Kotib yopilardi;
  administrator oynasiga diktovka jimgina yoʻqolardi (endi matn clipboard'da);
  videokarta drayveri yiqilsa keyingi ishga tushish protsessorda; kirillcha
  foydalanuvchi nomida tarjima modeli ochilmasdi.
- Yuklab olingan model sha256 bilan tekshiriladi (ikkala platforma).
- **Takrorlanish halqasi** («oʻzbekiston respublikasi oʻzbekiston respublikasi …»
  oʻn besh marta) endi matnga tushmaydi: sifatsiz ovozda model bir iborani
  takrorlab qolsa, u qayta dekodlanadi, qolganida esa bitta qoldiriladi (ikkala
  platforma). Toza va shovqinli nutqda natija oʻzgarmadi.
- Windows: model fayli qaytgandan keyin ham oynada «Nutq modeli topilmadi»
  banneri qolib ketardi.
- Majburiy yangilanishda «Saytdan yuklab olish» tugmasi endi faqat avtomatik
  yuklash muvaffaqiyatsiz boʻlganda chiqadi; oynada ochiq dialog boʻlsa
  yangilanish uning yopilishini kutadi (ilgari oʻrnatilmay qolib ketardi).

## [1.1.0] — 2026-09-10

### Qoʻshildi
- **Windows** versiyasi (x64 va ARM64, bitta oʻrnatuvchi).
- **Fayl (Studiya)** — ovozli yoki video faylni matnga oʻgirish, uzun fayllar
  boʻlaklab; ixtiyoriy sunʼiy intellekt amallari (oʻz API kalitingiz bilan).
- **Oflayn tarjimon** — 202 til, istalgan yoʻnalishda (NLLB-200).

### Oʻzgardi
- Ilova nomi — **Kotib** (ilgari *Audio-Matnga*); maʼlumotlar avtomatik koʻchiriladi.
- Yangi interfeys: bitta oyna, uch tab — Yozish, Audio (Windows'da «Fayl»), Tarjima.

## [1.0.0] — 2026-06-26

- Birinchi reliz (*RubaiSTT Dictation*, macOS): tizim boʻylab oʻzbekcha
  diktovka, toʻliq oflayn, rubaiSTT v2 medium (q8_0) modeli.
- 2026-08: nom *Audio-Matnga* ga oʻzgardi, «Donat qilish» qoʻshildi.
