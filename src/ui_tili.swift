// Voxly — interfeys tili (rus / ingliz).
//
// Har bir matn chaqiruv joyida ikkala tilda turadi: `tr("Настройки", "Settings")`.
// Nega .strings fayllar emas: kalit va tarjima bir joyda — tarjimasi unutilgan
// matn kompilyatsiya qilinmaydi, kodni oʻqiganda ham nima koʻrinishi darhol aniq.
//
// Til ilova ishga tushganda bir marta aniqlanadi (Sozlamalar → «Язык
// интерфейса»); oʻzgartirilsa ilova qayta ishga tushadi.
//
// Foundation'dan boshqa hech narsa import qilmaydi — test.sh sinaydi.

import Foundation

enum UITili: String, CaseIterable {
    case tizim = "system"
    case ru
    case en

    /// Sozlamalardagi roʻyxat uchun nom — har doim oʻz tilida.
    var nomi: String {
        switch self {
        case .tizim: return tr("Как в системе", "System default")
        case .ru: return "Русский"
        case .en: return "English"
        }
    }

    static let kalit = "ui.tili"

    /// Saqlangan tanlov.
    static var tanlangan: UITili {
        get { UserDefaults.standard.string(forKey: kalit).flatMap(UITili.init(rawValue:)) ?? .tizim }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: kalit) }
    }

    /// Tizim tillari roʻyxatidan: rus tilini tushunadigan mintaqalar (MDH) —
    /// rus, qolganlar — ingliz.
    static func tizimdan(_ tillar: [String]) -> UITili {
        let rusTushunadi: Set<String> = ["ru", "uk", "be", "kk", "uz", "ky", "tg", "az", "hy", "ka", "tk"]
        for t in tillar {
            let kod = String(t.prefix(while: { $0 != "-" && $0 != "_" })).lowercased()
            if kod == "en" { return .en }
            if rusTushunadi.contains(kod) { return .ru }
        }
        return .en
    }

    /// Ishlayotgan jarayondagi til (ru yoki en) — bir marta hisoblanadi.
    static let joriy: UITili = {
        switch tanlangan {
        case .tizim: return tizimdan(Locale.preferredLanguages)
        case let t: return t
        }
    }()
}

/// Interfeys matni: rus va ingliz varianti.
func tr(_ ru: String, _ en: String) -> String {
    UITili.joriy == .en ? en : ru
}
