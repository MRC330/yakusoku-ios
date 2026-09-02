import SwiftUI
import WebKit

/// 把 WebViewModel 持有的 WKWebView 接进 SwiftUI
struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var model: WebViewModel

    func makeUIView(context: Context) -> WKWebView {
        model.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 深浅色切换时同步给网页
        model.refreshTheme()
    }
}

extension WebViewModel {
    func refreshTheme() {
        webView.evaluateJavaScript(Self.themeBridgeJS, completionHandler: nil)
    }
}

// MARK: - 图片选择代理

final class PhotoPickerProxy: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    static let shared = PhotoPickerProxy()
    var onPick: ((UIImage?) -> Void)?

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
        picker.dismiss(animated: true) { self.onPick?(image) }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { self.onPick?(nil) }
    }
}

// MARK: - 取当前顶层 VC

enum TopViewController {
    static func present(_ vc: UIViewController, animated: Bool) {
        current()?.present(vc, animated: animated)
    }

    static func alert(title: String?,
                      message: String?,
                      actions: [(String, UIAlertAction.Style, (() -> Void)?)],
                      handler: @escaping (Int) -> Void) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        actions.enumerated().forEach { index, item in
            ac.addAction(UIAlertAction(title: item.0, style: item.1) { _ in
                item.2?()
                handler(index)
            })
        }
        current()?.present(ac, animated: true)
    }

    private static func current() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }

        var top = root
        while let next = top.presentedViewController { top = next }
        return top
    }
}
