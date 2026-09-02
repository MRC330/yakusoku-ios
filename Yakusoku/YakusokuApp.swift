import SwiftUI

@main
struct YakusokuApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                // 整 App 跟着系统深浅色走，和网页端的 data-theme 保持一致
                .preferredColorScheme(nil)
        }
    }
}
