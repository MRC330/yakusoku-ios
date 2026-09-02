import UIKit
import WebKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 关掉 UIWebView 遗留的键盘自动缩放问题
        UITextField.appearance().keyboardDismissMode = .interactive
        return true
    }

    // 后台回来时刷新一下，避免 WKWebView 被系统回收后白屏
    func applicationDidBecomeActive(_ application: UIApplication) {
        WebViewStore.shared.reloadIfBlank()
    }
}

/// 全局持有，方便 AppDelegate 通知到具体的 WebView
final class WebViewStore {
    static let shared = WebViewStore()
    private(set) weak var webView: WKWebView?

    func attach(_ wv: WKWebView) { webView = wv }

    func reloadIfBlank() {
        guard let wv = webView else { return }
        wv.evaluateJavaScript("document.body && document.body.innerHTML.length") { value, _ in
            let len = (value as? Int) ?? 0
            if len < 32 { wv.reload() }
        }
    }
}
