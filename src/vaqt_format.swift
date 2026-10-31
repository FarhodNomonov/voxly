// Kotib — foydalanuvchiga koʻrsatiladigan vaqt yozuvlari.
//
// Dizayn ("Kotib - yangi.dc.html") tarix qatorlarida "bugun 16:04" /
// "kecha 18:22" koʻrinishini, yozib olish kartasida esa "0:04" taymerini
// talab qiladi. Ikkalasi ham sof mantiq — Foundation'dan boshqa hech narsa
// kerak emas, shuning uchun test.sh ularni qamraydi.

import Foundation

enum VaqtFormat {

    /// Yozib olish taymeri: `0:04`, `1:23`, `12:05`.
    ///
    /// Soniyalar PASTGA yaxlitlanadi — 4.9 soniya hali "0:04". Sekund sanogʻi
    /// oldinga yugurib ketsa foydalanuvchi taymerga ishonmay qoladi.
    static func taymer(_ soniya: Double) -> String {
        // Tizim soati sozlanib qolsa hisob manfiy chiqishi mumkin.
        let jami = max(0, Int(soniya.rounded(.down)))
        return String(format: "%d:%02d", jami / 60, jami % 60)
    }

    /// Tarix qatoridagi sana: `bugun 16:04`, `kecha 18:22`, aks holda `22 avg 18:22`.
    ///
    /// Taqqoslash KALENDAR kuni boʻyicha, "24 soat oldin" boʻyicha emas: bugun
    /// yarim tundan keyin turib kechagi kechki yozuvni "bugun" deb koʻrsatish
    /// notoʻgʻri boʻlardi.
    ///
    /// `hozir` parametri sinov uchun — ishlab turgan ilova uni bermaydi.
    static func nisbiy(_ sana: Date, hozir: Date = Date()) -> String {
        let taqvim = Calendar.current
        let vaqt = soatFormatter.string(from: sana)
        if taqvim.isDate(sana, inSameDayAs: hozir) { return tr("сегодня \(vaqt)", "today \(vaqt)") }
        if let kecha = taqvim.date(byAdding: .day, value: -1, to: hozir),
            taqvim.isDate(sana, inSameDayAs: kecha)
        {
            return tr("вчера \(vaqt)", "yesterday \(vaqt)")
        }
        return "\(sanaFormatter.string(from: sana)) \(vaqt)"
    }

    /// Fayl uzunligi: `12 daqiqa`, `1 soat 5 daqiqa`, `1 daqiqadan kam`.
    ///
    /// Soniyalar KOʻRSATILMAYDI — foydalanuvchi roʻyxatda faylni tanish uchun
    /// taxminiy uzunlikni koʻradi, aniq sekundlar unga hech narsa bermaydi.
    static func davomiylik(_ soniya: Double) -> String {
        let daqiqa = max(0, Int(soniya)) / 60
        // Nol daqiqa "fayl boʻsh" degan taassurot beradi — buni ochiq aytamiz.
        if daqiqa == 0 { return tr("меньше минуты", "under a minute") }
        if daqiqa < 60 { return tr("\(daqiqa) мин", "\(daqiqa) min") }
        let soat = daqiqa / 60
        let qoldiq = daqiqa % 60
        return qoldiq == 0 ? tr("\(soat) ч", "\(soat) h") : tr("\(soat) ч \(qoldiq) мин", "\(soat) h \(qoldiq) min")
    }

    /// Faqat kun: `bugun`, `kecha`, aks holda `22 avg`. Vaqtsiz — fayl
    /// roʻyxatida soat-daqiqa ortiqcha shovqin.
    static func kun(_ sana: Date, hozir: Date = Date()) -> String {
        let taqvim = Calendar.current
        if taqvim.isDate(sana, inSameDayAs: hozir) { return tr("сегодня", "today") }
        if let kecha = taqvim.date(byAdding: .day, value: -1, to: hozir),
            taqvim.isDate(sana, inSameDayAs: kecha)
        {
            return tr("вчера", "yesterday")
        }
        return sanaFormatter.string(from: sana)
    }

    // Formatterlar qayta ishlatiladi: DateFormatter yaratish qimmat, tarix
    // roʻyxati esa har yangilanishda 200 tagacha qator chizadi.
    private static let soatFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let sanaFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: UITili.joriy == .en ? "en_US" : "ru_RU")
        f.dateFormat = "d MMM"
        return f
    }()
}
