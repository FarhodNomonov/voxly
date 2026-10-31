// Voxly — saqlanadigan sozlamalar.

import AppKit

// MARK: - Matnni kiritish usuli

enum InsertMode: Int, CaseIterable {
    case fast = 0  // clipboard + ⌘V
    case slow = 1  // belgima-belgi yozish

    var label: String {
        switch self {
        case .fast: return tr("Быстро (вставка через буфер обмена) — рекомендуется", "Fast (paste via clipboard) — recommended")
        case .slow: return tr("Медленно (ввод по символу) — если вставка не работает", "Slow (type character by character) — if pasting fails")
        }
    }
}

// MARK: - Saqlanadigan sozlamalar

enum Prefs {
    private static let d = UserDefaults.standard

    /// nil — tizim standart mikrofoni.
    static var micUID: String? {
        get { d.string(forKey: "mic.uid") }
        set {
            if let v = newValue { d.set(v, forKey: "mic.uid") } else { d.removeObject(forKey: "mic.uid") }
        }
    }

    static var insertMode: InsertMode {
        get { InsertMode(rawValue: d.integer(forKey: "insert.mode")) ?? .fast }
        set { d.set(newValue.rawValue, forKey: "insert.mode") }
    }

    /// Nutq tili — qaysi model va whisper tili ishlatiladi (model_tanlov.swift).
    static var nutqTili: NutqTili {
        get { d.string(forKey: "nutq.tili").flatMap(NutqTili.init(rawValue:)) ?? NutqTili.standart }
        set { d.set(newValue.rawValue, forKey: "nutq.tili") }
    }

    /// Chiqadigan matnda apostrof uslubi. Standart — oʻzbek lotin meʼyori.
    static var apostrof: Apostrof {
        // Oʻzbek lotin meʼyori (ʻ/ʼ) faqat oʻzbek nutqi uchun: rus/ingliz matnida
        // «don't» kabi soʻzlar «donʼt» boʻlib ketmasin.
        get {
            guard nutqTili == .ozbek else { return .oddiy }
            return UserDefaults.standard.bool(forKey: "oddiyApostrof") ? .oddiy : .standart
        }
        set { UserDefaults.standard.set(newValue == .oddiy, forKey: "oddiyApostrof") }
    }

    /// «Diagnostika rejimi» — yoqilsa transkript matni ham logga yoziladi va
    /// rejim 24 soatdan keyin oʻzi oʻchadi (log_siyosati.swift). Saqlanadigani —
    /// tugash vaqti (unix soniya).
    static var diagnostika: Bool {
        get {
            let t = UserDefaults.standard.object(forKey: "diagnostikaTugash") as? Double
            return LogSiyosati.diagnostikaFaolmi(tugash: t, hozir: Date().timeIntervalSince1970)
        }
        set {
            if newValue {
                UserDefaults.standard.set(
                    Date().timeIntervalSince1970 + LogSiyosati.diagnostikaMuddati,
                    forKey: "diagnostikaTugash")
            } else {
                UserDefaults.standard.removeObject(forKey: "diagnostikaTugash")
            }
        }
    }
}

/// `saqla()` (SozlamalarVC, sozlamalar_view.swift) LLM sozlamasi saqlangach
/// joʻnatadi — `StudiyaVC` shuni tinglab, Studio tugmalarini darhol yangilaydi (I1).
extension Notification.Name { static let llmSozlamaSaqlandi = Notification.Name("llmSozlamaSaqlandi") }
