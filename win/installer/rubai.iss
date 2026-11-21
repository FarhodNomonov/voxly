﻿; Voxly — Windows oʻrnatuvchisi (Inno Setup 6).
;
; Voxly — Kotib (Muhammad Mirqobilov, MIT) fork'i. Kotib'dan farqli AppId,
; nom va papkalar: ikkala ilova bir kompyuterda yonma-yon tura oladi va
; Voxly oʻrnatuvchisi Kotib'ga TEGMAYDI.
;
; Bitta skriptdan ikki xil fayl chiqadi:
;
;   Voxly-<v>-win-setup.exe         nutq modeli ICHIDA (`/DBundleModel=…`) —
;                                   tarqatiladigan yagona fayl
;   Voxly-<v>-win-onlayn-setup.exe  modelsiz, modelni oʻzi yuklaydi — faqat
;                                   ishlab chiqish uchun
;
; Avto-yangilanish YOʻQ (Voxly tarmoqqa faqat model yuklash va foydalanuvchining
; oʻz AI kaliti bilan chiqadi): yangi versiya shunchaki ustidan oʻrnatiladi.
;
; x64 va ARM64 binarlari ikkalasi ham ichida (`Check: IsArm64`).
;
; PER-USER: administrator huquqi soʻralmaydi, ilova
; `%LOCALAPPDATA%\Programs\Voxly` ga, nutq modeli `%LOCALAPPDATA%\Voxly\models`
; ga tushadi.
;
; Build: `win/tools/ornatuvchi-yasa.sh` (iscc faqat Windows'da — VM ichida).

#define AppName        "Voxly"
; Versiya bu yerda YOZILMAYDI — yagona manba repo ildizidagi `VERSION`.
; Uni yigʻuvchi skript beradi: `iscc /DAppVersion=<versiya> …`
; (`win/tools/ornatuvchi-yasa.sh`, `win/build.ps1`). Busiz yigʻilsa oʻrnatuvchi
; notoʻgʻri versiya bilan chiqardi — shuning uchun toʻxtatamiz.
#ifndef AppVersion
  #error AppVersion berilmagan: iscc /DAppVersion=<VERSION faylidagi qiymat> (win/tools/ornatuvchi-yasa.sh shuni qiladi)
#endif
#define AppPublisher   "Farkhod Nomonov"
#define AppExe         "Voxly.exe"
#define AppUrl         "https://farhod-nomonov.netlify.app"
; TODO(voxly): rehost — model hozircha asl muallif (Kotib) CDN'idan olinadi
; (`win/core/model_yuklovchi.cpp`, `src/model_download.swift` bilan bir xil).
#define ModelUrl       "https://cdn.mirqobilov.com/v1.0/ggml-rubaistt.bin"
#define ModelSha256    "1b02df434902015e1464611a7748927e42fcb55c49791c85239cf713c8edc1a3"
#define ModelSize      823369796
; Ilovaning yagona nusxa mutex'i (`win/ui/app.h` → kMutexName).
#define AppMutex       "Global\VoxlySingleInstance"

; Tayyorlangan binar papkalari (`win/tools/ornatuvchi-yasa.sh` beradi).
#ifndef SrcX64
  #define SrcX64 "..\build-x64"
#endif
#ifndef SrcArm64
  #define SrcArm64 "..\build-arm64"
#endif

[Setup]
; Voxly'ning OʻZ AppId'si — Kotib'nikidan ({9C4D7B02-…}) farqli, shuning uchun
; «Ilovalar» roʻyxatida ular ikki alohida ilova boʻlib turadi.
AppId={{ABD93FC3-BC59-41AA-A8CE-8CA93CAA61F6}
AppName={#AppName}
AppVersion={#AppVersion}
; Busiz Windows "Ilovalar" ro'yxatida "... version 1.0.0" deb ko'rsatadi.
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}
; Per-user rejimda {autopf} = %LOCALAPPDATA%\Programs.
DefaultDirName={autopf}\{#AppName}
DisableDirPage=yes
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#AppExe}
OutputDir=..\..\dist
#if defined(BundleModel)
OutputBaseFilename={#AppName}-{#AppVersion}-win-setup
#else
; Modelsiz, oʻzi yuklaydigan variant faqat ishlab chiqish uchun —
; foydalanuvchiga tarqatiladigani modelli, yagona fayl.
OutputBaseFilename={#AppName}-{#AppVersion}-win-onlayn-setup
#endif
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Sehrgar tili — Windows interfeysi tilidan; mos kelmasa tanlash oynasi.
ShowLanguageDialog=auto

; 64-bitli ilova; 32-bitli Windows'da oʻrnatilmaydi.
; `x64compatible` ARM64 Windows'ni ham qamraydi — u x64 ni emulyatsiya
; qila oladi. Qaysi binar qoʻyilishini esa [Files] dagi `IsArm64` hal
; qiladi, shuning uchun ARM mashinada TABIIY nusxa oʻrnatiladi.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Windows 10 1809 (build 17763) dan pastda ishlamaydi — WASAPI va DWM
; funksiyalari yetishmaydi.
MinVersion=10.0.17763

; Per-user: administrator huquqi soʻralmaydi.
PrivilegesRequired=lowest

; Ishlab turgan Voxly'ni Restart Manager yopadi; qayta ochishni oʻzimiz
; qilamiz (CurStepChanged → ssDone), chunki RM uni qaytarmaydi.
CloseApplications=yes
RestartApplications=no

[Languages]
; Oʻzbekcha tarjima Inno Setup bilan kelmaydi — u yonimizda turadi
; (`Uzbek.isl`, UTF-8 + BOM). Ruscha va inglizcha — Inno'ning oʻzidan.
Name: "uz"; MessagesFile: "Uzbek.isl"
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
uz.DownloadingModel=Til modeli yuklab olinmoqda (785 MB)...
uz.ModelFailed=Til modelini yuklab olib boʻlmadi (3 marta urinildi).%n%nBu odatda internet ulanishi uzilganini bildiradi — 785 MB fayl uchun barqaror ulanish kerak.%n%nQOʻLDA YUKLAB OLISH (tavsiya etiladi):%n%n1. Quyidagi havolani brauzerda oching yoki yuklab olish menejeriga bering:%n   {#ModelUrl}%n%n2. Yuklangan «ggml-rubaistt.bin» faylini shu oʻrnatuvchi (setup.exe) turgan papkaga qoʻying%n%n3. Oʻrnatuvchini qaytadan ishga tushiring — u faylni oʻzi topadi va internetsiz oʻrnatadi%n%nTexnik xato: %1
uz.ModelCopyFailed=Til modeli yangi joyga koʻchirilmadi. Diskda joy yetarlimi?%n%n%1
uz.ExtraTasks=Qoʻshimcha:
uz.UninstallModelsSavol=Til modeli saqlab qolinsinmi?
uz.UninstallModels=Nutq modeli ~800 MB joy egallaydi. Saqlab qolsangiz, Voxly'ni qayta oʻrnatganda uni qayta yuklash shart boʻlmaydi.
uz.UninstallModelsHa=Ha, saqlansin
uz.UninstallModelsYoq=Yoʻq, oʻchirilsin

ru.DownloadingModel=Загрузка языковой модели (785 МБ)...
ru.ModelFailed=Не удалось загрузить языковую модель (3 попытки).%n%nОбычно это значит, что прервалось интернет-соединение — для файла 785 МБ нужна стабильная связь.%n%nЗАГРУЗИТЬ ВРУЧНУЮ (рекомендуется):%n%n1. Откройте ссылку в браузере или менеджере загрузок:%n   {#ModelUrl}%n%n2. Положите скачанный файл «ggml-rubaistt.bin» в папку, где лежит этот установщик (setup.exe)%n%n3. Запустите установщик снова — он сам найдёт файл и установит без интернета%n%nТехническая ошибка: %1
ru.ModelCopyFailed=Не удалось скопировать языковую модель. Достаточно ли места на диске?%n%n%1
ru.ExtraTasks=Дополнительно:
ru.UninstallModelsSavol=Сохранить языковую модель?
ru.UninstallModels=Модель распознавания речи занимает ~800 МБ. Если сохранить, при повторной установке Voxly её не придётся скачивать заново.
ru.UninstallModelsHa=Да, сохранить
ru.UninstallModelsYoq=Нет, удалить

en.DownloadingModel=Downloading the language model (785 MB)...
en.ModelFailed=Could not download the language model (3 attempts).%n%nThis usually means the internet connection dropped — a 785 MB file needs a stable connection.%n%nDOWNLOAD MANUALLY (recommended):%n%n1. Open this link in a browser or download manager:%n   {#ModelUrl}%n%n2. Put the downloaded «ggml-rubaistt.bin» next to this installer (setup.exe)%n%n3. Run the installer again — it will find the file and install offline%n%nTechnical error: %1
en.ModelCopyFailed=Could not copy the language model. Is there enough disk space?%n%n%1
en.ExtraTasks=Additional:
en.UninstallModelsSavol=Keep the language model?
en.UninstallModels=The speech model takes ~800 MB. If you keep it, reinstalling Voxly will not need to download it again.
en.UninstallModelsHa=Yes, keep it
en.UninstallModelsYoq=No, delete it

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:ExtraTasks}"

; Avtostart bu yerda EMAS — ilovaning oʻzi birinchi ishga tushganda yoqadi
; (`win/ui/autostart.cpp`).

[Files]
; IKKALA ARXITEKTURA BITTA OʻRNATUVCHIDA.
;
; Windows'da macOS'dagi «universal binary» yoʻq, shuning uchun ikkala
; toʻplam ham ichkariga solinadi va oʻrnatish paytida MOSI tanlanadi.
;
; Manba papkalari TAYYORLANGAN boʻladi (`win/tools/ornatuvchi-yasa.sh`):
; ular ichida faqat tarqatiladigan fayllar turadi — `Voxly.exe`, DLL'lar,
; VAD modeli va `Litsenziyalar.txt`.
Source: "{#SrcX64}\*";   DestDir: "{app}"; Flags: ignoreversion; Check: not IsArm64
Source: "{#SrcArm64}\*"; DestDir: "{app}"; Flags: ignoreversion; Check: IsArm64

; MIT litsenziyasi — Kotib muallifi (Muhammad Mirqobilov) mualliflik huquqi
; bilan. Litsenziya talabi: har nusxada turishi shart.
Source: "..\..\LICENSE";                   DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion

; NUTQ MODELI OʻRNATUVCHI ICHIDA
;
; Joyi — `%LOCALAPPDATA%\Voxly\models`, ilova papkasida EMAS: yangi versiya
; ilova papkasini almashtiradi, model esa unga tegmasdan qoladi.
; Allaqachon toʻgʻri hajmda turgan boʻlsa (qayta oʻrnatish yoki Kotib'dan
; koʻchiriladigan nusxa) — 785 MB qayta yozilmaydi.
;
; `nocompression`: model allaqachon kvantlangan (q8_0) va siqilmaydi.
#ifdef BundleModel
Source: "{#BundleModel}"; DestDir: "{localappdata}\{#AppName}\models"; \
    DestName: "ggml-rubaistt.bin"; Flags: ignoreversion nocompression uninsneveruninstall; \
    Check: not ModelAlreadyInstalled
#endif

[Icons]
Name: "{group}\{#AppName}";                        Filename: "{app}\{#AppExe}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}";  Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}";                  Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; Oynali oʻrnatish oxiridagi «ishga tushirish» katagi. Voxly avval ochiq
; boʻlgan boʻlsa uni CurStepChanged oʻzi qayta ochadi — katak koʻrsatilmaydi,
; aks holda ikkinchi nusxa Sozlamalarni ochardi.
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; \
    Flags: nowait postinstall skipifsilent; \
    Check: AppWasNotRunning

[Code]
//
// MODEL QAYERDAN OLINADI (faqat `onlayn` variantda; `setup` da model ichida)
//
// Model 785 MB. Manbalar ketma-ket tekshiriladi:
//
//   1. Allaqachon o'rnatilgan — %LOCALAPPDATA%\Voxly\models
//   2. Kotib qo'ygan nusxa     — %LOCALAPPDATA%\Kotib\models. Unga tegilmaydi:
//                                Voxly birinchi ishga tushganda Kotib papkasini
//                                o'zi ko'chirib oladi (`win/core/util.cpp`).
//   3. setup.exe YONIDA        — foydalanuvchi modelni brauzer, yuklab olish
//                                menejeri yoki fleshka orqali olib qo'yishi mumkin
//   4. Internetdan yuklash     — 3 marta urinib ko'riladi

var
  DownloadPage: TDownloadWizardPage;
  ModelSource: String;      // ko'chirish uchun manba; bo'sh = ko'chirish shart emas
  AppWasRunning: Boolean;   // o'rnatishdan oldin ilova ochiq edimi
  ModellarniOchir: Boolean; // uninstall: til modeli ham oʻchirilsinmi

// ---- Umumiy yordamchilar

function VoxlyOchiqmi(): Boolean;
begin
  Result := CheckForMutexes('{#AppMutex}');
end;

// Voxly yopilishini `Soniya` gacha kutadi. Yopildi — True.
function VoxlyYopilishiniKut(Soniya: Integer): Boolean;
var
  I: Integer;
begin
  for I := 1 to Soniya * 4 do
  begin
    if not VoxlyOchiqmi() then
    begin
      Result := True;
      Exit;
    end;
    Sleep(250);
  end;
  Result := not VoxlyOchiqmi();
end;

// Ochiq Voxly'ni yopadi: avval yumshoq (`taskkill` WM_CLOSE yuboradi), 5 s
// ichida yopilmasa — majburan.
procedure VoxlyniYop();
var
  ResultCode: Integer;
begin
  if not VoxlyOchiqmi() then
    Exit;
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/im {#AppExe}', '', SW_HIDE,
       ewWaitUntilTerminated, ResultCode);
  if VoxlyYopilishiniKut(5) then
    Exit;
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/f /im {#AppExe}', '', SW_HIDE,
       ewWaitUntilTerminated, ResultCode);
  VoxlyYopilishiniKut(5);
end;

function YangiModelYoli(): String;
begin
  Result := ExpandConstant('{localappdata}\{#AppName}\models\ggml-rubaistt.bin');
end;

function KotibModelYoli(): String;
begin
  Result := ExpandConstant('{localappdata}\Kotib\models\ggml-rubaistt.bin');
end;

// Fayl bor va hajmi to'g'rimi (chala yuklangan fayl o'tib ketmasligi uchun).
function ModelFileValid(const Path: String): Boolean;
var
  Size: Int64;
begin
  Result := False;
  if not FileExists(Path) then
    Exit;
  if not FileSize64(Path, Size) then
    Exit;
  Result := (Size = {#ModelSize});
end;

// [Files] Check: ham shu — model joyida (yoki Kotib papkasida, ilova uni
// birinchi ishga tushishda koʻchiradi) boʻlsa qayta yozilmaydi.
function ModelAlreadyInstalled(): Boolean;
begin
  Result := ModelFileValid(YangiModelYoli()) or
            (not DirExists(ExpandConstant('{localappdata}\{#AppName}')) and
             ModelFileValid(KotibModelYoli()));
end;

// ---- Sehrgar

function InitializeSetup(): Boolean;
begin
  Result := True;
  AppWasRunning := VoxlyOchiqmi();
end;

// [Run] bo'limi uchun: ilova avval ishlamayotgan bo'lsagina "ishga tushirish"
// katagi ko'rsatiladi.
function AppWasNotRunning(): Boolean;
begin
  Result := not AppWasRunning;
end;

function OnDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  if ProgressMax <> 0 then
    DownloadPage.SetProgress(Progress, ProgressMax);
  Result := True;
end;

// setup.exe yonidagi model.
function LocalModelPath(): String;
begin
  Result := ExpandConstant('{src}\ggml-rubaistt.bin');
end;

// Internetdan yuklash, N marta urinib. Muvaffaqiyatda True.
function TryDownload(Attempts: Integer; var ErrText: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  ErrText := '';
  for I := 1 to Attempts do
  begin
    try
      if WizardSilent() then
        DownloadTemporaryFile('{#ModelUrl}', 'ggml-rubaistt.bin', '{#ModelSha256}', nil)
      else
      begin
        DownloadPage.Clear;
        DownloadPage.Add('{#ModelUrl}', 'ggml-rubaistt.bin', '{#ModelSha256}');
        DownloadPage.Download;
      end;
      Result := True;
      Exit;
    except
      ErrText := GetExceptionMessage;
    end;
  end;
end;

// Modelni tayyorlaydi. Bo'sh satr = muvaffaqiyat, aks holda xato matni.
// `ModelSource` boʻsh boʻlmasa — ssPostInstall uni yangi joyga nusxalaydi.
function AcquireModel(): String;
var
  ErrText: String;
begin
  Result := '';
  ModelSource := '';

  if ModelAlreadyInstalled() then
    Exit;

#ifdef BundleModel
  // Model ichida, [Files] uni joylaydi.
  Exit;
#endif

  // setup.exe yonida
  if ModelFileValid(LocalModelPath()) then
  begin
    ModelSource := LocalModelPath();
    Exit;
  end;

  // Internet
  if not WizardSilent() then
    DownloadPage.Show;
  try
    if TryDownload(3, ErrText) then
      ModelSource := ExpandConstant('{tmp}\ggml-rubaistt.bin')
    else
      Result := FmtMessage(ExpandConstant('{cm:ModelFailed}'), [ErrText]);
  finally
    if not WizardSilent() then
      DownloadPage.Hide;
  end;
end;

procedure InitializeWizard;
begin
  DownloadPage := CreateDownloadPage(
    SetupMessage(msgWizardPreparing),
    ExpandConstant('{cm:DownloadingModel}'),
    @OnDownloadProgress);
end;

// Oynali (odatiy) o'rnatish.
function NextButtonClick(CurPageID: Integer): Boolean;
var
  ErrText: String;
begin
  Result := True;
  if CurPageID <> wpReady then
    Exit;

  ErrText := AcquireModel();
  if ErrText <> '' then
  begin
    SuppressibleMsgBox(ErrText, mbCriticalError, MB_OK, IDOK);
    Result := False;      // "Ready" sahifasida qolamiz, qayta urinish mumkin
  end;
end;

// Jimgina o'rnatish (/SILENT, /VERYSILENT): sehrgar hodisalari chaqirilmaydi,
// PrepareToInstall esa ikkala rejimda ham chaqiriladi.
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if WizardSilent() then
    Result := AcquireModel();
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Dst: String;
  ResultCode: Integer;
begin
  if (CurStep = ssPostInstall) and (ModelSource <> '') then
  begin
    Dst := YangiModelYoli();
    ForceDirectories(ExtractFileDir(Dst));
    if not CopyFile(ModelSource, Dst, False) then
      SuppressibleMsgBox(FmtMessage(ExpandConstant('{cm:ModelCopyFailed}'), [Dst]),
                         mbCriticalError, MB_OK, IDOK);
  end;

  // Voxly ochiq edi — yangisini ochamiz.
  if (CurStep = ssDone) and AppWasRunning then
    Exec(ExpandConstant('{app}\{#AppExe}'), '', '', SW_SHOWNORMAL, ewNoWait, ResultCode);
end;

// ---- Uninstall

function InitializeUninstall(): Boolean;
begin
  Result := True;
  ModellarniOchir := False;
  // Ochiq Voxly .exe va DLL'larni qulflaydi — fayllar qolib ketmasin.
  VoxlyniYop();
end;

// «Til modeli saqlab qolinsinmi?» — Inno'ning «Haqiqatan oʻchirasizmi?»
// tasdigʻidan KEYIN (usUninstall). Savol ataylab «saqlansinmi» shaklida:
// TaskDialog'da standart tugma doim BIRINCHISI, demak Enter yoki shoshib
// bosish modelni SAQLAYDI. Jim rejimda ham saqlanadi.
function ModellarniOchirishniSora(): Boolean;
var
  Tugmalar: TArrayOfString;
begin
  Result := False;
  if UninstallSilent() then
    Exit;
  // Diqqat: satr `[` bilan boshlansa Inno uni boʻlim sarlavhasi deb oʻqiydi.
  Tugmalar := [ExpandConstant('{cm:UninstallModelsHa}'), ExpandConstant('{cm:UninstallModelsYoq}')];
  Result := TaskDialogMsgBox(ExpandConstant('{cm:UninstallModelsSavol}'),
                             ExpandConstant('{cm:UninstallModels}'),
                             mbConfirmation, MB_YESNO, Tugmalar, 0) = IDNO;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  RunKalit, Qiymat: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    ModellarniOchir := ModellarniOchirishniSora();
    // Avtostart yozuvi shu nusxaga koʻrsatsa — oʻchiriladi. Boshqa
    // (tirik) nusxaga koʻrsatsa — tegmaymiz.
    RunKalit := 'Software\Microsoft\Windows\CurrentVersion\Run';
    if RegQueryStringValue(HKCU, RunKalit, '{#AppName}', Qiymat) then
      if CompareText(RemoveQuotes(Qiymat), ExpandConstant('{app}\{#AppExe}')) = 0 then
        RegDeleteValue(HKCU, RunKalit, '{#AppName}');
  end;

  // Faqat model (foydalanuvchi rozi boʻlsa). Sozlamalar, tarix va hujjatlar
  // (`%APPDATA%\Voxly`) hech qachon oʻchirilmaydi.
  if (CurUninstallStep = usPostUninstall) and ModellarniOchir then
    DelTree(ExpandConstant('{localappdata}\{#AppName}\models'), True, True, True);
end;
