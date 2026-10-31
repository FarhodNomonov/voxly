// Kotib — ilovaning asosiy menyu satri.
//
// NEGA BU FAYL BOR: macOS'da ⌘C, ⌘V, ⌘A, ⌘Z sehrli emas — ular NSMenuItem'ning
// `keyEquivalent` maydoni orqali ishlaydi. Kotib LSUIElement (menyu satri
// ilovasi) sifatida boshlangani uchun `NSApp.mainMenu` umuman qurilmagan edi:
// natijada oyna ichidagi hech bir matn maydonida standart qisqartmalar
// ishlamasdi. Status-bar menyusi (`ilova.swift`) buning oʻrnini bosmaydi —
// undagi `keyEquivalent` faqat menyu ochiq turganda tekshiriladi.
//
// `target = nil` ATAYLAB: shunda AppKit amalni javobgarlik zanjiri (responder
// chain) boʻylab yuboradi va qaysi matn maydoni faol boʻlsa, oʻsha bajaradi.
// Aniq nishon berilsa, qisqartma faqat oʻsha obyekt uchun ishlab qolardi.
//
// Menyu satri faqat aktivlik siyosati `.regular` boʻlganda koʻrinadi (yaʼni
// oyna ochiq paytda). `.accessory` rejimda u shunchaki yashirin turadi —
// shuning uchun menyuni bir marta, ishga tushishda qurish yetarli.

import AppKit

/// Nomi oʻzgarmaydigan menyu bandi.
///
/// `NSUndoManager` `undo:`/`redo:` bandlarining nomini har validatsiyada oʻzi
/// qayta yozadi («Undo», «Undo Typing» …). Ilovada lokalizatsiya yoʻq, shuning
/// uchun u inglizcha tushadi va qolgan hammasi oʻzbekcha boʻlgan menyuda yalt
/// etib koʻrinadi. Bu sinf birinchi nomdan keyin oʻzgartirishni qabul qilmaydi.
private final class QatiyNomliBand: NSMenuItem {
    private var qulflangan = false

    override var title: String {
        get { super.title }
        set { if !qulflangan { super.title = newValue } }
    }

    func qulfla() { qulflangan = true }
}

enum Menyu {

    /// Asosiy menyuni quradi va `NSApp.mainMenu` ga oʻrnatadi.
    /// `applicationDidFinishLaunching` dan bir marta chaqiriladi.
    static func qur() {
        let bosh = NSMenu()
        bosh.addItem(ilova())
        bosh.addItem(fayl())
        bosh.addItem(tahrir())
        bosh.addItem(korinish())
        bosh.addItem(oyna())
        NSApp.mainMenu = bosh
    }

    // MARK: Yordamchi

    private static func band(
        _ nom: String,
        _ amal: Selector?,
        _ tugma: String = "",
        _ modifikator: NSEvent.ModifierFlags = .command,
        nishon: AnyObject? = nil
    ) -> NSMenuItem {
        let i = NSMenuItem(title: nom, action: amal, keyEquivalent: tugma)
        if !tugma.isEmpty { i.keyEquivalentModifierMask = modifikator }
        i.target = nishon
        return i
    }

    /// `band` bilan bir xil, faqat nomi qulflanadi (`QatiyNomliBand` ga qarang).
    private static func qatiy(
        _ nom: String,
        _ amal: Selector?,
        _ tugma: String,
        _ modifikator: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let i = QatiyNomliBand(title: nom, action: amal, keyEquivalent: tugma)
        i.keyEquivalentModifierMask = modifikator
        i.target = nil
        i.qulfla()
        return i
    }

    private static func bolim(_ nom: String, _ menyu: NSMenu) -> NSMenuItem {
        let b = NSMenuItem(title: nom, action: nil, keyEquivalent: "")
        b.submenu = menyu
        return b
    }

    // MARK: Menyular

    private static func ilova() -> NSMenuItem {
        let m = NSMenu(title: "Voxly")
        m.addItem(band(tr("О Voxly", "About Voxly"), #selector(NSApplication.orderFrontStandardAboutPanel(_:))))
        m.addItem(.separator())
        m.addItem(
            band(
                tr("Настройки…", "Settings…"), #selector(AsosiyOyna.menyuSozlamalar), ",",
                nishon: AsosiyOyna.birgalik))
        m.addItem(.separator())

        // Tizim «Xizmatlar» menyusi: matn tanlanganda boshqa ilovalarga uzatish.
        let xizmatlar = NSMenu(title: tr("Службы", "Services"))
        m.addItem(bolim(tr("Службы", "Services"), xizmatlar))
        NSApp.servicesMenu = xizmatlar

        m.addItem(.separator())
        m.addItem(band(tr("Скрыть Voxly", "Hide Voxly"), #selector(NSApplication.hide(_:)), "h"))
        m.addItem(
            band(
                tr("Скрыть остальные", "Hide Others"),
                #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]))
        m.addItem(band(tr("Показать все", "Show All"), #selector(NSApplication.unhideAllApplications(_:))))
        m.addItem(.separator())
        m.addItem(band(tr("Завершить Voxly", "Quit Voxly"), #selector(NSApplication.terminate(_:)), "q"))
        return bolim("Voxly", m)
    }

    private static func fayl() -> NSMenuItem {
        let m = NSMenu(title: tr("Файл", "File"))
        m.addItem(
            band(
                tr("Открыть…", "Open…"), #selector(AsosiyOyna.menyuFaylOch), "o",
                nishon: AsosiyOyna.birgalik))
        m.addItem(.separator())
        m.addItem(band(tr("Закрыть окно", "Close Window"), #selector(NSWindow.performClose(_:)), "w"))
        return bolim(tr("Файл", "File"), m)
    }

    private static func tahrir() -> NSMenuItem {
        let m = NSMenu(title: tr("Правка", "Edit"))
        // undo:/redo: NSResponder'da eʼlon qilinmagan — ular UndoManager'ga
        // javobgarlik zanjiri orqali boradi, shuning uchun selektor qoʻlda.
        m.addItem(qatiy(tr("Отменить", "Undo"), Selector(("undo:")), "z"))
        m.addItem(qatiy(tr("Повторить", "Redo"), Selector(("redo:")), "z", [.command, .shift]))
        m.addItem(.separator())
        m.addItem(band(tr("Вырезать", "Cut"), #selector(NSText.cut(_:)), "x"))
        m.addItem(band(tr("Копировать", "Copy"), #selector(NSText.copy(_:)), "c"))
        m.addItem(band(tr("Вставить", "Paste"), #selector(NSText.paste(_:)), "v"))
        m.addItem(
            band(
                tr("Вставить без форматирования", "Paste and Match Style"), #selector(NSTextView.pasteAsPlainText(_:)), "v",
                [.command, .option, .shift]))
        m.addItem(band(tr("Удалить", "Delete"), #selector(NSText.delete(_:))))
        m.addItem(.separator())
        m.addItem(band(tr("Выбрать всё", "Select All"), #selector(NSText.selectAll(_:)), "a"))
        return bolim(tr("Правка", "Edit"), m)
    }

    private static func korinish() -> NSMenuItem {
        let m = NSMenu(title: tr("Вид", "View"))
        for b in Bolim.allCases {
            let i = band(
                b.nom, #selector(AsosiyOyna.menyuBolim(_:)), "\(b.rawValue + 1)",
                nishon: AsosiyOyna.birgalik)
            i.tag = b.rawValue
            m.addItem(i)
        }
        return bolim(tr("Вид", "View"), m)
    }

    private static func oyna() -> NSMenuItem {
        let m = NSMenu(title: tr("Окно", "Window"))
        m.addItem(band(tr("Свернуть", "Minimize"), #selector(NSWindow.performMiniaturize(_:)), "m"))
        m.addItem(band(tr("Изменить масштаб", "Zoom"), #selector(NSWindow.performZoom(_:))))
        m.addItem(.separator())
        m.addItem(
            band(
                tr("Все окна — на передний план", "Bring All to Front"),
                #selector(NSApplication.arrangeInFront(_:))))
        NSApp.windowsMenu = m
        return bolim(tr("Окно", "Window"), m)
    }
}
