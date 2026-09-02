# yakusoku · iOS

原生 Swift/SwiftUI App：以 WKWebView 承载 yakusoku（https://tianruo.top）聊天服务，
并内置原生加载/错误处理、深浅色同步、文件上传桥接与外链跳转 Safari 等壳能力。

## 目录

```
Yakusoku/
  YakusokuApp.swift     # @main 入口
  AppDelegate.swift     # 生命周期 + 白屏兜底刷新
  RootView.swift        # SwiftUI 容器（加载遮罩 / 断网提示）
  WebViewModel.swift    # WKWebView 配置、导航策略、文件选择、弹窗桥
  WebViewContainer.swift# UIViewRepresentable 接入 + 图片选择代理
  Info.plist            # 权限文案（相册/相机/麦克风）、ATS、深色
project.yml             # XcodeGen 工程描述
build-ipa.sh            # 一键 Archive + 打包 IPA（macOS 运行）
```

## 本地构建（必须 macOS + Xcode）

```bash
brew install xcodegen        # 只装一次
./build-ipa.sh unsigned      # 不签名（越狱机/自签工具装）
TEAM_ID=XXXXXXXXXX ./build-ipa.sh auto    # 免费 Apple ID 自动签名（7 天）
# 有开发者证书：
P12_PATH=/path/cert.p12 P12_PASSWORD=xxx PROVISION=xxx TEAM_ID=XXXX \
EXPORT_METHOD=ad-hoc ./build-ipa.sh cert
```

产物在 `build/yakusoku.ipa`。

## 云端构建（GitHub Actions macOS Runner，免费额度）

推到 GitHub 后，在仓库 Actions 里手动触发 `Build IPA (unsigned)`，
跑完在 workflow 的 Artifacts 中下载 `yakusoku.ipa`。工作流文件见
`.github/workflows/build-ipa.yml`。

## 上架注意

- 服务器为纯 IPv4：Apple 在 NAT64 网络下审核，域名有正常 A 记录即可，
  但建议后续接 Cloudflare 或开通 IPv6，进一步降低白屏风险。
- Bundle ID `com.yakusoku.app` 需在 App Store Connect 中先登记且未被占用。
- 提交前需准备 1024×1024 无透明 App Icon 与 6.9″/6.5″/5.5″ 截图。
- 审核账号：330 / 902（内测白名单直登）。
