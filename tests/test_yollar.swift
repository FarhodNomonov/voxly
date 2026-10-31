// Yollar — eski "Audio-Matnga" papkasidan "Kotib" papkasiga koʻchirish testlari.
//
// Bu koʻchirish mavjud foydalanuvchilarning diktovka tarixi va Studiya hujjatlarini
// saqlab qoladi, shuning uchun har bir chekka holat alohida tekshiriladi: koʻchirish
// hech qachon maʼlumotni yoʻqotmasligi yoki ustiga yozmasligi kerak.

import Foundation

private func vaqtinchalikPapka() -> URL {
    let u = FileManager.default.temporaryDirectory
        .appendingPathComponent("kotib-test-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
}

private func faylYoz(_ papka: URL, _ nom: String, _ matn: String) {
    try? FileManager.default.createDirectory(at: papka, withIntermediateDirectories: true)
    try? matn.write(to: papka.appendingPathComponent(nom), atomically: true, encoding: .utf8)
}

private func faylOqi(_ papka: URL, _ nom: String) -> String? {
    try? String(contentsOf: papka.appendingPathComponent(nom), encoding: .utf8)
}

func yollarTestlari() {
    testQosh("koʻchirish — eski papka yangisiga oʻtadi, ichidagi fayl saqlanadi") {
        let baza = vaqtinchalikPapka()
        defer { try? FileManager.default.removeItem(at: baza) }
        let eski = baza.appendingPathComponent(Yollar.eskiPapkaNomi, isDirectory: true)
        let yangi = baza.appendingPathComponent(Yollar.papkaNomi, isDirectory: true)
        faylYoz(eski, "diktovka-tarixi.json", "[]")

        tekshir("koʻchirildi deb qaytadi", Yollar.kochir(baza: baza))
        tekshir("yangi papka paydo boʻldi", FileManager.default.fileExists(atPath: yangi.path))
        tekshir("eski papka qolmadi", !FileManager.default.fileExists(atPath: eski.path))
        tengmi("fayl mazmuni saqlandi", faylOqi(yangi, "diktovka-tarixi.json"), "[]")
    }

    testQosh("koʻchirish — ichma-ich papkalar ham oʻtadi") {
        let baza = vaqtinchalikPapka()
        defer { try? FileManager.default.removeItem(at: baza) }
        let eski = baza.appendingPathComponent(Yollar.eskiPapkaNomi, isDirectory: true)
        let yangi = baza.appendingPathComponent(Yollar.papkaNomi, isDirectory: true)
        faylYoz(eski.appendingPathComponent("hujjatlar/abc", isDirectory: true), "hujjat.json", "{}")

        tekshir("koʻchirildi", Yollar.kochir(baza: baza))
        tengmi(
            "ichki hujjat joyida",
            faylOqi(yangi.appendingPathComponent("hujjatlar/abc", isDirectory: true), "hujjat.json"),
            "{}")
    }

    testQosh("koʻchirish — yangi papka allaqachon bor boʻlsa tegilmaydi") {
        let baza = vaqtinchalikPapka()
        defer { try? FileManager.default.removeItem(at: baza) }
        let eski = baza.appendingPathComponent(Yollar.eskiPapkaNomi, isDirectory: true)
        let yangi = baza.appendingPathComponent(Yollar.papkaNomi, isDirectory: true)
        faylYoz(eski, "tarix.json", "ESKI")
        faylYoz(yangi, "tarix.json", "YANGI")

        tekshir("koʻchirmadi deb qaytadi", !Yollar.kochir(baza: baza))
        tengmi("yangi maʼlumot ustiga yozilmadi", faylOqi(yangi, "tarix.json"), "YANGI")
        tengmi("eski papka ham yoʻqolmadi", faylOqi(eski, "tarix.json"), "ESKI")
    }

    testQosh("koʻchirish — eski papka yoʻq boʻlsa hech narsa yaratilmaydi") {
        let baza = vaqtinchalikPapka()
        defer { try? FileManager.default.removeItem(at: baza) }
        let yangi = baza.appendingPathComponent(Yollar.papkaNomi, isDirectory: true)

        tekshir("koʻchirmadi deb qaytadi", !Yollar.kochir(baza: baza))
        tekshir("boʻsh papka yaratilmadi", !FileManager.default.fileExists(atPath: yangi.path))
    }

    testQosh("koʻchirish — ikkinchi chaqiruv hech narsa qilmaydi") {
        let baza = vaqtinchalikPapka()
        defer { try? FileManager.default.removeItem(at: baza) }
        faylYoz(baza.appendingPathComponent(Yollar.eskiPapkaNomi, isDirectory: true), "a.json", "1")

        tekshir("birinchi chaqiruv koʻchiradi", Yollar.kochir(baza: baza))
        tekshir("ikkinchi chaqiruv tegmaydi", !Yollar.kochir(baza: baza))
        tengmi(
            "maʼlumot buzilmadi",
            faylOqi(baza.appendingPathComponent(Yollar.papkaNomi, isDirectory: true), "a.json"), "1")
    }

    // MARK: Eski tarjima modellarini oʻchirish (tarjimon olib tashlandi)

    testQosh("eski tarjima modellari oʻchiriladi") {
        let baza = vaqtinchalikPapka()
        defer { try? FileManager.default.removeItem(at: baza) }
        let a = baza.appendingPathComponent("tarjima-model", isDirectory: true)
        let b = baza.appendingPathComponent("tarjima-model-33b", isDirectory: true)
        faylYoz(a, "model.bin", "xxx")
        faylYoz(b, "model.bin", "yyy")
        faylYoz(baza, "diktovka-tarixi.json", "[]")

        tekshir("oʻchirildi deb qaytdi", Yollar.eskiTarjimaModellariniOchir(baza: baza))
        tekshir("1.3B yoʻq", !FileManager.default.fileExists(atPath: a.path))
        tekshir("3.3B yoʻq", !FileManager.default.fileExists(atPath: b.path))
        tengmi("tarix joyida", faylOqi(baza, "diktovka-tarixi.json"), "[]")
        tekshir("ikkinchi marta — false", !Yollar.eskiTarjimaModellariniOchir(baza: baza))
    }

    testQosh("koʻchirish — Kotib'dan Voxly'ga, tarjima modeli tashlanadi") {
        let baza = vaqtinchalikPapka()
        defer { try? FileManager.default.removeItem(at: baza) }
        let kotib = baza.appendingPathComponent("Kotib", isDirectory: true)
        faylYoz(kotib, "diktovka-tarixi.json", "K")
        faylYoz(kotib.appendingPathComponent("tarjima-model-33b", isDirectory: true), "model.bin", "x")
        faylYoz(baza.appendingPathComponent("Audio-Matnga", isDirectory: true), "diktovka-tarixi.json", "A")

        tekshir("koʻchirildi", Yollar.kochir(baza: baza))
        let voxly = baza.appendingPathComponent("Voxly", isDirectory: true)
        tengmi("eng yangi eski papka olindi", faylOqi(voxly, "diktovka-tarixi.json"), "K")
        tekshir(
            "tarjima modeli yoʻq",
            !FileManager.default.fileExists(atPath: voxly.appendingPathComponent("tarjima-model-33b").path))
    }
}
