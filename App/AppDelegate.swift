import UIKit
import WebKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class Tab {
    let id = UUID().uuidString
    let web: WKWebView
    init(web: WKWebView) { self.web = web }
    var isHome: Bool { web.url?.isFileURL ?? true }
    var title: String {
        if isHome { return "Beranda" }
        let t = web.title ?? ""
        return t.isEmpty ? (web.url?.host ?? "Tab") : t
    }
}

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    var tabs: [Tab] = []
    var current = 0
    let bar = UIView()
    let scroll = UIScrollView()
    let stack = UIStackView()
    let content = UIView()
    var home: URL { Bundle.main.url(forResource: "index", withExtension: "html")! }
    var showOnHome: Bool {
        get { UserDefaults.standard.object(forKey: "showTabs") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showTabs") }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.12, alpha: 1)
        [bar, content].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; view.addSubview($0) }
        bar.backgroundColor = UIColor(white: 0.12, alpha: 1)
        let plus = UIButton(type: .system)
        plus.setTitle("＋", for: .normal)
        plus.titleLabel?.font = .systemFont(ofSize: 24)
        plus.tintColor = .white
        plus.addTarget(self, action: #selector(newTab), for: .touchUpInside)
        [scroll, plus].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; bar.addSubview($0) }
        stack.axis = .horizontal; stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        scroll.showsHorizontalScrollIndicator = false
        let g: UILayoutGuide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: g.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 44),
            plus.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
            plus.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            plus.widthAnchor.constraint(equalToConstant: 40),
            scroll.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: plus.leadingAnchor),
            scroll.topAnchor.constraint(equalTo: bar.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
            stack.heightAnchor.constraint(equalToConstant: 32),
            content.topAnchor.constraint(equalTo: bar.bottomAnchor),
            content.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        let tap = UITapGestureRecognizer(target: self, action: #selector(goHome))
        tap.numberOfTouchesRequired = 3
        view.addGestureRecognizer(tap)
        addTab(url: nil)
    }

    // MARK: Tab management
    @discardableResult
    func addTab(url: URLRequest?) -> Tab {
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(self, name: "native")
        let w = WKWebView(frame: .zero, configuration: cfg)
        w.navigationDelegate = self
        w.uiDelegate = self
        w.allowsBackForwardNavigationGestures = true
        w.translatesAutoresizingMaskIntoConstraints = false
        let t = Tab(web: w)
        tabs.append(t)
        if let r = url { w.load(r) } else { w.loadFileURL(home, allowingReadAccessTo: home.deletingLastPathComponent()) }
        select(tabs.count - 1)
        return t
    }

    func select(_ i: Int) {
        guard tabs.indices.contains(i) else { return }
        current = i
        content.subviews.forEach { $0.removeFromSuperview() }
        let w = tabs[i].web
        content.addSubview(w)
        NSLayoutConstraint.activate([
            w.topAnchor.constraint(equalTo: content.topAnchor),
            w.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            w.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            w.trailingAnchor.constraint(equalTo: content.trailingAnchor)
        ])
        refreshUI()
    }

    func close(_ i: Int) {
        guard tabs.indices.contains(i) else { return }
        tabs[i].web.configuration.userContentController.removeScriptMessageHandler(forName: "native")
        tabs.remove(at: i)
        if tabs.isEmpty { addTab(url: nil); return }
        select(min(current > i ? current - 1 : current, tabs.count - 1))
    }

    @objc func newTab() { addTab(url: nil) }
    @objc func goHome() {
        let w = tabs[current].web
        w.loadFileURL(home, allowingReadAccessTo: home.deletingLastPathComponent())
    }
    @objc func tapTab(_ s: UIButton) { select(s.tag) }
    @objc func tapClose(_ s: UIButton) { close(s.tag) }

    // MARK: UI
    func refreshUI() {
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        for (i, t) in tabs.enumerated() {
            let b = UIButton(type: .system)
            var title = t.title
            if title.count > 18 { title = String(title.prefix(18)) + "…" }
            b.setTitle(title, for: .normal)
            b.tag = i
            b.titleLabel?.font = .systemFont(ofSize: 14)
            b.tintColor = .white
            b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 4)
            b.addTarget(self, action: #selector(tapTab(_:)), for: .touchUpInside)
            let x = UIButton(type: .system)
            x.setTitle("✕", for: .normal)
            x.titleLabel?.font = .systemFont(ofSize: 12)
            x.tintColor = UIColor(white: 0.8, alpha: 1)
            x.tag = i
            x.contentEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 10)
            x.addTarget(self, action: #selector(tapClose(_:)), for: .touchUpInside)
            let row = UIStackView(arrangedSubviews: [b, x])
            row.layer.cornerRadius = 10
            row.clipsToBounds = true
            row.backgroundColor = i == current ? UIColor(white: 0.32, alpha: 1) : UIColor(white: 0.2, alpha: 1)
            stack.addArrangedSubview(row)
        }
        pushTabsToHome()
    }

    func pushTabsToHome() {
        var list: [[String: Any]] = []
        for (i, t) in tabs.enumerated() where !t.isHome {
            list.append(["id": i, "title": t.title, "url": t.web.url?.host ?? ""])
        }
        guard let data = try? JSONSerialization.data(withJSONObject: list),
              let json = String(data: data, encoding: .utf8) else { return }
        let js = "if(window.setTabs)setTabs(\(json),\(showOnHome ? "true" : "false"))"
        for t in tabs where t.isHome { t.web.evaluateJavaScript(js, completionHandler: nil) }
    }

    // MARK: Delegates
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { refreshUI() }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { refreshUI() }

    func webView(_ webView: WKWebView, createWebViewWith c: WKWebViewConfiguration, for a: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if a.targetFrame == nil { addTab(url: a.request) }
        return nil
    }

    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let d = message.body as? [String: Any], let a = d["a"] as? String else { return }
        switch a {
        case "switch": if let i = d["id"] as? Int { select(i) }
        case "close": if let i = d["id"] as? Int { close(i) }
        case "new": addTab(url: nil)
        case "toggle": showOnHome = (d["v"] as? Bool) ?? true; pushTabsToHome()
        case "ready": pushTabsToHome()
        default: break
        }
    }
}
