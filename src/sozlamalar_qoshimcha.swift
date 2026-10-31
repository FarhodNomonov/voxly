// Sozlamalar: yigʻiladigan «Qoʻshimcha sozlamalar» — kiritish usuli, oddiy
// apostrof, diagnostika rejimi, statistika izohi, AI (LLM) boʻlimining koʻrinishi,
// log va ilovani oʻchirish tugmalari. `SozlamalarVC` kengaytmasi.

import AppKit

extension SozlamalarVC {
    // MARK: Qoʻshimcha sozlamalar

    func qoshimchaniAlmashtir() {
        qoshimchaOchiq.toggle()
        qoshimcha.isHidden = !qoshimchaOchiq
        qoshimchaLink.stringValue =
            qoshimchaOchiq
            ? tr("Дополнительно  ⌃", "Advanced  ⌃") : tr("Дополнительно  ⌄", "Advanced  ⌄")
    }

    func qurQoshimcha() -> NSStackView {
        let chiziq = NSView()
        chiziq.wantsLayer = true
        chiziq.layer?.backgroundColor = U.ajratgich.cgColor
        chiziq.heightAnchor.constraint(equalToConstant: 1).isActive = true

        // — Matn kiritish usuli
        modePopup = NSPopUpButton()
        for m in InsertMode.allCases { modePopup.addItem(withTitle: m.label) }
        modePopup.target = self
        modePopup.action = #selector(modeOzgardi)
        modePopup.translatesAutoresizingMaskIntoConstraints = false
        modePopup.widthAnchor.constraint(equalToConstant: 240).isActive = true
        let modeQator = teng(U.yozuv(tr("Способ ввода текста", "Text input method"), 16), modePopup)

        // — Apostrof
        apostrofSwitch = NSSwitch()
        apostrofSwitch.target = self
        apostrofSwitch.action = #selector(apostrofOzgardi)
        let apostrofQator = teng(U.yozuv(tr("Простой апостроф (') в узбекском", "Plain apostrophe (') for Uzbek"), 16), apostrofSwitch)

        // — Diagnostika rejimi (barqarorlik spec'i, G1). Standart holatda logga
        // transkript MATNI yozilmaydi; muammoni tekshirish uchun 24 soatga
        // yoqiladi va keyin oʻzi oʻchadi (log_siyosati.swift).
        diagnostikaSwitch = NSSwitch()
        diagnostikaSwitch.target = self
        diagnostikaSwitch.action = #selector(diagnostikaOzgardi)
        diagnostikaSwitch.toolTip =
            tr("Если включить, 24 часа текст диктовок будет попадать в лог — ", "When on, dictated text is written to the log for 24 hours — ")
            + tr("для поиска проблем. Потом выключится сам. Обычно текста в логе нет.", "to help diagnose problems. It then turns itself off. Normally the log has no text.")
        let diagnostikaQator = teng(U.yozuv(tr("Режим диагностики (24 часа)", "Diagnostic mode (24 hours)"), 16), diagnostikaSwitch)

        // — Anonim statistika (oshkoralik yozuvi)
        //
        // Toggle YOʻQ — statistika doim yoqiq (ega qarori). Lekin yigʻish
        // YASHIRIN emas: bu yozuv nima yuborilishini va nima YUBORILMASLIGINI
        // aniq aytadi, va maxfiylik siyosatiga havola beradi. Bu — huquqiy
        // oshkoralik talabini qondiradigan qism.
        let statistikaSarlavha = U.yozuv(tr("Конфиденциальность", "Privacy"), 16)

        let statistikaIzoh = U.yozuv(
            tr("Распознавание речи работает полностью на вашем Mac, без интернета. ", "Speech recognition runs entirely on your Mac, offline. ")
                + tr("Голос, текст и статистика никуда не отправляются. ", "Your voice, text and usage data are never sent anywhere. ")
                + tr("Интернет нужен только для скачивания модели и для ИИ-функций, ", "The internet is only used to download models and for AI features, ")
                + tr("если вы сами добавите ключ.", "if you add your own key."),
            14, .regular, U.matn2)
        statistikaIzoh.lineBreakMode = .byWordWrapping
        statistikaIzoh.maximumNumberOfLines = 6
        statistikaIzoh.preferredMaxLayoutWidth = 512

        let statistika = NSStackView(views: [statistikaSarlavha, statistikaIzoh])
        statistika.orientation = .vertical
        statistika.alignment = .leading
        statistika.spacing = 4

        // — Sunʼiy intellekt
        let aiSarlavha = U.yozuv(tr("Искусственный интеллект (по желанию)", "AI (optional)"), 16)
        let aiIzoh = U.yozuv(
            tr("С вашим ключом API появятся чистка текста и краткое изложение. ", "Add your API key to get text cleanup and summaries. ")
                + tr("Без него приложение тоже полностью работает.", "The app works fully without it."), 14, .regular, U.matn2)
        aiIzoh.lineBreakMode = .byWordWrapping
        aiIzoh.maximumNumberOfLines = 3
        aiIzoh.preferredMaxLayoutWidth = 512

        provayderPopup = NSPopUpButton()
        provayderPopup.addItem(withTitle: tr("— не выбран —", "— none —"))
        provayderlar.forEach { provayderPopup.addItem(withTitle: $0.nom) }
        provayderPopup.target = self
        provayderPopup.action = #selector(provayderOzgardi)
        provayderPopup.translatesAutoresizingMaskIntoConstraints = false
        provayderPopup.widthAnchor.constraint(equalToConstant: 180).isActive = true

        kalitMaydon = NSSecureTextField()
        kalitMaydon.placeholderString = tr("Ключ API", "API key")
        kalitMaydon.delegate = self

        let aiQator = NSStackView(views: [provayderPopup, kalitMaydon])
        aiQator.orientation = .horizontal
        aiQator.alignment = .centerY
        aiQator.spacing = 10
        kalitMaydon.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Base URL va model FAQAT "Boshqa (custom)" provayderda kerak — dizaynda
        // ular umuman yoʻq, lekin ularsiz custom provayderni sozlab boʻlmaydi.
        baseURLMaydon = NSTextField()
        baseURLMaydon.placeholderString = "Base URL"
        baseURLMaydon.delegate = self
        xosQator = NSStackView(views: [baseURLMaydon])
        xosQator.orientation = .horizontal
        xosQator.alignment = .centerY
        xosQator.spacing = 10
        xosQator.isHidden = true

        // Model — NSComboBox, oddiy popup emas. Ikki sabab:
        //  1. OpenRouter 396 ta model qaytaradi — ularni popup'dan tanlab
        //     boʻlmaydi, combo box'da yozib qidiriladi.
        //  2. U ayni paytda matn maydoni ham: provayderda /models boʻlmasa
        //     yoki tarmoq yoʻq boʻlsa, nom qoʻlda yoziladi. Boshi berk
        //     koʻcha hech qachon boʻlmaydi.
        modelCombo = NSComboBox()
        modelCombo.usesDataSource = false
        modelCombo.completes = true
        modelCombo.hasVerticalScroller = true
        modelCombo.numberOfVisibleItems = 12
        modelCombo.placeholderString = tr("название модели", "model name")
        modelCombo.delegate = self
        let yangilash = U.ikkilamchiTugma(
            tr("Обновить", "Refresh"), target: self,
            action: #selector(modellarniYangila),
            balandlik: 38, shrift: 14)
        modelHolati = U.yozuv("", 13, .regular, U.matn2)
        let modelQator = NSStackView(views: [U.yozuv(tr("Модель", "Model"), 16), modelCombo, yangilash])
        modelQator.orientation = .horizontal
        modelQator.alignment = .centerY
        modelQator.spacing = 10
        modelCombo.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Saqlangan model provayder roʻyxatidan yoʻqolgan boʻlsa shu chiqadi.
        // Ilova modelni OʻZI almashtirmaydi — bu pulga va sifatga tegadi,
        // qaror foydalanuvchiniki.
        eskirganYozuv = U.yozuv("", 13, .regular, U.bannerMatn)
        eskirganYozuv.lineBreakMode = .byWordWrapping
        eskirganYozuv.maximumNumberOfLines = 2
        eskirganYozuv.preferredMaxLayoutWidth = 320
        eskirganTugma =
            U.ikkilamchiTugma(
                tr("Перейти", "Switch"), target: self,
                action: #selector(taklifgaOt),
                balandlik: 32, shrift: 13) as? FonliTugma
        eskirganQator = NSStackView(views: [U.yozuv("⚠️", 14), eskirganYozuv, eskirganTugma])
        eskirganQator.orientation = .horizontal
        eskirganQator.alignment = .centerY
        eskirganQator.spacing = 8
        eskirganQator.isHidden = true

        tekshirTugma =
            U.ikkilamchiTugma(
                tr("Проверить подключение", "Test connection"), target: self,
                action: #selector(ulanishniTekshir),
                balandlik: 38, shrift: 14) as? FonliTugma
        tekshirNatija = U.yozuv("", 14, .regular, U.matn2)
        let tekshirQator = NSStackView(views: [tekshirTugma, tekshirNatija])
        tekshirQator.orientation = .horizontal
        tekshirQator.alignment = .centerY
        tekshirQator.spacing = 12

        let ai = NSStackView(views: [
            aiSarlavha, aiIzoh, aiQator, xosQator,
            modelQator, eskirganQator, modelHolati, tekshirQator
        ])
        ai.orientation = .vertical
        ai.alignment = .leading
        ai.spacing = 10

        // — Xizmat tugmalari
        let log = U.ikkilamchiTugma(
            tr("Открыть лог…", "Open log file…"), target: self,
            action: #selector(logniOch), balandlik: 38, shrift: 14)
        let ochir = U.ikkilamchiTugma(
            tr("Удалить приложение…", "Uninstall…"), target: self,
            action: #selector(ilovaniOchir), balandlik: 38, shrift: 14)
        let litsenziya = U.ikkilamchiTugma(
            tr("Лицензии…", "Licenses…"), target: self,
            action: #selector(litsenziyalarniOch), balandlik: 38, shrift: 14)
        let xizmat = NSStackView(views: [log, litsenziya, ochir])
        xizmat.orientation = .horizontal
        xizmat.spacing = 10

        let stack = NSStackView(views: [chiziq, modeQator, apostrofQator, diagnostikaQator, statistika, ai, xizmat])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        for v in [chiziq, modeQator, apostrofQator, diagnostikaQator, statistika, ai] as [NSView] {
            v.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        for v in [statistikaSarlavha, statistikaIzoh] as [NSView] {
            v.widthAnchor.constraint(equalTo: statistika.widthAnchor).isActive = true
        }
        for v in [aiIzoh, aiQator, xosQator, modelQator, eskirganQator] as [NSView] {
            v.widthAnchor.constraint(equalTo: ai.widthAnchor).isActive = true
        }
        return stack
    }

    /// Chapda yozuv, oʻngda boshqaruv — orasi choʻziladi.
    private func teng(_ chap: NSView, _ ong: NSView) -> NSStackView {
        let s = NSStackView(views: [chap, NSView(), ong])
        s.orientation = .horizontal
        s.alignment = .centerY
        s.spacing = 16
        chap.setContentHuggingPriority(.required, for: .horizontal)
        return s
    }

    @objc private func modeOzgardi() {
        Prefs.insertMode = InsertMode(rawValue: modePopup.indexOfSelectedItem) ?? .fast
    }

    @objc private func apostrofOzgardi() {
        Prefs.apostrof = apostrofSwitch.state == .on ? .oddiy : .standart
    }

    @objc private func diagnostikaOzgardi() {
        Prefs.diagnostika = diagnostikaSwitch.state == .on
        RubaiLog.write("diagnostika rejimi: \(Prefs.diagnostika ? "yoqildi (24 soat)" : "oʻchirildi")")
    }
}
