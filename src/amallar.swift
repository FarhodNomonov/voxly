// Studio amallari va ularning prompt'lari.
// Prompt'lar inglizcha; javob — transkriptning oʻz tilida.

import Foundation

struct Amal {
    let id: String
    let nom: String
    /// true — natija butun matndan yigʻiladi (map-reduce kerak).
    /// false — matnni oʻzgartiradi (boʻlaklar ketma-ket ulanadi).
    /// DIQQAT: maydonlar tartibi quyidagi Amal(...) chaqiruvlari bilan mos —
    /// Swift memberwise init argumentlarni AYNAN shu tartibda kutadi.
    let yiguvchi: Bool
    let system: String
}

/// Har bir prompt'ga qoʻshiladigan umumiy qoidalar. Prompt'lar inglizcha —
/// modellar ularni eng aniq bajaradi; javob tili esa matnning oʻz tili.
private let umumiyQoida = """
    You work on a speech-to-text transcript.

    Strict rules:
    - Reply in the SAME language and script as the transcript (Russian stays in
      Cyrillic, Uzbek stays in Latin, English stays English). Do not translate.
    - Do NOT change the meaning. Do NOT add facts that are not in the text.
    - Return only the result. No preamble like "Here is the result" or "Sure".
    """

private func amal(_ id: String, _ nom: String, yiguvchi: Bool, _ vazifa: String) -> Amal {
    Amal(id: id, nom: nom, yiguvchi: yiguvchi, system: umumiyQoida + "\n\nYour task: " + vazifa)
}

let amallar: [Amal] = [
    amal(
        "tozalash", tr("Почистить текст", "Clean up"), yiguvchi: false,
        """
        make the transcript easy to read.
        - Fix punctuation.
        - Split into meaningful paragraphs.
        - Remove filler words, false starts and repeated words.
        - Turn half-finished sentences into complete ones.
        - Write numbers as digits ("twenty five" → "25").
        """),
    amal(
        "xulosa", tr("Краткое содержание", "Summary"), yiguvchi: true,
        "write a 3–5 sentence summary of the text."),
    amal(
        "asosiy_fikrlar", tr("Главные мысли", "Key points"), yiguvchi: true,
        "list the key points as a bulleted list (each line starts with \"- \")."),
    amal(
        "bayonnoma", tr("Протокол встречи", "Meeting minutes"), yiguvchi: true,
        """
        write meeting minutes with three sections: what was discussed, decisions,
        action items. Use section titles in the transcript's language. Leave a
        section empty if the text has nothing for it — do not invent.
        """),
    amal(
        "maqola", tr("Статья", "Article"), yiguvchi: false,
        "rewrite the text as an article or blog post with a title, subheadings and paragraphs."),
    amal(
        "savol_javob", tr("Вопросы и ответы", "Q&A"), yiguvchi: true,
        "write a FAQ based on the text. Start each question with \"**Q:** \" and each answer with \"**A:** \"."),
    amal(
        "qisqartirish", tr("Сократить", "Shorten"), yiguvchi: false,
        "shorten the text to about half its length, keeping all important information."),
    amal(
        "uzaytirish", tr("Расширить", "Expand"), yiguvchi: false,
        "write the text out in more detail — fuller sentences, clearer ideas. Do not add new FACTS.")
]

/// Erkin soʻrov — foydalanuvchi oʻz koʻrsatmasini yozadi.
func erkinAmal(_ korsatma: String) -> Amal {
    Amal(
        id: "erkin", nom: tr("Свой запрос", "Custom request"), yiguvchi: false,
        system: umumiyQoida + "\n\nUser instruction: \(korsatma)")
}

/// Bitta boʻlakka beriladigan maksimal soʻz soni.
private let bolakSozLimiti = 3000

final class AmalIshi {
    private let mijoz = LLMMijoz()

    /// Amalni bajaradi. Uzun matn boʻlaklanadi. Qaytarilgan `Task`ni chaqiruvchi
    /// "Bekor qilish" uchun `.cancel()` qilishi mumkin (I6) — `URLSession.bytes`
    /// bekor qilishni hurmat qiladi, shu bilan oqim toʻxtaydi.
    @discardableResult
    func bajar(
        amal: Amal, matn: String,
        onDelta: @escaping (String) -> Void,
        onTayyor: @escaping (String) -> Void,
        onXato: @escaping (String) -> Void
    ) -> Task<Void, Never>? {
        guard let p = LLMSozlama.tanlangan, LLMSozlama.sozlanganmi else {
            onXato(LLMXato.kalitYoq.xabar); return nil
        }
        let bolaklar = paragrafBolaklari(matn, maxSoz: bolakSozLimiti)
        guard !bolaklar.isEmpty else { onXato(tr("Текст пустой.", "The text is empty.")); return nil }

        return Task {
            do {
                let natija: String
                if bolaklar.count == 1 {
                    natija = try await bitta(p, amal, bolaklar[0], onDelta)
                } else if amal.yiguvchi {
                    natija = try await yig(p, amal, bolaklar, onDelta)
                } else {
                    natija = try await ketmaKet(p, amal, bolaklar, onDelta)
                }
                await MainActor.run { onTayyor(natija) }
            } catch {
                // Bekor qilingan boʻlsa (Task.cancel()) buni alohida ushlaymiz —
                // aks holda foydalanuvchi oʻzi bosgan "Bekor qilish" tugmasi
                // uchun "Tarmoqqa ulanib boʻlmadi" kabi chalgʻituvchi xato
                // koʻrsatilar edi.
                let xabar: String
                if Task.isCancelled {
                    xabar = tr("Отменено.", "Cancelled.")
                } else if let e = error as? LLMXato {
                    xabar = e.xabar
                } else {
                    xabar = LLMXato.tarmoq.xabar
                }
                await MainActor.run { onXato(xabar) }
            }
        }
    }

    private func bitta(
        _ p: Provayder, _ amal: Amal, _ matn: String,
        _ onDelta: @escaping (String) -> Void
    ) async throws -> String {
        var yigilgan = ""
        try await mijoz.oqim(
            provayder: p, baseURL: LLMSozlama.baseURL,
            model: LLMSozlama.model, kalit: LLMSozlama.joriyKalit,
            system: amal.system, user: matn,
            onDelta: { d in
                yigilgan += d
                // DispatchQueue.main.async — FIFO kafolatlanadi;
                // mustaqil yaratilgan Task'lar orasida Swift
                // hech qanday tartib kafolatini bermaydi (M9).
                DispatchQueue.main.async { onDelta(d) }
            })
        return yigilgan
    }

    /// Oʻzgartiruvchi amallar: har bir boʻlak alohida, natijalar ulanadi.
    private func ketmaKet(
        _ p: Provayder, _ amal: Amal, _ bolaklar: [String],
        _ onDelta: @escaping (String) -> Void
    ) async throws -> String {
        var natijalar: [String] = []
        for (i, b) in bolaklar.enumerated() {
            if i > 0 { DispatchQueue.main.async { onDelta("\n\n") } }
            natijalar.append(try await bitta(p, amal, b, onDelta))
        }
        return natijalar.joined(separator: "\n\n")
    }

    /// Yigʻuvchi amallar: har bir boʻlak qisqartiriladi, soʻng yakuniy soʻrov.
    private func yig(
        _ p: Provayder, _ amal: Amal, _ bolaklar: [String],
        _ onDelta: @escaping (String) -> Void
    ) async throws -> String {
        let oraliqAmal = Amal(
            id: "oraliq", nom: "", yiguvchi: false,
            system: umumiyQoida
                + "\n\nYour task: briefly write down the main content of this part. "
                + "It will be merged with other parts in the next step.")
        var oraliq: [String] = []
        for b in bolaklar {
            oraliq.append(try await bitta(p, oraliqAmal, b, { _ in }))
        }
        return try await bitta(p, amal, oraliq.joined(separator: "\n\n"), onDelta)
    }
}
