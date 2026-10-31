// Sozlamalar sheet'i: diktovka tugmasi, mikrofon, avtoishga tushish, ruxsatlar
// va yigʻiladigan "Qoʻshimcha sozlamalar".
// Dizayn manbasi: Claude Design "Kotib - yangi.dc.html".
//
// MUHIM XATTI-HARAKAT OʻZGARISHI: sozlamalar endi DARHOL qoʻllanadi.
// Ilgari "qoralama → Saqlash/Qaytarish" modeli edi; dizaynda esa faqat "Tayyor"
// tugmasi bor va u shunchaki oynani yopadi. Bu macOS'ning oʻz System Settings
// xatti-harakati bilan bir xil: foydalanuvchi tugmani bosishi bilan oʻzgarish
// kuchga kiradi va "saqladimmi yoki yoʻqmi" degan savol umuman tugʻilmaydi.
//
// Joylashuv Auto Layout'da (ilgari 460×700 qatʼiy freym edi) — sheet kengligi
// 560 va "Qoʻshimcha sozlamalar" yigʻilib-ochilganda balandlik oʻzgaradi,
// qatʼiy freym bunga yaramaydi.

import AppKit
import AVFoundation
import Carbon.HIToolbox
import Security

final class SozlamalarVC: NSViewController {

    /// Saqlangach chaqiriladi — AsosiyOyna yangi tugmani roʻyxatdan oʻtkazadi.
    /// Yangi tugmani qoʻllaydi; tizim uni roʻyxatdan oʻtkazmasa — false.
    var onSave: ((HotKeyConfig) -> Bool)?
    /// Sheet sifatida ochilganda "Tayyor" bosilishi — `AsosiyOyna` ulaydi.
    var onYop: (() -> Void)?

    private var monitor: Any?
    private var recording = false
    private var joriyHotkey: HotKeyConfig

    private var hotkeyChip: NSTextField!
    private var hotkeyTugma: FonliTugma!
    private var hotkeyIzoh: NSTextField!
    private var micPopup: NSPopUpButton!
    private var micWarning: NSTextField!
    private var avtoSwitch: NSSwitch!

    private var mikBelgi: NSTextField!
    private var mikYozuv: NSTextField!
    private var axBelgi: NSTextField!
    private var axTugma: FonliTugma!
    private var ruxsatTimer: Timer?

    var qoshimchaLink: BosiladiganYozuv!
    var qoshimcha: NSStackView!
    var qoshimchaOchiq = false

    var modePopup: NSPopUpButton!
    private var tilPopup: NSPopUpButton!
    private var uiTilPopup: NSPopUpButton!
    private var tilIzoh: NSTextField!
    var apostrofSwitch: NSSwitch!
    var diagnostikaSwitch: NSSwitch!
    var provayderPopup: NSPopUpButton!
    var kalitMaydon: NSSecureTextField!
    var baseURLMaydon: NSTextField!
    var modelCombo: NSComboBox!
    var modelHolati: NSTextField!
    var eskirganQator: NSStackView!
    var eskirganYozuv: NSTextField!
    var eskirganTugma: FonliTugma!
    var taklifQilingan: String = ""
    var modelTask: Task<Void, Never>?
    var xosQator: NSStackView!
    var tekshirTugma: FonliTugma!
    var tekshirNatija: NSTextField!

    /// Roʻyxatdagi tartib: [0] = tizim standarti, keyin qurilmalar.
    private var micList: [MicDevice] = []

    init(_ c: HotKeyConfig) {
        joriyHotkey = c
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) ishlatilmaydi") }

    /// Tashqaridan tugma oʻzgarsa sinxronlash uchun.
    func update(_ c: HotKeyConfig) {
        joriyHotkey = c
        hotkeyniYangila()
    }

    // MARK: Hayot sikli

    override func viewWillAppear() {
        super.viewWillAppear()
        stopRecording()
        holatniYukla()
        ruxsatniYangila()
        // Ruxsat ilovadan TASHQARIDA beriladi va hech qanday bildirishnoma
        // kelmaydi — sheet ochiq turganida davriy tekshiramiz.
        ruxsatTimer?.invalidate()
        ruxsatTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.ruxsatniYangila()
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        stopRecording()  // hotkey yozish monitorini qoldirmaymiz
        llmniSaqla()  // maydonda tahrir qolgan boʻlsa — yozib qoʻyamiz
        ruxsatTimer?.invalidate()
        ruxsatTimer = nil
        modelTask?.cancel()  // sheet yopilgach tarmoq soʻrovini kutmaymiz
        modelTask = nil
    }

    private func holatniYukla() {
        reloadMics()
        tilniYukla()
        uiTilPopup.selectItem(at: UITili.allCases.firstIndex(of: UITili.tanlangan) ?? 0)
        modePopup.selectItem(at: Prefs.insertMode.rawValue)
        avtoSwitch.state = LoginItem.isEnabled ? .on : .off
        apostrofSwitch.state = Prefs.apostrof == .oddiy ? .on : .off
        diagnostikaSwitch.state = Prefs.diagnostika ? .on : .off
        llmniYukla()
        hotkeyniYangila()
    }

    // MARK: Qurish

    override func loadView() {
        let kontent = NSStackView()
        kontent.orientation = .vertical
        kontent.alignment = .leading
        kontent.spacing = 22
        kontent.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 18, right: 24)
        kontent.translatesAutoresizingMaskIntoConstraints = false

        kontent.addArrangedSubview(U.yozuv(tr("Настройки", "Settings"), 22, .bold))
        kontent.addArrangedSubview(qurHotkey())
        kontent.addArrangedSubview(qurNutqTili())
        kontent.addArrangedSubview(qurUITili())
        kontent.addArrangedSubview(qurMikrofon())
        kontent.addArrangedSubview(qurAvtoIshga())
        kontent.addArrangedSubview(qurRuxsatQutisi())

        qoshimchaLink = BosiladiganYozuv(
            tr("Дополнительно  ⌄", "Advanced  ⌄"), rang: U.kok,
            size: 16, weight: .medium)
        qoshimchaLink.onBos = { [weak self] in self?.qoshimchaniAlmashtir() }
        kontent.addArrangedSubview(qoshimchaLink)

        qoshimcha = qurQoshimcha()
        qoshimcha.isHidden = true
        kontent.addArrangedSubview(qoshimcha)

        // Har bir qator sheet kengligiga tortilsin — aks holda NSStackView ularni
        // eng keng elementga qarab tekislaydi va oʻng chekka "sakrab" turadi.
        for qator in kontent.arrangedSubviews where qator is NSStackView || qator is NSView {
            qator.widthAnchor.constraint(
                equalTo: kontent.widthAnchor,
                constant: -48
            ).isActive = true
        }

        let scroll = NSScrollView()
        scroll.contentView = TepagaTekislovchiKlipView()
        scroll.documentView = kontent
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        // Hujjat kengligi klip kengligiga bogʻlanadi — gorizontal skroll chiqmaydi.
        kontent.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        view = scroll
    }

    // MARK: Diktovka tugmasi

    private func qurHotkey() -> NSView {
        let sarlavha = U.yozuv(tr("Клавиша диктовки", "Dictation shortcut"), 17)
        let izoh = U.yozuv(tr("Нажмите её в любом приложении", "Press it in any app"), 14, .regular, U.matn2)
        let matnlar = NSStackView(views: [sarlavha, izoh])
        matnlar.orientation = .vertical
        matnlar.alignment = .leading
        matnlar.spacing = 2

        hotkeyChip = U.yozuv(joriyHotkey.displayString, 18, .semibold)
        hotkeyChip.alignment = .center
        let chipQuti = NSView()
        chipQuti.wantsLayer = true
        chipQuti.layer?.backgroundColor = U.yumshoqFon.cgColor
        chipQuti.layer?.cornerRadius = 8
        chipQuti.layer?.cornerCurve = .continuous
        hotkeyChip.translatesAutoresizingMaskIntoConstraints = false
        chipQuti.addSubview(hotkeyChip)
        NSLayoutConstraint.activate([
            hotkeyChip.topAnchor.constraint(equalTo: chipQuti.topAnchor, constant: 8),
            hotkeyChip.bottomAnchor.constraint(equalTo: chipQuti.bottomAnchor, constant: -8),
            hotkeyChip.leadingAnchor.constraint(equalTo: chipQuti.leadingAnchor, constant: 14),
            hotkeyChip.trailingAnchor.constraint(equalTo: chipQuti.trailingAnchor, constant: -14),
            chipQuti.widthAnchor.constraint(greaterThanOrEqualToConstant: 76)
        ])

        hotkeyTugma =
            U.ikkilamchiTugma(
                tr("Изменить", "Change"), target: self,
                action: #selector(toggleRecord),
                balandlik: 40) as? FonliTugma

        let qator = NSStackView(views: [matnlar, chipQuti, hotkeyTugma])
        qator.orientation = .horizontal
        qator.alignment = .centerY
        qator.spacing = 16
        matnlar.setContentHuggingPriority(.defaultLow, for: .horizontal)
        chipQuti.setContentHuggingPriority(.required, for: .horizontal)

        hotkeyIzoh = U.yozuv("", 13, .regular, U.matn2)
        hotkeyIzoh.lineBreakMode = .byWordWrapping
        hotkeyIzoh.maximumNumberOfLines = 2
        hotkeyIzoh.preferredMaxLayoutWidth = 512
        hotkeyIzoh.isHidden = true

        let ustun = NSStackView(views: [qator, hotkeyIzoh])
        ustun.orientation = .vertical
        ustun.alignment = .leading
        ustun.spacing = 6
        qator.widthAnchor.constraint(equalTo: ustun.widthAnchor).isActive = true
        return ustun
    }

    private func hotkeyniYangila() {
        guard hotkeyChip != nil else { return }
        hotkeyChip.stringValue = recording ? tr("Нажмите…", "Press keys…") : joriyHotkey.displayString
        hotkeyTugma.matnniAlmashtir(recording ? tr("Отмена", "Cancel") : tr("Изменить", "Change"))
        hotkeyIzoh.isHidden = !recording
        hotkeyIzoh.stringValue = tr("⌃, ⌥ или ⌘ (можно с ⇧) + клавиша. Отмена: ⎋", "⌃, ⌥ or ⌘ (⇧ optional) + a key. Cancel: ⎋")
        hotkeyIzoh.textColor = U.matn2
    }

    @objc private func toggleRecord() {
        if recording { stopRecording() } else { startRecording() }
        hotkeyniYangila()
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == UInt16(kVK_Escape) {
                self.stopRecording(); self.hotkeyniYangila(); return nil
            }
            let yangi = HotKeyConfig(
                keyCode: UInt32(event.keyCode),
                carbonModifiers: carbonModifiers(from: event.modifierFlags),
                label: keyLabel(for: event))
            // Modifikatorsiz tugma global qotib qoladi, yolgʻiz ⇧ esa bosh
            // harflarni yeb qoʻyadi — ikkalasiga ham ruxsat yoʻq (F5).
            guard yangi.modifikatorYetarli else {
                self.hotkeyIzoh.stringValue = tr("Нужна хотя бы одна из ⌃, ⌥ или ⌘ — одной ⇧ мало.", "Use at least one of ⌃, ⌥ or ⌘ — ⇧ alone is not enough.")
                self.hotkeyIzoh.textColor = U.qizil
                return nil
            }
            self.stopRecording()
            // Darhol qoʻllanadi — "Saqlash" tugmasi yoʻq. Saqlash tizim tugmani
            // qabul qilgandan keyin (AppDelegate.applyHotKey).
            if self.onSave?(yangi) == true {
                self.joriyHotkey = yangi
                self.hotkeyniYangila()
                RubaiLog.write("sozlamalar: tugma \(yangi.displayString)")
            } else {
                self.hotkeyniYangila()
                self.hotkeyIzoh.isHidden = false
                self.hotkeyIzoh.stringValue =
                    tr("\(yangi.displayString) не удалось назначить — возможно, её занимает другое приложение. Работает прежняя клавиша.", "Couldn't register \(yangi.displayString) — another app may be using it. The previous shortcut still works.")
                self.hotkeyIzoh.textColor = U.qizil
                RubaiLog.write("sozlamalar: tugma \(yangi.displayString) roʻyxatdan oʻtmadi")
            }
            return nil
        }
    }

    private func stopRecording() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    // MARK: Mikrofon

    // MARK: Nutq tili

    private func qurNutqTili() -> NSView {
        tilPopup = NSPopUpButton()
        for t in NutqTili.allCases { tilPopup.addItem(withTitle: t.nomi) }
        tilPopup.target = self
        tilPopup.action = #selector(tilOzgardi)
        tilPopup.translatesAutoresizingMaskIntoConstraints = false
        tilPopup.widthAnchor.constraint(equalToConstant: 280).isActive = true

        let qator = NSStackView(views: [U.yozuv(tr("Язык речи", "Speech language"), 17), tilPopup])
        qator.orientation = .horizontal
        qator.alignment = .centerY
        qator.spacing = 16

        tilIzoh = U.yozuv("", 13, .regular, U.matn2)
        tilIzoh.lineBreakMode = .byWordWrapping
        tilIzoh.maximumNumberOfLines = 3
        tilIzoh.preferredMaxLayoutWidth = 512

        let ustun = NSStackView(views: [qator, tilIzoh])
        ustun.orientation = .vertical
        ustun.alignment = .leading
        ustun.spacing = 6
        tilIzoh.widthAnchor.constraint(equalTo: ustun.widthAnchor).isActive = true
        return ustun
    }

    // MARK: Interfeys tili

    private func qurUITili() -> NSView {
        uiTilPopup = NSPopUpButton()
        for t in UITili.allCases { uiTilPopup.addItem(withTitle: t.nomi) }
        uiTilPopup.target = self
        uiTilPopup.action = #selector(uiTilOzgardi)
        uiTilPopup.translatesAutoresizingMaskIntoConstraints = false
        uiTilPopup.widthAnchor.constraint(equalToConstant: 280).isActive = true
        let qator = NSStackView(views: [U.yozuv(tr("Язык интерфейса", "App language"), 17), uiTilPopup])
        qator.orientation = .horizontal
        qator.alignment = .centerY
        qator.spacing = 16
        return qator
    }

    /// Til ishga tushishda bir marta aniqlanadi (ui_tili.swift) — oʻzgarsa
    /// ilova qayta ishga tushadi.
    @objc private func uiTilOzgardi() {
        let idx = uiTilPopup.indexOfSelectedItem
        guard idx >= 0, idx < UITili.allCases.count else { return }
        let yangi = UITili.allCases[idx]
        guard yangi != UITili.tanlangan else { return }
        UITili.tanlangan = yangi
        let a = NSAlert()
        a.messageText = tr("Перезапустить Voxly?", "Restart Voxly?")
        a.informativeText = tr(
            "Язык интерфейса сменится после перезапуска.", "The new language applies after a restart.")
        a.addButton(withTitle: tr("Перезапустить", "Restart"))
        a.addButton(withTitle: tr("Позже", "Later"))
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? p.run()
        NSApp.terminate(nil)
    }

    private func tilniYukla() {
        tilPopup.selectItem(at: NutqTili.allCases.firstIndex(of: Prefs.nutqTili) ?? 0)
        tilIzohiniYangila()
    }

    private func tilIzohiniYangila() {
        let m = ModelTanlov.joriy(Prefs.nutqTili)
        tilIzoh.stringValue =
            ModelStore.isReady
            ? tr("Всё будет записываться на этом языке.", "Everything will be transcribed in this language.")
            : tr("Модель (~\(m.hajm / 1_048_576) МБ) скачается при первой диктовке.", "The model (~\(m.hajm / 1_048_576) MB) will download on first dictation.")
    }

    @objc private func tilOzgardi() {
        let idx = tilPopup.indexOfSelectedItem
        guard idx >= 0, idx < NutqTili.allCases.count else { return }
        Prefs.nutqTili = NutqTili.allCases[idx]
        RubaiLog.write("sozlamalar: nutq tili → \(Prefs.nutqTili.kod)")
        tilIzohiniYangila()
    }

    private func qurMikrofon() -> NSView {
        micPopup = NSPopUpButton()
        micPopup.target = self
        micPopup.action = #selector(micChanged)
        micPopup.translatesAutoresizingMaskIntoConstraints = false
        micPopup.widthAnchor.constraint(equalToConstant: 280).isActive = true

        let qator = NSStackView(views: [U.yozuv(tr("Микрофон", "Microphone"), 17), micPopup])
        qator.orientation = .horizontal
        qator.alignment = .centerY
        qator.spacing = 16
        qator.setHuggingPriority(.defaultLow, for: .horizontal)

        micWarning = U.yozuv("", 13, .regular, U.matn2)
        micWarning.lineBreakMode = .byWordWrapping
        micWarning.maximumNumberOfLines = 3
        micWarning.preferredMaxLayoutWidth = 512
        micWarning.isHidden = true

        let ustun = NSStackView(views: [qator, micWarning])
        ustun.orientation = .vertical
        ustun.alignment = .leading
        ustun.spacing = 6
        qator.widthAnchor.constraint(equalTo: ustun.widthAnchor).isActive = true
        micWarning.widthAnchor.constraint(equalTo: ustun.widthAnchor).isActive = true
        return ustun
    }

    private func reloadMics() {
        micList = AudioDevices.inputDevices()
        micPopup.removeAllItems()
        micPopup.addItem(withTitle: tr("(системный)", "(system default)"))
        for d in micList { micPopup.addItem(withTitle: d.listLabel) }

        // Saqlangan qurilma hali ulanganmi?
        if let uid = Prefs.micUID, let idx = micList.firstIndex(where: { $0.uid == uid }) {
            micPopup.selectItem(at: idx + 1)
        } else {
            micPopup.selectItem(at: 0)
            if Prefs.micUID != nil {
                // Qurilma uzilgan — jim standartga qaytamiz, lekin logga yozamiz
                RubaiLog.write("sozlamalar: saqlangan mikrofon topilmadi, standartga qaytildi")
            }
        }
        micOgohlantirishi()
    }

    @objc private func micChanged() {
        let idx = micPopup.indexOfSelectedItem
        Prefs.micUID = idx <= 0 ? nil : micList[idx - 1].uid
        micOgohlantirishi()
    }

    private func micOgohlantirishi() {
        let idx = micPopup.indexOfSelectedItem
        var matn = ""
        var ogohmi = false
        if idx <= 0 {
            if let def = AudioDevices.defaultInput() {
                let w = def.kind.warning
                matn = tr("Системный: \(def.name)", "System default: \(def.name)") + (w.isEmpty ? "" : "\n\(w)")
                ogohmi = !w.isEmpty
            } else {
                matn = tr("Микрофон не найден. Проверьте, что он подключён.", "No microphone found. Check that it's connected.")
                ogohmi = true
            }
        } else {
            matn = micList[idx - 1].kind.warning
            ogohmi = !matn.isEmpty
        }
        micWarning.stringValue = matn
        micWarning.textColor = ogohmi ? U.qizil : U.matn2
        micWarning.isHidden = matn.isEmpty
    }

    // MARK: Avtomatik ishga tushish

    private func qurAvtoIshga() -> NSView {
        avtoSwitch = NSSwitch()
        avtoSwitch.target = self
        avtoSwitch.action = #selector(avtoOzgardi)
        let qator = NSStackView(views: [U.yozuv(tr("Запускать при входе в систему", "Open at login"), 17), avtoSwitch])
        qator.orientation = .horizontal
        qator.alignment = .centerY
        qator.spacing = 16
        return qator
    }

    @objc private func avtoOzgardi() {
        let xohlangan = avtoSwitch.state == .on
        guard xohlangan != LoginItem.isEnabled else { return }
        if !LoginItem.set(xohlangan) {
            avtoSwitch.state = LoginItem.isEnabled ? .on : .off
            ogohlantir(
                tr("Не удалось включить автозапуск", "Couldn't enable open at login"),
                tr("macOS отклонила запрос. Включите вручную: Системные настройки → Основные → Объекты входа.", "macOS declined the request. Turn it on in System Settings → General → Login Items."))
        }
    }

    // MARK: Yangilanishlar

    /// Avto-yangilanish (`yangilovchi.swift`). Yoqish/oʻchirish tugmasi YOʻQ —
    /// spec: yangilanish doim avtomatik; bu yerda faqat holat va qoʻlda tekshirish.

    // MARK: Ruxsat holati

    private func qurRuxsatQutisi() -> NSView {
        let quti = NSView()
        quti.wantsLayer = true
        quti.layer?.backgroundColor = U.panel.cgColor
        quti.layer?.cornerRadius = 10
        quti.layer?.cornerCurve = .continuous

        mikBelgi = U.yozuv("○", 17, .regular, U.matn4)
        mikYozuv = U.yozuv(tr("Доступ к микрофону", "Microphone access"), 16)
        let mikQator = NSStackView(views: [mikBelgi, mikYozuv])
        mikQator.orientation = .horizontal
        mikQator.alignment = .centerY
        mikQator.spacing = 10

        axBelgi = U.yozuv("○", 17, .regular, U.matn4)
        let axYozuv = U.yozuv(tr("Доступ к вводу текста (Универсальный доступ)", "Text input access (Accessibility)"), 16)
        axTugma =
            U.ikkilamchiTugma(
                tr("Разрешить", "Allow"), target: self, action: #selector(axniOch),
                balandlik: 36, shrift: 15) as? FonliTugma
        let axQator = NSStackView(views: [axBelgi, axYozuv, NSView(), axTugma])
        axQator.orientation = .horizontal
        axQator.alignment = .centerY
        axQator.spacing = 10
        axYozuv.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let ustun = NSStackView(views: [mikQator, axQator])
        ustun.orientation = .vertical
        ustun.alignment = .leading
        ustun.spacing = 10
        ustun.translatesAutoresizingMaskIntoConstraints = false
        quti.addSubview(ustun)
        NSLayoutConstraint.activate([
            ustun.topAnchor.constraint(equalTo: quti.topAnchor, constant: 14),
            ustun.bottomAnchor.constraint(equalTo: quti.bottomAnchor, constant: -14),
            ustun.leadingAnchor.constraint(equalTo: quti.leadingAnchor, constant: 16),
            ustun.trailingAnchor.constraint(equalTo: quti.trailingAnchor, constant: -16),
            axQator.widthAnchor.constraint(equalTo: ustun.widthAnchor)
        ])
        return quti
    }

    private func ruxsatniYangila() {
        let mikOK = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let axOK = AXIsProcessTrusted()
        mikBelgi.stringValue = mikOK ? "✓" : "○"
        mikBelgi.textColor = mikOK ? U.yashil : U.matn4
        mikYozuv.stringValue = mikOK ? tr("Доступ к микрофону есть", "Microphone access granted") : tr("Доступ к микрофону", "Microphone access")
        axBelgi.stringValue = axOK ? "✓" : "○"
        axBelgi.textColor = axOK ? U.yashil : U.matn4
        axTugma.isHidden = axOK
    }

    @objc private func axniOch() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        NSWorkspace.shared.open(
            URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    // MARK: Xizmat amallari


    @objc func logniOch() {
        let path = Yollar.log.path
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: Data())
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    /// Ilova ichidagi `Litsenziyalar.txt` (`scripts/litsenziyalar.sh` yasaydi):
    /// Kotib, uchinchi tomon dasturlari va modellar litsenziyalari — rubaiSTT
    /// (Apache-2.0) va NLLB-200 (CC-BY-NC-4.0) atribusiyasi shu yerda.
    @objc func litsenziyalarniOch() {
        guard let url = Bundle.main.url(forResource: "Litsenziyalar", withExtension: "txt") else {
            RubaiLog.write("XATO: Litsenziyalar.txt bundle'da yoʻq")
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Ilovani oʻchirish. Toʻliq oʻchirish (paket kvitansiyasi, TCC ruxsatlari,
    /// /Applications) admin huquqini talab qiladi, shuning uchun ilova buni
    /// OʻZI BAJARMAYDI — skript `.app` ichida keladi va buyruq nusxalanadi.
    /// Foydalanuvchi nima bajarilishini koʻrib turib oʻzi tasdiqlaydi.
    @objc func ilovaniOchir() {
        let skript = Bundle.main.path(forResource: "uninstall", ofType: "sh")
        let buyruq = "sudo \"\(skript ?? "/Applications/Voxly.app/Contents/Resources/uninstall.sh")\""

        let a = NSAlert()
        a.messageText = tr("Удалить Voxly", "Uninstall Voxly")
        a.informativeText =
            tr("Будут удалены приложение, настройки, разрешения и модели. История диктовок и ", "This removes the app, settings, permissions and models. Dictation history and ")
            + tr("документы тоже удалятся.\n\nНужен пароль администратора, ", "documents are removed too.\n\nIt needs an administrator password, ")
            + tr("поэтому команда выполняется в Терминале. Она будет скопирована:\n\n\(buyruq)", "so you run it in Terminal. This command will be copied:\n\n\(buyruq)")
        a.addButton(withTitle: tr("Скопировать команду", "Copy command"))
        a.addButton(withTitle: tr("Отмена", "Cancel"))
        guard a.runModal() == .alertFirstButtonReturn else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(buyruq, forType: .string)
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
    }

    private func ogohlantir(_ sarlavha: String, _ matn: String) {
        let a = NSAlert()
        a.messageText = sarlavha
        a.informativeText = matn
        a.alertStyle = .warning
        a.addButton(withTitle: "OK")
        a.runModal()
    }
}
