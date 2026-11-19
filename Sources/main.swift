import Cocoa
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    var window: NSWindow!
    var webView: WKWebView!

    // ~/Library/Application Support/TypeSpeed/data.json
    let dataURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("TypeSpeed", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()

        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "native")

        // Сохраненный профиль и статистика передаются странице до ее загрузки
        if let data = try? Data(contentsOf: dataURL),
           (try? JSONSerialization.jsonObject(with: data)) != nil,
           let json = String(data: data, encoding: .utf8) {
            let script = WKUserScript(source: "window.__saved = " + json + ";", injectionTime: .atDocumentStart, forMainFrameOnly: true)
            config.userContentController.addUserScript(script)
        }

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1100, height: 700), configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TypeSpeed"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(srgbRed: 0.169, green: 0.176, blue: 0.192, alpha: 1)
        window.appearance = NSAppearance(named: .darkAqua)
        window.minSize = NSSize(width: 860, height: 600)
        window.isReleasedWhenClosed = false
        window.contentView = webView
        window.center()
        window.setFrameAutosaveName("TypeSpeedMain")

        loadPage()

        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(webView)
        NSApp.activate(ignoringOtherApps: true)
    }

    func loadPage() {
        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // Перед выходом забираем у страницы свежие данные и пишем на диск
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard webView != nil else { return .terminateNow }
        var done = false
        let finish = { if !done { done = true; NSApp.reply(toApplicationShouldTerminate: true) } }
        webView.evaluateJavaScript("typeof DB==='object'?JSON.stringify(DB):null") { [weak self] result, _ in
            if let self = self, let json = result as? String, let data = json.data(using: .utf8) {
                try? data.write(to: self.dataURL, options: .atomic)
            }
            finish()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { finish() }
        return .terminateLater
    }

    // Если процесс страницы упал - перезагружаем ее с сохраненными данными
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        if let data = try? Data(contentsOf: dataURL), let json = String(data: data, encoding: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            ucc.addUserScript(WKUserScript(source: "window.__saved = " + json + ";", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        loadPage()
    }

    @objc func showTest(_ sender: Any?) { webView.evaluateJavaScript("window.go&&go('test')") }
    @objc func showProfile(_ sender: Any?) { webView.evaluateJavaScript("window.go&&go('profile')") }
    @objc func showSettings(_ sender: Any?) { webView.evaluateJavaScript("window.go&&go('settings')") }

    // Страница присылает данные для сохранения и цвет темы для заголовка окна
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        if let json = body["save"] as? String, let data = json.data(using: .utf8) {
            try? data.write(to: dataURL, options: .atomic)
            return
        }
        if let hex = body["bg"] as? String, let color = AppDelegate.color(fromHex: hex) {
            window.backgroundColor = color
        }
        if let dark = body["dark"] as? Bool {
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        }
    }

    static func color(fromHex hex: String) -> NSColor? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        return NSColor(
            srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255,
            alpha: 1
        )
    }

    func buildMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "О программе TypeSpeed", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        let settings = NSMenuItem(title: "Настройки…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Скрыть TypeSpeed", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Завершить TypeSpeed", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        // Правка - чтобы в полях (имя, свое время) работали ⌘C / ⌘V / ⌘A
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Правка")
        editMenu.addItem(withTitle: "Отменить", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Вырезать", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Копировать", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Вставить", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Выбрать все", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "Вид")
        for (title, sel, key) in [("Тест", #selector(showTest(_:)), "1"), ("Профиль", #selector(showProfile(_:)), "2"), ("Настройки", #selector(showSettings(_:)), "3")] {
            let item = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            item.target = self
            viewMenu.addItem(item)
        }
        viewItem.submenu = viewMenu
        main.addItem(viewItem)

        let winItem = NSMenuItem()
        let winMenu = NSMenu(title: "Окно")
        winMenu.addItem(withTitle: "Свернуть", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        winMenu.addItem(withTitle: "Закрыть", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let fs = NSMenuItem(title: "Полный экран", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fs.keyEquivalentModifierMask = [.command, .control]
        winMenu.addItem(fs)
        winItem.submenu = winMenu
        main.addItem(winItem)

        NSApp.mainMenu = main
        NSApp.windowsMenu = winMenu
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
