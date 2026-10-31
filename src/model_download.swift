// Kotib — til modeli qayerda va (topilmasa) uni yuklab olish.
//
// 1.2 dan boshlab `.pkg` modelni bundle'dan TASHQARIGA qoʻyadi
// (`Yollar.tizimModellari`) — avto-yangilanish bundle'ni almashtiradi va model
// har safar qayta yuklanmasligi kerak. Qidiruv tartibi va tekshiruv —
// `model_tanlov.swift`. Bu yuklovchi faqat hech qayerda model topilmasa
// ishlaydi va uni foydalanuvchi papkasiga (`Yollar.model`) yozadi.
//
// Uzilgan ulanish uchun HTTP Range bilan davom ettirish bor: yarim yuklangan fayl
// ".part" nomi bilan turadi va keyingi urinishda oʻsha joydan davom etadi.

import AppKit

// MARK: - Model qayerda

enum ModelStore {
    /// Joriy nutq tili (Sozlamalar). Model, hajm, manzil — shu tilniki.
    static var til: NutqTili { Prefs.nutqTili }

    /// Yuklanadigan model — `ModelTanlov.joriy(til)` (hajm/sha256 bitta joyda).
    static var joriyModel: MaʼlumModel { ModelTanlov.joriy(til) }
    static var expectedBytes: Int64 { joriyModel.hajm }
    static var url: URL {
        URL(string: joriyModel.url.isEmpty ? "https://cdn.mirqobilov.com/v1.0/ggml-rubaistt.bin" : joriyModel.url)!
    }

    /// Yuklovchi modelni shu yerga yozadi (foydalanuvchi papkasi — admin paroli kerak emas).
    /// Oʻzbek modeli uchun bu `Yollar.model` bilan bir xil.
    static var downloadedURL: URL { Yollar.foydalanuvchiModellari.appendingPathComponent(joriyModel.fayl) }

    static var partURL: URL { downloadedURL.appendingPathExtension("part") }

    /// Yuklasa boʻladigan modellar, ustuvorlik tartibida — har biri mavjudligi
    /// va HAJMI bilan tekshirilgan (A1). Bundle — CFBundle keshi orqali EMAS,
    /// papka sifatida: kesh oʻchirilgan faylni ham «bor» deb berardi.
    static func nomzodlar(_ til: NutqTili = ModelStore.til) -> [String] {
        var papkalar = [Yollar.foydalanuvchiModellari, Yollar.tizimModellari, Yollar.eskiTizimModellari]
        // 1.1.0 dan oʻtish davri: eski .pkg modelni bundle ichiga qoʻygan.
        if let r = Bundle.main.resourceURL { papkalar.append(r) }
        papkalar.append(Yollar.eskiModellar)
        return ModelTanlov.nomzodlar(papkalar: papkalar, til: til, hajmi: ModelTanlov.faylHajmi).map(\.path)
    }

    static func existingPath() -> String? { nomzodlar().first }

    static var isReady: Bool { existingPath() != nil }
}

// MARK: - Yuklovchi

final class ModelDownloader: NSObject, URLSessionDataDelegate {

    enum Failure: LocalizedError {
        case http(Int)
        case shortFile(Int64, Int64)
        case write(String)
        case buzilgan

        var errorDescription: String? {
            switch self {
            case .http(let code):
                return tr("Сервер не ответил (код \(code)). Проверьте интернет и попробуйте снова.", "The server didn't respond (code \(code)). Check your connection and try again.")
            case .shortFile(let got, let want):
                return tr("Файл скачался не полностью (\(got) / \(want) байт). Попробуйте снова.", "The download is incomplete (\(got) / \(want) bytes). Try again.")
            case .write(let msg):
                return tr("Не удалось записать файл: \(msg). Проверьте место на диске.", "Couldn't write the file: \(msg). Check free disk space.")
            case .buzilgan:
                return tr("Скачанный файл повреждён — попробуйте снова (загрузка начнётся заново).", "The downloaded file is corrupted — try again (it will restart).")
            }
        }
    }

    // Yuklash boshlanganda tanlangan model — til yuklash oʻrtasida
    // oʻzgarsa ham .part va sha256 bitta modelga tegishli boʻlib qoladi.
    private let model = ModelStore.joriyModel
    private let dest = ModelStore.downloadedURL
    private let manzil = ModelStore.url
    private var partURL: URL { dest.appendingPathExtension("part") }

    private var session: URLSession!
    private var task: URLSessionDataTask?
    private var handle: FileHandle?
    private var received: Int64 = 0
    private lazy var total: Int64 = model.hajm

    // Tezlikni oʻlchash uchun
    private var lastTick = Date()
    private var lastBytes: Int64 = 0
    private var speed: Double = 0

    /// (yuklangan, jami, bayt/sek) — asosiy oqimda chaqiriladi.
    var onProgress: ((Int64, Int64, Double) -> Void)?
    /// Yakun — asosiy oqimda chaqiriladi.
    var onFinish: ((Result<Void, Error>) -> Void)?

    func start() {
        let fm = FileManager.default
        let dir = dest.deletingLastPathComponent()
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return finish(.failure(Failure.write(error.localizedDescription)))
        }

        // Yarim yuklangan fayl bormi — oʻsha joydan davom etamiz
        let part = partURL
        var offset: Int64 = 0
        let partSize = (try? fm.attributesOfItem(atPath: part.path)[.size] as? NSNumber)??.int64Value ?? 0
        if partSize == model.hajm {
            // Oldingi urinishda toʻliq yuklangan, lekin yakunlanmagan (masalan
            // ilova shu paytda yopilgan). Ilgari bunday fayl oʻchirilib, 823 MB
            // qaytadan yuklanardi (F2) — endi tarmoqsiz tekshirib yakunlanadi.
            RubaiLog.write("model: .part toʻliq — tarmoqsiz yakunlanmoqda")
            DispatchQueue.global(qos: .userInitiated).async { self.yakunla(part: part, got: partSize) }
            return
        }
        if partSize > 0 && partSize < model.hajm {
            offset = partSize
        } else {
            try? fm.removeItem(at: part)
        }
        if !fm.fileExists(atPath: part.path) {
            fm.createFile(atPath: part.path, contents: nil)
        }
        guard let h = try? FileHandle(forWritingTo: part) else {
            return finish(.failure(Failure.write(tr("не удалось открыть «\(part.lastPathComponent)»", "couldn't open “\(part.lastPathComponent)”"))))
        }
        handle = h
        _ = try? h.seekToEnd()
        received = offset
        lastBytes = offset
        lastTick = Date()

        var req = URLRequest(url: manzil)
        req.timeoutInterval = 60
        if offset > 0 {
            req.setValue("bytes=\(offset)-", forHTTPHeaderField: "Range")
            RubaiLog.write("model: \(offset) baytdan davom ettirilmoqda")
        } else {
            RubaiLog.write("model: yuklab olish boshlandi")
        }

        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForResource = 3600 * 4  // sekin internet uchun keng
        cfg.waitsForConnectivity = true
        session = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
        task = session.dataTask(with: req)
        task?.resume()
    }

    func cancel() {
        onFinish = nil  // kech keladigan javob boshqaruvchi holatini buzmasin
        task?.cancel()
        session?.invalidateAndCancel()
        try? handle?.close()
        handle = nil
        RubaiLog.write("model: yuklab olish bekor qilindi (yarim fayl saqlanib qoldi)")
    }

    // MARK: URLSession delegati

    func urlSession(
        _ s: URLSession, dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.allow); return
        }
        // 206 — davom ettirish qabul qilindi. 200 — server Range'ni qoʻllamadi,
        // demak boshidan keladi: yarim faylni tashlab, noldan yozamiz.
        if http.statusCode == 200 && received > 0 {
            RubaiLog.write("model: server Range'ni qoʻllamadi — noldan boshlanadi")
            try? handle?.truncate(atOffset: 0)
            received = 0
            lastBytes = 0
        } else if http.statusCode != 200 && http.statusCode != 206 {
            completionHandler(.cancel)
            finish(.failure(Failure.http(http.statusCode)))
            return
        }

        if http.expectedContentLength > 0 {
            total = received + http.expectedContentLength
        }
        completionHandler(.allow)
    }

    func urlSession(_ s: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        do {
            try handle?.write(contentsOf: data)
        } catch {
            task?.cancel()
            finish(.failure(Failure.write(error.localizedDescription)))
            return
        }
        received += Int64(data.count)

        // Tezlikni ~0.4s da bir yangilaymiz — UI titramasin
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        if dt >= 0.4 {
            speed = Double(received - lastBytes) / dt
            lastTick = now
            lastBytes = received
            let r = received, t = total, sp = speed
            DispatchQueue.main.async { self.onProgress?(r, t, sp) }
        }
    }

    func urlSession(_ s: URLSession, task t: URLSessionTask, didCompleteWithError error: Error?) {
        try? handle?.close()
        handle = nil
        // Sessiya delegatini (bizni) kuchli ushlaydi — boʻshatilmasa yuklovchi
        // abadiy xotirada qolardi (F3).
        s.finishTasksAndInvalidate()

        if let e = error {
            // Bekor qilish — xato emas, foydalanuvchi oʻzi toʻxtatgan
            if (e as NSError).code == NSURLErrorCancelled { return }
            RubaiLog.write("model: tarmoq xatosi — \(e.localizedDescription)")
            finish(.failure(e))
            return
        }

        // Hajm tekshiruvi — yarim yoki buzilgan fayl bilan ishga tushmaymiz
        let part = partURL
        let got = (try? FileManager.default.attributesOfItem(atPath: part.path)[.size] as? NSNumber)??.int64Value ?? 0
        guard got >= model.hajm else {
            finish(.failure(Failure.shortFile(got, model.hajm)))
            return
        }
        yakunla(part: part, got: got)
    }

    /// sha256 tekshiruvi va atomik yakun. Fon oqimida chaqiriladi (~2 s).
    private func yakunla(part: URL, got: Int64) {
        // Hajm toʻgʻri boʻlsa ham ichi buzilgan boʻlishi mumkin (disk, tarmoq
        // proksisi). Buzilgan model whisper'da «Model yuklanmadi» boʻlib
        // chiqardi — endi bu yerda tutiladi va .part oʻchiriladi.
        guard ModelTanlov.faylSha256(part) == model.sha256 else {
            try? FileManager.default.removeItem(at: part)
            RubaiLog.write("model: sha256 mos emas — .part oʻchirildi")
            finish(.failure(Failure.buzilgan))
            return
        }

        // Atomik yakun: toʻliq fayl boʻlgandagina asl nomga oʻtadi
        do {
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: part, to: dest)
            RubaiLog.write("model: yuklab olindi (\(got) bayt) → \(dest.path)")
            finish(.success(()))
        } catch {
            finish(.failure(Failure.write(error.localizedDescription)))
        }
    }

    private func finish(_ r: Result<Void, Error>) {
        DispatchQueue.main.async {
            self.onFinish?(r); self.onFinish = nil
        }
    }
}

// MARK: - Yuklab olish oynasi

final class ModelDownloadWindow: NSObject {
    private var window: NSWindow?
    private var bar: NSProgressIndicator!
    private var statusLabel: NSTextField!
    private var noteLabel: NSTextField!
    private var actionButton: NSButton!  // tr("Отмена", "Cancel") yoki tr("Повторить", "Try again")
    private var downloader: ModelDownloader?
    private var failed = false
    /// Yuklash ketayotganini belgilaydi. Busiz show() har chaqirilganda ikkinchi
    /// yuklovchi ishga tushib, ikkalasi bitta .part fayliga yozadi va model buziladi.
    private var isDownloading = false

    /// Model tayyor boʻlganda chaqiriladi (onboarding shundan keyin boshlanadi).
    var onReady: (() -> Void)?

    private static let fmt: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useMB, .useGB]
        f.countStyle = .file
        return f
    }()

    func show() {
        if window == nil { build() }
        presentWindow()
        // Allaqachon yuklanayotgan boʻlsa — faqat oynani koʻrsatamiz, qayta boshlamaymiz
        if !isDownloading && !failed { beginDownload() }
    }

    /// Oynani ekranga chiqaradi.
    ///
    /// Ilova LSUIElement (menyu satri ilovasi) boʻlgani uchun makeKeyAndOrderFront
    /// yolgʻiz oʻzi yetarli emas — ishga tushish paytida oyna ekranga umuman
    /// chiqmaydi. orderFrontRegardless() ilova faol boʻlmasa ham majburan koʻrsatadi;
    /// loyihadagi Overlay ham xuddi shu sababdan shuni ishlatadi.
    private func presentWindow() {
        guard let w = window else { return }
        NSApp.activate(ignoringOtherApps: true)
        w.center()
        w.makeKeyAndOrderFront(nil)
        w.orderFrontRegardless()
    }

    private let W: CGFloat = 460
    private let H: CGFloat = 250

    private func build() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: W, height: H),
            styleMask: [.titled], backing: .buffered, defer: false)
        w.title = "Voxly"
        w.isReleasedWhenClosed = false
        let v = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))

        let icon = NSImageView(frame: NSRect(x: (W - 56) / 2, y: H - 78, width: 56, height: 56))
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        v.addSubview(icon)

        let title = NSTextField(labelWithString: tr("Скачиваю модель распознавания", "Downloading the speech model"))
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: H - 108, width: W - 40, height: 22)
        v.addSubview(title)

        noteLabel = NSTextField(
            wrappingLabelWithString:
                tr("Это нужно один раз. Модель ~\(ModelStore.expectedBytes / 1_048_576) МБ — в зависимости от интернета ", "This happens once. The model is ~\(ModelStore.expectedBytes / 1_048_576) MB — depending on your connection ")
                + tr("займёт 5–20 минут. Если связь прервётся, загрузка продолжится с того же места.", "it takes 5–20 minutes. If the connection drops, it resumes where it left off."))
        noteLabel.font = .systemFont(ofSize: 11)
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.alignment = .center
        noteLabel.frame = NSRect(x: 30, y: H - 150, width: W - 60, height: 34)
        v.addSubview(noteLabel)

        bar = NSProgressIndicator(frame: NSRect(x: 30, y: 84, width: W - 60, height: 12))
        bar.isIndeterminate = true
        bar.minValue = 0
        bar.maxValue = 1
        bar.style = .bar
        v.addSubview(bar)

        statusLabel = NSTextField(labelWithString: tr("Подключаюсь…", "Connecting…"))
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.frame = NSRect(x: 30, y: 62, width: W - 60, height: 16)
        v.addSubview(statusLabel)

        actionButton = NSButton(title: tr("Отмена", "Cancel"), target: self, action: #selector(actionPressed))
        actionButton.bezelStyle = .rounded
        actionButton.frame = NSRect(x: W - 30 - 130, y: 20, width: 130, height: 30)
        v.addSubview(actionButton)

        w.contentView = v
        window = w
    }

    private func beginDownload() {
        guard !isDownloading else { return }
        isDownloading = true
        failed = false
        actionButton.title = tr("Отмена", "Cancel")
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = tr("Подключаюсь…", "Connecting…")
        bar.isIndeterminate = true
        bar.startAnimation(nil)

        let d = ModelDownloader()
        d.onProgress = { [weak self] got, total, speed in
            guard let self = self else { return }
            self.bar.isIndeterminate = false
            self.bar.doubleValue = total > 0 ? Double(got) / Double(total) : 0
            let g = Self.fmt.string(fromByteCount: got)
            let t = Self.fmt.string(fromByteCount: total)
            let s = Self.fmt.string(fromByteCount: Int64(speed))
            self.statusLabel.stringValue = "\(g) / \(t)  ·  \(s)/s"
        }
        d.onFinish = { [weak self] result in
            guard let self = self else { return }
            self.isDownloading = false
            switch result {
            case .success:
                self.bar.doubleValue = 1
                self.statusLabel.stringValue = tr("Готово!", "Done!")
                self.window?.close()
                self.onReady?()
            case .failure(let e):
                self.showFailure(e)
            }
        }
        downloader = d
        d.start()
    }

    private func showFailure(_ e: Error) {
        failed = true
        bar.stopAnimation(nil)
        bar.isIndeterminate = false
        statusLabel.textColor = .systemRed
        statusLabel.stringValue = e.localizedDescription
        noteLabel.stringValue =
            tr("Скачанная часть сохранена — при повторе ", "The downloaded part is kept — the next attempt ")
            + tr("загрузка продолжится с того же места.", "resumes where it left off.")
        actionButton.title = tr("Повторить", "Try again")
    }

    @objc private func actionPressed() {
        if failed {
            beginDownload()
            return
        }
        // Bekor qilish — ilova modelsiz ishlay olmaydi, shuning uchun ogohlantiramiz
        let a = NSAlert()
        a.messageText = tr("Остановить загрузку?", "Stop the download?")
        a.informativeText =
            tr("Без модели диктовка не работает. Скачанная часть сохранится — ", "Dictation doesn't work without the model. The downloaded part is kept — ")
            + tr("продолжить можно позже через значок 🎙 в строке меню.", "you can resume later from the 🎙 icon in the menu bar.")
        a.alertStyle = .warning
        a.addButton(withTitle: tr("Продолжить", "Continue"))
        a.addButton(withTitle: tr("Остановить", "Stop"))
        if a.runModal() == .alertSecondButtonReturn {
            downloader?.cancel()
            // Holat toʻliq tiklanadi: ilgari `isDownloading` true qolib, keyingi
            // `show()` yuklashni davom ettirmasdi (F1). `.part` saqlanadi.
            downloader = nil
            isDownloading = false
            window?.close()
        }
    }
}
