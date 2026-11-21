﻿; Voxly — Windows oʻrnatuvchisi (Inno Setup 6).
;
; Voxly — Kotib (Muhammad Mirqobilov, MIT) fork'i. Kotib'dan farqli AppId,
; nom va papkalar: ikkala ilova bir kompyuterda yonma-yon tura oladi va
; Voxly oʻrnatuvchisi Kotib'ga TEGMAYDI.
;
; Natija — `Voxly-<v>-win-setup.exe` (kichik, modelsiz). Nutq modeli oʻrnatuvchida
; YOʻQ va oʻrnatuvchi uni yuklamaydi ham: model nutq tiliga bogʻliq
; (rus/ingliz — Whisper large-v3-turbo ~550 MB, oʻzbek — rubaiSTT ~785 MB),
; til esa ilova ichida tanlanadi. Ilova birinchi ishga tushganda kerakli
; modelni oʻzi yuklaydi (`win/core/model_yuklovchi.cpp`, `model_tanlov.h`).
;
; Avto-yangilanish YOʻQ (Voxly tarmoqqa faqat model yuklash va foydalanuvchining
; oʻz AI kaliti bilan chiqadi): yangi versiya shunchaki ustidan oʻrnatiladi.
;
; x64 va ARM64 binarlari ikkalasi ham ichida (`Check: IsArm64`).
;
; PER-USER: administrator huquqi soʻralmaydi, ilova
; `%LOCALAPPDATA%\Programs\Voxly` ga tushadi; ilova yuklagan nutq modellari —
; `%LOCALAPPDATA%\Voxly\models` da (uninstall ularni soʻrab oʻchiradi).
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
OutputBaseFilename={#AppName}-{#AppVersion}-win-setup
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
uz.ExtraTasks=Qoʻshimcha:
uz.UninstallModelsSavol=Nutq modellari saqlab qolinsinmi?
uz.UninstallModels=Voxly yuklagan nutq modellari 550 MB – 1,4 GB joy egallaydi. Saqlab qolsangiz, Voxly'ni qayta oʻrnatganda ularni qayta yuklash shart boʻlmaydi.
uz.UninstallModelsHa=Ha, saqlansin
uz.UninstallModelsYoq=Yoʻq, oʻchirilsin

ru.ExtraTasks=Дополнительно:
ru.UninstallModelsSavol=Сохранить модели распознавания речи?
ru.UninstallModels=Скачанные Voxly модели занимают от 550 МБ до 1,4 ГБ. Если сохранить, при повторной установке Voxly их не придётся скачивать заново.
ru.UninstallModelsHa=Да, сохранить
ru.UninstallModelsYoq=Нет, удалить

en.ExtraTasks=Additional:
en.UninstallModelsSavol=Keep the speech models?
en.UninstallModels=The speech models Voxly downloaded take 550 MB – 1.4 GB. If you keep them, reinstalling Voxly will not need to download them again.
en.UninstallModelsHa=Yes, keep them
en.UninstallModelsYoq=No, delete them

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

; Nutq modeli bu yerda YOʻQ — ilova uni tanlangan til uchun oʻzi yuklaydi.
; Kotib'dan oʻtayotgan foydalanuvchining modeli (`%LOCALAPPDATA%\Kotib\models`)
; ham bu yerda koʻchirilmaydi: ilova birinchi ishga tushganda Kotib papkasini
; butunligicha oʻzi koʻchirib oladi (`win/core/util.cpp`) va oʻzbek modeli
; qayta yuklanmaydi.

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
var
  AppWasRunning: Boolean;   // o'rnatishdan oldin ilova ochiq edimi
  ModellarniOchir: Boolean; // uninstall: nutq modellari ham oʻchirilsinmi

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

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
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

// «Nutq modellari saqlab qolinsinmi?» — Inno'ning «Haqiqatan oʻchirasizmi?»
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

  // Faqat modellar (foydalanuvchi rozi boʻlsa). Sozlamalar, tarix va hujjatlar
  // (`%APPDATA%\Voxly`) hech qachon oʻchirilmaydi.
  if (CurUninstallStep = usPostUninstall) and ModellarniOchir then
    DelTree(ExpandConstant('{localappdata}\{#AppName}\models'), True, True, True);
end;
