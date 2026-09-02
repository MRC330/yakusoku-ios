import Foundation
import WebKit
import Combine

/// 站点地址。改这里就能指向别的环境。
enum YakusokuConfig {
    static let homeURL = URL(string: "https://tianruo.top")!
    /// 允许在外部 Safari 打开的域名白名单（其余站内跳转一律留在 App 内）
    static let externalHosts: Set<String> = []
    /// 允许打开的 URL scheme
    static let allowedSchemes: Set<String> = ["http", "https", "tel", "mailto", "sms"]
}

@MainActor
final class WebViewModel: NSObject, ObservableObject {

    @Published private(set) var isLoading = true
    @Published private(set) var progress: Double = 0
    @Published var notice: String?

    private var progressObservation: NSKeyValueObservation?
    private(set) var webView: WKWebView!
    private var didLoad = false

    override init() {
        super.init()
        webView = makeWebView()
        WebViewStore.shared.attach(webView)
        observeProgress()
    }

    // MARK: - WKWebView 构造

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true           // 视频内联播放，不全屏
        config.mediaTypesRequiringUserActionForPlayback = [.video]
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.suppressesIncrementalRendering = false

        // localStorage / cookie 持久化，保证登录态不丢
        config.websiteDataStore = .default()

        // 注入一小段脚本：让网页跟随系统深浅色（网页端读 prefers-color-scheme）
        let themeScript = WKUserScript(
            source: Self.themeBridgeJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(themeScript)

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.scrollView.bounces = false                      // 页面自己处理滚动回弹
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.allowsBackForwardNavigationGestures = false     // 聊天页有内部路由，交给网页
        wv.isOpaque = false
        wv.backgroundColor = UIColor.systemBackground
        return wv
    }

    /// 把系统外观同步给网页：写 localStorage 的 theme，并加 / 去 data-theme
    static let themeBridgeJS = """
    (function () {
      try {
        var dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
        var t = dark ? 'dark' : 'light';
        document.documentElement.setAttribute('data-theme', t);
        var meta = document.querySelector('meta[name="theme-color"]');
        if (meta) meta.setAttribute('content', dark ? '#0B0B0C' : '#F4F4F6');
      } catch (e) {}
    })();
    """

    private func observeProgress() {
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
            guard let self else { return }
            Task { @MainActor in
                self.progress = wv.estimatedProgress
            }
        }
    }

    // MARK: - 对外操作

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        reload()
    }

    func reload() {
        notice = nil
        let request = URLRequest(url: YakusokuConfig.homeURL, cachePolicy: .reloadRevalidatingCacheData)
        webView.load(request)
    }
}

// MARK: - WKNavigationDelegate

extension WebViewModel: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        notice = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        progress = 1
        // 网页端自己的 Theme 初始化会覆盖 data-theme，这里再兜一次底
        webView.evaluateJavaScript(Self.themeBridgeJS, completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handle(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handle(error)
    }

    private func handle(_ error: Error) {
        isLoading = false
        let ns = error as NSError
        // WebKit 在加载被新导航打断时会抛 102，忽略即可
        if ns.domain == "WebKitErrorDomain" && ns.code == 102 { return }
        if ns.code == NSURLErrorCancelled { return }
        notice = ns.code == NSURLErrorNotConnectedToInternet
            ? "没有网络连接，检查网络后重试"
            : "加载失败：\(ns.localizedDescription)"
    }

    /// 决定导航是否放行：外链交给 Safari，站内留在 App
    func webView(
        _ webView: WKWebView,
        decidePolicyFor action: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = action.request.url else {
            decisionHandler(.allow)
            return
        }

        if let scheme = url.scheme?.lowercased(), !YakusokuConfig.allowedSchemes.contains(scheme) {
            // tel: / mailto: / 微信等外部 scheme
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
            return
        }

        guard let host = url.host?.lowercased() else {
            decisionHandler(.allow)
            return
        }

        let isSelf = host == YakusokuConfig.homeURL.host?.lowercased()
            || host.hasSuffix("." + (YakusokuConfig.homeURL.host?.lowercased() ?? ""))

        if isSelf || YakusokuConfig.externalHosts.contains(host) {
            decisionHandler(.allow)
        } else {
            UIApplication.shared.open(url)   // 站外跳 Safari
            decisionHandler(.cancel)
        }
    }
}

// MARK: - WKUIDelegate（新窗口 / 文件上传 / 弹窗）

extension WebViewModel: WKUIDelegate {

    /// target="_blank" 的链接在当前 WebView 打开
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    /// <input type="file"> —— 不实现这个方法，网页里点选图片会毫无反应
    @available(iOS 18.4, *)
    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image"]
        picker.delegate = PhotoPickerProxy.shared
        PhotoPickerProxy.shared.onPick = { image in
            guard let image else { completionHandler(nil); return }
            // WKWebView 只能拿文件路径，先把选中的图写到临时目录
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("yakusoku-upload", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let file = dir.appendingPathComponent("pick-\(UUID().uuidString).jpg")
            if let data = image.jpegData(compressionQuality: 0.9) {
                try? data.write(to: file)
                completionHandler([file])
            } else {
                completionHandler(nil)
            }
        }
        TopViewController.present(picker, animated: true)
    }

    /// JS 的 alert / confirm / prompt
    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        TopViewController.alert(title: "yakusoku", message: message, actions: [("好", .default, nil)]) { _ in
            completionHandler()
        }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        TopViewController.alert(title: "yakusoku", message: message,
                                actions: [("取消", .cancel, nil), ("确定", .default, nil)]) { index in
            completionHandler(index == 1)
        }
    }
}
